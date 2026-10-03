--!strict
-- REBIRTH: before/after multipliers, rewards, progress, rebirth + skip.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Util.Format)
local Stats = require(Shared.Util.Stats)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)

local C = Theme.Colors

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Rebirth", Color = C.Purple, Size = Vector2.new(900, 660) })
	local body = panel.Body

	local headers = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 6), Parent = body })
	UIKit.Label({ Text = "BEFORE", TextSize = 46, Size = UDim2.fromScale(0.4, 1), Parent = headers })
	UIKit.Label({
		Text = "AFTER",
		TextSize = 46,
		Size = UDim2.fromScale(0.4, 1),
		Position = UDim2.fromScale(0.6, 0),
		Parent = headers,
	})

	local function row(y: number, color: Color3, icon: string): (TextLabel, TextLabel)
		local function box(x: number): TextLabel
			local b = Instance.new("Frame")
			b.Position = UDim2.new(x, 0, 0, y)
			b.Size = UDim2.new(0.4, 0, 0, 84)
			b.BackgroundColor3 = color
			UIKit.Corner(b, 20)
			UIKit.Stroke(b, 4, C.Ink)
			UIKit.Gradient(b, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 205)), 90)
			local inner = Instance.new("Frame")
			inner.BackgroundTransparency = 1
			inner.Position = UDim2.fromOffset(5, 5)
			inner.Size = UDim2.new(1, -10, 1, -10)
			UIKit.Corner(inner, 16)
			UIKit.Stroke(inner, 2.5, C.White, 0.25)
			inner.Parent = b
			local ic = UIKit.Icon("__", UDim2.fromOffset(56, 56), b, icon)
			ic.Position = UDim2.fromOffset(18, 14)
			local l = UIKit.Label({
				Text = "",
				TextSize = 44,
				Size = UDim2.new(1, -90, 1, 0),
				Position = UDim2.fromOffset(84, 0),
				Parent = b,
			})
			b.Parent = body
			return l
		end
		local before = box(0)
		local after = box(0.6)
		UIKit.Label({
			Text = "▶▶▶",
			TextSize = 50,
			Size = UDim2.new(0.2, 0, 0, 84),
			Position = UDim2.new(0.4, 0, 0, y),
			Parent = body,
		})
		return before, after
	end

	local viewsBefore, viewsAfter = row(70, C.Red, "👁️")
	local cloutBefore, cloutAfter = row(170, C.Gold, "💰")
	viewsAfter.TextColor3 = C.Mint
	cloutAfter.TextColor3 = C.Mint

	UIKit.Label({
		Text = "REBIRTH REWARDS:  🎟️ x" .. Economy.Rebirth.TicketsPerRebirth .. " NICHE TICKET",
		TextSize = 32,
		Color = C.Cyan,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 272),
		Parent = body,
	})
	UIKit.Label({
		Text = "⚠️  Rebirth resets your VIEWS + VIDEOS (gates relock)  ⚠️",
		TextSize = 28,
		Color = Color3.fromRGB(255, 90, 100),
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 318),
		Parent = body,
	})
	UIKit.Label({
		Text = "You KEEP: clout, devices, pets, upgrades, worlds",
		TextSize = 24,
		Font = Theme.Fonts.Body,
		Color = Color3.fromRGB(210, 205, 230),
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 356),
		Stroke = 0,
		Parent = body,
	})
	local bar = UIKit.Progress({
		Size = UDim2.new(1, -40, 0, 64),
		Position = UDim2.fromOffset(20, 396),
		Color = C.Orange,
		TextSize = 32,
		Parent = body,
	})

	local buttons = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 110), Position = UDim2.fromOffset(0, 476), Parent = body })
	local rebirthBtn = UIKit.Button({
		Text = "REBIRTH",
		Color = C.Purple,
		Size = UDim2.fromOffset(300, 84),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.27, 0),
		TextSize = 40,
		Parent = buttons,
		OnClick = function()
			local r = Request.Call("Rebirth")
			if r.ok then
				UI.Close()
			end
		end,
	})
	local skipHolder = UIKit.Frame({
		Size = UDim2.fromOffset(300, 110),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.73, 0),
		Parent = buttons,
	})
	UIKit.Button({
		Text = "SKIP",
		Icon = "⏩",
		Color = C.Yellow,
		Size = UDim2.fromOffset(300, 84),
		TextSize = 40,
		Parent = skipHolder,
		OnClick = function()
			Request.BuyProduct("SkipRebirth")
		end,
	})
	local skipPrice = UIKit.Label({
		Text = "R$ 99",
		TextSize = 26,
		Color = C.Mint,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 86),
		Parent = skipHolder,
	})

	local function refresh()
		if not State.IsLoaded then
			return
		end
		local data = State.Data
		local r = data.Rebirths
		viewsBefore.Text = Format.Mult(Stats.RebirthMultiplier(r))
		viewsAfter.Text = Format.Mult(Stats.RebirthMultiplier(r + 1))
		cloutBefore.Text = "+" .. math.floor(r * Economy.Rebirth.CloutBonusPerRebirth * 100 + 0.5) .. "%"
		cloutAfter.Text = "+" .. math.floor((r + 1) * Economy.Rebirth.CloutBonusPerRebirth * 100 + 0.5) .. "%"
		local video = Stats.VideoLevel(data.Views)
		local need = Stats.RebirthVideo(r)
		bar:Set(video / need, "VIDEO " .. video .. " / VIDEO " .. need)
		rebirthBtn:SetEnabled(video >= need)
	end
	State.On("Views", function()
		if UI.IsOpen("Rebirth") then
			refresh()
		end
	end)
	State.On("Rebirths", function()
		if UI.IsOpen("Rebirth") then
			refresh()
		end
	end)

	return {
		Panel = panel,
		Open = function()
			refresh()
			task.spawn(function()
				skipPrice.Text = "R$ " .. Request.Price("Product", "SkipRebirth")
			end)
		end,
	}
end
