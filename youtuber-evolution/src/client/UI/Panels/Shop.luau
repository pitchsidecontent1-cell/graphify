--!strict
-- SHOP (Robux): featured packs, game passes, boosts, currency.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Products = require(Shared.Config.Products)
local Format = require(Shared.Util.Format)
local Stats = require(Shared.Util.Stats)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)

local C = Theme.Colors

local function robuxButton(
	parent: Instance,
	kind: string,
	key: string,
	size: UDim2,
	pos: UDim2?,
	anchor: Vector2?
): UIKit.Button
	local b = UIKit.Button({
		Text = "R$ ...",
		Color = C.Green,
		Size = size,
		Position = pos,
		AnchorPoint = anchor,
		TextSize = 30,
		Parent = parent,
		OnClick = function()
			if kind == "Pass" then
				Request.BuyPass(key)
			else
				Request.BuyProduct(key)
			end
		end,
	})
	task.spawn(function()
		b:SetText("R$ " .. Request.Price(kind, key))
	end)
	return b
end

local function slot(parent: Instance, emoji: string, text: string, order: number)
	local f = Instance.new("Frame")
	f.LayoutOrder = order
	f.Size = UDim2.fromOffset(112, 112)
	f.BackgroundColor3 = C.White
	f.BackgroundTransparency = 0.15
	UIKit.Corner(f, 16)
	UIKit.Stroke(f, 3, C.Ink)
	local icon = UIKit.Icon("__", UDim2.fromScale(0.62, 0.62), f, emoji)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0.04)
	UIKit.Label({
		Text = text,
		Scaled = true,
		TextSize = 24,
		Size = UDim2.new(0.92, 0, 0.3, 0),
		Position = UDim2.fromScale(0.04, 0.66),
		Parent = f,
	})
	f.Parent = parent
end

local function grantText(
	g: { Kind: string, Pads: number?, Amount: number?, Potion: string?, Minutes: number? }
): (string, string)
	if g.Kind == "Tickets" then
		return "🎟️", "x" .. (g.Amount or 1)
	elseif g.Kind == "Potion" then
		return "🧪", (g.Minutes or 5) .. "m x2"
	elseif g.Kind == "Clout" then
		local amount = 0
		if State.IsLoaded then
			amount = Stats.BestPadBase(State.Data) * (g.Pads or 1) * Stats.CloutMultiplier(State.Data, State.Ctx)
		end
		return "💰", Format.Abbrev(amount)
	end
	return "🎁", ""
end

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Shop", Color = C.Pink, Size = Vector2.new(1080, 720) })
	local body = panel.Body
	local tabRow = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 66), Parent = body })
	UIKit.List(tabRow, 12, true, Enum.HorizontalAlignment.Left)
	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: UIKit.Button } = {}
	local order = { "Featured", "Passes", "Boosts", "Currency" }

	local function page(name: string): ScrollingFrame
		local s = Instance.new("ScrollingFrame")
		s.Name = name
		s.BackgroundTransparency = 1
		s.BorderSizePixel = 0
		s.Position = UDim2.fromOffset(0, 76)
		s.Size = UDim2.new(1, 0, 1, -76)
		s.CanvasSize = UDim2.new()
		s.AutomaticCanvasSize = Enum.AutomaticSize.Y
		s.ScrollBarThickness = 8
		s.Visible = false
		s.Parent = body
		pages[name] = s
		return s
	end

	local function show(name: string)
		for n, p in pages do
			p.Visible = n == name
		end
		for n, b in tabButtons do
			b:SetColor(if n == name then C.Pink else C.InkSoft)
		end
	end

	for i, name in order do
		tabButtons[name] = UIKit.Button({
			Text = string.upper(name),
			Color = C.InkSoft,
			Size = UDim2.fromOffset(240, 60),
			TextSize = 26,
			Parent = tabRow,
			LayoutOrder = i,
			OnClick = function()
				show(name)
			end,
		})
	end

	-- Featured packs ---------------------------------------------------------------
	local featured = page("Featured")
	UIKit.List(featured, 18)
	UIKit.Padding(featured, 6, 8)
	local packCards: { [string]: Frame } = {}
	local function buildPacks()
		for _, c in featured:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		for i, key in { "StarterPack", "MegaPack" } do
			local product = Products.ProductByKey[key]
			local card = Instance.new("Frame")
			card.LayoutOrder = i
			card.Size = UDim2.new(1, -16, 0, 230)
			card.BackgroundColor3 = product.Color
			UIKit.Corner(card, 22)
			UIKit.Stroke(card, 5, C.Ink)
			UIKit.Gradient(
				card,
				ColorSequence.new(product.Color:Lerp(C.White, 0.25), product.Color:Lerp(C.Ink, 0.45)),
				0
			)
			local inner = Instance.new("Frame")
			inner.BackgroundTransparency = 1
			inner.Position = UDim2.fromOffset(5, 5)
			inner.Size = UDim2.new(1, -10, 1, -10)
			UIKit.Corner(inner, 18)
			UIKit.Stroke(inner, 2.5, C.White, 0.3)
			inner.Parent = card
			local art = UIKit.Icon("__", UDim2.fromOffset(170, 170), card, product.Emoji)
			art.Position = UDim2.fromOffset(20, 30)
			UIKit.Label({
				Text = string.upper(product.Name),
				TextSize = 40,
				XAlign = Enum.TextXAlignment.Left,
				Size = UDim2.fromOffset(500, 46),
				Position = UDim2.fromOffset(210, 12),
				Parent = card,
			})
			UIKit.Label({
				Text = "⚡ Disappears after one purchase",
				TextSize = 20,
				Color = C.Yellow,
				XAlign = Enum.TextXAlignment.Left,
				Size = UDim2.fromOffset(500, 24),
				Position = UDim2.fromOffset(210, 58),
				Parent = card,
			})
			local slots =
				UIKit.Frame({ Size = UDim2.fromOffset(520, 120), Position = UDim2.fromOffset(210, 92), Parent = card })
			UIKit.List(slots, 12, true, Enum.HorizontalAlignment.Left)
			for j, g in product.Grants do
				local emoji, text = grantText(g)
				slot(slots, emoji, text, j)
			end
			local priceHolder = UIKit.Frame({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -24, 0.5, 0),
				Size = UDim2.fromOffset(230, 140),
				Parent = card,
			})
			if product.OldPrice then
				local old = UIKit.Label({
					Text = "R$ " .. product.OldPrice,
					TextSize = 30,
					Color = Color3.fromRGB(255, 120, 120),
					Size = UDim2.new(1, 0, 0, 36),
					Parent = priceHolder,
				})
				local line = Instance.new("Frame")
				line.AnchorPoint = Vector2.new(0.5, 0.5)
				line.Position = UDim2.fromScale(0.5, 0.5)
				line.Size = UDim2.new(0.5, 0, 0, 4)
				line.Rotation = -8
				line.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
				line.Parent = old
			end
			robuxButton(priceHolder, "Product", key, UDim2.fromOffset(230, 84), UDim2.fromOffset(0, 46))
			card.Parent = featured
			packCards[key] = card
		end
		-- VIP banner
		local vip = Products.PassByKey.VIP
		local banner = Instance.new("Frame")
		banner.LayoutOrder = 3
		banner.Size = UDim2.new(1, -16, 0, 150)
		banner.BackgroundColor3 = vip.Color
		UIKit.Corner(banner, 22)
		UIKit.Stroke(banner, 5, C.Ink)
		UIKit.Gradient(banner, ColorSequence.new(vip.Color:Lerp(C.White, 0.2), vip.Color:Lerp(C.Ink, 0.4)), 0)
		local art = UIKit.Icon("__", UDim2.fromOffset(110, 110), banner, vip.Emoji)
		art.Position = UDim2.fromOffset(24, 20)
		UIKit.Label({
			Text = "VIP",
			TextSize = 44,
			XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.fromOffset(400, 50),
			Position = UDim2.fromOffset(150, 18),
			Parent = banner,
		})
		UIKit.Label({
			Text = vip.Description,
			TextSize = 22,
			Wrapped = true,
			XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.fromOffset(520, 60),
			Position = UDim2.fromOffset(150, 70),
			Parent = banner,
		})
		robuxButton(banner, "Pass", "VIP", UDim2.fromOffset(230, 84), UDim2.new(1, -24, 0.5, 0), Vector2.new(1, 0.5))
		banner.Parent = featured
	end

	-- Passes ---------------------------------------------------------------------------
	local passes = page("Passes")
	local passGrid = Instance.new("UIGridLayout")
	passGrid.CellSize = UDim2.fromOffset(318, 280)
	passGrid.CellPadding = UDim2.fromOffset(16, 16)
	passGrid.SortOrder = Enum.SortOrder.LayoutOrder
	passGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	passGrid.Parent = passes
	UIKit.Padding(passes, 6, 8)
	local passCards: { [string]: { owned: TextLabel, button: UIKit.Button } } = {}
	for i, pass in Products.Passes do
		local card = Instance.new("Frame")
		card.LayoutOrder = i
		card.BackgroundColor3 = pass.Color
		UIKit.Corner(card, 20)
		UIKit.Stroke(card, 4, C.Ink)
		UIKit.Gradient(card, ColorSequence.new(pass.Color:Lerp(C.White, 0.3), pass.Color:Lerp(C.Ink, 0.4)), 90)
		local icon = UIKit.Icon("__", UDim2.fromOffset(84, 84), card, pass.Emoji)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 12)
		UIKit.Label({
			Text = string.upper(pass.Name),
			TextSize = 30,
			Size = UDim2.new(1, -16, 0, 36),
			Position = UDim2.fromOffset(8, 100),
			Scaled = true,
			Parent = card,
		})
		UIKit.Label({
			Text = pass.Description,
			TextSize = 20,
			Wrapped = true,
			Font = Theme.Fonts.Body,
			Stroke = 2,
			Size = UDim2.new(1, -24, 0, 60),
			Position = UDim2.fromOffset(12, 138),
			Parent = card,
		})
		local button = robuxButton(
			card,
			"Pass",
			pass.Key,
			UDim2.new(1, -40, 0, 64),
			UDim2.new(0.5, 0, 1, -14),
			Vector2.new(0.5, 1)
		)
		local owned = UIKit.Label({
			Text = "✅ OWNED",
			TextSize = 32,
			Color = C.Mint,
			Size = UDim2.new(1, 0, 0, 64),
			Position = UDim2.new(0, 0, 1, -78),
			Parent = card,
		})
		owned.Visible = false
		card.Parent = passes
		passCards[pass.Key] = { owned = owned, button = button }
	end

	-- Boosts -----------------------------------------------------------------------------
	local function productRow(parent: Instance, key: string, i: number)
		local product = Products.ProductByKey[key]
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -16, 0, 120)
		row.BackgroundColor3 = product.Color
		UIKit.Corner(row, 20)
		UIKit.Stroke(row, 4, C.Ink)
		UIKit.Gradient(row, ColorSequence.new(product.Color:Lerp(C.White, 0.25), product.Color:Lerp(C.Ink, 0.45)), 0)
		local icon = UIKit.Icon("__", UDim2.fromOffset(88, 88), row, product.Emoji)
		icon.Position = UDim2.fromOffset(18, 16)
		UIKit.Label({
			Text = string.upper(product.Name),
			TextSize = 32,
			XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.fromOffset(520, 40),
			Position = UDim2.fromOffset(124, 14),
			Parent = row,
		})
		local desc = UIKit.Label({
			Text = product.Description,
			TextSize = 22,
			Font = Theme.Fonts.Body,
			Stroke = 2,
			XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.fromOffset(560, 40),
			Position = UDim2.fromOffset(124, 58),
			Parent = row,
		})
		desc.Name = "Desc"
		robuxButton(row, "Product", key, UDim2.fromOffset(220, 76), UDim2.new(1, -20, 0.5, 0), Vector2.new(1, 0.5))
		row.Parent = parent
		return row
	end
	local boosts = page("Boosts")
	UIKit.List(boosts, 14)
	UIKit.Padding(boosts, 6, 8)
	for i, key in { "ViewsPotion", "CloutPotion", "SkipRebirth" } do
		productRow(boosts, key, i)
	end

	local currency = page("Currency")
	UIKit.List(currency, 14)
	UIKit.Padding(currency, 6, 8)
	local cloutRows: { [string]: Frame } = {}
	for i, key in { "CloutSmall", "CloutMedium", "CloutLarge", "Tickets5", "Tickets25" } do
		cloutRows[key] = productRow(currency, key, i)
	end

	local function refresh()
		if not State.IsLoaded then
			return
		end
		for key, card in packCards do
			card.Visible = not State.Data.OneTime[key]
		end
		for key, refs in passCards do
			local owns = State.Ctx.Passes[key] == true
			refs.owned.Visible = owns
			refs.button.Root.Visible = not owns
		end
		for key, row in cloutRows do
			local product = Products.ProductByKey[key]
			local g = product.Grants[1]
			if g.Kind == "Clout" then
				local _, text = grantText(g)
				local desc = row:FindFirstChild("Desc") :: TextLabel
				desc.Text = "💰 +" .. text .. " clout (scales with your progress)"
			end
		end
	end
	State.On("OneTime", refresh)
	State.On("Context", refresh)

	buildPacks()
	show("Featured")

	return {
		Panel = panel,
		Open = function(tab: any)
			buildPacks()
			refresh()
			if typeof(tab) == "string" and pages[tab] then
				show(tab)
			end
		end,
	}
end
