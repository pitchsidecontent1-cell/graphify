-- Economy simulator: plays an idealised player using the real Config tables
-- and prints when they hit each milestone. Tune Config/Economy, Worlds gates
-- and Devices, then re-run:
--   rojo build default.project.json -o build/base.rbxl
--   lune run tools/simulate.luau build/base.rbxl [extraMultiplier]
--
-- Model: walk to the deepest open clout pad, claim, teleport back, buy every
-- affordable device, rebirth as soon as allowed, beat the rival when all gates
-- are open and views >= rival power. Pets/niches/passes are folded into the
-- optional extraMultiplier (default 1 = a free player who ignores them).

local process = require("@lune/process")
local rbxenv = require("./rbxenv")

local game = rbxenv.loadPlace(process.args[1] or "build/base.rbxl")
local env = rbxenv.new(game)
local Shared = game:GetService("ReplicatedStorage").Shared
local Stats = env.require(Shared.Util.Stats)
local Devices = env.require(Shared.Config.Devices)
local Worlds = env.require(Shared.Config.Worlds)
local Economy = env.require(Shared.Config.Economy)
local Format = env.require(Shared.Util.Format)
local Layout = env.require(game:GetService("ServerScriptService").Server.Map.Layout)

local extra = tonumber(process.args[2]) or 1
local ctx = { Passes = {}, Friends = 0, Premium = false, Group = false }

local data = {
	Views = 0,
	Clout = 0,
	Rebirths = 0,
	Devices = { d1 = true },
	Equipped = "d1",
	Upgrades = {},
	Pets = {},
	EquippedPets = {},
	Niche = "",
	Potions = { Views = 0, Clout = 0 },
	Unlocked = { ["1"] = true },
	RivalsBeaten = {},
}

local speed = Economy.BaseWalkSpeed
local world = 1
local t = 0
local seen = {}
local function mark(label)
	if seen[label] then
		return
	end
	seen[label] = true
	local video = Stats.VideoLevel(data.Views)
	local d = Devices.ById[data.Equipped]
	print(
		string.format(
			"%-22s %7.1f min  rebirths=%-3d device=%-18s W%d  video=%-4d clout=%s",
			label,
			t / 60,
			data.Rebirths,
			d.Name,
			world,
			video,
			Format.Abbrev(data.Clout)
		)
	)
end

local function padDistance(gate)
	return Layout.GateZ(gate) + Layout.Road.PadOffsetZ - Layout.Spawn.Z + 8
end

local lastRebirth = 0
while t < 3600 * 30 do
	local vps = Stats.ViewsPerStep(data, ctx) * extra
	local open = Stats.OpenGates(data, world)
	local claimWorld, claimGate = world, open
	if open == 0 and world > 1 then
		claimWorld = world - 1
		claimGate = Stats.OpenGates(data, world - 1)
	end
	if claimGate == 0 then
		t += 10
		data.Views += (10 * speed / Economy.StudsPerStep) * vps
	else
		local dist = padDistance(claimGate)
		t += dist / speed + 2.5
		data.Views += dist / Economy.StudsPerStep * vps
		data.Clout += Stats.PadReward(data, ctx, claimWorld, claimGate)
		if claimWorld == world and (claimGate == 1 or claimGate == 8 or claimGate == 15) then
			mark("W" .. world .. " gate " .. claimGate)
		end
	end
	-- buy devices in order
	for _, d in Devices.List do
		if not data.Devices[d.Id] then
			if data.Unlocked[tostring(d.World)] and data.Clout >= d.Cost then
				data.Clout -= d.Cost
				data.Devices[d.Id] = true
				data.Equipped = d.Id
				if d.Tier == 21 then
					mark("all " .. Worlds[d.World].DeviceLabel)
				end
			else
				break
			end
		end
	end
	-- rival
	if Stats.OpenGates(data, world) >= Stats.GatesPerWorld and data.Views >= Stats.RivalPower(world) then
		mark("beat " .. Worlds[world].Rival.Name)
		data.RivalsBeaten[tostring(world)] = true
		if Worlds[world + 1] then
			world += 1
			data.Unlocked[tostring(world)] = true
		else
			break
		end
	end
	-- rebirth
	if Stats.CanRebirth(data) then
		data.Rebirths += 1
		data.Views = 0
		if data.Rebirths <= 3 or data.Rebirths % 5 == 0 then
			mark("rebirth " .. data.Rebirths .. string.format(" (cycle %.1fm)", (t - lastRebirth) / 60))
		end
		lastRebirth = t
	end
end
print(string.format("Finished at %.1f hours with %d rebirths", t / 3600, data.Rebirths))
