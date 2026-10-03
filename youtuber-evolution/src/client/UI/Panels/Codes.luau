--!strict
-- CODES: type a code, get a reward.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)
local Sound = require(script.Parent.Parent.Parent.Controllers.Sound)

local C = Theme.Colors

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Codes", Color = C.Cyan, Size = Vector2.new(760, 420) })
	local body = panel.Body
	UIKit.Label({
		Text = "Enter a code for free rewards!",
		TextSize = 30,
		Color = C.Yellow,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 10),
		Parent = body,
	})
	local boxFrame = UIKit.Card(body, UDim2.new(1, -40, 0, 84), C.White)
	boxFrame.Position = UDim2.fromOffset(20, 70)
	local box = Instance.new("TextBox")
	box.BackgroundTransparency = 1
	box.Size = UDim2.new(1, -30, 1, 0)
	box.Position = UDim2.fromOffset(15, 0)
	box.Text = ""
	box.PlaceholderText = "TYPE CODE HERE"
	box.PlaceholderColor3 = Color3.fromRGB(150, 145, 170)
	box.TextColor3 = C.Ink
	box.TextSize = 38
	box.FontFace = Theme.Fonts.Display
	box.ClearTextOnFocus = false
	box.Parent = boxFrame
	local result = UIKit.Label({
		Text = "",
		TextSize = 26,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 170),
		Parent = body,
	})
	UIKit.Button({
		Text = "REDEEM",
		Icon = "🎟️",
		Color = C.Green,
		Size = UDim2.fromOffset(300, 84),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 220),
		TextSize = 36,
		Parent = body,
		OnClick = function()
			local r = Request.Call("RedeemCode", { Code = box.Text })
			if r.ok then
				Sound.Play("Claim")
				result.Text = "✅ " .. ((r.data and r.data.Text) or "Redeemed!")
				result.TextColor3 = C.Mint
				box.Text = ""
			else
				result.Text = "❌ " .. (r.msg or "Invalid code")
				result.TextColor3 = Color3.fromRGB(255, 120, 120)
			end
		end,
	})
	return {
		Panel = panel,
		Open = function()
			result.Text = ""
		end,
	}
end
