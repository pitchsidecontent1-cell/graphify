--!strict
-- Spawning (per-world spawn points), walk speed, and everything visible on
-- the character: size, Evolution gear, held device and the overhead nametag.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Stats = require(Shared.Util.Stats)
local Format = require(Shared.Util.Format)
local Theme = require(Shared.Config.Theme)
local Evolutions = require(Shared.Config.Evolutions)
local Niches = require(Shared.Config.Niches)
local Devices = require(Shared.Config.Devices)
local DeviceModels = require(Shared.Models.DeviceModels)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local ProgressService = require(script.Parent.ProgressService)
local GearBuilder = require(script.Parent.GearBuilder)

local CharacterService = {}

local INK = Color3.fromRGB(27, 21, 48)
local HELD_SCALE = 0.55

local lookVersion: { [Player]: number } = {}
local tagRefs: { [Player]: { Title: TextLabel, Info: TextLabel, Views: TextLabel, Gradient: UIGradient }? } = {}
local lastTagUpdate: { [Player]: number } = {}
local frozen: { [Player]: boolean } = {}

local function humanoidOf(player: Player): Humanoid?
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChildOfClass("Humanoid")
end

function CharacterService.Root(player: Player): BasePart?
	local char = player.Character
	if not char then
		return nil
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function CharacterService.ApplySpeed(player: Player)
	local data = DataService.Get(player)
	local hum = humanoidOf(player)
	if data and hum and not frozen[player] then
		-- admins can override walk speed for testing (see AdminService "speed")
		local override = player:GetAttribute("AdminSpeed")
		hum.WalkSpeed = if typeof(override) == "number" then override else Stats.WalkSpeed(data)
	end
end

-- Freeze/unfreeze movement (used by View Wars).
function CharacterService.SetFrozen(player: Player, isFrozen: boolean)
	if isFrozen then
		frozen[player] = true
	else
		frozen[player] = nil
	end
	local hum = humanoidOf(player)
	if hum then
		if isFrozen then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum.UseJumpPower = true
		else
			hum.JumpPower = 50
			CharacterService.ApplySpeed(player)
		end
	end
end

-- World teleport (also moves the respawn point).
function CharacterService.SendToWorld(player: Player, world: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if data.World ~= world then
		data.World = world
		DataService.Dirty(player, "World")
	end
	local spawn = MapService.Spawns[world]
	if spawn then
		player.RespawnLocation = spawn
	end
	MapService.Teleport(player.Character, MapService.SpawnCFrame(world))
end

-- Nametag -----------------------------------------------------------------------------
local function buildNametag(player: Player, char: Model)
	local head = char:FindFirstChild("Head")
	if not head then
		return
	end
	local existing = head:FindFirstChild("Nametag")
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nametag"
	gui.Size = UDim2.fromOffset(240, 78)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false

	local function label(name: string, y: number, h: number, color: Color3, size: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.FontFace = Theme.Fonts.Display
		l.TextColor3 = color
		l.TextSize = size
		l.TextScaled = false
		l.Text = ""
		local s = Instance.new("UIStroke")
		s.Thickness = 2.5
		s.Color = INK
		s.Parent = l
		l.Parent = gui
		return l
	end
	local title = label("Title", 0, 0.38, Color3.new(1, 1, 1), 22)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = title
	local info = label("Info", 0.38, 0.3, Color3.fromRGB(230, 230, 240), 16)
	local views = label("Views", 0.66, 0.34, Theme.Colors.Yellow, 18)
	gui.Parent = head
	tagRefs[player] = { Title = title, Info = info, Views = views, Gradient = gradient }
end

function CharacterService.UpdateNametag(player: Player)
	local refs = tagRefs[player]
	local data = DataService.Get(player)
	if not refs or not data or not refs.Title.Parent then
		return
	end
	local tier = ProgressService.Tier(player)
	local evo = Evolutions[tier]
	local rarity = Theme.Rarities[evo.Rarity]
	refs.Title.Text = string.upper(evo.Title)
	if rarity.Animated then
		refs.Gradient.Color = Theme.Rainbow
	else
		refs.Gradient.Color = ColorSequence.new(rarity.Color:Lerp(Color3.new(1, 1, 1), 0.45), rarity.Color)
	end
	local niche = Niches.ById[data.Niche]
	local nicheText = if niche then (" • " .. niche.Emoji .. " " .. niche.Name) else ""
	refs.Info.Text = "🔄 " .. Format.Abbrev(data.Rebirths) .. nicheText
	refs.Views.Text = "👁️ " .. Format.Abbrev(data.Views)
	lastTagUpdate[player] = os.clock()
end

-- Look: size + gear + held device ----------------------------------------------------------
local function attachDevice(player: Player, char: Model)
	local old = char:FindFirstChild("HeldDevice")
	if old then
		old:Destroy()
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local device = Devices.ById[data.Equipped]
	if not device then
		return
	end
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local model = DeviceModels.Build(device, CFrame.new(), true)
	model.Name = "HeldDevice"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
		end
	end
	model:ScaleTo(HELD_SCALE)
	local isR15 = hand.Name == "RightHand"
	local grip = if isR15 then CFrame.new(0, -0.45, -0.55) else CFrame.new(0, -1.15, -0.6)
	if device.Kind == "Studio" then
		grip = if isR15 then CFrame.new(0, -0.2, -0.2) else CFrame.new(0, -0.9, -0.2)
	elseif device.Kind == "Laptop" then
		grip = grip * CFrame.new(0, 0, -0.2) * CFrame.Angles(math.rad(10), 0, 0)
	end
	model:PivotTo(hand.CFrame * grip)
	local root = model.PrimaryPart
	if root then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				local w = Instance.new("WeldConstraint")
				w.Part0 = hand
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	model.Parent = char
end

function CharacterService.RefreshLook(player: Player)
	local char = player.Character
	if not char or not char.Parent then
		return
	end
	local version = (lookVersion[player] or 0) + 1
	lookVersion[player] = version
	local tier = ProgressService.Tier(player)
	local evo = Evolutions[tier]
	local ok, err = pcall(function()
		if char:GetScale() ~= 1 then
			char:ScaleTo(1)
		end
		GearBuilder.Build(char, tier)
		attachDevice(player, char)
		if evo.Scale ~= 1 then
			char:ScaleTo(evo.Scale)
		end
		GearBuilder.ScaleOrbits(char, evo.Scale)
	end)
	if not ok then
		warn("[Character] look refresh failed: " .. tostring(err))
	end
	CharacterService.UpdateNametag(player)
end

-- Pets shown to everyone: comma-separated pet ids in a player attribute.
function CharacterService.UpdatePetAttribute(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local ids = {}
	for _, uid in data.EquippedPets do
		local item = Stats.FindPet(data, uid)
		if item then
			table.insert(ids, item.Pet)
		end
	end
	player:SetAttribute("Pets", table.concat(ids, ","))
end

local function onCharacterAdded(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	hum.Died:Connect(function()
		task.delay(2.5, function()
			if player.Parent and DataService.Get(player) then
				player:LoadCharacterAsync()
			end
		end)
	end)
	frozen[player] = nil
	CharacterService.ApplySpeed(player)
	buildNametag(player, char)
	CharacterService.UpdateNametag(player)
	-- wait for accessories so scaling includes them
	if not player:HasAppearanceLoaded() then
		local t = os.clock()
		while char.Parent and not player:HasAppearanceLoaded() and os.clock() - t < 6 do
			task.wait(0.2)
		end
	end
	if char.Parent then
		CharacterService.RefreshLook(player)
	end
end

function CharacterService.Init() end

function CharacterService.Start()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			onCharacterAdded(player, char)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(char)
			onCharacterAdded(player, char)
		end)
	end

	DataService.Loaded:Connect(function(player: Player, data)
		local world = data.World
		if not data.Unlocked[tostring(world)] then
			world = 1
			data.World = 1
		end
		local spawn = MapService.Spawns[world]
		if spawn then
			player.RespawnLocation = spawn
		end
		CharacterService.UpdatePetAttribute(player)
		player:LoadCharacterAsync()
	end)

	ProgressService.TierChanged:Connect(function(player: Player)
		CharacterService.RefreshLook(player)
	end)

	DataService.Changed:Connect(function(player: Player, key: string)
		if key == "Equipped" then
			CharacterService.RefreshLook(player)
		elseif key == "Upgrades" or key == "Context" then
			CharacterService.ApplySpeed(player)
		elseif key == "Rebirths" or key == "Niche" then
			CharacterService.UpdateNametag(player)
		elseif key == "EquippedPets" or key == "Pets" then
			CharacterService.UpdatePetAttribute(player)
		elseif key == "Views" then
			if os.clock() - (lastTagUpdate[player] or 0) > 0.4 then
				CharacterService.UpdateNametag(player)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lookVersion[player] = nil
		tagRefs[player] = nil
		lastTagUpdate[player] = nil
		frozen[player] = nil
	end)
end

return CharacterService
