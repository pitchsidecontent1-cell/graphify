--!strict
-- Screen setup, responsive scaling and the panel manager (one panel open at
-- a time, blurred background, pop-in animation).

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local UIKit = require(script.Parent.UIKit)
local Sound = require(script.Parent.Parent.Controllers.Sound)

local UI = {}

export type PanelHandle = {
	Panel: UIKit.Panel,
	Open: ((args: any?) -> ())?,
	Close: (() -> ())?,
}

local DESIGN_HEIGHT = 1080

UI.Opened = Signal.new() -- (name)
UI.Closed = Signal.new() -- (name)
UI.Current = nil :: string?
UI.Scale = 1
UI.IsTouch = false

local panels: { [string]: PanelHandle } = {}
local scales: { UIScale } = {}
local blur: BlurEffect? = nil
local dim: TextButton? = nil

-- Each screen has a "Container" frame whose UIScale makes design pixels fit.
-- Children of the container are laid out as if the screen were 1080 tall.
function UI.Layer(gui: ScreenGui): Frame
	return gui:FindFirstChild("Container") :: Frame
end

local function updateScale()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local vp = cam.ViewportSize
	local s = vp.Y / DESIGN_HEIGHT
	if UI.IsTouch then
		s *= 1.15
	end
	s = math.clamp(s, 0.42, 1.6)
	UI.Scale = s
	for _, sc in scales do
		sc.Scale = s
		local container = sc.Parent :: Frame
		local gui = container.Parent :: ScreenGui
		local abs = gui.AbsoluteSize
		if abs.X < 1 then
			abs = vp
		end
		-- the container is sized in design pixels so scale-based children still fill the screen
		container.Size = UDim2.fromOffset(abs.X / s, abs.Y / s)
	end
end

local function makeScreen(name: string, order: number, fullscreen: boolean): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = fullscreen
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = container
	table.insert(scales, scale)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(updateScale)
	end)
	return gui
end

function UI.Init()
	UI.IsTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	UI.HUD = makeScreen("HUD", 1, false)
	UI.Panels = makeScreen("Panels", 5, true)
	UI.FX = makeScreen("FX", 8, true)
	UI.Top = makeScreen("Top", 12, true)
	local b = Instance.new("BlurEffect")
	b.Name = "UIBlur"
	b.Size = 0
	b.Parent = Lighting
	blur = b

	local d = Instance.new("TextButton")
	d.Name = "Dim"
	d.Text = ""
	d.AutoButtonColor = false
	d.BackgroundColor3 = UIKit.Colors.Ink
	d.BackgroundTransparency = 1
	d.Size = UDim2.fromScale(1, 1)
	d.Visible = false
	d.ZIndex = 1
	d.Parent = UI.Layer(UI.Panels)
	d.Activated:Connect(function()
		UI.Close()
	end)
	dim = d

	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local c = Workspace.CurrentCamera
		if c then
			c:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
			updateScale()
		end
	end)
	updateScale()

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if UI.Current then
				UI.Close()
			end
		end
		local _ = processed
	end)
	GuiService.MenuOpened:Connect(function()
		UI.Close()
	end)
end

UI.HUD = (nil :: any) :: ScreenGui
UI.Panels = (nil :: any) :: ScreenGui
UI.FX = (nil :: any) :: ScreenGui
UI.Top = (nil :: any) :: ScreenGui

function UI.Register(name: string, handle: PanelHandle)
	panels[name] = handle
	handle.Panel.Root.Parent = UI.Layer(UI.Panels)
	handle.Panel.Close.Activated:Connect(function()
		UI.Close()
	end)
end

function UI.IsOpen(name: string): boolean
	return UI.Current == name
end

function UI.Open(name: string, args: any?)
	local handle = panels[name]
	if not handle then
		return
	end
	if UI.Current and UI.Current ~= name then
		UI.Close(true)
	end
	local alreadyOpen = UI.Current == name
	UI.Current = name
	if handle.Open then
		handle.Open(args)
	end
	if alreadyOpen then
		return
	end
	local root = handle.Panel.Root
	root.Visible = true
	local window = handle.Panel.Window
	local s = UIKit.ScaleOf(window)
	s.Scale = 0.82
	UIKit.Tween(s, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	if dim then
		dim.Visible = true
		UIKit.Tween(dim, 0.2, { BackgroundTransparency = 0.55 })
	end
	if blur then
		UIKit.Tween(blur, 0.25, { Size = 14 })
	end
	Sound.Play("Open")
	UI.Opened:Fire(name)
end

function UI.Close(silent: boolean?)
	local name = UI.Current
	if not name then
		return
	end
	local handle = panels[name]
	UI.Current = nil
	if handle then
		handle.Panel.Root.Visible = false
		if handle.Close then
			handle.Close()
		end
	end
	if not silent then
		if dim then
			local d = dim
			UIKit.Tween(d, 0.15, { BackgroundTransparency = 1 })
			task.delay(0.15, function()
				if not UI.Current then
					d.Visible = false
				end
			end)
		end
		if blur then
			UIKit.Tween(blur, 0.2, { Size = 0 })
		end
		Sound.Play("Close")
	end
	UI.Closed:Fire(name)
end

function UI.Toggle(name: string, args: any?)
	if UI.Current == name then
		UI.Close()
	else
		UI.Open(name, args)
	end
end

return UI
