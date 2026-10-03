--!strict
-- Admin / test panel: every admin command as a button, grouped in tabs, plus
-- a target picker (you / everyone / another player) and the full command
-- list. Visible to admins only (Studio, the owner, Config/Admin).

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Products = require(Shared.Config.Products)
local Worlds = require(Shared.Config.Worlds)
local Niches = require(Shared.Config.Niches)
local Pets = require(Shared.Config.Pets)
local Upgrades = require(Shared.Config.Upgrades)
local Devices = require(Shared.Config.Devices)
local Evolutions = require(Shared.Config.Evolutions)
local Rewards = require(Shared.Config.Rewards)
local Stats = require(Shared.Util.Stats)
local AdminCommands = require(Shared.Util.AdminCommands)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)
local Admin = require(script.Parent.Parent.Parent.Controllers.Admin)

local C = Theme.Colors
local PANEL = Vector2.new(1180, 780)
local TAB_W = 214
local CELL = Vector2.new(272, 56)

type Target = { label: string, token: string }

local TABS = {
	{ Id = "Progress", Icon = "📈", Color = C.Blue },
	{ Id = "World", Icon = "🌍", Color = C.Mint },
	{ Id = "Items", Icon = "📷", Color = C.Orange },
	{ Id = "Pets", Icon = "🐾", Color = C.Green },
	{ Id = "Rewards", Icon = "🎁", Color = C.Pink },
	{ Id = "Rivals", Icon = "⚔️", Color = C.Red },
	{ Id = "Robux", Icon = "💎", Color = C.Purple },
	{ Id = "Server", Icon = "🖥️", Color = C.Cyan },
	{ Id = "Commands", Icon = "📜", Color = C.Gold },
}

local function currentWorld(): number
	return if State.IsLoaded then State.Data.World else 1
end

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Admin", Color = C.Red, Size = PANEL })
	local body = panel.Body

	-- Target picker ----------------------------------------------------------------------------
	local targets: { Target } = {}
	local targetIndex = 1

	local topBar = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 60), Parent = body })
	UIKit.Label({
		Text = "TARGET",
		TextSize = 26,
		Color = C.Yellow,
		XAlign = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(110, 60),
		Parent = topBar,
	})
	local pill = UIKit.Card(topBar, UDim2.fromOffset(330, 52), C.InkSoft)
	pill.Position = UDim2.fromOffset(176, 4)
	local targetLabel = UIKit.Label({
		Text = "ME",
		TextSize = 28,
		Scaled = true,
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		Parent = pill,
	})
	local function arrow(text: string, x: number, delta: number)
		UIKit.Button({
			Text = text,
			Color = C.Blue,
			TextSize = 26,
			Size = UDim2.fromOffset(54, 52),
			Position = UDim2.fromOffset(x, 2),
			Parent = topBar,
			OnClick = function()
				targetIndex = ((targetIndex - 1 + delta) % #targets) + 1
				targetLabel.Text = targets[targetIndex].label
			end,
		})
	end
	arrow("◀", 114, -1)
	arrow("▶", 514, 1)

	local function rebuildTargets()
		local keep = if targets[targetIndex] then targets[targetIndex].token else "me"
		table.clear(targets)
		table.insert(targets, { label = "ME", token = "me" })
		table.insert(targets, { label = "EVERYONE", token = "all" })
		local others = 0
		for _, p in Players:GetPlayers() do
			if p ~= Players.LocalPlayer then
				others += 1
				table.insert(targets, { label = string.upper(p.DisplayName), token = p.Name })
			end
		end
		if others > 1 then
			table.insert(targets, 3, { label = "EVERYONE ELSE", token = "others" })
		end
		targetIndex = 1
		for i, t in targets do
			if t.token == keep then
				targetIndex = i
			end
		end
		targetLabel.Text = targets[targetIndex].label
	end
	rebuildTargets()
	Players.PlayerAdded:Connect(rebuildTargets)
	Players.PlayerRemoving:Connect(function()
		task.defer(rebuildTargets)
	end)

	local function targetToken(): string
		return targets[targetIndex].token
	end

	UIKit.Button({
		Text = "COMMAND BAR",
		Icon = "⌨️",
		Color = C.Purple,
		TextSize = 24,
		Size = UDim2.fromOffset(290, 54),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		Parent = topBar,
		OnClick = function()
			UI.Close()
			Admin.OpenConsole()
		end,
	})

	-- Runs `cmd`, adding the chosen target when the command takes one.
	local function run(cmd: string)
		local spec = AdminCommands.Find(string.match(cmd, "^%S+") or "")
		local text = cmd
		if spec and spec.Target and targetToken() ~= "me" then
			text ..= " " .. targetToken()
		end
		task.spawn(Admin.Run, text, "panel")
	end

	-- Tabs + pages -----------------------------------------------------------------------------------
	local tabColumn = UIKit.Frame({
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(0, TAB_W, 1, -74),
		Parent = body,
	})
	local tabList = UIKit.List(tabColumn, 8)
	tabList.VerticalAlignment = Enum.VerticalAlignment.Top
	local content = UIKit.Frame({
		Position = UDim2.fromOffset(TAB_W + 16, 74),
		Size = UDim2.new(1, -(TAB_W + 16), 1, -74),
		Parent = body,
	})

	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: UIKit.Button } = {}
	local currentTab = "Progress"

	local function selectTab(id: string)
		currentTab = id
		for _, tab in TABS do
			local on = tab.Id == id
			pages[tab.Id].Visible = on
			tabButtons[tab.Id]:SetColor(if on then C.Yellow else tab.Color)
			tabButtons[tab.Id].Label.TextColor3 = if on then C.Ink else C.White
			local stroke = tabButtons[tab.Id].Label:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Enabled = not on
			end
		end
	end

	for i, tab in TABS do
		local page = Instance.new("ScrollingFrame")
		page.Name = tab.Id
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.Size = UDim2.fromScale(1, 1)
		page.CanvasSize = UDim2.new()
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.ScrollBarThickness = 8
		page.ScrollBarImageColor3 = C.White
		page.ScrollBarImageTransparency = 0.4
		page.ScrollingDirection = Enum.ScrollingDirection.Y
		page.Visible = false
		local list = UIKit.List(page, 16, false, Enum.HorizontalAlignment.Left)
		list.VerticalAlignment = Enum.VerticalAlignment.Top
		UIKit.Padding(page, 4, 6)
		page.Parent = content
		pages[tab.Id] = page
		tabButtons[tab.Id] = UIKit.Button({
			Text = string.upper(tab.Id),
			Icon = tab.Icon,
			Color = tab.Color,
			TextSize = 22,
			Size = UDim2.fromOffset(TAB_W, 56),
			LayoutOrder = i,
			Parent = tabColumn,
			OnClick = function()
				selectTab(tab.Id)
			end,
		})
	end

	-- Builders -------------------------------------------------------------------------------------------
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function section(page: string, title: string, note: string?): Frame
		local block = UIKit.Frame({
			Size = UDim2.new(1, -16, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = nextOrder(),
			Parent = pages[page],
		})
		local list = UIKit.List(block, 10, false, Enum.HorizontalAlignment.Left)
		list.VerticalAlignment = Enum.VerticalAlignment.Top
		local head = UIKit.Label({
			Text = string.upper(title),
			TextSize = 26,
			Color = C.Yellow,
			XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = block,
		})
		head.LayoutOrder = 0
		if note then
			local n = UIKit.Label({
				Text = note,
				TextSize = 18,
				Font = Theme.Fonts.Body,
				Stroke = 0,
				Color = Color3.fromRGB(205, 200, 225),
				XAlign = Enum.TextXAlignment.Left,
				Wrapped = true,
				Size = UDim2.new(1, 0, 0, 22),
				Parent = block,
			})
			n.LayoutOrder = 1
		end
		return block
	end

	local function grid(block: Frame, cell: Vector2?): Frame
		local holder = UIKit.Frame({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = nextOrder(),
			Parent = block,
		})
		local g = Instance.new("UIGridLayout")
		local size = cell or CELL
		g.CellSize = UDim2.fromOffset(size.X, size.Y)
		g.CellPadding = UDim2.fromOffset(12, 14)
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.Parent = holder
		UIKit.Padding(holder, 2, 2)
		return holder
	end

	local function button(holder: Frame, text: string, color: Color3, onClick: () -> (), textSize: number?)
		return UIKit.Button({
			Text = text,
			Color = color,
			TextSize = textSize or 21,
			LayoutOrder = nextOrder(),
			Parent = holder,
			OnClick = onClick,
		})
	end

	-- quick button that runs a fixed command
	local function cmdButton(holder: Frame, text: string, color: Color3, cmd: string | () -> string?, textSize: number?)
		return button(holder, text, color, function()
			local resolved = if typeof(cmd) == "function" then cmd() else cmd
			if resolved then
				run(resolved)
			end
		end, textSize)
	end

	-- label + text box + button, e.g. "SET VIDEO [ 20 ] SET"
	local function inputRow(
		block: Frame,
		label: string,
		default: string,
		placeholder: string,
		buttonText: string,
		color: Color3,
		build: (value: string) -> string?
	): TextBox
		local row = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 62), LayoutOrder = nextOrder(), Parent = block })
		UIKit.Label({
			Text = label,
			TextSize = 23,
			XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.fromOffset(250, 56),
			Parent = row,
		})
		local card = UIKit.Card(row, UDim2.fromOffset(340, 54), Color3.fromRGB(248, 246, 255))
		card.Position = UDim2.fromOffset(252, 0)
		local box = Instance.new("TextBox")
		box.BackgroundTransparency = 1
		box.Position = UDim2.fromOffset(14, 0)
		box.Size = UDim2.new(1, -28, 1, 0)
		box.Text = default
		box.PlaceholderText = placeholder
		box.PlaceholderColor3 = Color3.fromRGB(150, 145, 170)
		box.TextColor3 = C.Ink
		box.TextSize = 26
		box.FontFace = Theme.Fonts.Body
		box.ClearTextOnFocus = false
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.ClipsDescendants = true
		box.Parent = card
		local function go()
			local value = string.gsub(box.Text, "^%s+", "")
			value = string.gsub(value, "%s+$", "")
			if value == "" then
				Request.Toast:Fire("Type a value first", "error")
				return
			end
			local cmd = build(value)
			if cmd then
				run(cmd)
			end
		end
		UIKit.Button({
			Text = buttonText,
			Color = color,
			TextSize = 22,
			Size = UDim2.fromOffset(196, 54),
			Position = UDim2.fromOffset(606, 0),
			Parent = row,
			OnClick = go,
		})
		box.FocusLost:Connect(function(enter)
			if enter then
				go()
			end
		end)
		return box
	end

	local function chips(block: Frame, from: number, to: number, color: Color3, cmd: (n: number) -> string)
		local holder = grid(block, Vector2.new(56, 52))
		for n = from, to do
			cmdButton(holder, tostring(n), color, cmd(n), 22)
		end
	end

	-- PROGRESS -----------------------------------------------------------------------------------------------
	do
		local b = section("Progress", "Video level", "Views set your Video level. Video opens gates + evolves you.")
		local g = grid(b)
		cmdButton(g, "+1 VIDEO", C.Blue, "addvideo 1")
		cmdButton(g, "+10 VIDEOS", C.Blue, "addvideo 10")
		cmdButton(g, "-1 VIDEO", C.Grey, "addvideo -1")
		cmdButton(g, "REBIRTH READY", C.Purple, function()
			return "video " .. Stats.RebirthVideo(if State.IsLoaded then State.Data.Rebirths else 0)
		end)
		cmdButton(g, "OPEN ALL GATES", C.Mint, function()
			local w = Worlds[currentWorld()]
			return "video " .. w.Gates[#w.Gates]
		end)
		cmdButton(g, "BACK TO VIDEO 1", C.Grey, "video 1")
		inputRow(b, "SET VIDEO", "20", "1-400", "SET", C.Green, function(v)
			return "video " .. v
		end)

		b = section("Progress", "Evolution", "Each evolution tier changes your size, gear and title.")
		g = grid(b)
		cmdButton(g, "◀ PREVIOUS EVO", C.Grey, function()
			local tier = Players.LocalPlayer:GetAttribute("Evo")
			return "evo " .. math.max(1, (if typeof(tier) == "number" then tier else 1) - 1)
		end)
		cmdButton(g, "NEXT EVO ▶", C.Pink, function()
			local tier = Players.LocalPlayer:GetAttribute("Evo")
			return "evo " .. math.min(#Evolutions, (if typeof(tier) == "number" then tier else 1) + 1)
		end)
		cmdButton(g, "FINAL EVO", C.Gold, "evo " .. #Evolutions)
		inputRow(b, "SET EVOLUTION", "5", "1-" .. #Evolutions, "SET", C.Green, function(v)
			return "evo " .. v
		end)

		b = section("Progress", "Views + clout")
		g = grid(b)
		cmdButton(g, "+1M VIEWS", C.Red, "views 1m")
		cmdButton(g, "+1B VIEWS", C.Red, "views 1b")
		cmdButton(g, "+1T VIEWS", C.Red, "views 1t")
		cmdButton(g, "+1M CLOUT", C.Gold, "addclout 1m")
		cmdButton(g, "+1B CLOUT", C.Gold, "addclout 1b")
		cmdButton(g, "+1T CLOUT", C.Gold, "addclout 1t")
		cmdButton(g, "+1QA CLOUT", C.Gold, "addclout 1qa")
		cmdButton(g, "ZERO CLOUT", C.Grey, "clout 0")
		inputRow(b, "SET CLOUT", "1m", "1k / 2.5m / 1e12", "SET", C.Green, function(v)
			return "clout " .. v
		end)

		b = section("Progress", "Rebirth + tickets", "Treadmills unlock at 2 / 5 / 9 / 14 rebirths.")
		g = grid(b)
		cmdButton(g, "REBIRTH NOW", C.Purple, "rebirth")
		for _, n in { 0, 2, 5, 9, 14, 25 } do
			cmdButton(g, n .. " REBIRTHS", C.Blue, "rebirths " .. n)
		end
		cmdButton(g, "99 TICKETS", C.Cyan, "tickets 99")
		cmdButton(g, "0 TICKETS", C.Grey, "tickets 0")
		inputRow(b, "SET REBIRTHS", "3", "0-100", "SET", C.Green, function(v)
			return "rebirths " .. v
		end)

		b = section("Progress", "Upgrades")
		g = grid(b)
		cmdButton(g, "MAX ALL", C.Mint, "upgrade all max")
		cmdButton(g, "RESET ALL", C.Grey, "upgrade all 0")
		for _, u in Upgrades do
			cmdButton(g, "MAX " .. string.upper(u.Id), C.Blue, "upgrade " .. string.lower(u.Id) .. " max")
		end

		b = section("Progress", "Everything", "MAX gives you the whole game. RESET wipes the save (click twice).")
		g = grid(b)
		cmdButton(g, "⭐ MAX EVERYTHING", C.Gold, "max")
		local armed = 0
		local resetButton: UIKit.Button
		resetButton = button(g, "🗑️ RESET DATA", C.Red, function()
			if os.clock() - armed < 3 then
				armed = 0
				resetButton:SetText("🗑️ RESET DATA")
				run("reset confirm")
			else
				armed = os.clock()
				resetButton:SetText("CLICK AGAIN!")
				task.delay(3, function()
					if os.clock() - armed >= 3 then
						resetButton:SetText("🗑️ RESET DATA")
					end
				end)
			end
		end)
	end

	-- WORLD -------------------------------------------------------------------------------------------------------
	do
		local b = section("World", "Worlds", "Unlocks the world (if needed) and takes you there.")
		local g = grid(b)
		for _, w in Worlds do
			cmdButton(g, w.Id .. " " .. string.upper(w.Name), w.Palette.Accent1, "world " .. w.Id)
		end
		cmdButton(g, "UNLOCK ALL WORLDS", C.Mint, "unlockworlds")

		b = section("World", "Teleport", "Places in the world you're standing in.")
		g = grid(b, Vector2.new(206, 56))
		for _, place in
			{
				{ "SPAWN", "spawn" },
				{ "ARENA", "arena" },
				{ "TREADMILLS", "treadmills" },
				{ "PORTAL", "portal" },
				{ "DEVICES", "devices" },
				{ "UPGRADES", "upgrades" },
				{ "REBIRTH", "rebirth" },
				{ "NICHE", "niche" },
				{ "EGGS", "eggs" },
			}
		do
			cmdButton(g, place[1], C.Blue, "goto " .. place[2])
		end

		b = section("World", "Gates", "Stand in front of gate N.")
		chips(b, 1, 15, C.Orange, function(n)
			return "gate " .. n
		end)
		b = section("World", "Clout pads", "Teleport onto pad N (claims it if its gate is open).")
		chips(b, 1, 15, C.Gold, function(n)
			return "pad " .. n
		end)

		b = section("World", "Movement")
		g = grid(b)
		local fly = cmdButton(g, "🕊️ FLY", C.Cyan, "fly")
		local noclip = cmdButton(g, "👻 NOCLIP", C.Purple, "noclip")
		local function paintToggles()
			local me = Players.LocalPlayer
			fly:SetText(if me:GetAttribute("AdminFly") then "🕊️ FLY: ON" else "🕊️ FLY")
			noclip:SetText(if me:GetAttribute("AdminNoclip") then "👻 NOCLIP: ON" else "👻 NOCLIP")
		end
		Players.LocalPlayer:GetAttributeChangedSignal("AdminFly"):Connect(paintToggles)
		Players.LocalPlayer:GetAttributeChangedSignal("AdminNoclip"):Connect(paintToggles)
		paintToggles()
		cmdButton(g, "RESPAWN", C.Grey, "respawn")
		cmdButton(g, "SPEED 60", C.Blue, "speed 60")
		cmdButton(g, "SPEED 150", C.Blue, "speed 150")
		cmdButton(g, "NORMAL SPEED", C.Grey, "speed")
		inputRow(b, "SET SPEED", "80", "1-500", "SET", C.Green, function(v)
			return "speed " .. v
		end)

		b = section("World", "Players", "Pick a player as the TARGET at the top first.")
		g = grid(b)
		cmdButton(g, "BRING TARGET", C.Pink, function()
			if targetToken() == "me" then
				Request.Toast:Fire("Pick another player as the TARGET first", "error")
				return nil
			end
			return "bring " .. targetToken()
		end)
		cmdButton(g, "GO TO TARGET", C.Pink, function()
			local token = targetToken()
			if token == "me" or token == "all" or token == "others" then
				Request.Toast:Fire("Pick one player as the TARGET first", "error")
				return nil
			end
			-- teleport yourself, not the target
			task.spawn(Admin.Run, "goto " .. token, "panel")
			return nil
		end)
	end

	-- ITEMS ----------------------------------------------------------------------------------------------------------
	do
		local b = section("Items", "Devices", #Devices.List .. " devices, 21 per world.")
		local g = grid(b)
		cmdButton(g, "ALL DEVICES", C.Mint, "devices")
		cmdButton(g, "CLEAR DEVICES", C.Grey, "cleardevices")
		for w = 1, #Worlds do
			local list = Devices.ByWorld[w]
			local best = list and list[#list]
			if best then
				cmdButton(g, "BEST OF WORLD " .. w, C.Orange, "device " .. best.Index)
			end
		end
		inputRow(b, "GIVE DEVICE", "10", "number 1-" .. #Devices.List .. " or name", "GIVE", C.Green, function(v)
			return "device " .. string.gsub(v, "%s+", "")
		end)

		b = section("Items", "Niche", "Pity 49 = your next roll is guaranteed Epic or better.")
		g = grid(b, Vector2.new(206, 56))
		for _, n in Niches.List do
			local rarity = Theme.Rarities[n.Rarity]
			cmdButton(g, n.Emoji .. " " .. string.upper(n.Id), rarity.Color, "niche " .. string.lower(n.Id), 20)
		end
		cmdButton(g, "NO NICHE", C.Grey, "niche none")
		cmdButton(g, "PITY 49", C.Purple, "pity 49")

		b = section("Items", "Potions + boosts")
		g = grid(b)
		cmdButton(g, "x2 VIEWS 15M", C.Red, "potion views 15")
		cmdButton(g, "x2 CLOUT 15M", C.Orange, "potion clout 15")
		cmdButton(g, "BOTH FOR 1 HOUR", C.Pink, "potion all 60")
		cmdButton(g, "CLEAR POTIONS", C.Grey, "potion all 0")
		cmdButton(g, "3 FRIENDS BOOST", C.Mint, "friends 3")
		cmdButton(g, "NO FRIENDS BOOST", C.Grey, "friends 0")
		cmdButton(g, "TOGGLE PREMIUM", C.Gold, "premium")
		cmdButton(g, "TOGGLE GROUP", C.Blue, "group")
	end

	-- PETS --------------------------------------------------------------------------------------------------------------
	do
		local b = section("Pets", "Give pets")
		local g = grid(b)
		cmdButton(g, "ALL PETS", C.Mint, "allpets")
		cmdButton(g, "👑 SECRET PET", C.Pink, "secretpet")
		cmdButton(g, "CLEAR PETS", C.Grey, "clearpets")
		inputRow(b, "GIVE PET", "dragon 3", "name or id, then amount", "GIVE", C.Green, function(v)
			return "pet " .. v
		end)

		b = section("Pets", "Free hatch x10", "Real odds, no clout and no walking needed.")
		g = grid(b)
		for _, eggId in Pets.EggOrder do
			local egg = Pets.Eggs[eggId]
			cmdButton(
				g,
				string.upper(egg.Name),
				egg.Color:Lerp(C.White, 0.15),
				"hatch " .. string.lower(eggId) .. " 10",
				20
			)
		end
	end

	-- REWARDS ------------------------------------------------------------------------------------------------------------
	do
		local b = section("Rewards", "Playtime gifts", #Rewards.Gifts .. " gifts unlock over an hour of play.")
		local g = grid(b)
		cmdButton(g, "ALL GIFTS READY", C.Mint, "gifts")
		cmdButton(g, "RESET GIFTS", C.Grey, "resetgifts")

		b = section("Rewards", "Daily reward", "Pick which day the next claim gives.")
		g = grid(b)
		cmdButton(g, "DAILY READY", C.Orange, "daily")
		local days = grid(b, Vector2.new(110, 52))
		for day = 1, #Rewards.Daily do
			cmdButton(days, "DAY " .. day, if day == #Rewards.Daily then C.Gold else C.Blue, "daily " .. day, 20)
		end

		b = section("Rewards", "Other")
		g = grid(b)
		cmdButton(g, "RESET CODES", C.Cyan, "resetcodes")
		cmdButton(g, "REPLAY TUTORIAL", C.Pink, "tutorial")
	end

	-- RIVALS -----------------------------------------------------------------------------------------------------------------
	do
		local b = section("Rivals", "View War", "FIGHT starts the rival of the world you're in, no requirements.")
		local g = grid(b)
		cmdButton(g, "⚔️ FIGHT NOW", C.Red, "fight")
		cmdButton(g, "🏆 WIN WAR", C.Mint, "win")
		cmdButton(g, "💀 LOSE WAR", C.Grey, "lose")
		cmdButton(g, "GO TO ARENA", C.Blue, "goto arena")
		cmdButton(g, "CLEAR COOLDOWNS", C.Cyan, "nocooldown")

		b = section("Rivals", "Beat rivals", "Beating a rival unlocks the next world.")
		g = grid(b)
		cmdButton(g, "BEAT THIS WORLD", C.Orange, "beat here")
		cmdButton(g, "BEAT ALL", C.Gold, "beat all")
		cmdButton(g, "RESET RIVALS", C.Grey, "resetrivals")
		local chipsHolder = grid(b, Vector2.new(206, 52))
		for _, w in Worlds do
			cmdButton(chipsHolder, "BEAT " .. string.upper(w.Rival.Name), w.Palette.Accent1, "beat " .. w.Id, 17)
		end
	end

	-- ROBUX --------------------------------------------------------------------------------------------------------------------
	do
		local b = section("Robux", "Game passes", "Given for this session only - rejoin to reset.")
		local g = grid(b)
		cmdButton(g, "GIVE ALL PASSES", C.Mint, "pass all")
		cmdButton(g, "REMOVE ALL", C.Grey, "unpass all")
		local status: { [string]: TextLabel } = {}
		for _, pass in Products.Passes do
			local row = UIKit.Card(b, UDim2.new(1, 0, 0, 66), Color3.fromRGB(58, 46, 94))
			row.LayoutOrder = nextOrder()
			UIKit.Label({
				Text = pass.Emoji .. " " .. string.upper(pass.Name),
				TextSize = 24,
				XAlign = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(18, 0),
				Size = UDim2.new(0, 330, 1, 0),
				Parent = row,
			})
			status[pass.Key] = UIKit.Label({
				Text = "",
				TextSize = 20,
				Color = C.Mint,
				XAlign = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(350, 0),
				Size = UDim2.new(0, 120, 1, 0),
				Parent = row,
			})
			UIKit.Button({
				Text = "GIVE",
				Color = C.Green,
				TextSize = 22,
				Size = UDim2.fromOffset(140, 48),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -168, 0.5, -2),
				Parent = row,
				OnClick = function()
					run("pass " .. string.lower(pass.Key))
				end,
			})
			UIKit.Button({
				Text = "REMOVE",
				Color = C.Red,
				TextSize = 22,
				Size = UDim2.fromOffset(140, 48),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, -2),
				Parent = row,
				OnClick = function()
					run("unpass " .. string.lower(pass.Key))
				end,
			})
		end
		State.On("Context", function(ctx)
			for key, label in status do
				label.Text = if ctx and ctx.Passes and ctx.Passes[key] then "✅ OWNED" else ""
			end
		end)

		b = section("Robux", "Developer products", "Grants the product exactly like a real purchase (no Robux).")
		g = grid(b)
		for _, product in Products.Products do
			cmdButton(g, string.upper(product.Name), product.Color, "product " .. string.lower(product.Key), 19)
		end
	end

	-- SERVER ------------------------------------------------------------------------------------------------------------------------
	do
		local b = section("Server", "Tools")
		local g = grid(b)
		cmdButton(g, "📊 SHOW STATS", C.Blue, "stats")
		cmdButton(g, "💾 SAVE NOW", C.Mint, "save")
		cmdButton(g, "🏆 LEADERBOARDS", C.Gold, "lb")
		inputRow(b, "ANNOUNCE", "", "message for everyone", "SEND", C.Pink, function(v)
			return "announce " .. v
		end)

		b = section("Server", "Test effects", "Plays the celebration without changing anything.")
		g = grid(b, Vector2.new(206, 56))
		for _, fx in { "video", "evolve", "rebirth", "claim", "world", "reward", "purchase" } do
			cmdButton(g, string.upper(fx), C.Purple, "fx " .. fx)
		end
	end

	-- COMMANDS (help) -----------------------------------------------------------------------------------------------------------
	do
		local page = pages.Commands
		local searchRow = UIKit.Frame({ Size = UDim2.new(1, -16, 0, 60), LayoutOrder = nextOrder(), Parent = page })
		local card = UIKit.Card(searchRow, UDim2.new(1, 0, 0, 54), Color3.fromRGB(248, 246, 255))
		local search = Instance.new("TextBox")
		search.BackgroundTransparency = 1
		search.Position = UDim2.fromOffset(16, 0)
		search.Size = UDim2.new(1, -32, 1, 0)
		search.Text = ""
		search.PlaceholderText = "🔍 search commands..."
		search.PlaceholderColor3 = Color3.fromRGB(150, 145, 170)
		search.TextColor3 = C.Ink
		search.TextSize = 24
		search.FontFace = Theme.Fonts.Body
		search.ClearTextOnFocus = false
		search.TextXAlignment = Enum.TextXAlignment.Left
		search.Parent = card

		local tip = UIKit.Label({
			Text = "Press ; (or F2) to open the command bar • chat works too: /clout 1m • add a player name at the end: clout 1m Bob",
			TextSize = 18,
			Font = Theme.Fonts.Body,
			Stroke = 0,
			Color = Color3.fromRGB(205, 200, 225),
			Wrapped = true,
			XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -16, 0, 44),
			Parent = page,
		})
		tip.LayoutOrder = nextOrder()

		type Row = { frame: Frame, text: string }
		local rows: { Row } = {}
		for _, category in AdminCommands.Categories do
			local head = UIKit.Label({
				Text = string.upper(category),
				TextSize = 24,
				Color = C.Yellow,
				XAlign = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, -16, 0, 30),
				Parent = page,
			})
			head.LayoutOrder = nextOrder()
			for _, c in AdminCommands.List do
				if c.Category == category then
					local row = UIKit.Card(page, UDim2.new(1, -16, 0, 64), Color3.fromRGB(58, 46, 94))
					row.LayoutOrder = nextOrder()
					local usage = UIKit.Label({
						Text = AdminCommands.Usage(c),
						TextSize = 22,
						XAlign = Enum.TextXAlignment.Left,
						Position = UDim2.fromOffset(16, 4),
						Size = UDim2.new(1, -150, 0, 28),
						Parent = row,
					})
					usage.TextTruncate = Enum.TextTruncate.AtEnd
					local aliasText = if #c.Aliases > 0 then "  (also: " .. table.concat(c.Aliases, ", ") .. ")" else ""
					local help = UIKit.Label({
						Text = c.Help .. aliasText,
						TextSize = 17,
						Font = Theme.Fonts.Body,
						Stroke = 0,
						Color = Color3.fromRGB(215, 210, 235),
						XAlign = Enum.TextXAlignment.Left,
						Position = UDim2.fromOffset(16, 32),
						Size = UDim2.new(1, -150, 0, 26),
						Parent = row,
					})
					help.TextTruncate = Enum.TextTruncate.AtEnd
					UIKit.Button({
						Text = "USE",
						Color = C.Purple,
						TextSize = 20,
						Size = UDim2.fromOffset(110, 46),
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -12, 0.5, -2),
						Parent = row,
						OnClick = function()
							UI.Close()
							local needsArgs = #c.Args > 0 or c.Target
							Admin.OpenConsole(c.Name .. (if needsArgs then " " else ""))
						end,
					})
					table.insert(rows, {
						frame = row,
						text = string.lower(c.Name .. " " .. table.concat(c.Aliases, " ") .. " " .. c.Help),
					})
				end
			end
		end
		search:GetPropertyChangedSignal("Text"):Connect(function()
			local q = string.lower(search.Text)
			for _, r in rows do
				r.frame.Visible = q == "" or string.find(r.text, q, 1, true) ~= nil
			end
		end)
	end

	selectTab(currentTab)

	return {
		Panel = panel,
		Open = function(args: any?)
			if typeof(args) == "table" and typeof(args.Tab) == "string" and pages[args.Tab] then
				selectTab(args.Tab)
			end
		end,
	}
end
