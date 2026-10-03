--!strict
-- Playtime GIFTS: 12 gifts unlocking over the session.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Rewards = require(Shared.Config.Rewards)
local Format = require(Shared.Util.Format)
local Stats = require(Shared.Util.Stats)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local HUD = require(script.Parent.Parent.HUD)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)
local Sound = require(script.Parent.Parent.Parent.Controllers.Sound)

local C = Theme.Colors
local KIND_EMOJI = { Clout = "💰", Tickets = "🎟️", Potion = "🧪" } :: { [string]: string }

local function rewardText(r: Rewards.Reward): string
	if r.Kind == "Clout" then
		local amount = 0
		if State.IsLoaded then
			amount = Stats.BestPadBase(State.Data) * (r.Pads or 1) * Stats.CloutMultiplier(State.Data, State.Ctx)
		end
		return "+" .. Format.Abbrev(amount)
	elseif r.Kind == "Tickets" then
		return "+" .. (r.Amount or 1) .. " TICKET" .. (if (r.Amount or 1) > 1 then "S" else "")
	elseif r.Kind == "Potion" then
		return "x2 " .. string.upper(r.Potion or "Views") .. " " .. (r.Minutes or 5) .. "M"
	end
	return ""
end

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Free Gifts", Color = C.Red, Size = Vector2.new(1000, 700) })
	local body = panel.Body
	UIKit.Label({
		Text = "Stay online to unlock more gifts!",
		TextSize = 26,
		Color = C.Yellow,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = body,
	})
	local holder = UIKit.Frame({ Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), Parent = body })
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(214, 182)
	grid.CellPadding = UDim2.fromOffset(16, 14)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = holder

	type Card = { frame: Frame, label: TextLabel, timer: TextLabel, button: UIKit.Button, stroke: UIStroke }
	local cards: { Card } = {}

	for i, gift in Rewards.Gifts do
		local f = Instance.new("Frame")
		f.LayoutOrder = i
		f.BackgroundColor3 = Color3.fromRGB(70, 56, 112)
		UIKit.Corner(f, 18)
		local stroke = UIKit.Stroke(f, 4, C.Ink)
		local icon = UIKit.Icon("__", UDim2.fromOffset(64, 64), f, KIND_EMOJI[gift.Reward.Kind] or "🎁")
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 8)
		local label = UIKit.Label({
			Text = "",
			TextSize = 24,
			Scaled = true,
			Size = UDim2.new(1, -16, 0, 30),
			Position = UDim2.fromOffset(8, 74),
			Parent = f,
		})
		local timer = UIKit.Label({
			Text = "",
			TextSize = 26,
			Color = C.Cyan,
			Size = UDim2.new(1, -16, 0, 30),
			Position = UDim2.fromOffset(8, 106),
			Parent = f,
		})
		local button = UIKit.Button({
			Text = "CLAIM",
			Color = C.Green,
			Size = UDim2.new(1, -30, 0, 50),
			Position = UDim2.fromOffset(15, 122),
			TextSize = 26,
			Parent = f,
			OnClick = function()
				local r = Request.Call("ClaimGift", { Index = i })
				if r.ok then
					HUD.GiftClaimed[i] = true
					Sound.Play("Claim")
				end
			end,
		})
		f.Parent = holder
		table.insert(cards, { frame = f, label = label, timer = timer, button = button, stroke = stroke })
	end

	local function refresh()
		local elapsed = os.clock() - State.SessionStart
		for i, gift in Rewards.Gifts do
			local card = cards[i]
			card.label.Text = rewardText(gift.Reward)
			local remaining = gift.Minutes * 60 - elapsed
			if HUD.GiftClaimed[i] then
				card.timer.Visible = true
				card.timer.Text = "✅ CLAIMED"
				card.timer.TextColor3 = C.Mint
				card.button.Root.Visible = false
				card.stroke.Color = C.Ink
			elseif remaining <= 0 then
				card.timer.Visible = false
				card.button.Root.Visible = true
				card.stroke.Color = C.Gold
			else
				card.timer.Visible = true
				card.timer.Text = Format.Time(remaining)
				card.timer.TextColor3 = C.Cyan
				card.button.Root.Visible = false
				card.stroke.Color = C.Ink
			end
		end
	end

	local open = false
	task.spawn(function()
		while true do
			if open then
				refresh()
			end
			task.wait(0.5)
		end
	end)

	return {
		Panel = panel,
		Open = function()
			open = true
			refresh()
		end,
		Close = function()
			open = false
		end,
	}
end
