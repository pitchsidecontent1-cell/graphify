--!strict
-- DAILY rewards: 7-day streak.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Rewards = require(Shared.Config.Rewards)
local Format = require(Shared.Util.Format)
local Stats = require(Shared.Util.Stats)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)
local Sound = require(script.Parent.Parent.Parent.Controllers.Sound)

local C = Theme.Colors
local KIND_EMOJI = { Clout = "💰", Tickets = "🎟️", Potion = "🧪" } :: { [string]: string }

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Daily Rewards", Color = C.Orange, Size = Vector2.new(1060, 520) })
	local body = panel.Body
	local status =
		UIKit.Label({ Text = "", TextSize = 28, Color = C.Yellow, Size = UDim2.new(1, 0, 0, 36), Parent = body })
	local row = UIKit.Frame({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 230), Parent = body })
	UIKit.List(row, 12, true)
	type Card = { frame: Frame, stroke: UIStroke, check: TextLabel, amount: TextLabel }
	local cards: { Card } = {}
	for day, reward in Rewards.Daily do
		local f = Instance.new("Frame")
		f.LayoutOrder = day
		f.Size = UDim2.fromOffset(128, 220)
		f.BackgroundColor3 = if day == 7 then C.Gold else Color3.fromRGB(70, 56, 112)
		UIKit.Corner(f, 18)
		local stroke = UIKit.Stroke(f, 4, C.Ink)
		UIKit.Label({
			Text = "DAY " .. day,
			TextSize = 28,
			Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.fromOffset(0, 8),
			Parent = f,
		})
		local icon = UIKit.Icon("__", UDim2.fromOffset(70, 70), f, KIND_EMOJI[reward.Kind] or "🎁")
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 52)
		local amount = UIKit.Label({
			Text = "",
			TextSize = 22,
			Scaled = true,
			Size = UDim2.new(1, -12, 0, 30),
			Position = UDim2.fromOffset(6, 130),
			Parent = f,
		})
		local check = UIKit.Label({
			Text = "✅",
			TextSize = 40,
			Size = UDim2.new(1, 0, 0, 44),
			Position = UDim2.fromOffset(0, 166),
			Parent = f,
		})
		f.Parent = row
		table.insert(cards, { frame = f, stroke = stroke, check = check, amount = amount })
	end
	local claim = UIKit.Button({
		Text = "CLAIM",
		Color = C.Green,
		Size = UDim2.fromOffset(320, 86),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 300),
		TextSize = 40,
		Parent = body,
		OnClick = function()
			local r = Request.Call("ClaimDaily")
			if r.ok then
				Sound.Play("Claim")
			end
		end,
	})

	local function describe(r: Rewards.Reward): string
		if r.Kind == "Clout" then
			local amount = Stats.BestPadBase(State.Data) * (r.Pads or 1) * Stats.CloutMultiplier(State.Data, State.Ctx)
			return "+" .. Format.Abbrev(amount)
		elseif r.Kind == "Tickets" then
			return "+" .. (r.Amount or 1)
		end
		return (r.Minutes or 5) .. "M x2"
	end

	local function refresh()
		if not State.IsLoaded then
			return
		end
		local d = State.Data.Daily
		local now = os.time()
		local ready = now - d.Last >= Rewards.DailyCooldown
		local streak = d.Streak
		if d.Last > 0 and now - d.Last > Rewards.DailyWindow then
			streak = 0
		end
		local nextDay = (streak % #Rewards.Daily) + 1
		for day, card in cards do
			card.amount.Text = describe(Rewards.Daily[day])
			local done = day <= streak and not (ready and nextDay == 1 and streak == #Rewards.Daily)
			card.check.Visible = done
			card.stroke.Color = if ready and day == nextDay then C.Mint else C.Ink
			card.stroke.Thickness = if ready and day == nextDay then 6 else 4
		end
		if ready then
			status.Text = "DAY " .. nextDay .. " IS READY!"
			claim:SetEnabled(true)
			claim:SetText("CLAIM DAY " .. nextDay)
		else
			status.Text = "NEXT REWARD IN " .. Format.Duration(Rewards.DailyCooldown - (now - d.Last))
			claim:SetEnabled(false)
			claim:SetText("COME BACK SOON")
		end
	end
	State.On("Daily", function()
		if UI.IsOpen("Daily") then
			refresh()
		end
	end)
	return { Panel = panel, Open = refresh }
end
