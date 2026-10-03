--!strict
-- Per-player world state + ambient animation:
--   * gates open/close locally (collision + colour + label) from your Video
--   * clout pad labels show YOUR reward, treadmill signs show YOUR lock state
--   * rival monitors vanish once you've beaten that rival
--   * treadmill belts scroll; you jog in place on a treadmill
--   * evolution gear: orbiting drones/screens/planets + rainbow parts
--   * portal swirls spin

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Treadmills = require(Shared.Config.Treadmills)
local Format = require(Shared.Util.Format)
local Stats = require(Shared.Util.Stats)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local WorldFX = {}

local C = Theme.Colors
local player = Players.LocalPlayer

local LOCKED = Color3.fromRGB(255, 70, 90)
local NEAR = Color3.fromRGB(255, 200, 60)
local OPEN = Color3.fromRGB(80, 230, 120)

-- Gates --------------------------------------------------------------------------------------
local gateOpen: { [Instance]: boolean } = {}

local function refreshGate(barrier: BasePart)
	if not State.IsLoaded then
		return
	end
	local req = barrier:GetAttribute("Video")
	if typeof(req) ~= "number" then
		return
	end
	local video = Stats.VideoLevel(State.Data.Views)
	local open = video >= req
	local wasOpen = gateOpen[barrier]
	gateOpen[barrier] = open
	local gui = barrier:FindFirstChild("Req")
	local label = gui and gui:FindFirstChild("Text") :: TextLabel?
	if open then
		barrier.CanCollide = false
		barrier.Transparency = 0.92
		barrier.Color = OPEN
		if label then
			label.Text = "✅ OPEN"
			label.TextColor3 = OPEN
		end
		if wasOpen == false then
			-- just unlocked: flash + sound
			barrier.Transparency = 0.2
			barrier.Material = Enum.Material.Neon
			task.delay(0.25, function()
				barrier.Material = Enum.Material.ForceField
				barrier.Transparency = 0.92
			end)
			local idx = barrier:GetAttribute("Gate")
			Sound.Play("Gate", 1 + (if typeof(idx) == "number" then idx else 0) * 0.04)
		end
	else
		barrier.CanCollide = true
		barrier.Transparency = 0
		barrier.Material = Enum.Material.ForceField
		local near = video >= req - 2
		barrier.Color = if near then NEAR else LOCKED
		if label then
			label.Text = "🔒 VIDEO " .. req
			label.TextColor3 = if near then NEAR else C.White
		end
	end
end

local function refreshAllGates()
	for _, b in CollectionService:GetTagged("GateBarrier") do
		if b:IsA("BasePart") then
			refreshGate(b)
		end
	end
end

-- Clout pad labels ------------------------------------------------------------------------------
local function refreshPadLabels()
	if not State.IsLoaded then
		return
	end
	local data = State.Data
	local video = Stats.VideoLevel(data.Views)
	for _, anchor in CollectionService:GetTagged("CloutPadLabel") do
		local world = anchor:GetAttribute("World")
		local gate = anchor:GetAttribute("Gate")
		local gui = anchor:FindFirstChild("PadLabel")
		if typeof(world) == "number" and typeof(gate) == "number" and gui then
			local amount = gui:FindFirstChild("Amount") :: TextLabel?
			local title = gui:FindFirstChild("Title") :: TextLabel?
			local req = Stats.OpenGates(data, world) >= gate
			if amount then
				amount.Text = "+" .. Format.Abbrev(Stats.PadReward(data, State.Ctx, world, gate))
			end
			if title then
				title.Text = if req then "💰 CLAIM CLOUT" else "🔒 LOCKED"
			end
		end
	end
	local _ = video
end

-- Treadmill signs ----------------------------------------------------------------------------------
local function refreshTreadmillSigns()
	if not State.IsLoaded then
		return
	end
	for _, model in CollectionService:GetTagged("Treadmill") do
		local tier = model:GetAttribute("Tier")
		local t = if typeof(tier) == "number" then Treadmills[tier] else nil
		local sign = model:FindFirstChild("TreadmillSign", true)
		local req = sign and sign:FindFirstChild("Req") :: TextLabel?
		if t and req then
			local ok
			if t.Pass then
				ok = State.Ctx.Passes[t.Pass] == true
				req.Text = if ok
					then "✅ OWNED"
					else ("🔒 " .. (if t.Pass == "VIP" then "VIP GAMEPASS" else "GAMEPASS"))
			else
				ok = State.Data.Rebirths >= t.Rebirths
				req.Text = if ok then "✅ READY" else ("🔒 " .. t.Rebirths .. " REBIRTHS")
			end
			req.TextColor3 = if ok then OPEN else Color3.fromRGB(255, 150, 160)
		end
	end
end

-- Rival monitors -------------------------------------------------------------------------------------
local function refreshMonitors()
	if not State.IsLoaded then
		return
	end
	for _, screen in CollectionService:GetTagged("RivalGate") do
		if screen:IsA("BasePart") then
			local world = screen:GetAttribute("World")
			local beaten = State.Data.RivalsBeaten[tostring(world)] == true
			screen.CanCollide = not beaten
			screen.Transparency = if beaten then 1 else 0
			local gui = screen:FindFirstChildOfClass("SurfaceGui")
			if gui then
				gui.Enabled = not beaten
			end
		end
	end
end

-- Belts: stripe parts scroll along each treadmill (client-only) ----------------------------------------
type Belt = { part: BasePart, stripes: { BasePart } }
local belts: { Belt } = {}

local function setupBelt(part: BasePart)
	local stripeColor = part:GetAttribute("Stripe")
	local folder = Instance.new("Folder")
	folder.Name = "Stripes"
	folder.Parent = part
	local stripes: { BasePart } = {}
	for _ = 1, 6 do
		local s = Instance.new("Part")
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.CastShadow = false
		s.Size = Vector3.new(part.Size.X - 0.4, 0.06, 1.1)
		s.Color = if typeof(stripeColor) == "Color3" then stripeColor else C.White
		s.Material = Enum.Material.SmoothPlastic
		s.Parent = folder
		table.insert(stripes, s)
	end
	table.insert(belts, { part = part, stripes = stripes })
end

-- Treadmill jogging -----------------------------------------------------------------------------------
local runTrack: AnimationTrack? = nil

local function stopJog()
	if runTrack then
		runTrack:Stop(0.2)
		runTrack = nil
	end
end

local function startJog()
	if runTrack then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local animate = char and char:FindFirstChild("Animate")
	if not animator or not animate then
		return
	end
	local runValue = animate:FindFirstChild("run")
	local anim = runValue and runValue:FindFirstChildOfClass("Animation")
	if not anim then
		return
	end
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.2)
		track:AdjustSpeed(1.2)
		runTrack = track
	end
end

local function updateJog()
	local tier = player:GetAttribute("Treadmill")
	local onTread = typeof(tier) == "number" and tier > 0
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if onTread and hum and hum.MoveDirection.Magnitude < 0.1 then
		startJog()
		-- face the treadmill console (-X in every world)
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local look = root.CFrame.LookVector
			if look.X > -0.98 then
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(90), 0)
			end
		end
	else
		stopJog()
	end
end

-- Graphics / nametags --------------------------------------------------------------------------------
local function applySettings()
	if not State.IsLoaded then
		return
	end
	local s = State.Data.Settings
	Lighting.GlobalShadows = not s.LowGfx
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local head = char and char:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("Nametag")
		if tag and tag:IsA("BillboardGui") then
			tag.Enabled = s.Nametags ~= false
		end
	end
end

function WorldFX.Init() end

function WorldFX.Start()
	State.On("Views", function()
		refreshAllGates()
		refreshPadLabels()
	end)
	for _, key in { "Rebirths", "Context", "Upgrades", "Potions" } do
		State.On(key, function()
			refreshPadLabels()
			refreshTreadmillSigns()
		end)
	end
	State.On("RivalsBeaten", refreshMonitors)
	State.On("Settings", applySettings)
	CollectionService:GetInstanceAddedSignal("GateBarrier"):Connect(function(b)
		if b:IsA("BasePart") then
			refreshGate(b)
		end
	end)
	for _, b in CollectionService:GetTagged("TreadmillBelt") do
		if b:IsA("BasePart") then
			setupBelt(b)
		end
	end
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function()
			task.wait(1)
			applySettings()
		end)
	end)
	player.CharacterAdded:Connect(function()
		runTrack = nil
	end)

	local t = 0
	local rainbowParts: { BasePart } = {}
	local function collectRainbow()
		rainbowParts = {}
		for _, p in CollectionService:GetTagged("GearRainbow") do
			if p:IsA("BasePart") then
				table.insert(rainbowParts, p)
			end
		end
	end
	CollectionService:GetInstanceAddedSignal("GearRainbow"):Connect(collectRainbow)
	CollectionService:GetInstanceRemovedSignal("GearRainbow"):Connect(collectRainbow)
	collectRainbow()

	local portals: { BasePart } = {}
	for _, p in CollectionService:GetTagged("Portal") do
		if p:IsA("BasePart") then
			table.insert(portals, p)
		end
	end

	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local cam = Workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero
		-- belts near the camera
		for _, belt in belts do
			local part = belt.part
			if (part.Position - camPos).Magnitude < 260 then
				local len = part.Size.Z
				for i, s in belt.stripes do
					local z = ((t * 9 + i * len / #belt.stripes) % len) - len / 2
					s.CFrame = part.CFrame * CFrame.new(0, part.Size.Y / 2 + 0.03, z)
				end
			end
		end
		-- orbiting gear
		for _, w in CollectionService:GetTagged("GearOrbit") do
			if w:IsA("Weld") then
				local r = w:GetAttribute("Radius")
				local h = w:GetAttribute("Height")
				local sp = w:GetAttribute("Speed")
				local ph = w:GetAttribute("Phase")
				if
					typeof(r) == "number"
					and typeof(h) == "number"
					and typeof(sp) == "number"
					and typeof(ph) == "number"
				then
					local a = t * sp + ph
					w.C0 = CFrame.Angles(0, a, 0)
						* CFrame.new(r, h + math.sin(t * 2 + ph) * 0.3, 0)
						* CFrame.Angles(0, -a, 0)
				end
			end
		end
		-- rainbow gear
		if #rainbowParts > 0 then
			local color = Color3.fromHSV((t * 0.25) % 1, 0.75, 1)
			for _, p in rainbowParts do
				p.Color = color
			end
		end
		-- portals
		for _, p in portals do
			p.CFrame = p.CFrame * CFrame.Angles(dt * 1.5, 0, 0)
		end
	end)

	task.spawn(function()
		while true do
			updateJog()
			task.wait(0.15)
		end
	end)

	if State.IsLoaded then
		refreshAllGates()
		refreshPadLabels()
		refreshTreadmillSigns()
		refreshMonitors()
		applySettings()
	end
end

return WorldFX
