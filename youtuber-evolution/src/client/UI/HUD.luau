--!strict
-- The always-on HUD: menu buttons, currencies, the VIDEO bar, boosts, offers.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Format = require(Shared.Util.Format)
local Stats = require(Shared.Util.Stats)
local Devices = require(Shared.Config.Devices)
local Evolutions = require(Shared.Config.Evolutions)
local Niches = require(Shared.Config.Niches)
local Rewards = require(Shared.Config.Rewards)
local Products = require(Shared.Config.Products)
local Treadmills = require(Shared.Config.Treadmills)
local UIKit = require(script.Parent.UIKit)
local UI = require(script.Parent.UI)
local State = require(script.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Controllers.Request)

local HUD = {}

local C = Theme.Colors

HUD.Root = (nil :: any) :: Frame
HUD.Pills = {} :: { [string]: UIKit.Pill }
HUD.Buttons = {} :: { [string]: UIKit.IconButton }
HUD.ViewsLabel = (nil :: any) :: TextLabel
HUD.VideoBar = (nil :: any) :: UIKit.Progress
HUD.GiftClaimed = {} :: { [number]: boolean }

local hidden = false

-- Smoothly rolling number label
local function roller(label: TextLabel, prefix: string, formatter: (number) -> string): (number) -> ()
	local value = Instance.new("NumberValue")
	local shown = 0
	value.Changed:Connect(function(v)
		shown = v
		label.Text = prefix .. formatter(v)
	end)
	return function(target: number)
		if target == shown then
			return
		end
		local grew = target > shown
		if math.abs(target - shown) < 1 or target < shown * 0.5 then
			value.Value = target
		else
			UIKit.Tween(value, 0.35, { Value = target })
		end
		if grew then
			UIKit.Pop(label, 1.08)
		end
	end
end

local function ctx()
	return State.Ctx
end

-- Badges -----------------------------------------------------------------------------------
local function refreshBadges()
	if not State.IsLoaded then
		return
	end
	local data = State.Data
	-- devices: can afford the next one?
	local nextDevice = nil
	for _, d in Devices.List do
		if not data.Devices[d.Id] then
			nextDevice = d
			break
		end
	end
	local canDevice = nextDevice ~= nil and data.Unlocked[tostring(nextDevice.World)] and data.Clout >= nextDevice.Cost
	HUD.Buttons.Devices.Badge:Set(if canDevice then "!" else nil)

	local canUpgrade = false
	for _, id in { "Speed", "Clout", "Treadmill" } do
		local u = Stats.UpgradeById(id)
		local lvl = Stats.UpgradeLevel(data, id)
		if u and lvl < u.Max and data.Clout >= Stats.UpgradeCost(id, lvl) then
			canUpgrade = true
		end
	end
	HUD.Buttons.Upgrades.Badge:Set(if canUpgrade then "!" else nil)

	local video = Stats.VideoLevel(data.Views)
	local need = Stats.RebirthVideo(data.Rebirths)
	if video >= need then
		HUD.Buttons.Rebirth.Badge:Set("READY")
		HUD.Buttons.Rebirth.Badge.Frame.BackgroundColor3 = C.Green
	else
		HUD.Buttons.Rebirth.Badge:Set(math.floor(video / need * 100) .. "%")
		HUD.Buttons.Rebirth.Badge.Frame.BackgroundColor3 = C.Purple
	end

	local dailyReady = os.time() - data.Daily.Last >= Rewards.DailyCooldown
	HUD.Buttons.Daily.Badge:Set(if dailyReady then "!" else nil)
end

-- Gifts timer ------------------------------------------------------------------------------
local giftLabel: TextLabel? = nil
local giftBadge: UIKit.Badge? = nil

local function giftStatus(): (number, number?)
	local elapsed = os.clock() - State.SessionStart
	local ready = 0
	local nextIn: number? = nil
	for i, gift in Rewards.Gifts do
		if not HUD.GiftClaimed[i] then
			local remaining = gift.Minutes * 60 - elapsed
			if remaining <= 0 then
				ready += 1
			elseif not nextIn or remaining < nextIn then
				nextIn = remaining
			end
		end
	end
	return ready, nextIn
end

-- Build ------------------------------------------------------------------------------------
local function buildLeft(root: Frame)
	local col = UIKit.Frame({
		Name = "LeftButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0.44, 0),
		Size = UDim2.fromOffset(250, 380),
		Parent = root,
	})
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(116, 116)
	grid.CellPadding = UDim2.fromOffset(14, 16)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = col
	local defs: { { Key: string, Text: string, Color: Color3 } } = {
		{ Key = "Shop", Text = "SHOP", Color = C.Pink },
		{ Key = "Pets", Text = "PETS", Color = C.Blue },
		{ Key = "Devices", Text = "DEVICES", Color = C.Cyan },
		{ Key = "Upgrades", Text = "UPGRADES", Color = C.Yellow },
		{ Key = "Rebirth", Text = "REBIRTH", Color = C.Purple },
		{ Key = "Daily", Text = "DAILY", Color = C.Orange },
	}
	for i, def in defs do
		local key, text, color = def.Key, def.Text, def.Color
		local b = UIKit.IconButton({ Key = key, Text = text, Color = color, Size = 116, Parent = col, LayoutOrder = i })
		b.Activated:Connect(function()
			UI.Toggle(key)
		end)
		HUD.Buttons[key] = b
	end
end

local function buildTopCenter(root: Frame)
	local holder = UIKit.Frame({
		Name = "NicheButton",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(440, 74),
		Parent = root,
	})
	local b = UIKit.Button({
		Text = "NICHE: NONE",
		Icon = "Niche",
		Color = C.Pink,
		Size = UDim2.fromScale(1, 1),
		TextSize = 26,
		Parent = holder,
		OnClick = function()
			UI.Toggle("Niche")
		end,
	})
	local badge = UIKit.Badge(b.Root, C.Ticket)
	State.On("Niche", function(id)
		local niche = Niches.ById[id]
		if niche then
			b:SetText(string.upper(niche.Name) .. "  " .. Format.Mult(niche.Mult))
			local rarity = Theme.Rarities[niche.Rarity]
			b:SetColor(if rarity.Animated then C.Purple else rarity.Color:Lerp(C.Pink, 0.25))
		else
			b:SetText("ROLL A NICHE!")
		end
	end)
	State.On("Tickets", function(t)
		badge:Set(if t > 0 then ("🎟️" .. Format.Abbrev(t)) else nil)
	end)
end

local function smallButton(parent: Instance, key: string, color: Color3, order: number, onClick: () -> ()): UIKit.Button
	local b = UIKit.Button({
		Name = key,
		Icon = key,
		Color = color,
		Size = UDim2.fromOffset(72, 72),
		TextSize = 34,
		Parent = parent,
		LayoutOrder = order,
		Radius = 18,
		OnClick = onClick,
	})
	return b
end

local function buildTopRight(root: Frame)
	local row = UIKit.Frame({
		Name = "TopRight",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 14),
		Size = UDim2.fromOffset(500, 80),
		Parent = root,
	})
	local list = UIKit.List(row, 12, true, Enum.HorizontalAlignment.Right)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	smallButton(row, "Worlds", C.Mint, 1, function()
		UI.Toggle("Worlds")
	end)
	smallButton(row, "Codes", C.Cyan, 2, function()
		UI.Toggle("Codes")
	end)
	smallButton(row, "Settings", C.Grey, 3, function()
		UI.Toggle("Settings")
	end)
	local hide = smallButton(row, "Hide", C.Blue, 4, function()
		HUD.SetHidden(not hidden)
	end)
	hide.Root.Name = "HideButton"
	local admin = smallButton(row, "Admin", C.Red, 0, function()
		UI.Toggle("Admin")
	end)
	admin.Root.Visible = Players.LocalPlayer:GetAttribute("Admin") == true
	Players.LocalPlayer:GetAttributeChangedSignal("Admin"):Connect(function()
		admin.Root.Visible = Players.LocalPlayer:GetAttribute("Admin") == true
	end)
end

local function offerButton(
	parent: Instance,
	order: number,
	color: Color3,
	top: string,
	bottom: string,
	onClick: () -> ()
): Frame
	local holder =
		UIKit.Frame({ Name = "Offer" .. order, Size = UDim2.fromOffset(150, 96), LayoutOrder = order, Parent = parent })
	local b = UIKit.Button({
		Text = top,
		Color = color,
		Size = UDim2.fromScale(1, 0.72),
		TextSize = 26,
		Parent = holder,
		OnClick = onClick,
	})
	local price = UIKit.Label({
		Text = bottom,
		TextSize = 24,
		Color = C.Mint,
		Size = UDim2.new(1, 0, 0.3, 0),
		Position = UDim2.fromScale(0, 0.74),
		Stroke = 3,
		Parent = holder,
	})
	price.Name = "Price"
	-- idle bob to draw the eye
	task.spawn(function()
		local s = UIKit.ScaleOf(b.Root)
		while holder.Parent do
			task.wait(3 + order * 0.7)
			UIKit.Tween(s, 0.18, { Scale = 1.08 }, Enum.EasingStyle.Back)
			task.wait(0.2)
			UIKit.Tween(s, 0.25, { Scale = 1 })
		end
	end)
	return holder
end

local function buildRight(root: Frame)
	local col = UIKit.Frame({
		Name = "RightColumn",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.42, 0),
		Size = UDim2.fromOffset(170, 470),
		Parent = root,
	})
	UIKit.List(col, 14, false, Enum.HorizontalAlignment.Right)

	-- Gifts
	local giftHolder = UIKit.Frame({ Name = "Gifts", Size = UDim2.fromOffset(150, 150), LayoutOrder = 1, Parent = col })
	local giftButton =
		UIKit.IconButton({ Key = "Gifts", Text = "GIFTS", Color = C.Red, Size = 116, Parent = giftHolder })
	giftButton.Root.AnchorPoint = Vector2.new(0.5, 0)
	giftButton.Root.Position = UDim2.fromScale(0.5, 0)
	giftButton.Activated:Connect(function()
		UI.Toggle("Gifts")
	end)
	giftBadge = giftButton.Badge
	giftLabel = UIKit.Label({
		Text = "0:00",
		TextSize = 26,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 122),
		Stroke = 3,
		Parent = giftHolder,
	})

	local starter = offerButton(col, 2, Color3.fromRGB(46, 210, 200), "🎁 STARTER", "R$ 79", function()
		UI.Open("Shop", "Featured")
	end)
	local potion = offerButton(col, 3, C.Red, "🧪 x2 VIEWS", "R$ 19", function()
		Request.BuyProduct("ViewsPotion")
	end)
	offerButton(col, 4, C.Gold, "👑 VIP", "R$ 299", function()
		Request.BuyPass("VIP")
	end)
	task.spawn(function()
		(starter:FindFirstChild("Price") :: TextLabel).Text = "R$ " .. Request.Price("Product", "StarterPack");
		(potion:FindFirstChild("Price") :: TextLabel).Text = "R$ " .. Request.Price("Product", "ViewsPotion")
	end)
	State.On("OneTime", function(oneTime)
		starter.Visible = not oneTime.StarterPack
	end)
	State.On("Context", function(c)
		local vip = col:FindFirstChild("Offer4")
		if vip then
			(vip :: Frame).Visible = not c.Passes.VIP
		end
	end)
end

local function buildBottomLeft(root: Frame)
	local col = UIKit.Frame({
		Name = "Currencies",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 22, 1, -22),
		Size = UDim2.fromOffset(300, 220),
		Parent = root,
	})
	local list = UIKit.List(col, 10, false, Enum.HorizontalAlignment.Left)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	local clout = UIKit.Pill({
		Key = "Clout",
		Color = C.Gold,
		Width = 290,
		Height = 66,
		TextSize = 38,
		Parent = col,
		LayoutOrder = 1,
	})
	local tickets = UIKit.Pill({
		Key = "Tickets",
		Color = C.Ticket,
		Width = 230,
		Height = 54,
		TextSize = 30,
		Parent = col,
		LayoutOrder = 2,
	})
	local rebirths = UIKit.Pill({
		Key = "Rebirths",
		Color = C.Purple,
		Width = 230,
		Height = 54,
		TextSize = 30,
		Parent = col,
		LayoutOrder = 3,
	})
	HUD.Pills.Clout = clout
	HUD.Pills.Tickets = tickets
	HUD.Pills.Rebirths = rebirths
	local setClout = roller(clout.Label, "", Format.Abbrev)
	State.On("Clout", function(v)
		setClout(v)
		refreshBadges()
	end)
	State.On("Tickets", function(v)
		tickets.Label.Text = Format.Abbrev(v)
	end)
	State.On("Rebirths", function(v)
		rebirths.Label.Text = Format.Abbrev(v)
		UIKit.Pop(rebirths.Root, 1.15)
	end)
end

local function buildBottomCenter(root: Frame)
	local holder = UIKit.Frame({
		Name = "VideoArea",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(820, 200),
		Parent = root,
	})
	-- evolution chip
	local evo = UIKit.Label({
		Name = "Evolution",
		Text = "",
		TextSize = 26,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 0),
		Stroke = 3,
		Parent = holder,
	})
	local evoGradient = UIKit.Gradient(evo, ColorSequence.new(C.White, C.White), 90)
	-- total views
	local views = UIKit.Label({
		Name = "TotalViews",
		Text = "TOTAL VIEWS: 0",
		TextSize = 54,
		Size = UDim2.new(1, 0, 0, 62),
		Position = UDim2.fromOffset(0, 30),
		Stroke = 4.5,
		Parent = holder,
	})
	HUD.ViewsLabel = views
	local perStep = UIKit.Label({
		Name = "PerStep",
		Text = "+1 / STEP",
		TextSize = 26,
		Color = C.Mint,
		Size = UDim2.fromOffset(200, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 96),
		XAlign = Enum.TextXAlignment.Right,
		Stroke = 3,
		Parent = holder,
	})
	local multi = UIKit.Label({
		Name = "Multi",
		Text = "MULTI: x1",
		TextSize = 26,
		Color = Color3.fromRGB(205, 160, 255),
		Size = UDim2.fromOffset(240, 30),
		Position = UDim2.fromOffset(0, 96),
		XAlign = Enum.TextXAlignment.Left,
		Stroke = 3,
		Parent = holder,
	})
	-- video pill + bar
	local pill = Instance.new("Frame")
	pill.Name = "VideoPill"
	pill.Size = UDim2.fromOffset(250, 72)
	pill.Position = UDim2.fromOffset(0, 128)
	pill.BackgroundColor3 = C.Blue
	UIKit.Corner(pill, 16)
	UIKit.Stroke(pill, 4, C.Ink)
	UIKit.Gradient(pill, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 205)), 90)
	local pillInner = Instance.new("Frame")
	pillInner.BackgroundTransparency = 1
	pillInner.Position = UDim2.fromOffset(4, 4)
	pillInner.Size = UDim2.new(1, -8, 1, -8)
	UIKit.Corner(pillInner, 12)
	UIKit.Stroke(pillInner, 2.5, C.White, 0.2)
	pillInner.Parent = pill
	local videoText = UIKit.Label({ Text = "▶ VIDEO 1", TextSize = 38, Stroke = 3.5, Parent = pill })
	pill.Parent = holder
	local bar = UIKit.Progress({
		Size = UDim2.new(1, -266, 0, 72),
		Position = UDim2.fromOffset(266, 128),
		Color = C.Red,
		TextSize = 34,
		Parent = holder,
	})
	bar.Label.TextColor3 = C.Ink
	local barStroke = bar.Label:FindFirstChildOfClass("UIStroke")
	if barStroke then
		barStroke.Color = C.White
	end
	HUD.VideoBar = bar

	local setViews = roller(views, "TOTAL VIEWS: ", Format.Smart)
	local lastVideo = 0
	local function update()
		if not State.IsLoaded then
			return
		end
		local data = State.Data
		setViews(data.Views)
		local level, into, need = Stats.Video(data.Views)
		videoText.Text = "▶ VIDEO " .. level
		bar:Set(into / math.max(need, 1), Format.Smart(into) .. " / " .. Format.Smart(need))
		if level ~= lastVideo then
			if lastVideo ~= 0 and level > lastVideo then
				UIKit.Pop(pill, 1.18)
			end
			lastVideo = level
			local tier = Stats.EvolutionTier(level)
			local e = Evolutions[tier]
			local nextEvo = Evolutions[tier + 1]
			local rarity = Theme.Rarities[e.Rarity]
			evo.Text = "EVO "
				.. tier
				.. " • "
				.. string.upper(e.Title)
				.. (if nextEvo then ("   ➜ NEXT AT VIDEO " .. nextEvo.Video) else "   ★ MAX")
			evoGradient.Color = if rarity.Animated
				then Theme.Rainbow
				else ColorSequence.new(rarity.Color:Lerp(C.White, 0.5), rarity.Color:Lerp(C.White, 0.1))
			refreshBadges()
		end
		local mult = Stats.ViewsMultiplier(data, ctx())
		multi.Text = "MULTI: " .. Format.Mult(mult)
		perStep.Text = "+" .. Format.Abbrev(Stats.ViewsPerStep(data, ctx())) .. " / STEP"
	end
	for _, key in { "Views", "Rebirths", "Niche", "EquippedPets", "Equipped", "Potions", "Context" } do
		State.On(key, update)
	end
end

local boostList: Frame? = nil

local function chip(parent: Instance, name: string, text: string, color: Color3, order: number): TextLabel
	local f = parent:FindFirstChild(name) :: Frame?
	if not f then
		local nf = Instance.new("Frame")
		nf.Name = name
		nf.Size = UDim2.fromOffset(0, 44)
		nf.AutomaticSize = Enum.AutomaticSize.X
		nf.BackgroundColor3 = color
		nf.LayoutOrder = order
		UIKit.Round(nf)
		UIKit.Stroke(nf, 3, C.Ink)
		UIKit.Gradient(nf, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210)), 90)
		UIKit.Padding(nf, 14, 0)
		local l = UIKit.Label({
			Name = "Text",
			Text = text,
			TextSize = 24,
			Size = UDim2.fromScale(0, 1),
			AutoX = true,
			Stroke = 2.5,
			Parent = nf,
		})
		l.Name = "Text"
		nf.Parent = parent
		f = nf
	end
	local label = (f :: Frame):FindFirstChild("Text") :: TextLabel
	label.Text = text
	return label
end

local function buildBottomRight(root: Frame)
	local col = UIKit.Frame({
		Name = "Boosts",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -22),
		Size = UDim2.fromOffset(320, 300),
		Parent = root,
	})
	local list = UIKit.List(col, 8, false, Enum.HorizontalAlignment.Right)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	boostList = col
	local back = UIKit.Button({
		Name = "Return",
		Text = "SPAWN",
		Icon = "Home",
		Color = C.Mint,
		Size = UDim2.fromOffset(170, 60),
		TextSize = 26,
		Parent = col,
		LayoutOrder = 100,
		OnClick = function()
			Request.Call("ReturnToSpawn")
		end,
	})
	back.Root.Name = "Return"
end

local function refreshBoosts()
	local col = boostList
	if not col or not State.IsLoaded then
		return
	end
	local data = State.Data
	local c = ctx()
	local function set(name: string, show: boolean, text: string, color: Color3, order: number)
		local existing = col:FindFirstChild(name)
		if show then
			chip(col, name, text, color, order)
		elseif existing then
			existing:Destroy()
		end
	end
	set("Friends", c.Friends > 0, "👥 FRIENDS +" .. math.floor(math.min(c.Friends * 10, 50)) .. "%", C.Blue, 1)
	set("Premium", c.Premium, "⭐ PREMIUM +10%", C.Gold, 2)
	set("ViewsPotion", data.Potions.Views > 0, "🧪 x2 VIEWS " .. Format.Time(data.Potions.Views), C.Red, 3)
	set("CloutPotion", data.Potions.Clout > 0, "🧪 x2 CLOUT " .. Format.Time(data.Potions.Clout), C.Orange, 4)
	local tier = Players.LocalPlayer:GetAttribute("Treadmill")
	local tm = if typeof(tier) == "number" then Treadmills[tier] else nil
	set("Treadmill", tm ~= nil, if tm then ("🏃 TREADMILL x" .. tm.Mult) else "", C.Purple, 5)
end

-- Phones: keep the bottom-left (thumbstick) and bottom-right (jump) corners
-- clear by moving the menu buttons into a top row and currencies under it.
function HUD.ApplyLayout()
	if not UI.IsTouch then
		return
	end
	local root = HUD.Root
	local left = root:FindFirstChild("LeftButtons") :: Frame?
	if left then
		local grid = left:FindFirstChildOfClass("UIGridLayout")
		if grid then
			grid.CellSize = UDim2.fromOffset(100, 100)
			grid.CellPadding = UDim2.fromOffset(12, 12)
			grid.FillDirection = Enum.FillDirection.Horizontal
		end
		left.AnchorPoint = Vector2.zero
		left.Position = UDim2.fromOffset(18, 10)
		left.Size = UDim2.fromOffset(6 * 100 + 5 * 12, 100)
		for _, b in left:GetChildren() do
			if b:IsA("Frame") then
				b.Size = UDim2.fromOffset(100, 100)
			end
		end
	end
	local currencies = root:FindFirstChild("Currencies") :: Frame?
	if currencies then
		currencies.AnchorPoint = Vector2.zero
		currencies.Position = UDim2.fromOffset(18, 128)
		local list = currencies:FindFirstChildOfClass("UIListLayout")
		if list then
			list.VerticalAlignment = Enum.VerticalAlignment.Top
		end
	end
	local boosts = root:FindFirstChild("Boosts") :: Frame?
	if boosts then
		boosts.Position = UDim2.new(1, -22, 1, -230)
	end
end

function HUD.SetHidden(isHidden: boolean)
	hidden = isHidden
	for _, child in HUD.Root:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "TopRight" then
			child.Visible = not isHidden
		end
	end
end

function HUD.Init() end

function HUD.Start()
	local root = UI.Layer(UI.HUD)
	HUD.Root = root
	buildLeft(root)
	buildTopCenter(root)
	buildTopRight(root)
	buildRight(root)
	buildBottomLeft(root)
	buildBottomCenter(root)
	buildBottomRight(root)
	HUD.ApplyLayout()

	for _, key in { "Devices", "Upgrades", "Daily", "Rebirths", "Unlocked" } do
		State.On(key, function()
			refreshBadges()
		end)
	end
	for _, key in { "Potions", "Context" } do
		State.On(key, refreshBoosts)
	end
	Players.LocalPlayer:GetAttributeChangedSignal("Treadmill"):Connect(refreshBoosts)

	-- 1s UI clock: gift timer + potion countdown smoothing
	task.spawn(function()
		while true do
			if State.IsLoaded then
				local ready, nextIn = giftStatus()
				if giftLabel and giftBadge then
					if ready > 0 then
						giftLabel.Text = "CLAIM!"
						giftLabel.TextColor3 = C.Mint
						giftBadge:Set(tostring(ready))
					else
						giftLabel.Text = if nextIn then Format.Time(nextIn) else "ALL DONE"
						giftLabel.TextColor3 = C.White
						giftBadge:Set(nil)
					end
				end
				refreshBoosts()
				refreshBadges()
			end
			task.wait(1)
		end
	end)
	local _ = RunService
	local __ = Products
end

return HUD
