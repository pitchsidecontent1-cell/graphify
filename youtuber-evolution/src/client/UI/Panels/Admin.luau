--!strict
-- Admin / test panel (Studio + game owner + Config/Admin UserIds).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Products = require(Shared.Config.Products)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)

local C = Theme.Colors

local COMMANDS = {
	{ "Views", "+1 VIDEO" },
	{ "Views10", "+10 VIDEOS" },
	{ "Clout", "CLOUT x10" },
	{ "Tickets", "+10 TICKETS" },
	{ "Rebirth", "REBIRTH" },
	{ "UnlockWorlds", "UNLOCK WORLDS" },
	{ "AllDevices", "ALL DEVICES" },
	{ "ResetData", "RESET DATA" },
}

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Admin", Color = C.Red, Size = Vector2.new(1000, 700) })
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 8
	scroll.Parent = panel.Body
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(300, 70)
	grid.CellPadding = UDim2.fromOffset(14, 14)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll
	UIKit.Padding(scroll, 6, 8)

	local order = 0
	local function add(text: string, color: Color3, cmd: string, arg: string?)
		order += 1
		UIKit.Button({
			Text = text,
			Color = color,
			TextSize = 24,
			Parent = scroll,
			LayoutOrder = order,
			OnClick = function()
				local r = Request.Call("Admin", { Cmd = cmd, Arg = arg })
				if r.ok and r.data then
					Request.Toast:Fire("🛠️ " .. tostring(r.data.Text), "success")
				end
			end,
		})
	end
	for _, c in COMMANDS do
		add(c[2], if c[1] == "ResetData" then C.Red else C.Blue, c[1])
	end
	for _, pass in Products.Passes do
		add("PASS: " .. string.upper(pass.Name), C.Purple, "GrantPass", pass.Key)
	end
	for _, product in Products.Products do
		add("TEST: " .. string.upper(product.Name), C.Orange, "GrantProduct", product.Key)
	end
	return { Panel = panel }
end
