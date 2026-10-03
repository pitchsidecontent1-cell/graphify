--!strict
-- Rival card shown at the challenge pad: power comparison + CHALLENGE.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Util.Format)
local Stats = require(Shared.Util.Stats)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)

local C = Theme.Colors

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "View War", Color = C.Red, Size = Vector2.new(900, 640) })
	local body = panel.Body
	local world = 1

	local face = UIKit.Label({
		Text = "😱",
		TextSize = 120,
		Size = UDim2.new(1, 0, 0, 130),
		Position = UDim2.fromOffset(0, 4),
		Stroke = 0,
		Parent = body,
	})
	local name = UIKit.Label({
		Text = "",
		TextSize = 52,
		Color = C.Yellow,
		Size = UDim2.new(1, 0, 0, 58),
		Position = UDim2.fromOffset(0, 136),
		Parent = body,
	})
	local title = UIKit.Label({
		Text = "",
		TextSize = 24,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 194),
		Parent = body,
	})

	local compare = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 236), Parent = body })
	local yours = UIKit.Card(compare, UDim2.new(0.46, 0, 1, 0), C.Blue)
	local theirs = UIKit.Card(compare, UDim2.new(0.46, 0, 1, 0), C.Red)
	theirs.Position = UDim2.fromScale(0.54, 0)
	UIKit.Label({ Text = "YOUR VIEWS", TextSize = 26, Size = UDim2.new(1, 0, 0.4, 0), Parent = yours })
	UIKit.Label({ Text = "THEIR VIEWS", TextSize = 26, Size = UDim2.new(1, 0, 0.4, 0), Parent = theirs })
	local yourValue = UIKit.Label({
		Text = "0",
		TextSize = 46,
		Size = UDim2.new(1, 0, 0.6, 0),
		Position = UDim2.fromScale(0, 0.4),
		Parent = yours,
	})
	local theirValue = UIKit.Label({
		Text = "0",
		TextSize = 46,
		Size = UDim2.new(1, 0, 0.6, 0),
		Position = UDim2.fromScale(0, 0.4),
		Parent = theirs,
	})
	UIKit.Label({
		Text = "VS",
		TextSize = 46,
		Size = UDim2.new(0.08, 0, 1, 0),
		Position = UDim2.fromScale(0.46, 0),
		Parent = compare,
	})

	local verdict = UIKit.Label({
		Text = "",
		TextSize = 32,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 368),
		Parent = body,
	})
	local hint = UIKit.Label({
		Text = "TAP / CLICK FAST to post! Hit the #TRENDING bubbles for x2 power!",
		TextSize = 22,
		Font = Theme.Fonts.Body,
		Stroke = 2,
		Color = Color3.fromRGB(220, 215, 240),
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 410),
		Parent = body,
	})
	local _ = hint
	local challengeBtn = UIKit.Button({
		Text = "CHALLENGE!",
		Icon = "⚔️",
		Color = C.Red,
		Size = UDim2.fromOffset(380, 92),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 456),
		TextSize = 42,
		Parent = body,
		OnClick = function()
			local r = Request.Call("ChallengeRival", { World = world })
			if r.ok then
				UI.Close()
			end
		end,
	})

	local function refresh()
		if not State.IsLoaded then
			return
		end
		local w = Worlds[world]
		local data = State.Data
		local rival = w.Rival
		face.Text = rival.Emoji
		name.Text = string.upper(rival.Name)
		title.Text = rival.Title
		local power = Stats.RivalPower(world)
		yourValue.Text = Format.Abbrev(data.Views)
		theirValue.Text = Format.Abbrev(power)
		local ratio = data.Views / power
		if Stats.OpenGates(data, world) < Stats.GatesPerWorld then
			verdict.Text = "🔒 OPEN ALL " .. Stats.GatesPerWorld .. " GATES FIRST"
			verdict.TextColor3 = Color3.fromRGB(255, 140, 140)
		elseif ratio >= 2 then
			verdict.Text = "😎 EASY WIN"
			verdict.TextColor3 = C.Mint
		elseif ratio >= 0.95 then
			verdict.Text = "🔥 CLOSE FIGHT - CLICK FAST!"
			verdict.TextColor3 = C.Yellow
		elseif ratio >= 0.6 then
			verdict.Text = "😬 HARD - you'll need trend bubbles"
			verdict.TextColor3 = C.Orange
		else
			verdict.Text = "💀 TOO STRONG - get more views first"
			verdict.TextColor3 = Color3.fromRGB(255, 120, 120)
		end
		local cooldown = (data.RivalCooldowns[tostring(world)] or 0) - os.time()
		if cooldown > 0 then
			challengeBtn:SetText("REMATCH IN " .. Format.Duration(cooldown))
			challengeBtn:SetEnabled(false)
		else
			challengeBtn:SetText(if data.RivalsBeaten[tostring(world)] then "REMATCH!" else "CHALLENGE!")
			challengeBtn:SetEnabled(true)
		end
	end

	return {
		Panel = panel,
		Open = function(w: any)
			if typeof(w) == "number" and Worlds[w] then
				world = w
			end
			refresh()
		end,
	}
end
