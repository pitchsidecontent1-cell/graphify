--!strict
-- UPGRADES: walk speed, clout bonus, treadmill power (bought with clout).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Upgrades = require(Shared.Config.Upgrades)
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Util.Format)
local Stats = require(Shared.Util.Stats)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)
local Sound = require(script.Parent.Parent.Parent.Controllers.Sound)

local C = Theme.Colors
local COLORS = { Speed = C.Mint, Clout = C.Gold, Treadmill = C.Purple } :: { [string]: Color3 }

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Upgrades", Color = C.Yellow, Size = Vector2.new(940, 600) })
	local body = panel.Body
	local list = UIKit.Frame({ Size = UDim2.fromScale(1, 1), Parent = body })
	UIKit.List(list, 16)

	type Row = { level: TextLabel, effect: TextLabel, button: UIKit.Button, bar: UIKit.Progress }
	local rows: { [string]: Row } = {}

	local function effectText(u: Upgrades.Upgrade, level: number): string
		if u.Format == "speed" then
			return "SPEED " .. (Economy.BaseWalkSpeed + level * u.Per)
		end
		return "+" .. math.floor(level * u.Per * 100 + 0.5) .. "%"
	end

	local function refresh()
		if not State.IsLoaded then
			return
		end
		local data = State.Data
		for _, u in Upgrades do
			local row = rows[u.Id]
			local level = Stats.UpgradeLevel(data, u.Id)
			row.level.Text = "LV " .. level .. " / " .. u.Max
			row.bar:Set(level / u.Max)
			if level >= u.Max then
				row.effect.Text = effectText(u, level) .. "  (MAX)"
				row.button:SetText("MAXED")
				row.button:SetEnabled(false)
			else
				row.effect.Text = effectText(u, level) .. "  ➜  " .. effectText(u, level + 1)
				local cost = Stats.UpgradeCost(u.Id, level)
				row.button:SetText("💰 " .. Format.Abbrev(cost))
				row.button:SetEnabled(data.Clout >= cost)
			end
		end
	end

	for i, u in Upgrades do
		local color = COLORS[u.Id] or C.Blue
		local card = UIKit.Card(list, UDim2.new(1, -10, 0, 150), Color3.fromRGB(58, 46, 94))
		card.LayoutOrder = i
		local iconBg = Instance.new("Frame")
		iconBg.Size = UDim2.fromOffset(112, 112)
		iconBg.Position = UDim2.fromOffset(18, 19)
		iconBg.BackgroundColor3 = color
		UIKit.Corner(iconBg, 22)
		UIKit.Stroke(iconBg, 4, C.Ink)
		UIKit.Gradient(iconBg, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 205)), 90)
		local icon = UIKit.Icon("__", UDim2.fromScale(0.7, 0.7), iconBg, u.Emoji)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		iconBg.Parent = card
		UIKit.Label({
			Text = string.upper(u.Name),
			TextSize = 36,
			XAlign = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(150, 14),
			Size = UDim2.new(0, 400, 0, 40),
			Parent = card,
		})
		UIKit.Label({
			Text = u.Description,
			TextSize = 22,
			Font = Theme.Fonts.Body,
			Color = Color3.fromRGB(210, 205, 230),
			XAlign = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(150, 54),
			Size = UDim2.new(0, 460, 0, 28),
			Stroke = 0,
			Parent = card,
		})
		local effect = UIKit.Label({
			Text = "",
			TextSize = 26,
			Color = color,
			XAlign = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(150, 86),
			Size = UDim2.new(0, 320, 0, 30),
			Parent = card,
		})
		local level = UIKit.Label({
			Text = "",
			TextSize = 24,
			XAlign = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -300, 0, 86),
			Size = UDim2.new(0, 0, 0, 30),
			Parent = card,
		})
		level.AnchorPoint = Vector2.new(1, 0)
		level.Position = UDim2.new(1, -290, 0, 86)
		level.Size = UDim2.fromOffset(160, 30)
		local bar = UIKit.Progress({
			Size = UDim2.new(1, -460, 0, 16),
			Position = UDim2.fromOffset(150, 122),
			Color = color,
			Parent = card,
		})
		bar.Label.Visible = false
		local button = UIKit.Button({
			Text = "",
			Color = C.Green,
			Size = UDim2.fromOffset(240, 80),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -20, 0.5, 0),
			TextSize = 30,
			Parent = card,
			OnClick = function()
				local r = Request.Call("BuyUpgrade", { Id = u.Id })
				if r.ok then
					Sound.Play("Purchase", 1 + (r.data and r.data.Level or 0) * 0.02)
					UIKit.Pop(card, 1.04)
				end
			end,
		})
		rows[u.Id] = { level = level, effect = effect, button = button, bar = bar }
	end

	for _, key in { "Clout", "Upgrades" } do
		State.On(key, function()
			if UI.IsOpen("Upgrades") then
				refresh()
			end
		end)
	end

	return { Panel = panel, Open = refresh }
end
