--!strict
-- Client entry point: builds UI, registers panels, starts controllers.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Controllers = script.Parent:WaitForChild("Controllers")
local UIFolder = script.Parent:WaitForChild("UI")
local Panels = UIFolder:WaitForChild("Panels")

local State = require(Controllers:WaitForChild("State"))
local Sound = require(Controllers:WaitForChild("Sound"))
local Request = require(Controllers:WaitForChild("Request"))
local UI = require(UIFolder:WaitForChild("UI"))
local UIKit = require(UIFolder:WaitForChild("UIKit"))
local HUD = require(UIFolder:WaitForChild("HUD"))

-- Core first: the State remote must be listening before the server sends data.
State.Init()
Sound.Init()
Request.Init()
UI.Init()

-- Loading splash ---------------------------------------------------------------------------
local splash = Instance.new("Frame")
splash.Name = "Splash"
splash.Size = UDim2.fromScale(1, 1)
splash.BackgroundColor3 = UIKit.Colors.Ink
splash.ZIndex = 200
splash.Parent = UI.Layer(UI.Top)
UIKit.Gradient(splash, ColorSequence.new(UIKit.Colors.Purple, UIKit.Colors.Ink), 90)
local logo = UIKit.Label({
	Text = "+1 YOUTUBER EVOLUTION",
	TextSize = 110,
	Color = UIKit.Colors.Yellow,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(1600, 140),
	Stroke = 8,
	Parent = splash,
})
logo.ZIndex = 201
UIKit.Gradient(logo, ColorSequence.new(UIKit.Colors.Yellow, UIKit.Colors.Orange), 90)
local loading = UIKit.Label({
	Text = "LOADING YOUR CHANNEL...",
	TextSize = 44,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.58),
	Size = UDim2.fromOffset(1200, 60),
	Parent = splash,
})
loading.ZIndex = 201

-- Panels -----------------------------------------------------------------------------------
local PANEL_MODULES = {
	"Devices",
	"Upgrades",
	"Rebirth",
	"Pets",
	"Egg",
	"Niche",
	"Shop",
	"Gifts",
	"Daily",
	"Settings",
	"Codes",
	"Worlds",
	"Rival",
	"Admin",
}
for _, name in PANEL_MODULES do
	local module = Panels:WaitForChild(name)
	local ok, result = pcall(function()
		return (require :: any)(module)()
	end)
	if ok then
		UI.Register(name, result)
	else
		warn("[UI] panel " .. name .. " failed: " .. tostring(result))
	end
end

-- Controllers -------------------------------------------------------------------------------
local ORDER = { "Effects", "WorldFX", "PetFollow", "Battle", "Stations", "Lighting", "Guide" }
local controllers = {}
for _, name in ORDER do
	controllers[name] = (require :: any)(Controllers:WaitForChild(name))
end
HUD.Init()
for _, name in ORDER do
	controllers[name].Init()
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

HUD.Start()
State.Start()
Sound.Start()
Request.Start()
for _, name in ORDER do
	task.spawn(controllers[name].Start)
end

-- Hide the splash once data arrives
task.spawn(function()
	local dots = 0
	while not State.IsLoaded do
		dots = (dots + 1) % 4
		loading.Text = "LOADING YOUR CHANNEL" .. string.rep(".", dots)
		task.wait(0.35)
	end
	loading.Text = "WELCOME, " .. string.upper(Players.LocalPlayer.DisplayName) .. "!"
	task.wait(0.6)
	UIKit.Tween(splash, 0.5, { BackgroundTransparency = 1 })
	UIKit.Tween(logo, 0.5, { TextTransparency = 1 })
	UIKit.Tween(loading, 0.5, { TextTransparency = 1 })
	for _, d in splash:GetDescendants() do
		if d:IsA("UIStroke") then
			UIKit.Tween(d, 0.5, { Transparency = 1 })
		end
	end
	task.wait(0.55)
	splash:Destroy()
	Sound.Play("Whoosh")
end)
