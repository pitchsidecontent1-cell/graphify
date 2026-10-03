--!strict
-- "Creator Pop" UI kit. Every button/panel/pill in the game is built here so
-- the look stays consistent: sticker double-outlines, glossy gradients, soft
-- ink shadows, bouncy hover/press motion.
--
-- Sizes are in "design pixels" for a 1080p-tall screen; the HUD's UIScale
-- scales everything to the actual viewport.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Assets = require(Shared.Config.Assets)
local Sound = require(script.Parent.Parent.Controllers.Sound)

local UIKit = {}

local C = Theme.Colors
local INK = C.Ink
local WHITE = C.White

UIKit.Colors = C

-- Basic helpers ------------------------------------------------------------------------

function UIKit.Tween(
	obj: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

function UIKit.Corner(parent: Instance, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.Corner)
	c.Parent = parent
	return c
end

function UIKit.Round(parent: Instance): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = parent
	return c
end

function UIKit.Stroke(parent: Instance, thickness: number?, color: Color3?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or Theme.Stroke
	s.Color = color or INK
	s.Transparency = transparency or 0
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

function UIKit.Gradient(parent: Instance, seq: ColorSequence, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = seq
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

function UIKit.Padding(parent: Instance, px: number, py: number?): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, py or px)
	p.PaddingBottom = UDim.new(0, py or px)
	p.Parent = parent
	return p
end

function UIKit.List(
	parent: Instance,
	padding: number,
	horizontal: boolean?,
	align: Enum.HorizontalAlignment?
): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = align or Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Parent = parent
	return l
end

function UIKit.Frame(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	for k, v in props do
		if k ~= "Parent" then
			(f :: any)[k] = v
		end
	end
	f.Parent = props.Parent
	return f
end

export type LabelProps = {
	Text: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextSize: number?,
	Color: Color3?,
	Font: Font?,
	Stroke: number?,
	StrokeColor: Color3?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	Scaled: boolean?,
	Wrapped: boolean?,
	Parent: Instance?,
	Name: string?,
	ZIndex: number?,
	RichText: boolean?,
	AutoX: boolean?,
}

function UIKit.Label(p: LabelProps): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = p.Name or "Label"
	l.BackgroundTransparency = 1
	l.Size = p.Size or UDim2.fromScale(1, 1)
	l.Position = p.Position or UDim2.new()
	l.AnchorPoint = p.AnchorPoint or Vector2.zero
	l.Text = p.Text or ""
	l.TextColor3 = p.Color or WHITE
	l.FontFace = p.Font or Theme.Fonts.Display
	l.TextSize = p.TextSize or 28
	l.TextScaled = p.Scaled == true
	l.TextWrapped = p.Wrapped == true
	l.RichText = p.RichText == true
	l.TextXAlignment = p.XAlign or Enum.TextXAlignment.Center
	l.TextYAlignment = p.YAlign or Enum.TextYAlignment.Center
	if p.AutoX then
		l.AutomaticSize = Enum.AutomaticSize.X
	end
	if p.ZIndex then
		l.ZIndex = p.ZIndex
	end
	if (p.Stroke or 2.5) > 0 then
		UIKit.Stroke(l, p.Stroke or 2.5, p.StrokeColor or INK)
	end
	if p.Scaled then
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = p.TextSize or 60
		c.Parent = l
	end
	l.Parent = p.Parent
	return l
end

-- Icon: an uploaded image if Assets.Images has one, else the emoji fallback.
function UIKit.Icon(key: string, size: UDim2, parent: Instance?, emoji: string?): GuiObject
	local id = Assets.Images[key]
	if id and id ~= "" then
		local img = Instance.new("ImageLabel")
		img.Name = "Icon"
		img.BackgroundTransparency = 1
		img.Size = size
		img.Image = id
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = parent
		return img
	end
	local l = Instance.new("TextLabel")
	l.Name = "Icon"
	l.BackgroundTransparency = 1
	l.Size = size
	l.Text = emoji or Assets.Emoji[key] or "⭐"
	l.TextScaled = true
	l.FontFace = Theme.Fonts.Display
	l.TextColor3 = WHITE
	l.Parent = parent
	return l
end

-- Motion ------------------------------------------------------------------------------------

local function scaleOf(obj: GuiObject): UIScale
	local s = obj:FindFirstChild("PopScale")
	if s and s:IsA("UIScale") then
		return s
	end
	local n = Instance.new("UIScale")
	n.Name = "PopScale"
	n.Parent = obj
	return n
end

UIKit.ScaleOf = scaleOf

function UIKit.Pop(obj: GuiObject, amount: number?)
	local s = scaleOf(obj)
	s.Scale = amount or 1.15
	UIKit.Tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

function UIKit.Shake(obj: GuiObject)
	local base = obj.Position
	task.spawn(function()
		for i = 1, 6 do
			obj.Position = base + UDim2.fromOffset(if i % 2 == 0 then 6 else -6, 0)
			task.wait(0.03)
		end
		obj.Position = base
	end)
end

-- Hover grows, press squishes, click plays a sound.
function UIKit.Interactive(button: GuiButton, target: GuiObject?)
	local s = scaleOf(target or button)
	button.MouseEnter:Connect(function()
		UIKit.Tween(s, 0.15, { Scale = 1.06 }, Enum.EasingStyle.Back)
	end)
	button.MouseLeave:Connect(function()
		UIKit.Tween(s, 0.15, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.Tween(s, 0.08, { Scale = 0.93 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.Tween(s, 0.2, { Scale = 1.04 }, Enum.EasingStyle.Back)
	end)
	button.Activated:Connect(function()
		Sound.Play("Click")
	end)
end

-- Animated rainbow gradients (Secret rarity etc.)
local rainbowGradients: { UIGradient } = {}
function UIKit.Rainbow(parent: Instance): UIGradient
	local g = UIKit.Gradient(parent, Theme.Rainbow, 0)
	table.insert(rainbowGradients, g)
	return g
end

RunService.RenderStepped:Connect(function()
	if #rainbowGradients == 0 then
		return
	end
	local r = (os.clock() * 60) % 360
	for i = #rainbowGradients, 1, -1 do
		local g = rainbowGradients[i]
		if g.Parent then
			g.Rotation = r
		else
			table.remove(rainbowGradients, i)
		end
	end
end)

-- Sticker button ------------------------------------------------------------------------------

export type ButtonProps = {
	Text: string?,
	Icon: string?, -- Assets key or raw emoji (if no key matches)
	Color: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextSize: number?,
	Parent: Instance?,
	Name: string?,
	LayoutOrder: number?,
	Radius: number?,
	TextColor: Color3?,
	OnClick: (() -> ())?,
	ZIndex: number?,
}

export type Button = {
	Root: Frame,
	Body: TextButton,
	Label: TextLabel,
	Icon: GuiObject?,
	SetText: (self: Button, text: string) -> (),
	SetColor: (self: Button, color: Color3) -> (),
	SetEnabled: (self: Button, enabled: boolean) -> (),
	Activated: RBXScriptSignal,
}

function UIKit.Button(p: ButtonProps): Button
	local color = p.Color or C.Blue
	local radius = p.Radius or 16
	local root = Instance.new("Frame")
	root.Name = p.Name or "Button"
	root.BackgroundTransparency = 1
	root.Size = p.Size or UDim2.fromOffset(220, 72)
	root.Position = p.Position or UDim2.new()
	root.AnchorPoint = p.AnchorPoint or Vector2.zero
	root.LayoutOrder = p.LayoutOrder or 0
	if p.ZIndex then
		root.ZIndex = p.ZIndex
	end

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = INK
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, 6)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = 0
	UIKit.Corner(shadow, radius)
	shadow.Parent = root

	local body = Instance.new("TextButton")
	body.Name = "Body"
	body.AutoButtonColor = false
	body.Text = ""
	body.BackgroundColor3 = color
	body.BorderSizePixel = 0
	body.Size = UDim2.fromScale(1, 1)
	UIKit.Corner(body, radius)
	UIKit.Stroke(body, 3.5, INK).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	UIKit.Gradient(body, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 196, 206)), 90)
	body.Parent = root

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(4, 4)
	inner.Size = UDim2.new(1, -8, 1, -8)
	UIKit.Corner(inner, math.max(radius - 4, 4))
	UIKit.Stroke(inner, 2.5, WHITE, 0.25)
	inner.Parent = body

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = WHITE
	shine.BackgroundTransparency = 0.78
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromOffset(6, 5)
	shine.Size = UDim2.new(1, -12, 0.42, -4)
	UIKit.Corner(shine, math.max(radius - 6, 4))
	shine.Parent = body

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = body
	local list = UIKit.List(content, 8, true)
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	local icon: GuiObject? = nil
	if p.Icon then
		local textSize = p.TextSize or 30
		local key = if Assets.Emoji[p.Icon] then p.Icon else "__raw"
		icon = UIKit.Icon(
			key,
			UDim2.fromOffset(textSize * 1.25, textSize * 1.25),
			content,
			if key == "__raw" then p.Icon else nil
		);
		(icon :: GuiObject).LayoutOrder = 1
	end
	local label = UIKit.Label({
		Text = p.Text or "",
		TextSize = p.TextSize or 30,
		Color = p.TextColor or WHITE,
		Size = UDim2.new(0, 0, 1, 0),
		AutoX = true,
		Stroke = 2.8,
		Parent = content,
	})
	label.LayoutOrder = 2
	if (p.Text or "") == "" then
		label.Visible = false
	end
	root.Parent = p.Parent

	UIKit.Interactive(body, root)
	body.MouseButton1Down:Connect(function()
		body.Position = UDim2.fromOffset(0, 3)
	end)
	body.MouseButton1Up:Connect(function()
		body.Position = UDim2.new()
	end)
	body.MouseLeave:Connect(function()
		body.Position = UDim2.new()
	end)

	local enabled = true
	local button: Button = {
		Root = root,
		Body = body,
		Label = label,
		Icon = icon,
		Activated = body.Activated,
		SetText = function(self: Button, text: string)
			self.Label.Text = text
			self.Label.Visible = text ~= ""
		end,
		SetColor = function(self: Button, c: Color3)
			self.Body.BackgroundColor3 = c
		end,
		SetEnabled = function(self: Button, on: boolean)
			enabled = on
			self.Body.BackgroundColor3 = if on then color else C.Grey
			self.Body.Active = on
		end,
	}
	if p.OnClick then
		local cb = p.OnClick
		body.Activated:Connect(function()
			if enabled then
				cb()
			end
		end)
	end
	return button
end

-- Badge (red dot / number / text) -----------------------------------------------------------------

export type Badge = { Frame: Frame, Set: (self: Badge, text: string?) -> () }

function UIKit.Badge(parent: GuiObject, color: Color3?): Badge
	local f = Instance.new("Frame")
	f.Name = "Badge"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new(1, -8, 0, 8)
	f.Size = UDim2.fromOffset(34, 34)
	f.AutomaticSize = Enum.AutomaticSize.X
	f.BackgroundColor3 = color or C.Red
	f.ZIndex = 20
	f.Visible = false
	UIKit.Round(f)
	UIKit.Stroke(f, 3, WHITE)
	UIKit.Padding(f, 6, 0)
	local l =
		UIKit.Label({ Text = "!", TextSize = 22, Size = UDim2.fromScale(0, 1), AutoX = true, Parent = f, Stroke = 2 })
	l.ZIndex = 21
	f.Parent = parent
	local badge: Badge = {
		Frame = f,
		Set = function(self: Badge, text: string?)
			if text == nil then
				self.Frame.Visible = false
			else
				local wasVisible = self.Frame.Visible
				self.Frame.Visible = true
				l.Text = text
				if not wasVisible then
					UIKit.Pop(self.Frame, 1.4)
				end
			end
		end,
	}
	return badge
end

-- Big square HUD button (icon + label under it) ---------------------------------------------------

export type IconButton = {
	Root: Frame,
	Body: TextButton,
	Badge: Badge,
	Label: TextLabel,
	Activated: RBXScriptSignal,
}

function UIKit.IconButton(p: {
	Key: string,
	Text: string,
	Color: Color3,
	Size: number?,
	Parent: Instance?,
	LayoutOrder: number?,
	Emoji: string?,
}): IconButton
	local size = p.Size or 112
	local root = Instance.new("Frame")
	root.Name = p.Key
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(size, size)
	root.LayoutOrder = p.LayoutOrder or 0

	local shadow = Instance.new("Frame")
	shadow.BackgroundColor3 = INK
	shadow.Position = UDim2.fromOffset(0, 6)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = 0
	UIKit.Corner(shadow, 22)
	shadow.Parent = root

	local body = Instance.new("TextButton")
	body.Name = "Body"
	body.Text = ""
	body.AutoButtonColor = false
	body.BackgroundColor3 = p.Color
	body.Size = UDim2.fromScale(1, 1)
	UIKit.Corner(body, 22)
	UIKit.Stroke(body, 4, INK).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	UIKit.Gradient(body, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 205)), 90)
	body.Parent = root

	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(5, 5)
	inner.Size = UDim2.new(1, -10, 1, -10)
	UIKit.Corner(inner, 18)
	UIKit.Stroke(inner, 3, WHITE, 0.15)
	inner.Parent = body

	-- subtle diagonal "sticker sheen"
	local sheen = Instance.new("Frame")
	sheen.BackgroundColor3 = WHITE
	sheen.BackgroundTransparency = 0.8
	sheen.Position = UDim2.fromOffset(8, 8)
	sheen.Size = UDim2.new(1, -16, 0.38, 0)
	UIKit.Corner(sheen, 14)
	sheen.Parent = body

	local icon = UIKit.Icon(p.Key, UDim2.fromScale(0.56, 0.56), body, p.Emoji)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0.1)

	local label = UIKit.Label({
		Text = p.Text,
		Size = UDim2.new(1, 0, 0.3, 0),
		Position = UDim2.fromScale(0, 0.66),
		Scaled = true,
		TextSize = 26,
		Stroke = 3,
		Parent = body,
	})
	root.Parent = p.Parent
	UIKit.Interactive(body, root)
	local badge = UIKit.Badge(root)
	return { Root = root, Body = body, Badge = badge, Label = label, Activated = body.Activated }
end

-- Pill counter (icon overlapping the left edge) ----------------------------------------------------

export type Pill = { Root: Frame, Label: TextLabel, Icon: GuiObject }

function UIKit.Pill(p: {
	Key: string,
	Color: Color3,
	Width: number?,
	Height: number?,
	Parent: Instance?,
	LayoutOrder: number?,
	TextSize: number?,
}): Pill
	local h = p.Height or 58
	local w = p.Width or 250
	local root = Instance.new("Frame")
	root.Name = p.Key .. "Pill"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(w, h)
	root.LayoutOrder = p.LayoutOrder or 0

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = Color3.fromRGB(40, 32, 66)
	bar.BackgroundTransparency = 0.12
	bar.Position = UDim2.new(0, h * 0.45, 0.5, 0)
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Size = UDim2.new(1, -h * 0.45, 0.78, 0)
	UIKit.Round(bar)
	UIKit.Stroke(bar, 3.5, INK)
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.BackgroundColor3 = p.Color
	accent.BackgroundTransparency = 0.55
	accent.Size = UDim2.new(1, 0, 0.18, 0)
	accent.Position = UDim2.fromScale(0, 0.82)
	accent.BorderSizePixel = 0
	UIKit.Round(accent)
	accent.Parent = bar
	bar.Parent = root

	local badge = Instance.new("Frame")
	badge.Name = "IconBadge"
	badge.BackgroundColor3 = p.Color
	badge.Size = UDim2.fromOffset(h, h)
	badge.ZIndex = 3
	UIKit.Round(badge)
	UIKit.Stroke(badge, 3.5, INK)
	UIKit.Gradient(badge, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 205)), 90)
	badge.Parent = root
	local icon = UIKit.Icon(p.Key, UDim2.fromScale(0.68, 0.68), badge)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ZIndex = 4

	local label = UIKit.Label({
		Text = "0",
		TextSize = p.TextSize or 34,
		Size = UDim2.new(1, -h - 12, 1, 0),
		Position = UDim2.fromOffset(h + 6, 0),
		XAlign = Enum.TextXAlignment.Left,
		Stroke = 3,
		Parent = root,
	})
	label.ZIndex = 3
	root.Parent = p.Parent
	return { Root = root, Label = label, Icon = icon }
end

-- Progress bar ------------------------------------------------------------------------------------

export type Progress = {
	Root: Frame,
	Fill: Frame,
	Label: TextLabel,
	Set: (self: Progress, alpha: number, text: string?, instant: boolean?) -> (),
}

function UIKit.Progress(p: {
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3,
	Parent: Instance?,
	TextSize: number?,
}): Progress
	local root = Instance.new("Frame")
	root.Name = "Progress"
	root.Size = p.Size
	root.Position = p.Position or UDim2.new()
	root.AnchorPoint = p.AnchorPoint or Vector2.zero
	root.BackgroundColor3 = Color3.fromRGB(240, 238, 248)
	UIKit.Corner(root, 14)
	UIKit.Stroke(root, 4, INK)
	root.ClipsDescendants = false

	local clip = Instance.new("Frame")
	clip.Name = "Clip"
	clip.BackgroundTransparency = 1
	clip.Size = UDim2.fromScale(1, 1)
	clip.ClipsDescendants = true
	UIKit.Corner(clip, 14)
	clip.Parent = root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = p.Color
	fill.Size = UDim2.fromScale(0, 1)
	UIKit.Corner(fill, 14)
	UIKit.Gradient(fill, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210)), 90)
	fill.Parent = clip

	-- moving shimmer
	local shimmer = Instance.new("Frame")
	shimmer.Name = "Shimmer"
	shimmer.BackgroundColor3 = WHITE
	shimmer.BackgroundTransparency = 0.6
	shimmer.Size = UDim2.new(0, 40, 1, 0)
	shimmer.Rotation = 20
	shimmer.BorderSizePixel = 0
	shimmer.Parent = fill
	task.spawn(function()
		while shimmer.Parent do
			shimmer.Position = UDim2.new(0, -60, 0, 0)
			UIKit.Tween(shimmer, 1.2, { Position = UDim2.new(1, 20, 0, 0) }, Enum.EasingStyle.Sine)
			task.wait(2.6)
		end
	end)

	local label = UIKit.Label({
		Text = "",
		TextSize = p.TextSize or 30,
		Size = UDim2.fromScale(1, 1),
		Stroke = 3,
		Parent = root,
	})
	label.ZIndex = 3
	root.Parent = p.Parent

	local progress: Progress = {
		Root = root,
		Fill = fill,
		Label = label,
		Set = function(self: Progress, alpha: number, text: string?, instant: boolean?)
			local a = math.clamp(if alpha == alpha then alpha else 0, 0, 1)
			if instant then
				self.Fill.Size = UDim2.fromScale(a, 1)
			else
				UIKit.Tween(self.Fill, 0.25, { Size = UDim2.fromScale(a, 1) })
			end
			if text then
				self.Label.Text = text
			end
		end,
	}
	return progress
end

-- Panels ------------------------------------------------------------------------------------------

export type Panel = {
	Root: Frame, -- full-screen container (dim + window)
	Window: Frame,
	Body: Frame,
	Title: TextLabel,
	Close: TextButton,
}

-- A modal window: ink outline, film-strip top band, tilted title sticker,
-- round red close sticker.
function UIKit.Panel(p: { Title: string, Color: Color3, Size: Vector2?, Parent: Instance? }): Panel
	local size = p.Size or Vector2.new(940, 640)
	local root = Instance.new("Frame")
	root.Name = "Panel_" .. p.Title
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.ZIndex = 50

	-- `window` is a transparent container (it carries the pop-in UIScale);
	-- the visible panel is `surface`, with the drop shadow behind it.
	-- (ZIndexBehavior is Sibling, so a child can never draw under its parent.)
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.52)
	window.Size = UDim2.fromOffset(size.X, size.Y)
	window.BackgroundTransparency = 1
	window.Parent = root

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = INK
	shadow.BackgroundTransparency = 0.2
	shadow.Position = UDim2.fromOffset(0, 10)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = 0
	UIKit.Corner(shadow, 28)
	shadow.Parent = window

	local surface = Instance.new("Frame")
	surface.Name = "Surface"
	surface.BackgroundColor3 = C.Panel
	surface.Size = UDim2.fromScale(1, 1)
	surface.ZIndex = 1
	UIKit.Corner(surface, 28)
	UIKit.Stroke(surface, 5, INK)
	UIKit.Gradient(surface, ColorSequence.new(C.PanelLight, C.PanelDark), 90)
	surface.Parent = window

	local innerBand = Instance.new("Frame")
	innerBand.BackgroundTransparency = 1
	innerBand.Position = UDim2.fromOffset(6, 6)
	innerBand.Size = UDim2.new(1, -12, 1, -12)
	UIKit.Corner(innerBand, 24)
	UIKit.Stroke(innerBand, 2.5, WHITE, 0.8)
	innerBand.Parent = surface

	-- film strip band
	local strip = Instance.new("Frame")
	strip.Name = "FilmStrip"
	strip.ZIndex = 2
	strip.BackgroundColor3 = INK
	strip.Position = UDim2.fromOffset(18, 16)
	strip.Size = UDim2.new(1, -36, 0, 22)
	UIKit.Corner(strip, 8)
	strip.Parent = window
	local holes = Instance.new("Frame")
	holes.BackgroundTransparency = 1
	holes.Size = UDim2.fromScale(1, 1)
	holes.Parent = strip
	local hl = UIKit.List(holes, 16, true)
	hl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	UIKit.Padding(holes, 14, 0)
	for _ = 1, math.floor((size.X - 300) / 34) do
		local hole = Instance.new("Frame")
		hole.BackgroundColor3 = p.Color
		hole.Size = UDim2.fromOffset(18, 10)
		UIKit.Corner(hole, 3)
		hole.Parent = holes
	end

	-- tilted title sticker
	local titleRoot = Instance.new("Frame")
	titleRoot.Name = "TitleSticker"
	titleRoot.BackgroundTransparency = 1
	titleRoot.Position = UDim2.fromOffset(-22, -34)
	titleRoot.Size = UDim2.fromOffset(0, 74)
	titleRoot.AutomaticSize = Enum.AutomaticSize.X
	titleRoot.Rotation = -3
	titleRoot.ZIndex = 5
	titleRoot.Parent = window
	local titleShadow = Instance.new("Frame")
	titleShadow.BackgroundColor3 = INK
	titleShadow.Position = UDim2.fromOffset(0, 6)
	titleShadow.Size = UDim2.fromScale(1, 1)
	titleShadow.ZIndex = 5
	UIKit.Corner(titleShadow, 18)
	titleShadow.Parent = titleRoot
	local titleBody = Instance.new("Frame")
	titleBody.Name = "Body"
	titleBody.BackgroundColor3 = p.Color
	titleBody.Size = UDim2.new(0, 0, 1, 0)
	titleBody.AutomaticSize = Enum.AutomaticSize.X
	titleBody.ZIndex = 6
	UIKit.Corner(titleBody, 18)
	UIKit.Stroke(titleBody, 4, INK)
	UIKit.Gradient(titleBody, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 196, 206)), 90)
	UIKit.Padding(titleBody, 28, 0)
	titleBody.Parent = titleRoot
	local titleInner = Instance.new("Frame")
	titleInner.BackgroundTransparency = 1
	titleInner.Position = UDim2.new(0, -22, 0, 5)
	titleInner.Size = UDim2.new(1, 44, 1, -10)
	titleInner.ZIndex = 6
	UIKit.Corner(titleInner, 14)
	UIKit.Stroke(titleInner, 2.5, WHITE, 0.2)
	titleInner.Parent = titleBody
	local title = UIKit.Label({
		Text = string.upper(p.Title),
		TextSize = 44,
		Size = UDim2.fromScale(0, 1),
		AutoX = true,
		Stroke = 3.5,
		Parent = titleBody,
	})
	title.ZIndex = 7

	-- close sticker
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -6, 0, 6)
	close.Size = UDim2.fromOffset(72, 72)
	close.BackgroundColor3 = C.Red
	close.Text = ""
	close.AutoButtonColor = false
	close.ZIndex = 8
	UIKit.Round(close)
	UIKit.Stroke(close, 4, INK).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	UIKit.Gradient(close, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 196, 206)), 90)
	local closeInner = Instance.new("Frame")
	closeInner.BackgroundTransparency = 1
	closeInner.Position = UDim2.fromOffset(5, 5)
	closeInner.Size = UDim2.new(1, -10, 1, -10)
	closeInner.ZIndex = 8
	UIKit.Round(closeInner)
	UIKit.Stroke(closeInner, 2.5, WHITE, 0.2)
	closeInner.Parent = close
	local x = UIKit.Label({ Text = "✕", TextSize = 40, Stroke = 3, Parent = close })
	x.ZIndex = 9
	close.Parent = window
	UIKit.Interactive(close)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.ZIndex = 3
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(28, 54)
	body.Size = UDim2.new(1, -56, 1, -78)
	body.Parent = window

	root.Parent = p.Parent
	return { Root = root, Window = window, Body = body, Title = title, Close = close }
end

-- Scrolling grid ---------------------------------------------------------------------------------

function UIKit.Grid(parent: Instance, cell: Vector2, padding: number?): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Grid"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = WHITE
	scroll.ScrollBarImageTransparency = 0.4
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	grid.CellPadding = UDim2.fromOffset(padding or 14, padding or 14)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll
	UIKit.Padding(scroll, 8, 10)
	scroll.Parent = parent
	return scroll
end

-- Viewport with a model, framed by its extent --------------------------------------------------------

function UIKit.Viewport(model: Model, extent: number, parent: Instance?, angle: number?): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Viewport"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(190, 190, 205)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-0.6, -1, -0.8)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	local world = Instance.new("WorldModel")
	world.Parent = vp
	model:PivotTo(CFrame.new())
	model.Parent = world
	local a = angle or math.rad(25)
	local dist = extent * 2.4
	cam.CFrame =
		CFrame.lookAt(Vector3.new(math.sin(a) * dist, extent * 0.45, -math.cos(a) * dist), Vector3.new(0, 0, 0))
	vp.Parent = parent
	return vp
end

-- Spin a viewport camera around its subject (call returns a stop function).
function UIKit.Spin(vp: ViewportFrame, extent: number, speed: number?): () -> ()
	local cam = vp.CurrentCamera
	if not cam then
		return function() end
	end
	local running = true
	local a = math.rad(25)
	local conn
	conn = RunService.RenderStepped:Connect(function(dt: number)
		if not running or not vp.Parent then
			conn:Disconnect()
			return
		end
		a += dt * (speed or 1.2)
		local dist = extent * 2.4
		cam.CFrame =
			CFrame.lookAt(Vector3.new(math.sin(a) * dist, extent * 0.45, -math.cos(a) * dist), Vector3.new(0, 0, 0))
	end)
	return function()
		running = false
	end
end

-- Rarity-coloured tile frame used by shops/inventories ---------------------------------------------------

export type Tile = { Root: TextButton, Content: Frame, Name: TextLabel, Sub: TextLabel, Tag: TextLabel, Stroke: UIStroke }

function UIKit.Tile(p: { Rarity: string, Parent: Instance?, LayoutOrder: number?, Name: string? }): Tile
	local style = Theme.Rarities[p.Rarity] or Theme.Rarities.Common
	local root = Instance.new("TextButton")
	root.Name = p.Name or "Tile"
	root.Text = ""
	root.AutoButtonColor = false
	root.LayoutOrder = p.LayoutOrder or 0
	root.BackgroundColor3 = style.Color
	UIKit.Corner(root, 18)
	local stroke = UIKit.Stroke(root, 4, INK)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	if style.Animated then
		UIKit.Rainbow(root)
	else
		UIKit.Gradient(root, ColorSequence.new(style.Color:Lerp(WHITE, 0.35), style.Dark), 90)
	end
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(4, 4)
	inner.Size = UDim2.new(1, -8, 1, -8)
	UIKit.Corner(inner, 14)
	UIKit.Stroke(inner, 2.5, WHITE, 0.3)
	inner.Parent = root

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(6, 6)
	content.Size = UDim2.new(1, -12, 0.58, 0)
	content.Parent = root

	local name = UIKit.Label({
		Name = "ItemName",
		Text = "",
		Scaled = true,
		TextSize = 24,
		Size = UDim2.new(1, -12, 0.15, 0),
		Position = UDim2.new(0, 6, 0.6, 0),
		Stroke = 2.5,
		Parent = root,
	})
	local sub = UIKit.Label({
		Name = "Sub",
		Text = "",
		Scaled = true,
		TextSize = 22,
		Color = C.Yellow,
		Size = UDim2.new(1, -12, 0.13, 0),
		Position = UDim2.new(0, 6, 0.76, 0),
		Stroke = 2.5,
		Parent = root,
	})
	local tag = UIKit.Label({
		Name = "Tag",
		Text = "",
		Scaled = true,
		TextSize = 20,
		Size = UDim2.new(1, -12, 0.11, 0),
		Position = UDim2.new(0, 6, 0.885, 0),
		Stroke = 2.5,
		Parent = root,
	})
	root.Parent = p.Parent
	UIKit.Interactive(root)
	return { Root = root, Content = content, Name = name, Sub = sub, Tag = tag, Stroke = stroke }
end

-- Small helpers for panels ---------------------------------------------------------------------------

function UIKit.Card(parent: Instance, size: UDim2, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.BackgroundColor3 = color or Color3.fromRGB(56, 45, 90)
	UIKit.Corner(f, 18)
	UIKit.Stroke(f, 3.5, INK)
	f.Parent = parent
	return f
end

return UIKit
