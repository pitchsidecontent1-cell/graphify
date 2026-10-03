--!strict
-- NICHE roll: slot-reel animation, odds list (always visible), pity counter.

local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Niches = require(Shared.Config.Niches)
local Format = require(Shared.Util.Format)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)
local Sound = require(script.Parent.Parent.Parent.Controllers.Sound)

local C = Theme.Colors
local CARD_W = 180

local function nicheCard(parent: Instance, niche: Niches.Niche?, size: Vector2): Frame
	local rarity = Theme.Rarities[if niche then niche.Rarity else "Common"]
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(size.X, size.Y)
	f.BackgroundColor3 = rarity.Color
	UIKit.Corner(f, 18)
	UIKit.Stroke(f, 4, C.Ink)
	if rarity.Animated then
		UIKit.Rainbow(f)
	else
		UIKit.Gradient(f, ColorSequence.new(rarity.Color:Lerp(C.White, 0.35), rarity.Dark), 90)
	end
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(4, 4)
	inner.Size = UDim2.new(1, -8, 1, -8)
	UIKit.Corner(inner, 14)
	UIKit.Stroke(inner, 2.5, C.White, 0.3)
	inner.Parent = f
	local icon = UIKit.Icon("__", UDim2.new(0.6, 0, 0.42, 0), f, if niche then niche.Emoji else "❔")
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0.06)
	UIKit.Label({
		Text = if niche then niche.Name else "NO NICHE",
		Scaled = true,
		TextSize = 30,
		Size = UDim2.new(0.92, 0, 0.18, 0),
		Position = UDim2.fromScale(0.04, 0.52),
		Parent = f,
	})
	UIKit.Label({
		Text = if niche then Format.Mult(niche.Mult) .. " VIEWS" else "ROLL ONE!",
		Scaled = true,
		TextSize = 28,
		Color = C.Yellow,
		Size = UDim2.new(0.92, 0, 0.15, 0),
		Position = UDim2.fromScale(0.04, 0.71),
		Parent = f,
	})
	UIKit.Label({
		Text = if niche then string.upper(niche.Rarity) else "",
		Scaled = true,
		TextSize = 22,
		Size = UDim2.new(0.92, 0, 0.11, 0),
		Position = UDim2.fromScale(0.04, 0.86),
		Parent = f,
	})
	f.Parent = parent
	return f
end

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Niche Roll", Color = C.Pink, Size = Vector2.new(1040, 700) })
	local body = panel.Body

	-- left: reel + current + roll
	local left = UIKit.Frame({ Size = UDim2.new(0.58, 0, 1, 0), Parent = body })
	local reelFrame = Instance.new("Frame")
	reelFrame.Name = "Reel"
	reelFrame.Size = UDim2.new(1, 0, 0, 280)
	reelFrame.BackgroundColor3 = Color3.fromRGB(26, 20, 44)
	reelFrame.ClipsDescendants = true
	UIKit.Corner(reelFrame, 20)
	UIKit.Stroke(reelFrame, 4, C.Ink)
	reelFrame.Parent = left
	local strip = UIKit.Frame({
		Name = "Strip",
		Size = UDim2.new(0, 0, 1, -20),
		Position = UDim2.fromOffset(0, 10),
		Parent = reelFrame,
	})
	local marker = Instance.new("Frame")
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.Position = UDim2.fromScale(0.5, 0)
	marker.Size = UDim2.new(0, 6, 1, 0)
	marker.BackgroundColor3 = C.Yellow
	marker.ZIndex = 5
	marker.Parent = reelFrame
	local currentHolder =
		UIKit.Frame({ Size = UDim2.new(1, 0, 1, -20), Position = UDim2.fromOffset(0, 10), Parent = reelFrame })

	local status = UIKit.Label({
		Text = "",
		TextSize = 30,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 292),
		Parent = left,
	})
	local pity = UIKit.Label({
		Text = "",
		TextSize = 24,
		Color = C.Cyan,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 334),
		Parent = left,
	})
	local tickets = UIKit.Label({
		Text = "",
		TextSize = 30,
		Color = C.Ticket,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 372),
		Parent = left,
	})

	local buttons = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromOffset(0, 420), Parent = left })
	UIKit.List(buttons, 16, true)
	local rolling = false

	local function showCurrent()
		for _, c in currentHolder:GetChildren() do
			c:Destroy()
		end
		local current = Niches.ById[State.Data.Niche]
		local card = nicheCard(currentHolder, current, Vector2.new(200, 250))
		card.AnchorPoint = Vector2.new(0.5, 0)
		card.Position = UDim2.fromScale(0.5, 0)
		currentHolder.Visible = true
		strip.Visible = false
		marker.Visible = false
	end

	local function refresh()
		if not State.IsLoaded then
			return
		end
		local data = State.Data
		local current = Niches.ById[data.Niche]
		status.Text = if current
			then ("YOUR NICHE: " .. string.upper(current.Name) .. "  " .. Format.Mult(current.Mult))
			else "NO NICHE YET"
		local left_ = Niches.PityRolls - data.NichePity
		pity.Text = "GUARANTEED " .. string.upper(Niches.PityMinRarity) .. "+ IN " .. left_ .. " ROLLS"
		tickets.Text = "🎟️ " .. Format.Abbrev(data.Tickets) .. " TICKETS"
		if not rolling then
			showCurrent()
		end
	end

	local function spin(resultId: string, kept: boolean)
		rolling = true
		currentHolder.Visible = false
		strip.Visible = true
		marker.Visible = true
		for _, c in strip:GetChildren() do
			c:Destroy()
		end
		-- 40 random cards with the result at index 34
		local count, target = 40, 34
		local cards = {}
		for i = 1, count do
			local n = if i == target then Niches.ById[resultId] else Niches.List[math.random(1, #Niches.List)]
			local card = nicheCard(strip, n, Vector2.new(CARD_W - 12, 250))
			card.Position = UDim2.fromOffset((i - 1) * CARD_W, 0)
			table.insert(cards, card)
		end
		local width = reelFrame.AbsoluteSize.X / math.max(UI.Scale, 0.01)
		local finalX = -((target - 1) * CARD_W + (CARD_W - 12) / 2) + width / 2
		local start = os.clock()
		local duration = 3.2
		local lastIndex = 0
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = math.min((os.clock() - start) / duration, 1)
			local eased = 1 - (1 - t) ^ 4
			local x = finalX * eased
			strip.Position = UDim2.fromOffset(x, 10)
			local idx = math.floor((-x + width / 2) / CARD_W)
			if idx ~= lastIndex then
				lastIndex = idx
				Sound.Play("Tick", 0.9 + t * 0.6)
			end
			if t >= 1 then
				conn:Disconnect()
			end
		end)
		task.wait(duration + 0.1)
		local result = Niches.ById[resultId]
		local rarity = Theme.Rarities[result.Rarity]
		UIKit.Pop(cards[target], 1.2)
		if rarity.Order >= Theme.Rarities.Legendary.Order then
			Sound.Play("Win")
			UIKit.Shake(panel.Window)
		else
			Sound.Play("Pop")
		end
		Request.Toast:Fire(
			if kept
				then ("NEW NICHE: " .. result.Name .. " " .. Format.Mult(result.Mult) .. "!")
				else ("Rolled " .. result.Name .. " - kept your better niche"),
			if kept then "reward" else "info"
		)
		task.wait(1.2)
		rolling = false
		refresh()
	end

	UIKit.Button({
		Text = "ROLL",
		Icon = "🎲",
		Color = C.Pink,
		Size = UDim2.fromOffset(260, 84),
		TextSize = 40,
		Parent = buttons,
		OnClick = function()
			if rolling then
				return
			end
			local r = Request.Call("RollNiche")
			if r.ok and r.data then
				spin(r.data.Niche, r.data.Kept)
			end
		end,
	})
	UIKit.Button({
		Text = "GET TICKETS",
		Icon = "🎟️",
		Color = C.Ticket,
		Size = UDim2.fromOffset(280, 84),
		TextSize = 30,
		Parent = buttons,
		OnClick = function()
			UI.Open("Shop", "Currency")
		end,
	})
	UIKit.Button({
		Text = "x2 LUCK",
		Icon = "🍀",
		Color = C.Mint,
		Size = UDim2.fromOffset(240, 66),
		TextSize = 26,
		Position = UDim2.fromOffset(0, 520),
		Parent = left,
		OnClick = function()
			Request.BuyPass("LuckyNiche")
		end,
	})

	-- right: odds
	local right = UIKit.Card(body, UDim2.new(0.4, 0, 1, 0), Color3.fromRGB(50, 40, 84))
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	UIKit.Label({
		Text = "ODDS",
		TextSize = 34,
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 8),
		Parent = right,
	})
	local oddsList =
		UIKit.Frame({ Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 1, -66), Parent = right })
	UIKit.List(oddsList, 6)
	for i, n in Niches.List do
		local rarity = Theme.Rarities[n.Rarity]
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 50)
		row.BackgroundColor3 = rarity.Color
		row.BackgroundTransparency = 0.15
		UIKit.Corner(row, 12)
		UIKit.Stroke(row, 2.5, C.Ink)
		if rarity.Animated then
			UIKit.Rainbow(row)
		else
			UIKit.Gradient(row, ColorSequence.new(rarity.Color:Lerp(C.White, 0.3), rarity.Dark), 90)
		end
		UIKit.Label({
			Text = n.Emoji .. " " .. n.Name,
			TextSize = 22,
			XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.new(0.55, 0, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			Parent = row,
		})
		UIKit.Label({
			Text = Format.Mult(n.Mult),
			TextSize = 22,
			Color = C.Yellow,
			Size = UDim2.new(0.2, 0, 1, 0),
			Position = UDim2.fromScale(0.56, 0),
			Parent = row,
		})
		UIKit.Label({
			Text = (if n.Chance < 0.1 then tostring(n.Chance) else tostring(n.Chance)) .. "%",
			TextSize = 22,
			XAlign = Enum.TextXAlignment.Right,
			Size = UDim2.new(0.22, -10, 1, 0),
			Position = UDim2.fromScale(0.78, 0),
			Parent = row,
		})
		row.Parent = oddsList
	end

	for _, key in { "Niche", "Tickets", "NichePity" } do
		State.On(key, function()
			if UI.IsOpen("Niche") and not rolling then
				refresh()
			end
		end)
	end

	return {
		Panel = panel,
		Open = function()
			refresh()
		end,
	}
end
