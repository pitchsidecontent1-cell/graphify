--!strict
-- DEVICES shop: 21 devices per world, bought with clout, best one is held.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Devices = require(Shared.Config.Devices)
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Util.Format)
local Stats = require(Shared.Util.Stats)
local DeviceModels = require(Shared.Models.DeviceModels)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)
local Sound = require(script.Parent.Parent.Parent.Controllers.Sound)

local C = Theme.Colors
local TAB_ICONS = { "📷", "📱", "💻", "🎬" }

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Devices", Color = C.Cyan, Size = Vector2.new(1000, 720) })
	local body = panel.Body
	local currentWorld = 1
	local tiles: { [string]: UIKit.Tile } = {}
	local built: { [number]: boolean } = {}

	-- tabs
	local tabRow = UIKit.Frame({ Name = "Tabs", Size = UDim2.new(1, 0, 0, 66), Parent = body })
	UIKit.List(tabRow, 12, true, Enum.HorizontalAlignment.Left)
	local tabButtons: { UIKit.Button } = {}

	local info = UIKit.Label({
		Text = "",
		TextSize = 24,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 70),
		XAlign = Enum.TextXAlignment.Left,
		Color = C.Yellow,
		Parent = body,
	})

	local gridHolder = UIKit.Frame({
		Name = "GridHolder",
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 1, -190),
		Parent = body,
	})
	local grids: { [number]: ScrollingFrame } = {}

	local footer = UIKit.Frame({
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 76),
		Parent = body,
	})
	UIKit.List(footer, 16, true)
	UIKit.Button({
		Text = "BUY ALL",
		Icon = "💰",
		Color = C.Gold,
		Size = UDim2.fromOffset(250, 70),
		Parent = footer,
		OnClick = function()
			local r = Request.Call("BuyBestDevices")
			if r.ok then
				Sound.Play("Purchase")
			end
		end,
	})
	UIKit.Button({
		Text = "EQUIP BEST",
		Icon = "⭐",
		Color = C.Mint,
		Size = UDim2.fromOffset(270, 70),
		Parent = footer,
		OnClick = function()
			Request.Call("EquipBestDevice")
		end,
	})

	local function refreshTile(d: Devices.Device)
		local tile = tiles[d.Id]
		if not tile or not State.IsLoaded then
			return
		end
		local data = State.Data
		local owned = data.Devices[d.Id] == true
		local prev = Devices.List[d.Index - 1]
		local buyable = not owned and (not prev or data.Devices[prev.Id] == true)
		tile.Name.Text = d.Name
		tile.Sub.Text = "+" .. Format.Abbrev(d.Value) .. " / STEP"
		if data.Equipped == d.Id then
			tile.Tag.Text = "✅ EQUIPPED"
			tile.Tag.TextColor3 = C.Mint
			tile.Stroke.Color = C.Mint
			tile.Stroke.Thickness = 6
		elseif owned then
			tile.Tag.Text = "TAP TO EQUIP"
			tile.Tag.TextColor3 = C.White
			tile.Stroke.Color = C.Ink
			tile.Stroke.Thickness = 4
		elseif buyable then
			tile.Tag.Text = "💰 " .. Format.Abbrev(d.Cost)
			tile.Tag.TextColor3 = if data.Clout >= d.Cost then C.Gold else Color3.fromRGB(255, 130, 130)
			tile.Stroke.Color = if data.Clout >= d.Cost then C.Gold else C.Ink
			tile.Stroke.Thickness = 4
		else
			tile.Tag.Text = "🔒 " .. Format.Abbrev(d.Cost)
			tile.Tag.TextColor3 = Color3.fromRGB(200, 200, 210)
			tile.Stroke.Color = C.Ink
			tile.Stroke.Thickness = 4
		end
		local vp = tile.Content:FindFirstChild("Viewport") :: ViewportFrame?
		if vp then
			vp.ImageTransparency = if owned or buyable then 0 else 0.55
			vp.ImageColor3 = if owned or buyable then Color3.new(1, 1, 1) else Color3.fromRGB(40, 30, 60)
		end
	end

	local function buildWorld(w: number)
		if built[w] then
			return
		end
		built[w] = true
		local grid = UIKit.Grid(gridHolder, Vector2.new(214, 252), 14)
		grid.Visible = false
		grids[w] = grid
		for _, d in Devices.ByWorld[w] do
			local tile = UIKit.Tile({ Rarity = d.Rarity, Parent = grid, LayoutOrder = d.Tier, Name = d.Id })
			tiles[d.Id] = tile
			local model = DeviceModels.Build(d, CFrame.new(), false)
			local extent = DeviceModels.Extents[d.Kind] or 3
			local vp = UIKit.Viewport(model, extent, tile.Content, math.rad(30))
			local stopSpin: (() -> ())? = nil
			tile.Root.MouseEnter:Connect(function()
				stopSpin = UIKit.Spin(vp, extent, 2)
			end)
			tile.Root.MouseLeave:Connect(function()
				if stopSpin then
					stopSpin()
					stopSpin = nil
				end
			end)
			tile.Root.Activated:Connect(function()
				local data = State.Data
				if data.Devices[d.Id] then
					Request.Call("EquipDevice", { Id = d.Id })
				else
					local r = Request.Call("BuyDevice", { Id = d.Id })
					if r.ok then
						Sound.Play("Purchase")
						UIKit.Pop(tile.Root, 1.15)
					else
						UIKit.Shake(tile.Root)
					end
				end
			end)
			refreshTile(d)
		end
	end

	local function refreshInfo()
		if not State.IsLoaded then
			return
		end
		local data = State.Data
		local eq = Devices.ById[data.Equipped]
		local mult = Stats.ViewsMultiplier(data, State.Ctx)
		info.Text = if eq
			then ("HOLDING: " .. string.upper(eq.Name) .. "  •  +" .. Format.Abbrev(eq.Value) .. " x " .. Format.Mult(
				mult
			) .. " = +" .. Format.Abbrev(eq.Value * mult) .. " VIEWS / STEP")
			else ""
	end

	local function showWorld(w: number)
		currentWorld = w
		buildWorld(w)
		for id, grid in grids do
			grid.Visible = id == w
		end
		for i, b in tabButtons do
			local unlocked = State.IsLoaded and State.Data.Unlocked[tostring(i)] == true
			b:SetColor(if i == w then C.Cyan elseif unlocked then C.InkSoft else Color3.fromRGB(70, 60, 90))
			local s = UIKit.ScaleOf(b.Root)
			s.Scale = if i == w then 1.05 else 1
		end
		for _, d in Devices.ByWorld[w] do
			refreshTile(d)
		end
	end

	for i, world in Worlds do
		local b = UIKit.Button({
			Text = string.upper(world.DeviceLabel),
			Icon = TAB_ICONS[i],
			Color = C.InkSoft,
			Size = UDim2.fromOffset(222, 60),
			TextSize = 22,
			Parent = tabRow,
			LayoutOrder = i,
			OnClick = function()
				if State.Data.Unlocked[tostring(i)] then
					showWorld(i)
				else
					Request.Toast:Fire("Unlock " .. world.Name .. " first!", "error")
				end
			end,
		})
		table.insert(tabButtons, b)
	end

	local function refreshAll()
		if not UI.IsOpen("Devices") then
			return
		end
		for _, d in Devices.ByWorld[currentWorld] do
			refreshTile(d)
		end
		refreshInfo()
	end
	for _, key in { "Clout", "Devices", "Equipped", "Context", "Rebirths" } do
		State.On(key, refreshAll)
	end

	return {
		Panel = panel,
		Open = function()
			local data = State.Data
			local w = data.World
			if not data.Unlocked[tostring(w)] then
				w = 1
			end
			-- jump to the tab holding your next device
			for _, d in Devices.List do
				if not data.Devices[d.Id] and data.Unlocked[tostring(d.World)] then
					w = d.World
					break
				end
			end
			showWorld(w)
			refreshInfo()
		end,
	}
end
