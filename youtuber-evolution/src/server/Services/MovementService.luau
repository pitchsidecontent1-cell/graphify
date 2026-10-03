--!strict
-- The +1 loop, server-authoritative:
--   * walking: every Economy.StudsPerStep studs = 1 step = ViewsPerStep views
--   * treadmills: passive views/sec while standing in a zone you've unlocked
--   * gates: anyone past a gate they haven't unlocked gets pushed back
--   * clout pads: claim -> clout + celebration -> back to spawn
--   * portals + rival monitors

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Stats = require(Shared.Util.Stats)
local Economy = require(Shared.Config.Economy)
local Treadmills = require(Shared.Config.Treadmills)
local Worlds = require(Shared.Config.Worlds)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local ProgressService = require(script.Parent.ProgressService)
local CharacterService = require(script.Parent.CharacterService)
local Comms = require(script.Parent.Comms)

local MovementService = {}

local TICK = 0.2

type Tracker = {
	last: Vector3?,
	steps: number, -- fractional step accumulator
	claimAt: number,
	graceUntil: number, -- ignore movement (after teleports)
	treadmill: number, -- current treadmill tier (0 = none)
	pushBackAt: number,
}

local trackers: { [Player]: Tracker } = {}

local function tracker(player: Player): Tracker
	local t = trackers[player]
	if not t then
		t = { last = nil, steps = 0, claimAt = 0, graceUntil = 0, treadmill = 0, pushBackAt = 0 }
		trackers[player] = t
	end
	return t
end

-- Call after moving a character so the jump isn't counted as steps.
function MovementService.Grace(player: Player, seconds: number?)
	local t = tracker(player)
	t.graceUntil = os.clock() + (seconds or 1)
	t.last = nil
end

function MovementService.TreadmillTier(player: Player): number
	local t = trackers[player]
	return if t then t.treadmill else 0
end

function MovementService.ToSpawn(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	MovementService.Grace(player, 1.5)
	CharacterService.SendToWorld(player, data.World)
end

local function inside(part: BasePart, pos: Vector3): boolean
	local localPos = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

local function treadmillAllowed(data: any, ctx: any, tier: number): boolean
	local t = Treadmills[tier]
	if not t then
		return false
	end
	if t.Pass then
		return ctx.Passes[t.Pass] == true
	end
	return data.Rebirths >= t.Rebirths
end

local function claimPad(player: Player, world: number, gate: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local ctx = DataService.Context(player)
	local reward = Stats.PadReward(data, ctx, world, gate)
	ProgressService.AddClout(player, reward)
	data.Stats.Claims += 1
	DataService.Dirty(player, "Stats")
	Comms.Effect(player, "Claim", { Amount = reward, World = world, Gate = gate })
	-- short celebration, then back to spawn to walk again (+views!)
	task.delay(0.35, function()
		if player.Parent then
			MovementService.ToSpawn(player)
		end
	end)
end

local function processPlayer(player: Player, now: number)
	local data = DataService.Get(player)
	local root = CharacterService.Root(player)
	if not data or not root then
		return
	end
	local char = player.Character :: Model
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local t = tracker(player)
	local pos = root.Position
	local ctx = DataService.Context(player)
	local world = MapService.WorldAt(pos)

	-- Walking -------------------------------------------------------------------
	if now >= t.graceUntil and t.last then
		local last = t.last :: Vector3
		local delta = Vector3.new(pos.X - last.X, 0, pos.Z - last.Z).Magnitude
		local maxAllowed = math.max(hum.WalkSpeed, 1) * TICK * Economy.MaxStepStuds + 0.5
		local seated = hum.Sit or hum:GetState() == Enum.HumanoidStateType.Seated
		if delta > 0.05 and delta <= maxAllowed and not seated then
			t.steps += delta / Economy.StudsPerStep
			local whole = math.floor(t.steps)
			if whole > 0 then
				t.steps -= whole
				data.Stats.Steps += whole
				ProgressService.AddViews(player, whole * Stats.ViewsPerStep(data, ctx))
			end
		end
	end
	t.last = pos

	-- Treadmills ----------------------------------------------------------------------
	local onTier = 0
	for _, zone in (MapService.Zones[world] or {}) :: { MapService.Zone } do
		if inside(zone.Part, pos) then
			onTier = zone.Tier
			break
		end
	end
	if onTier ~= t.treadmill then
		t.treadmill = onTier
		player:SetAttribute("Treadmill", onTier)
		if onTier > 0 and not treadmillAllowed(data, ctx, onTier) then
			local tm = Treadmills[onTier]
			if tm.Pass then
				Comms.Notify(player, "🔒 This treadmill needs the " .. tm.Name .. " gamepass!", "error")
			else
				Comms.Notify(player, "🔒 Needs " .. tm.Rebirths .. " rebirths!", "error")
			end
		end
	end
	if onTier > 0 and treadmillAllowed(data, ctx, onTier) then
		local tm = Treadmills[onTier]
		ProgressService.AddViews(player, Stats.TreadmillPerSecond(data, ctx, tm.Mult) * TICK)
	end

	-- Gates (anti-exploit push back) ------------------------------------------------------
	-- (admins flying / noclipping for testing are allowed through, and so is
	-- anyone in a View War: admins can start one before opening every gate)
	local bypass = player:GetAttribute("AdminFly") == true
		or player:GetAttribute("AdminNoclip") == true
		or player:GetAttribute("InBattle") == true
	local video = Stats.VideoLevel(data.Views)
	for _, gate in (if bypass then {} else MapService.Gates[world] or {}) :: { MapService.Gate } do
		if gate.Video > video then
			local localPos = gate.Part.CFrame:PointToObjectSpace(pos)
			if localPos.Z > 1.5 and math.abs(localPos.X) < 60 and localPos.Y > -10 and localPos.Y < 40 then
				if now - t.pushBackAt > 0.5 then
					t.pushBackAt = now
					MovementService.Grace(player, 0.6)
					MapService.Teleport(char, gate.Part.CFrame * CFrame.new(0, -7, -8) * CFrame.Angles(0, math.pi, 0))
					Comms.Notify(player, "🔒 Reach VIDEO " .. gate.Video .. " to pass this gate!", "error")
				end
			end
			break -- only the first locked gate matters
		end
	end

	-- Rival monitor -------------------------------------------------------------------------
	local monitor = MapService.RivalGates[world]
	if monitor and not bypass and not data.RivalsBeaten[tostring(world)] then
		local localPos = monitor.CFrame:PointToObjectSpace(pos)
		if localPos.Z > 1.5 and math.abs(localPos.X) < 75 and math.abs(localPos.Y) < 40 then
			MovementService.Grace(player, 0.6)
			MapService.Teleport(char, monitor.CFrame * CFrame.new(0, -12, -14) * CFrame.Angles(0, math.pi, 0))
		end
	end

	-- Clout pads ------------------------------------------------------------------------------
	if now >= t.claimAt then
		local open = Stats.OpenGates(data, world)
		for _, pad in (MapService.Pads[world] or {}) :: { MapService.Pad } do
			local offset = pos - pad.Part.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= pad.Radius + 1 and math.abs(offset.Y) < 7 then
				if pad.Gate <= open then
					t.claimAt = now + Economy.Clout.ClaimCooldown
					claimPad(player, world, pad.Gate)
				end
				break
			end
		end
	end

	-- Portals -----------------------------------------------------------------------------------
	local portal = MapService.Portals[world]
	if portal then
		local offset = pos - portal.Position
		if offset.Magnitude < 10 then
			local target = portal:GetAttribute("Target")
			if typeof(target) == "number" and Worlds[target] then
				if data.Unlocked[tostring(target)] then
					MovementService.Grace(player, 1.5)
					CharacterService.SendToWorld(player, target)
					Comms.Effect(player, "World", { World = target })
				elseif now - t.pushBackAt > 1 then
					t.pushBackAt = now
					Comms.Notify(
						player,
						"Beat " .. Worlds[world].Rival.Name .. " to unlock " .. Worlds[target].Name .. "!",
						"error"
					)
				end
			end
		end
	end

	-- keep data.World in sync if they walked/fell somewhere else
	if world ~= data.World and data.Unlocked[tostring(world)] then
		data.World = world
		DataService.Dirty(player, "World")
	end
end

function MovementService.Init()
	Comms.On("ReturnToSpawn", 1, function(player)
		if player:GetAttribute("InBattle") then
			return Comms.Fail("Finish your View War first!")
		end
		MovementService.ToSpawn(player)
		return Comms.Ok()
	end)
	Comms.On("TeleportWorld", 1, function(player, payload)
		local data = DataService.Get(player)
		local world = Comms.Int(payload.World, 1, #Worlds)
		if not data or not world then
			return Comms.Fail("Unknown world")
		end
		if not data.Unlocked[tostring(world)] then
			return Comms.Fail("You haven't unlocked " .. Worlds[world].Name .. " yet!")
		end
		if player:GetAttribute("InBattle") then
			return Comms.Fail("Finish your View War first!")
		end
		MovementService.Grace(player, 1.5)
		CharacterService.SendToWorld(player, world)
		Comms.Effect(player, "World", { World = world })
		return Comms.Ok()
	end)
end

function MovementService.Start()
	Players.PlayerRemoving:Connect(function(player)
		trackers[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			MovementService.Grace(player, 2)
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(processPlayer :: any, player, now)
				if not ok then
					warn("[Movement] " .. tostring(err))
				end
			end
		end
	end)
end

return MovementService
