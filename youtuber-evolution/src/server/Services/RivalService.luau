--!strict
-- Rival creators at the end of every road + the VIEW WAR minigame.
--
-- View War: a 15s tug-of-war simulated on the server at 10 ticks/s.
--   ratio      = your Views / rival power (rival power = views needed for their Video)
--   your push  = BASE * clamp(ratio, 0, 3) + clicks * CLICK (x2 during a trend boost)
--   rival push = BASE (x1.8 during telegraphed surges)
-- p starts at 0.5; reaching 1 wins instantly, otherwise p > 0.5 at the end wins.
-- Tuned so: ratio >= 2 wins without clicking, ratio ~1 needs ~6 clicks/sec.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Worlds = require(Shared.Config.Worlds)
local Stats = require(Shared.Util.Stats)
local Format = require(Shared.Util.Format)
local Theme = require(Shared.Config.Theme)
local PropKit = require(Shared.Models.PropKit)
local Net = require(Shared.Util.Net)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local ProgressService = require(script.Parent.ProgressService)
local CharacterService = require(script.Parent.CharacterService)
local MovementService = require(script.Parent.MovementService)
local GearBuilder = require(script.Parent.GearBuilder)
local Comms = require(script.Parent.Comms)

local RivalService = {}

local TICK = 0.1
local BASE = 0.006
local CLICK = 0.0026
local MAX_CPS = 12
local BUBBLE_WINDOW = 1.4

local IDLE_ANIM = "rbxassetid://507766388"
local WAVE_ANIM = "rbxassetid://507770239"
local INK = Color3.fromRGB(27, 21, 48)

type Bubble = { id: number, expires: number }
type Battle = {
	player: Player,
	world: number,
	p: number,
	t: number,
	duration: number,
	ratio: number,
	clicks: number,
	clickTokens: number,
	trendUntil: number,
	bubbles: { [number]: Bubble },
	nextBubble: number,
	bubbleId: number,
	surges: { number },
	you: number,
	rival: number,
	over: boolean,
	forced: boolean?, -- admin win/lose, applied on the next tick
}

local battles: { [Player]: Battle } = {}
local lastAttempt: { [Player]: number } = {}
local speech: { [number]: TextLabel } = {}
local rng = Random.new()

-- NPCs ---------------------------------------------------------------------------------------
local function billboard(parent: Instance, rival: Worlds.Rival, world: number, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "RivalTag"
	gui.Size = UDim2.fromOffset(300, 96)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	local function line(text: string, y: number, h: number, color: Color3, size: number)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.Text = text
		l.TextColor3 = color
		l.TextSize = size
		l.FontFace = Theme.Fonts.Display
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Color = INK
		s.Parent = l
		l.Parent = gui
	end
	line(if rival.Boss then "👑 FINAL BOSS" else "⚔️ RIVAL CREATOR", 0, 0.25, Theme.Colors.Red, 16)
	line(string.upper(rival.Name), 0.25, 0.4, Theme.Colors.Yellow, 32)
	line("👁️ " .. Format.Abbrev(Stats.RivalPower(world)) .. " VIEWS", 0.65, 0.35, Color3.new(1, 1, 1), 20)
	gui.Parent = parent

	local bubbleGui = Instance.new("BillboardGui")
	bubbleGui.Name = "Speech"
	bubbleGui.Size = UDim2.fromOffset(260, 64)
	bubbleGui.StudsOffsetWorldSpace = Vector3.new(0, height + 4.2, 0)
	bubbleGui.MaxDistance = 90
	bubbleGui.LightInfluence = 0
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = INK
	stroke.Parent = frame
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, -16, 1, -8)
	text.Position = UDim2.fromOffset(8, 4)
	text.TextScaled = true
	text.TextWrapped = true
	text.FontFace = Theme.Fonts.Display
	text.TextColor3 = INK
	text.Text = rival.Taunts[1]
	text.Parent = frame
	frame.Parent = bubbleGui
	bubbleGui.Parent = parent
	speech[world] = text
end

local function spawnHumanRival(world: Worlds.World, spot: BasePart)
	local rival = world.Rival
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = rival.SkinColor
	desc.LeftArmColor = rival.SkinColor
	desc.RightArmColor = rival.SkinColor
	desc.TorsoColor = rival.ShirtColor
	desc.LeftLegColor = rival.PantsColor
	desc.RightLegColor = rival.PantsColor
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("[Rival] couldn't create rig: " .. tostring(rig))
		return
	end
	rig.Name = rival.Name
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
		rig:Destroy()
		return
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	root.Anchored = true
	-- gear first (at scale 1), then scale up the whole rival
	GearBuilder.Build(rig, if world.Id == 1 then 5 elseif world.Id == 2 then 9 else 13)
	rig:PivotTo(spot.CFrame * CFrame.new(0, 3, 0))
	rig:ScaleTo(1.6)
	GearBuilder.ScaleOrbits(rig, 1.6)
	-- feet on the podium after scaling
	rig:PivotTo(spot.CFrame * CFrame.new(0, hum.HipHeight + root.Size.Y / 2 - 0.3, 0))
	rig.Parent = spot.Parent
	local head = rig:FindFirstChild("Head")
	billboard(head or root, rival, world.Id, 2.5)

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		local a = Instance.new("Animator")
		a.Parent = hum
		animator = a
	end
	local idle = Instance.new("Animation")
	idle.AnimationId = IDLE_ANIM
	local wave = Instance.new("Animation")
	wave.AnimationId = WAVE_ANIM
	task.spawn(function()
		local okIdle, idleTrack = pcall(function()
			return (animator :: Animator):LoadAnimation(idle)
		end)
		if okIdle and idleTrack then
			idleTrack.Looped = true
			idleTrack:Play()
		end
		local okWave, waveTrack = pcall(function()
			return (animator :: Animator):LoadAnimation(wave)
		end)
		while rig.Parent do
			task.wait(rng:NextNumber(6, 10))
			if okWave and waveTrack then
				waveTrack:Play()
			end
		end
	end)
end

local function spawnAlgorithm(world: Worlds.World, spot: BasePart)
	local model = Instance.new("Model")
	model.Name = world.Rival.Name
	local base = spot.CFrame * CFrame.new(0, 11, 0)
	local function ball(name: string, size: number, offset: CFrame, color: Color3, material: Enum.Material?)
		return PropKit.Part({
			Name = name,
			Shape = "Ball",
			Size = Vector3.new(size, size, size),
			CFrame = base * offset,
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = model,
		})
	end
	local core = ball("Sclera", 11, CFrame.new(), Color3.new(1, 1, 1))
	ball("Iris", 6.4, CFrame.new(0, 0, -3), Theme.Colors.Pink, Enum.Material.Neon)
	ball("Pupil", 3.4, CFrame.new(0, 0, -4.6), Color3.fromRGB(10, 6, 20))
	ball("Shine", 1.1, CFrame.new(1.1, 1.2, -5.7), Color3.new(1, 1, 1), Enum.Material.Neon)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		PropKit.Part({
			Name = "Screen",
			Size = Vector3.new(2.6, 1.7, 0.2),
			CFrame = base
				* CFrame.Angles(0, a, 0)
				* CFrame.new(0, math.sin(a * 2) * 2, -9)
				* CFrame.Angles(0, math.pi, 0),
			Color = if i % 2 == 0 then Theme.Colors.Cyan else Theme.Colors.Purple,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
	end
	model.PrimaryPart = core
	model.Parent = spot.Parent
	billboard(core, world.Rival, world.Id, 8)
	-- slow hover + spin
	task.spawn(function()
		local t = 0
		while model.Parent do
			t += 0.1
			model:PivotTo(
				spot.CFrame
					* CFrame.new(0, 11 + math.sin(t * 1.3) * 1.2, 0)
					* CFrame.Angles(0, math.sin(t * 0.4) * 0.35, 0)
			)
			task.wait(0.1)
		end
	end)
end

-- Battles ------------------------------------------------------------------------------------
local function send(battle: Battle, kind: string, payload: any)
	Net.Event("Battle"):FireClient(battle.player, kind, payload)
end

local function finish(battle: Battle, win: boolean)
	if battle.over then
		return
	end
	battle.over = true
	battles[battle.player] = nil
	local player = battle.player
	player:SetAttribute("InBattle", nil)
	CharacterService.SetFrozen(player, false)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Stats.Battles += 1
	local world = Worlds[battle.world]
	local key = tostring(battle.world)
	local result: { [string]: any } = { Win = win, World = battle.world }
	if win then
		local first = not data.RivalsBeaten[key]
		local ctx = DataService.Context(player)
		local pads = if first then world.Rival.FirstWinPads else world.Rival.ReplayPads
		local clout = Stats.PadReward(data, ctx, battle.world, Stats.GatesPerWorld) * pads
		ProgressService.AddClout(player, clout)
		result.Clout = clout
		result.First = first
		if first then
			data.RivalsBeaten[key] = true
			ProgressService.AddTickets(player, world.Rival.FirstWinTickets)
			result.Tickets = world.Rival.FirstWinTickets
			local nextWorld = Worlds[battle.world + 1]
			if nextWorld then
				data.Unlocked[tostring(nextWorld.Id)] = true
				result.Unlocked = nextWorld.Id
				DataService.Dirty(player, "Unlocked")
			end
			DataService.Dirty(player, "RivalsBeaten")
			Comms.NotifyAll("⚔️ " .. player.DisplayName .. " defeated " .. world.Rival.Name .. "!", "reward")
		end
		data.RivalCooldowns[key] = os.time() + world.Rival.Cooldown
		DataService.Dirty(player, "RivalCooldowns")
	else
		result.NeedViews = math.max(0, Stats.RivalPower(battle.world) * 1.1 - data.Views)
	end
	DataService.Dirty(player, "Stats")
	send(battle, "end", result)
	local label = speech[battle.world]
	if label then
		label.Text = if win then "NOOO... my views!! 😭" else "Too easy. Come back with more views! 😎"
	end
end

local function run(battle: Battle)
	local rivalPower = Stats.RivalPower(battle.world)
	local scale = rivalPower * 0.004
	while not battle.over do
		task.wait(TICK)
		if not battle.player.Parent or not CharacterService.Root(battle.player) then
			finish(battle, false)
			return
		end
		battle.t += TICK
		local t = battle.t
		-- click budget refills at MAX_CPS
		battle.clickTokens = math.min(MAX_CPS * 0.5, battle.clickTokens + MAX_CPS * TICK)
		local surging, warning = false, false
		for _, at in battle.surges do
			if t >= at and t < at + 1.5 then
				surging = true
			elseif t >= at - 1 and t < at then
				warning = true
			end
		end
		local trend = t < battle.trendUntil
		local push = BASE * math.clamp(battle.ratio, 0, 3) + battle.clicks * CLICK * (if trend then 2 else 1)
		local rivalPush = BASE * (if surging then 1.8 else 1)
		battle.clicks = 0
		battle.p = math.clamp(battle.p + push - rivalPush, 0, 1)
		if battle.forced ~= nil then
			battle.p = if battle.forced then 1 else 0
		end
		battle.you += push * scale * 40
		battle.rival += rivalPush * scale * 40
		-- trend bubbles
		if t >= battle.nextBubble and t < battle.duration - 1 then
			battle.bubbleId += 1
			local id = battle.bubbleId
			battle.bubbles[id] = { id = id, expires = t + BUBBLE_WINDOW }
			battle.nextBubble = t + rng:NextNumber(2.4, 3.4)
			send(
				battle,
				"bubble",
				{ Id = id, X = rng:NextNumber(0.2, 0.8), Y = rng:NextNumber(0.28, 0.66), Life = BUBBLE_WINDOW }
			)
		end
		for id, b in battle.bubbles do
			if t > b.expires then
				battle.bubbles[id] = nil
			end
		end
		send(battle, "tick", {
			P = battle.p,
			T = t,
			You = battle.you,
			Rival = battle.rival,
			Surge = surging,
			Warn = warning,
			Trend = trend,
		})
		if battle.forced ~= nil then
			finish(battle, battle.forced)
		elseif battle.p >= 1 then
			finish(battle, true)
		elseif t >= battle.duration then
			finish(battle, battle.p > 0.5)
		end
	end
end

-- `force` (admin testing) skips every requirement and walks you over first.
local function challenge(player: Player, world: number, force: boolean?): Comms.Result
	local data = DataService.Get(player)
	local w = Worlds[world]
	if not data or not w then
		return Comms.Fail("Unknown rival")
	end
	if battles[player] then
		return Comms.Fail("Already in a View War!")
	end
	if not force and os.clock() - (lastAttempt[player] or 0) < 3 then
		return Comms.Fail("Catch your breath first!")
	end
	local root = CharacterService.Root(player)
	if not root then
		return Comms.Fail("No character")
	end
	if force then
		-- stand on the challenge pad so the battle spot is at ground level
		for _, pad in MapService.StationPads do
			if pad:GetAttribute("Station") == "Rival" and pad:GetAttribute("World") == world then
				MovementService.Grace(player, 2)
				MapService.Teleport(player.Character, CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
				break
			end
		end
	else
		if MapService.WorldAt(root.Position) ~= world then
			return Comms.Fail("Go to " .. w.Name .. " first!")
		end
		if
			not MapService.NearStation(root.Position, "Rival", 26, function(pad)
				return pad:GetAttribute("World") == world
			end)
		then
			return Comms.Fail("Walk up to the rival to challenge them!")
		end
		if Stats.OpenGates(data, world) < Stats.GatesPerWorld then
			return Comms.Fail("Open all " .. Stats.GatesPerWorld .. " gates first!")
		end
		local cooldown = (data.RivalCooldowns[tostring(world)] or 0) - os.time()
		if cooldown > 0 then
			return Comms.Fail("Rematch available in " .. Format.Duration(cooldown))
		end
	end
	lastAttempt[player] = os.clock()
	local rivalPower = Stats.RivalPower(world)
	local battle: Battle = {
		player = player,
		world = world,
		p = 0.5,
		t = 0,
		duration = w.Rival.Duration,
		ratio = data.Views / rivalPower,
		clicks = 0,
		clickTokens = MAX_CPS * 0.5,
		trendUntil = 0,
		bubbles = {},
		nextBubble = 2,
		bubbleId = 0,
		surges = {},
		you = data.Views,
		rival = rivalPower,
		over = false,
	}
	for i = 1, w.Rival.Surges do
		table.insert(battle.surges, w.Rival.Duration * i / (w.Rival.Surges + 1) + rng:NextNumber(-1, 1))
	end
	battles[player] = battle
	player:SetAttribute("InBattle", true)
	-- stand the player in front of the rival
	local spot = MapService.RivalSpots[world]
	if spot then
		MovementService.Grace(player, 2)
		local stand = spot.CFrame * CFrame.new(0, 0, -20)
		MapService.Teleport(
			player.Character,
			CFrame.new(stand.Position.X, root.Position.Y, stand.Position.Z) * CFrame.Angles(0, math.pi, 0)
		)
	end
	CharacterService.SetFrozen(player, true)
	send(battle, "start", {
		World = world,
		Name = w.Rival.Name,
		Emoji = w.Rival.Emoji,
		Duration = w.Rival.Duration,
		You = data.Views,
		Rival = rivalPower,
		Ratio = battle.ratio,
		Boss = w.Rival.Boss == true,
	})
	local label = speech[world]
	if label then
		label.Text = "Oh, you think you can out-view ME?! 😤"
	end
	task.delay(3, function() -- client shows a 3-2-1 countdown first
		if not battle.over then
			run(battle)
		end
	end)
	return Comms.Ok()
end

function RivalService.InBattle(player: Player): boolean
	return battles[player] ~= nil
end

-- Admin: start a View War right now, ignoring gates, cooldowns and distance.
function RivalService.ForceStart(player: Player, world: number): Comms.Result
	return challenge(player, world, true)
end

-- Admin: end the current View War on its next tick (after the countdown).
function RivalService.ForceResult(player: Player, win: boolean): boolean
	local battle = battles[player]
	if not battle or battle.over then
		return false
	end
	battle.forced = win
	return true
end

function RivalService.Init()
	Comms.On("ChallengeRival", 1, function(player, payload)
		local world = Comms.Int(payload.World, 1, #Worlds)
		if not world then
			return Comms.Fail("Unknown rival")
		end
		return challenge(player, world)
	end)
end

function RivalService.Start()
	for _, world in Worlds do
		local spot = MapService.RivalSpots[world.Id]
		if spot then
			if world.Rival.Boss then
				spawnAlgorithm(world, spot)
			else
				task.spawn(spawnHumanRival, world, spot)
			end
		end
	end
	-- taunt rotation
	task.spawn(function()
		local i = 0
		while true do
			task.wait(7)
			i += 1
			for _, world in Worlds do
				local label = speech[world.Id]
				local taunts = world.Rival.Taunts
				if label and #taunts > 0 then
					label.Text = taunts[(i % #taunts) + 1]
				end
			end
		end
	end)

	Net.Event("BattleInput").OnServerEvent:Connect(function(player: Player, kind: any, value: any)
		local battle = battles[player]
		if not battle or battle.over or battle.t <= 0 then
			return
		end
		if kind == "click" and typeof(value) == "number" and value == value then
			local n = math.clamp(math.floor(value), 0, 20)
			local allowed = math.min(n, math.floor(battle.clickTokens))
			battle.clickTokens -= allowed
			battle.clicks += allowed
		elseif kind == "bubble" and typeof(value) == "number" then
			local b = battle.bubbles[value]
			if b and battle.t <= b.expires then
				battle.bubbles[value] = nil
				battle.trendUntil = battle.t + 2
				battle.p = math.clamp(battle.p + 0.03, 0, 1)
				send(battle, "bubblehit", { Id = value })
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local battle = battles[player]
		if battle then
			battle.over = true
			battles[player] = nil
		end
		lastAttempt[player] = nil
	end)
end

return RivalService
