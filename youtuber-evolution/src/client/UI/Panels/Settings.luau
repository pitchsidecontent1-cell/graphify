--!strict
-- SETTINGS toggles (saved to your profile).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)

local C = Theme.Colors

local OPTIONS = {
	{ Key = "Music", Text = "🎵  Music" },
	{ Key = "SFX", Text = "🔊  Sound effects" },
	{ Key = "Popups", Text = "➕  +Views popups" },
	{ Key = "OtherPets", Text = "🐾  Show other players' pets" },
	{ Key = "Beam", Text = "➡️  Guide arrow" },
	{ Key = "Nametags", Text = "🏷️  Nametags" },
	{ Key = "LowGfx", Text = "⚡  Low graphics (faster)" },
}

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Settings", Color = C.Grey, Size = Vector2.new(820, 700) })
	local list = UIKit.Frame({ Size = UDim2.fromScale(1, 1), Parent = panel.Body })
	UIKit.List(list, 12)
	local toggles: { [string]: UIKit.Button } = {}
	for i, opt in OPTIONS do
		local row = UIKit.Card(list, UDim2.new(1, -10, 0, 74), Color3.fromRGB(58, 46, 94))
		row.LayoutOrder = i
		UIKit.Label({
			Text = opt.Text,
			TextSize = 30,
			XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -220, 1, 0),
			Position = UDim2.fromOffset(20, 0),
			Parent = row,
		})
		toggles[opt.Key] = UIKit.Button({
			Text = "ON",
			Color = C.Green,
			Size = UDim2.fromOffset(150, 56),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			TextSize = 28,
			Parent = row,
			OnClick = function()
				local current = State.Data.Settings[opt.Key]
				Request.Call("SetSetting", { Key = opt.Key, Value = not current })
			end,
		})
	end
	local function refresh()
		if not State.IsLoaded then
			return
		end
		for key, b in toggles do
			local on = State.Data.Settings[key] == true
			b:SetText(if on then "ON" else "OFF")
			b:SetColor(if on then C.Green else C.Red)
		end
	end
	State.On("Settings", refresh)
	return { Panel = panel, Open = refresh }
end
