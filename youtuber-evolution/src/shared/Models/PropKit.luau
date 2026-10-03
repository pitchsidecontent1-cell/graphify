--!strict
-- Low-level builders for blocky, stud-style geometry + labels.
-- Everything here only sets plain properties (no PivotTo / Position reads),
-- so the exact same code runs on the server *and* under Lune when we bake the
-- map into the place file.

local Assets = require(script.Parent.Parent.Config.Assets)

local PropKit = {}

export type PartSpec = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Shape: string?, -- "Block" | "Cylinder" | "Ball" | "Wedge" | "CornerWedge"
	Transparency: number?,
	Reflectance: number?,
	CanCollide: boolean?,
	CanQuery: boolean?,
	CanTouch: boolean?,
	CastShadow: boolean?,
	Anchored: boolean?,
	Studs: boolean?,
	Parent: Instance?,
}

local WHITE = Color3.new(1, 1, 1)

function PropKit.Part(spec: PartSpec): BasePart
	local part: BasePart
	if spec.Shape == "Wedge" then
		part = Instance.new("WedgePart")
	elseif spec.Shape == "CornerWedge" then
		part = Instance.new("CornerWedgePart")
	else
		local p = Instance.new("Part")
		if spec.Shape == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
		elseif spec.Shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		end
		part = p
	end
	part.Name = spec.Name or "Part"
	part.Size = spec.Size
	part.CFrame = spec.CFrame
	part.Color = spec.Color or WHITE
	part.Material = spec.Material or Enum.Material.SmoothPlastic
	part.Transparency = spec.Transparency or 0
	part.Reflectance = spec.Reflectance or 0
	part.Anchored = spec.Anchored ~= false
	part.CanCollide = spec.CanCollide ~= false
	part.CanQuery = spec.CanQuery ~= false
	part.CanTouch = spec.CanTouch == true
	part.CastShadow = spec.CastShadow ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if spec.Studs then
		PropKit.Studs(part)
	end
	if spec.Parent then
		part.Parent = spec.Parent
	end
	return part
end

-- Decoration helper: no collision, no queries, no shadow.
function PropKit.Deco(spec: PartSpec): BasePart
	spec.CanCollide = if spec.CanCollide == nil then false else spec.CanCollide
	spec.CanQuery = false
	if spec.CastShadow == nil then
		spec.CastShadow = false
	end
	return PropKit.Part(spec)
end

-- Stud look on the top face: custom tinted texture if one is configured,
-- otherwise Roblox's built-in studs surface.
function PropKit.Studs(part: BasePart)
	local id = Assets.Images.StudTexture
	if id ~= "" then
		local tex = Instance.new("Texture")
		tex.Name = "Studs"
		tex.Texture = id
		tex.Face = Enum.NormalId.Top
		tex.StudsPerTileU = 4
		tex.StudsPerTileV = 4
		tex.Color3 = part.Color
		tex.Transparency = 0.35
		tex.Parent = part
	else
		part.Material = Enum.Material.Plastic
		part.TopSurface = Enum.SurfaceType.Studs
	end
end

function PropKit.Model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

function PropKit.Folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	if parent then
		f.Parent = parent
	end
	return f
end

-- Cylinder whose round faces point up (Roblox cylinders run along X).
function PropKit.Disc(spec: PartSpec): BasePart
	spec.Shape = "Cylinder"
	local s = spec.Size -- (diameter, height, diameter)
	spec.Size = Vector3.new(s.Y, s.X, s.Z)
	spec.CFrame = spec.CFrame * CFrame.Angles(0, 0, math.rad(90))
	return PropKit.Part(spec)
end

-- Cylinder pointing forward (-Z), e.g. a camera lens.
function PropKit.Tube(spec: PartSpec): BasePart
	spec.Shape = "Cylinder"
	local s = spec.Size -- (diameter, diameter, length)
	spec.Size = Vector3.new(s.Z, s.Y, s.X)
	spec.CFrame = spec.CFrame * CFrame.Angles(0, math.rad(90), 0)
	return PropKit.Part(spec)
end

export type TextSpec = {
	Text: string,
	Color: Color3?,
	StrokeColor: Color3?,
	StrokeThickness: number?,
	Background: Color3?,
	BackgroundTransparency: number?,
	PixelsPerStud: number?,
	Font: Font?,
	Gradient: ColorSequence?,
	LightInfluence: number?,
	Name: string?,
}

local function makeLabel(parent: Instance, spec: TextSpec): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = spec.BackgroundTransparency or 1
	label.BackgroundColor3 = spec.Background or Color3.new(0, 0, 0)
	label.BorderSizePixel = 0
	label.Text = spec.Text
	label.TextScaled = true
	label.TextColor3 = spec.Color or WHITE
	label.FontFace = spec.Font or Font.fromEnum(Enum.Font.FredokaOne)
	label.TextWrapped = true
	local stroke = Instance.new("UIStroke")
	stroke.Color = spec.StrokeColor or Color3.fromRGB(27, 21, 48)
	stroke.Thickness = spec.StrokeThickness or 4
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	if spec.Gradient then
		local g = Instance.new("UIGradient")
		g.Color = spec.Gradient
		g.Rotation = 90
		g.Parent = label
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.Parent = label
	label.Parent = parent
	return label
end

function PropKit.SurfaceText(part: BasePart, face: Enum.NormalId, spec: TextSpec): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = spec.Name or "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = spec.PixelsPerStud or 40
	gui.LightInfluence = spec.LightInfluence or 0
	gui.Brightness = 1.4
	gui.MaxDistance = 600
	makeLabel(gui, spec)
	gui.Parent = part
	return gui
end

export type BillboardSpec = TextSpec & {
	Size: Vector2, -- studs
	Offset: Vector3?,
	MaxDistance: number?,
	AlwaysOnTop: boolean?,
}

function PropKit.Billboard(parent: Instance, spec: BillboardSpec): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = spec.Name or "Billboard"
	gui.Size = UDim2.new(spec.Size.X, 0, spec.Size.Y, 0)
	gui.StudsOffset = spec.Offset or Vector3.new(0, 0, 0)
	gui.MaxDistance = spec.MaxDistance or 180
	gui.AlwaysOnTop = spec.AlwaysOnTop == true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	makeLabel(gui, spec)
	gui.Parent = parent
	return gui
end

function PropKit.Light(parent: Instance, color: Color3, brightness: number, range: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	return l
end

function PropKit.Sparkles(parent: Instance, color: Color3, rate: number?, size: number?): ParticleEmitter
	local p = Instance.new("ParticleEmitter")
	p.Name = "Sparkles"
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = ColorSequence.new(color)
	p.LightEmission = 0.8
	p.Rate = rate or 6
	p.Lifetime = NumberRange.new(0.8, 1.6)
	p.Speed = NumberRange.new(1, 3)
	p.SpreadAngle = Vector2.new(180, 180)
	local s = size or 0.6
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, s),
		NumberSequenceKeypoint.new(1, 0),
	})
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.Parent = parent
	return p
end

-- Simple weld that keeps parts together when unanchored (held items, gear).
function PropKit.WeldAll(model: Instance, root: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
end

function PropKit.Tag(inst: Instance, tag: string)
	inst:AddTag(tag)
end

return PropKit
