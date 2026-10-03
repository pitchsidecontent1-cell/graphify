--!strict
-- leaderstats (player list), global leaderboards (OrderedDataStore) on the
-- plaza boards, and the live "TOP CREATOR" board.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Format = require(Shared.Util.Format)
local Theme = require(Shared.Config.Theme)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local REFRESH = 120
local INK = Color3.fromRGB(27, 21, 48)

local stores: { [string]: OrderedDataStore } = {}
local nameCache: { [number]: string } = {}
local leaderstats: { [Player]: { Views: StringValue, Clout: StringValue, Rebirths: IntValue } } = {}

-- OrderedDataStores only hold integers (< 2^63), so huge view counts are
-- stored as log10 * 1e12 and decoded for display.
local function encode(stat: string, value: number): number
	if stat == "TotalViews" then
		return math.floor(math.log10(math.max(value, 1)) * 1e12)
	end
	return math.floor(value)
end

local function decode(stat: string, value: number): number
	if stat == "TotalViews" then
		return 10 ^ (value / 1e12)
	end
	return value
end

local function nameOf(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local value = if ok and name then name else ("Player" .. userId)
	nameCache[userId] = value
	return value
end

local function setupLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local views = Instance.new("StringValue")
	views.Name = "Views"
	views.Value = "0"
	views.Parent = folder
	local clout = Instance.new("StringValue")
	clout.Name = "Clout"
	clout.Value = "0"
	clout.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder
	folder.Parent = player
	leaderstats[player] = { Views = views, Clout = clout, Rebirths = rebirths }
end

local function updateLeaderstats(player: Player)
	local refs = leaderstats[player]
	local data = DataService.Get(player)
	if refs and data then
		refs.Views.Value = Format.Abbrev(data.Views)
		refs.Clout.Value = Format.Abbrev(data.Clout)
		refs.Rebirths.Value = data.Rebirths
	end
end

-- Board UI -------------------------------------------------------------------------------
local function boardGui(board: BasePart): ScrollingFrame
	local existing = board:FindFirstChild("BoardGui")
	if existing then
		return existing:FindFirstChild("List") :: ScrollingFrame
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Brightness = 1.3
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.14)
	title.Text = tostring(board:GetAttribute("Title") or "TOP")
	title.TextScaled = true
	title.FontFace = Theme.Fonts.Display
	title.TextColor3 = Theme.Colors.Yellow
	local ts = Instance.new("UIStroke")
	ts.Thickness = 4
	ts.Color = INK
	ts.Parent = title
	title.Parent = gui
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.04, 0.16)
	list.Size = UDim2.fromScale(0.92, 0.82)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 0
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = gui
	gui.Parent = board
	return list
end

local function fillBoard(board: BasePart, rows: { { name: string, value: string } })
	local list = boardGui(board)
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, row in rows do
		local f = Instance.new("Frame")
		f.LayoutOrder = i
		f.Size = UDim2.new(1, 0, 0, 34)
		f.BackgroundColor3 = if i == 1
			then Theme.Colors.Gold
			elseif i == 2 then Color3.fromRGB(205, 210, 222)
			elseif i == 3 then Color3.fromRGB(205, 127, 50)
			else Color3.fromRGB(60, 48, 96)
		f.BackgroundTransparency = if i <= 3 then 0.1 else 0.35
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = f
		local function cell(text: string, x: number, w: number, align: Enum.TextXAlignment)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(x, 0.1)
			l.Size = UDim2.fromScale(w, 0.8)
			l.Text = text
			l.TextScaled = true
			l.TextXAlignment = align
			l.FontFace = Theme.Fonts.Display
			l.TextColor3 = Color3.new(1, 1, 1)
			local s = Instance.new("UIStroke")
			s.Thickness = 2
			s.Color = INK
			s.Parent = l
			l.Parent = f
		end
		cell("#" .. i, 0.02, 0.12, Enum.TextXAlignment.Left)
		cell(row.name, 0.15, 0.52, Enum.TextXAlignment.Left)
		cell(row.value, 0.66, 0.32, Enum.TextXAlignment.Right)
		f.Parent = list
	end
end

local function refreshGlobal()
	-- write everyone's current values
	for player, data in DataService.Players() do
		for stat, store in stores do
			local value = if stat == "TotalViews" then data.TotalViews else data.Rebirths
			pcall(function()
				store:SetAsync(tostring(player.UserId), encode(stat, value))
			end)
		end
	end
	-- read top 50 for each stat, fill every board showing it
	for stat, store in stores do
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, 50)
		end)
		if ok and pages then
			local rows = {}
			for _, entry in pages:GetCurrentPage() do
				local userId = tonumber(entry.key)
				if userId then
					table.insert(rows, {
						name = nameOf(userId),
						value = Format.Abbrev(decode(stat, entry.value)),
					})
				end
			end
			for _, board in CollectionService:GetTagged("Leaderboard") do
				if board:IsA("BasePart") and board:GetAttribute("Stat") == stat then
					fillBoard(board, rows)
				end
			end
		end
	end
end

local liveLabels: { { name: TextLabel, value: TextLabel } } = {}

local function setupLiveBoards()
	for _, board in CollectionService:GetTagged("TopCreatorBoard") do
		if board:IsA("BasePart") then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "LiveGui"
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 25
			gui.LightInfluence = 0
			gui.Brightness = 1.4
			local function label(y: number, h: number, color: Color3, text: string): TextLabel
				local l = Instance.new("TextLabel")
				l.BackgroundTransparency = 1
				l.Position = UDim2.fromScale(0.04, y)
				l.Size = UDim2.fromScale(0.92, h)
				l.TextScaled = true
				l.FontFace = Theme.Fonts.Display
				l.TextColor3 = color
				l.Text = text
				local s = Instance.new("UIStroke")
				s.Thickness = 4
				s.Color = INK
				s.Parent = l
				l.Parent = gui
				return l
			end
			label(0.04, 0.2, Theme.Colors.Red, "● LIVE • TOP CREATOR IN THIS SERVER")
			local name = label(0.26, 0.3, Color3.new(1, 1, 1), "...")
			local value = label(0.58, 0.36, Theme.Colors.Yellow, "0")
			gui.Parent = board
			table.insert(liveLabels, { name = name, value = value })
		end
	end
end

function LeaderboardService.Init()
	for _, stat in { "TotalViews", "Rebirths" } do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore("LB_" .. stat .. "_v1")
		end)
		if ok and store then
			stores[stat] = store
		end
	end
end

function LeaderboardService.Start()
	DataService.Loaded:Connect(function(player: Player)
		setupLeaderstats(player)
		updateLeaderstats(player)
	end)
	DataService.Changed:Connect(function(player: Player, key: string)
		if key == "Clout" or key == "Rebirths" or key == "Views" then
			updateLeaderstats(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		leaderstats[player] = nil
	end)
	setupLiveBoards()
	task.spawn(function()
		while true do
			local best: Player? = nil
			local bestViews = -1
			for player, data in DataService.Players() do
				if data.Views > bestViews then
					best, bestViews = player, data.Views
				end
			end
			for _, l in liveLabels do
				if best then
					l.name.Text = (best :: Player).DisplayName
					l.value.Text = "👁️ " .. Format.Commas(bestViews)
				end
			end
			task.wait(0.5)
		end
	end)
	if DataService.Persistent then
		task.spawn(function()
			task.wait(10)
			while true do
				pcall(refreshGlobal)
				task.wait(REFRESH)
			end
		end)
	end
end

return LeaderboardService
