--!strict
-- WORLDS: teleport to any world you've unlocked.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Worlds = require(Shared.Config.Worlds)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)

local C = Theme.Colors
local ICONS = { "🌳", "🌆", "❄️", "🌌" }

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Worlds", Color = C.Mint, Size = Vector2.new(1040, 600) })
	local row = UIKit.Frame({ Size = UDim2.fromScale(1, 1), Parent = panel.Body })
	UIKit.List(row, 16, true)
	type Card = { button: UIKit.Button, lock: TextLabel, frame: Frame }
	local cards: { Card } = {}
	for i, w in Worlds do
		local f = Instance.new("Frame")
		f.LayoutOrder = i
		f.Size = UDim2.fromOffset(232, 500)
		f.BackgroundColor3 = w.Palette.Accent1
		UIKit.Corner(f, 22)
		UIKit.Stroke(f, 5, C.Ink)
		UIKit.Gradient(
			f,
			ColorSequence.new(w.Palette.Accent1:Lerp(C.White, 0.2), w.Palette.Ground:Lerp(C.Ink, 0.35)),
			90
		)
		local inner = Instance.new("Frame")
		inner.BackgroundTransparency = 1
		inner.Position = UDim2.fromOffset(5, 5)
		inner.Size = UDim2.new(1, -10, 1, -10)
		UIKit.Corner(inner, 18)
		UIKit.Stroke(inner, 2.5, C.White, 0.3)
		inner.Parent = f
		local icon = UIKit.Icon("__", UDim2.fromOffset(110, 110), f, ICONS[i])
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 22)
		UIKit.Label({
			Text = "WORLD " .. i,
			TextSize = 26,
			Color = C.Yellow,
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, 140),
			Parent = f,
		})
		UIKit.Label({
			Text = string.upper(w.Name),
			TextSize = 32,
			Scaled = true,
			Size = UDim2.new(1, -20, 0, 40),
			Position = UDim2.fromOffset(10, 172),
			Parent = f,
		})
		UIKit.Label({
			Text = w.Tagline,
			TextSize = 20,
			Wrapped = true,
			Font = Theme.Fonts.Body,
			Stroke = 2,
			Size = UDim2.new(1, -24, 0, 54),
			Position = UDim2.fromOffset(12, 216),
			Parent = f,
		})
		UIKit.Label({
			Text = "📦 " .. string.upper(w.DeviceLabel),
			TextSize = 22,
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, 276),
			Parent = f,
		})
		local lock = UIKit.Label({
			Text = "",
			TextSize = 20,
			Wrapped = true,
			Color = Color3.fromRGB(255, 200, 200),
			Size = UDim2.new(1, -20, 0, 70),
			Position = UDim2.fromOffset(10, 320),
			Parent = f,
		})
		local button = UIKit.Button({
			Text = "GO",
			Color = C.Green,
			Size = UDim2.new(1, -36, 0, 74),
			Position = UDim2.new(0, 18, 1, -94),
			TextSize = 32,
			Parent = f,
			OnClick = function()
				local r = Request.Call("TeleportWorld", { World = i })
				if r.ok then
					UI.Close()
				end
			end,
		})
		f.Parent = row
		table.insert(cards, { button = button, lock = lock, frame = f })
	end
	local function refresh()
		if not State.IsLoaded then
			return
		end
		local data = State.Data
		for i, card in cards do
			local unlocked = data.Unlocked[tostring(i)] == true
			card.button.Root.Visible = unlocked
			if unlocked then
				card.lock.Text = if data.RivalsBeaten[tostring(i)]
					then "👑 RIVAL BEATEN"
					else ("⚔️ RIVAL: " .. Worlds[i].Rival.Name)
				card.lock.TextColor3 = C.Mint
				card.button:SetText(if data.World == i then "YOU'RE HERE" else "TELEPORT")
				card.button:SetEnabled(data.World ~= i)
			else
				local prev = Worlds[i - 1]
				card.lock.Text = "🔒 Beat "
					.. (if prev then prev.Rival.Name else "?")
					.. " in "
					.. (if prev then prev.Name else "?")
					.. " to unlock"
				card.lock.TextColor3 = Color3.fromRGB(255, 200, 200)
			end
		end
	end
	for _, key in { "Unlocked", "World", "RivalsBeaten" } do
		State.On(key, function()
			if UI.IsOpen("Worlds") then
				refresh()
			end
		end)
	end
	return { Panel = panel, Open = refresh }
end
