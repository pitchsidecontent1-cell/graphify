--!strict
-- Admin command bar: a typing line with autocomplete (commands, then their
-- options and player names), command history and a small output log.
-- Built and opened by Controllers/Admin (press ; or F2).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Products = require(Shared.Config.Products)
local Niches = require(Shared.Config.Niches)
local Pets = require(Shared.Config.Pets)
local Upgrades = require(Shared.Config.Upgrades)
local AdminCommands = require(Shared.Util.AdminCommands)
local UIKit = require(script.Parent.UIKit)
local UI = require(script.Parent.UI)

local C = Theme.Colors
local MAX_SUGGESTIONS = 7
local MAX_LOG = 7
local WIDTH = 1180

local AdminConsole = {}

export type Console = {
	Open: (prefill: string?) -> (),
	Close: () -> (),
	Toggle: () -> (),
	IsOpen: () -> boolean,
	Log: (text: string, kind: string?) -> (),
}

type Suggestion = { usage: string, detail: string, insert: string }

local LOG_COLORS: { [string]: Color3 } = {
	ok = C.Mint,
	error = Color3.fromRGB(255, 120, 130),
	cmd = C.Cyan,
	info = Color3.fromRGB(225, 220, 240),
}

local function escape(s: string): string
	s = string.gsub(s, "&", "&amp;")
	s = string.gsub(s, "<", "&lt;")
	s = string.gsub(s, ">", "&gt;")
	return s
end

local function lowerList(list: { any }, field: string): { string }
	local out = {}
	for _, item in list do
		table.insert(out, string.lower(item[field]))
	end
	return out
end

local function playerWords(): { string }
	local out = { "me", "all", "others" }
	for _, p in Players:GetPlayers() do
		table.insert(out, string.lower(p.Name))
	end
	return out
end

-- Values worth suggesting for argument `index` of a command (nil = none).
local function optionsFor(command: AdminCommands.Command, index: number): { string }?
	local arg = command.Args[index]
	if not arg then
		return if command.Target and index == #command.Args + 1 then playerWords() else nil
	end
	local name = command.Name
	if arg.Kind == "player" then
		return playerWords()
	elseif name == "goto" then
		local list = { "spawn", "arena", "treadmills", "devices", "upgrades", "rebirth", "niche", "eggs", "portal" }
		for _, p in Players:GetPlayers() do
			table.insert(list, string.lower(p.Name))
		end
		return list
	elseif name == "pass" or name == "unpass" then
		local list = lowerList(Products.Passes, "Key")
		table.insert(list, "all")
		return list
	elseif name == "product" then
		return lowerList(Products.Products, "Key")
	elseif name == "niche" then
		local list = lowerList(Niches.List, "Id")
		table.insert(list, "none")
		return list
	elseif name == "hatch" and index == 1 then
		local list = {}
		for _, id in Pets.EggOrder do
			table.insert(list, string.lower(id))
		end
		return list
	elseif name == "upgrade" then
		if index == 1 then
			local list = lowerList(Upgrades, "Id")
			table.insert(list, "all")
			return list
		end
		return { "max", "0" }
	elseif name == "potion" and index == 1 then
		return { "views", "clout", "all" }
	elseif name == "fx" then
		return { "video", "evolve", "rebirth", "claim", "world", "reward", "purchase" }
	elseif name == "beat" then
		return { "here", "all", "1", "2", "3", "4" }
	elseif name == "reset" then
		return { "confirm" }
	end
	return nil
end

-- Command list sorted for suggestions: exact name, name prefix, alias prefix.
local function matchCommands(word: string): { AdminCommands.Command }
	local exact, byName, byAlias = {}, {}, {}
	local seen: { [string]: boolean } = {}
	for _, c in AdminCommands.List do
		if c.Name == word then
			table.insert(exact, c)
			seen[c.Name] = true
		end
	end
	for _, c in AdminCommands.List do
		if not seen[c.Name] and string.sub(c.Name, 1, #word) == word then
			table.insert(byName, c)
			seen[c.Name] = true
		end
	end
	for _, c in AdminCommands.List do
		if not seen[c.Name] then
			for _, alias in c.Aliases do
				if string.sub(alias, 1, #word) == word then
					table.insert(byAlias, c)
					seen[c.Name] = true
					break
				end
			end
		end
	end
	local out = {}
	for _, list in { exact, byName, byAlias } do
		for _, c in list do
			table.insert(out, c)
		end
	end
	return out
end

-- Usage line with the argument being typed in bold yellow.
local function richUsage(command: AdminCommands.Command, current: number?): string
	local parts = { "<b>" .. command.Name .. "</b>" }
	local n = 0
	local function add(text: string)
		n += 1
		local t = escape(text)
		if current == n then
			t = '<font color="#FFD23F"><b>' .. t .. "</b></font>"
		end
		table.insert(parts, t)
	end
	for _, arg in command.Args do
		add(if arg.Optional then "[" .. arg.Name .. "]" else "<" .. arg.Name .. ">")
	end
	if command.Target then
		add("[player]")
	end
	return table.concat(parts, " ")
end

local function suggestionsFor(text: string): { Suggestion }
	local clean = string.lower(AdminCommands.Clean(text))
	if clean == "" then
		return {}
	end
	local tokens = AdminCommands.Split(clean)
	local endsWithSpace = string.match(text, "%s$") ~= nil
	-- still typing the command name
	if #tokens == 1 and not endsWithSpace then
		local out = {}
		for _, c in matchCommands(tokens[1]) do
			local needsArgs = #c.Args > 0 or c.Target
			table.insert(out, {
				usage = richUsage(c, nil),
				detail = c.Help,
				insert = c.Name .. (if needsArgs then " " else ""),
			})
			if #out >= MAX_SUGGESTIONS then
				break
			end
		end
		return out
	end
	local command = AdminCommands.Find(tokens[1])
	if not command then
		return { { usage = "<b>?</b>", detail = "Unknown command - try cmds", insert = text } }
	end
	-- which argument is being typed (1-based, after the command word)
	local index = if endsWithSpace then #tokens else #tokens - 1
	local partial = if endsWithSpace then "" else tokens[#tokens]
	local out: { Suggestion } = {
		{ usage = richUsage(command, index), detail = command.Help, insert = text },
	}
	local options = optionsFor(command, index)
	if options then
		local base = table.concat(tokens, " ", 1, if endsWithSpace then #tokens else #tokens - 1)
		for _, option in options do
			if string.sub(option, 1, #partial) == partial and option ~= partial then
				table.insert(out, { usage = escape(option), detail = "", insert = base .. " " .. option .. " " })
				if #out >= MAX_SUGGESTIONS then
					break
				end
			end
		end
	end
	return out
end

function AdminConsole.Build(run: (text: string) -> ()): Console
	local layer = UI.Layer(UI.Top)

	local root = Instance.new("Frame")
	root.Name = "AdminConsole"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 16)
	root.Size = UDim2.fromOffset(WIDTH, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.BackgroundColor3 = C.Ink
	root.BackgroundTransparency = 0.06
	root.Visible = false
	root.ZIndex = 300
	UIKit.Corner(root, 20)
	UIKit.Stroke(root, 4, C.Ink)
	UIKit.Gradient(root, ColorSequence.new(C.PanelLight, C.PanelDark), 90)
	UIKit.Padding(root, 18, 14)
	local rootList = UIKit.List(root, 10)
	rootList.VerticalAlignment = Enum.VerticalAlignment.Top
	root.Parent = layer

	-- header
	local header = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, Parent = root })
	local title = UIKit.Label({
		Text = "🛠️ ADMIN COMMANDS",
		TextSize = 28,
		Color = C.Yellow,
		XAlign = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.5, 0, 1, 0),
		Parent = header,
	})
	title.ZIndex = 301
	local hint = UIKit.Label({
		Text = if UI.IsTouch
			then "tap a suggestion to fill it in"
			else "ENTER run  •  TAB complete  •  ↑↓ pick / history  •  ESC close",
		TextSize = 17,
		Font = Theme.Fonts.Body,
		Color = Color3.fromRGB(200, 195, 220),
		Stroke = 0,
		XAlign = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -54, 0, 0),
		Size = UDim2.new(0.6, 0, 1, 0),
		Parent = header,
	})
	hint.ZIndex = 301
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, 0, 0.5, 0)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = C.Red
	close.Text = ""
	close.AutoButtonColor = false
	close.ZIndex = 301
	UIKit.Round(close)
	UIKit.Stroke(close, 3, C.Ink).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local x = UIKit.Label({ Text = "✕", TextSize = 22, Stroke = 2, Parent = close })
	x.ZIndex = 302
	close.Parent = header

	-- input line
	local inputFrame = Instance.new("Frame")
	inputFrame.Name = "Input"
	inputFrame.LayoutOrder = 2
	inputFrame.Size = UDim2.new(1, 0, 0, 62)
	inputFrame.BackgroundColor3 = Color3.fromRGB(248, 246, 255)
	inputFrame.ZIndex = 301
	UIKit.Corner(inputFrame, 14)
	UIKit.Stroke(inputFrame, 3.5, C.Ink)
	inputFrame.Parent = root
	local prompt = UIKit.Label({
		Text = "›",
		TextSize = 40,
		Color = C.Purple,
		Stroke = 0,
		Size = UDim2.fromOffset(44, 62),
		Parent = inputFrame,
	})
	prompt.ZIndex = 302
	local box = Instance.new("TextBox")
	box.Name = "Box"
	box.BackgroundTransparency = 1
	box.Position = UDim2.fromOffset(44, 0)
	box.Size = UDim2.new(1, -60, 1, 0)
	box.ClearTextOnFocus = false
	box.Text = ""
	box.PlaceholderText = "type a command...   e.g.  clout 1m   •   video 50   •   pet dragon 3   •   cmds"
	box.PlaceholderColor3 = Color3.fromRGB(150, 145, 170)
	box.TextColor3 = C.Ink
	box.TextSize = 28
	box.FontFace = Theme.Fonts.Body
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClipsDescendants = true
	box.ZIndex = 302
	box.Parent = inputFrame

	-- suggestions
	local suggestFrame = UIKit.Frame({
		Name = "Suggestions",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = root,
	})
	local suggestList = UIKit.List(suggestFrame, 4)
	suggestList.VerticalAlignment = Enum.VerticalAlignment.Top

	-- output log
	local logFrame = UIKit.Frame({
		Name = "Log",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = root,
	})
	local logList = UIKit.List(logFrame, 2)
	logList.VerticalAlignment = Enum.VerticalAlignment.Top
	logList.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local suggestions: { Suggestion } = {}
	local rows: { TextButton } = {}
	local selected = 1
	local history: { string } = {}
	local historyIndex = 0 -- 0 = not browsing
	local openedAt = 0
	local logCount = 0

	local function setText(text: string)
		box.Text = text
		box.CursorPosition = #text + 1
	end

	local function paintSelection()
		for i, row in rows do
			local on = i == selected and #rows > 1
			row.BackgroundTransparency = if on then 0 else 0.55
			row.BackgroundColor3 = if on then C.Purple else C.InkSoft
		end
	end

	local function renderSuggestions()
		for _, row in rows do
			row:Destroy()
		end
		table.clear(rows)
		for i, s in suggestions do
			local row = Instance.new("TextButton")
			row.Name = "Suggestion" .. i
			row.LayoutOrder = i
			row.Size = UDim2.new(1, 0, 0, 40)
			row.AutoButtonColor = false
			row.Text = ""
			row.ZIndex = 301
			UIKit.Corner(row, 10)
			local usage = UIKit.Label({
				Text = s.usage,
				RichText = true,
				TextSize = 24,
				Stroke = 2,
				XAlign = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(0.46, -14, 1, 0),
				Parent = row,
			})
			usage.ZIndex = 302
			usage.TextTruncate = Enum.TextTruncate.AtEnd
			local detail = UIKit.Label({
				Text = s.detail,
				TextSize = 18,
				Font = Theme.Fonts.Body,
				Stroke = 0,
				Color = Color3.fromRGB(215, 210, 235),
				XAlign = Enum.TextXAlignment.Left,
				Position = UDim2.new(0.46, 6, 0, 0),
				Size = UDim2.new(0.54, -18, 1, 0),
				Parent = row,
			})
			detail.ZIndex = 302
			detail.TextTruncate = Enum.TextTruncate.AtEnd
			row.Activated:Connect(function()
				setText(s.insert)
				box:CaptureFocus()
			end)
			row.Parent = suggestFrame
			table.insert(rows, row)
		end
		selected = math.clamp(selected, 1, math.max(#rows, 1))
		paintSelection()
	end

	local function refresh()
		suggestions = suggestionsFor(box.Text)
		-- the first row of an argument hint is the usage line; start on the first option
		selected = if #suggestions > 1 and suggestions[1].insert == box.Text then 2 else 1
		renderSuggestions()
	end

	local lastComplete = 0
	local function complete()
		lastComplete = os.clock()
		local s = suggestions[selected]
		if s and s.insert ~= box.Text then
			setText(s.insert)
		end
	end

	local console: Console

	local function submit()
		local text = AdminCommands.Clean(box.Text)
		if text == "" then
			return
		end
		if history[#history] ~= text then
			table.insert(history, text)
			if #history > 50 then
				table.remove(history, 1)
			end
		end
		historyIndex = 0
		console.Log("› " .. text, "cmd")
		setText("")
		task.spawn(run, text)
	end

	box:GetPropertyChangedSignal("Text"):Connect(function()
		local text = box.Text
		-- the ; that opened the bar, or a Tab character from completion
		if os.clock() - openedAt < 0.25 and (text == ";" or text == "/") then
			box.Text = ""
			return
		end
		if string.find(text, "\t") then
			-- Tab typed into the box: complete once (InputBegan may already have)
			setText((string.gsub(text, "\t", "")))
			if os.clock() - lastComplete > 0.15 then
				complete()
			end
			return
		end
		if historyIndex > 0 and history[historyIndex] ~= text then
			historyIndex = 0
		end
		refresh()
	end)

	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
			-- keep typing: chain commands without reopening
			task.defer(function()
				if root.Visible then
					box:CaptureFocus()
				end
			end)
		end
	end)

	UserInputService.InputBegan:Connect(function(input)
		if not root.Visible then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.Escape then
			console.Close()
		elseif not box:IsFocused() then
			return
		elseif key == Enum.KeyCode.Tab then
			complete()
		elseif key == Enum.KeyCode.Up or key == Enum.KeyCode.Down then
			local browsing = box.Text == "" or (historyIndex > 0 and history[historyIndex] == box.Text)
			if browsing and #history > 0 then
				if key == Enum.KeyCode.Up then
					historyIndex = if historyIndex == 0 then #history else math.max(1, historyIndex - 1)
				else
					historyIndex = if historyIndex == 0 then 0 else historyIndex + 1
					if historyIndex > #history then
						historyIndex = 0
					end
				end
				setText(if historyIndex > 0 then history[historyIndex] else "")
			elseif #rows > 1 then
				selected = if key == Enum.KeyCode.Up then selected - 1 else selected + 1
				if selected < 1 then
					selected = #rows
				elseif selected > #rows then
					selected = 1
				end
				paintSelection()
			end
		end
	end)

	console = {
		Open = function(prefill: string?)
			openedAt = os.clock()
			root.Visible = true
			UIKit.Pop(root, 0.25)
			setText(prefill or "")
			refresh()
			task.defer(function()
				box:CaptureFocus()
			end)
		end,
		Close = function()
			root.Visible = false
			if box:IsFocused() then
				box:ReleaseFocus()
			end
		end,
		Toggle = function()
			if root.Visible then
				console.Close()
			else
				console.Open()
			end
		end,
		IsOpen = function(): boolean
			return root.Visible
		end,
		Log = function(text: string, kind: string?)
			logCount += 1
			local label = UIKit.Label({
				Text = text,
				TextSize = 20,
				Font = Theme.Fonts.Body,
				Stroke = 0,
				Color = LOG_COLORS[kind or "info"] or LOG_COLORS.info,
				Wrapped = true,
				XAlign = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 0),
				Parent = logFrame,
			})
			label.AutomaticSize = Enum.AutomaticSize.Y
			label.LayoutOrder = logCount
			label.ZIndex = 301
			local entries = {}
			for _, child in logFrame:GetChildren() do
				if child:IsA("TextLabel") then
					table.insert(entries, child)
				end
			end
			table.sort(entries, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			for i = 1, #entries - MAX_LOG do
				entries[i]:Destroy()
			end
		end,
	}

	close.Activated:Connect(function()
		console.Close()
	end)

	return console
end

return AdminConsole
