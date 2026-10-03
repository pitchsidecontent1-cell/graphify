--!strict
-- Builds Evolution gear (phones, headsets, ring lights, plaques, drones,
-- capes, wings, auras...) out of parts and welds it to a character.
-- Works for R15 and R6. Orbiting pieces use a Weld tagged "GearOrbit" whose
-- C0 the client animates (Radius/Height/Speed/Phase attributes).

local Shared = game:GetService("ReplicatedStorage").Shared
local PropKit = require(Shared.Models.PropKit)
local Evolutions = require(Shared.Config.Evolutions)
local Theme = require(Shared.Config.Theme)

type GearSpec = Evolutions.GearSpec

local GearBuilder = {}

local INK = Color3.fromRGB(27, 21, 48)
local WHITE = Color3.new(1, 1, 1)

local function find(char: Model, ...: string): BasePart?
	for _, name in { ... } do
		local p = char:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

type Rig = {
	char: Model,
	root: BasePart,
	head: BasePart,
	torso: BasePart,
	leftHand: BasePart,
	rightHand: BasePart,
	folder: Folder,
}

local function gearPart(rig: Rig, parent: Instance, spec: PropKit.PartSpec): BasePart
	spec.Parent = parent
	spec.Anchored = false
	spec.CanCollide = false
	spec.CanQuery = false
	spec.CanTouch = false
	spec.CastShadow = false
	local p = PropKit.Part(spec)
	p.Massless = true
	return p
end

-- weld every part in `container` to `to`, keeping current offsets
local function weldTo(container: Instance, to: BasePart)
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then
			local w = Instance.new("WeldConstraint")
			w.Part0 = to
			w.Part1 = d
			w.Parent = d
		end
	end
end

local function rainbowTag(inst: Instance, spec: GearSpec)
	if spec.Rainbow then
		inst:AddTag("GearRainbow")
	end
end

-- Hub part on a C0-animated Weld; children get welded to the hub.
local function orbitHub(
	rig: Rig,
	name: string,
	attach: BasePart,
	radius: number,
	height: number,
	speed: number,
	phase: number
): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = rig.folder
	local start = attach.CFrame * CFrame.Angles(0, phase, 0) * CFrame.new(radius, height, 0)
	local hub = gearPart(rig, model, {
		Name = "Hub",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = start,
		Transparency = 1,
	})
	local weld = Instance.new("Weld")
	weld.Name = "OrbitWeld"
	weld.Part0 = attach
	weld.Part1 = hub
	weld.C0 = CFrame.Angles(0, phase, 0) * CFrame.new(radius, height, 0)
	weld:SetAttribute("Radius", radius)
	weld:SetAttribute("Height", height)
	weld:SetAttribute("Speed", speed)
	weld:SetAttribute("Phase", phase)
	weld:AddTag("GearOrbit")
	weld.Parent = hub
	return model, hub
end

local BUILD: { [string]: (Rig, GearSpec) -> () } = {}

BUILD.Sparkles = function(rig, spec)
	local att = Instance.new("Attachment")
	att.Name = "GearSparkles"
	att.Parent = rig.root
	PropKit.Sparkles(att, spec.Color or WHITE, 3, 0.35)
	att:SetAttribute("Gear", true)
end

BUILD.Phone = function(rig, spec)
	local model = Instance.new("Model")
	model.Name = "Phone"
	model.Parent = rig.folder
	local hand = rig.leftHand
	local base = hand.CFrame
		* CFrame.new(0, -hand.Size.Y / 2 - 0.15, -0.2)
		* CFrame.Angles(math.rad(-75), math.rad(160), 0)
	gearPart(rig, model, { Name = "Body", Size = Vector3.new(0.55, 1, 0.1), CFrame = base, Color = spec.Color or INK })
	gearPart(rig, model, {
		Name = "Screen",
		Size = Vector3.new(0.47, 0.88, 0.02),
		CFrame = base * CFrame.new(0, 0, -0.06),
		Color = spec.Color2 or Theme.Colors.Cyan,
		Material = Enum.Material.Neon,
	})
	weldTo(model, hand)
end

BUILD.Headset = function(rig, spec)
	local model = Instance.new("Model")
	model.Name = "Headset"
	model.Parent = rig.folder
	local head = rig.head
	local hs = head.Size
	local cf = head.CFrame
	local color = spec.Color or INK
	gearPart(rig, model, {
		Name = "Band",
		Size = Vector3.new(hs.X + 0.25, 0.18, 0.32),
		CFrame = cf * CFrame.new(0, hs.Y / 2 + 0.06, 0),
		Color = color,
	})
	for _, side in { -1, 1 } do
		gearPart(rig, model, {
			Name = "Cup",
			Size = Vector3.new(0.22, 0.62, 0.62),
			CFrame = cf * CFrame.new(side * (hs.X / 2 + 0.1), 0, 0),
			Color = color,
			Shape = "Cylinder",
		})
		gearPart(rig, model, {
			Name = "Pad",
			Size = Vector3.new(0.08, 0.5, 0.5),
			CFrame = cf * CFrame.new(side * (hs.X / 2 + 0.24), 0, 0),
			Color = spec.Color2 or Theme.Colors.Red,
			Material = Enum.Material.Neon,
			Shape = "Cylinder",
		})
		gearPart(rig, model, {
			Name = "Arm",
			Size = Vector3.new(0.14, hs.Y / 2, 0.2),
			CFrame = cf * CFrame.new(side * (hs.X / 2 + 0.12), hs.Y / 4 + 0.05, 0),
			Color = color,
		})
	end
	gearPart(rig, model, {
		Name = "Boom",
		Size = Vector3.new(0.08, 0.08, 0.7),
		CFrame = cf * CFrame.new(-hs.X / 2 - 0.12, -0.2, -0.3) * CFrame.Angles(0, math.rad(-25), 0),
		Color = color,
	})
	gearPart(rig, model, {
		Name = "Mic",
		Size = Vector3.new(0.18, 0.18, 0.18),
		CFrame = cf * CFrame.new(-hs.X / 2 + 0.05, -0.22, -0.62),
		Color = spec.Color2 or Theme.Colors.Red,
		Shape = "Ball",
	})
	weldTo(model, head)
end

BUILD.RingLight = function(rig, spec)
	local model = Instance.new("Model")
	model.Name = "RingLight"
	model.Parent = rig.folder
	local head = rig.head
	local center = head.CFrame * CFrame.new(0, 0.25, head.Size.Z / 2 + 0.7)
	local segments = 14
	local radius = 1.25
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local p = gearPart(rig, model, {
			Name = "Ring",
			Size = Vector3.new(0.62, 0.16, 0.16),
			CFrame = center * CFrame.Angles(0, 0, a) * CFrame.new(0, radius, 0),
			Color = spec.Color or WHITE,
			Material = Enum.Material.Neon,
		})
		rainbowTag(p, spec)
	end
	weldTo(model, head)
end

local function hexagon(
	rig: Rig,
	parent: Instance,
	cf: CFrame,
	radius: number,
	depth: number,
	color: Color3,
	material: Enum.Material?
): { BasePart }
	local parts = {}
	for i = 0, 2 do
		table.insert(
			parts,
			gearPart(rig, parent, {
				Name = "Hex",
				Size = Vector3.new(radius, radius * math.sqrt(3), depth),
				CFrame = cf * CFrame.Angles(0, 0, math.rad(60 * i)),
				Color = color,
				Material = material,
			})
		)
	end
	return parts
end

BUILD.Plaque = function(rig, spec)
	local model = Instance.new("Model")
	model.Name = "Plaque"
	model.Parent = rig.folder
	local torso = rig.torso
	local cf = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.12, -torso.Size.Z / 2 - 0.08)
	hexagon(rig, model, cf * CFrame.new(0, 0, 0.02), 0.62, 0.08, INK)
	for _, p in
		hexagon(
			rig,
			model,
			cf * CFrame.new(0, 0, -0.03),
			0.52,
			0.1,
			spec.Color or Theme.Colors.Gold,
			Enum.Material.Metal
		)
	do
		rainbowTag(p, spec)
	end
	gearPart(rig, model, {
		Name = "Star",
		Size = Vector3.new(0.3, 0.3, 0.06),
		CFrame = cf * CFrame.new(0, 0, -0.1) * CFrame.Angles(0, 0, math.rad(45)),
		Color = WHITE,
		Material = Enum.Material.Neon,
	})
	-- strap
	gearPart(rig, model, {
		Name = "Strap",
		Size = Vector3.new(0.1, torso.Size.Y * 0.5, 0.05),
		CFrame = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.36, -torso.Size.Z / 2 - 0.04),
		Color = INK,
	})
	weldTo(model, torso)
end

BUILD.Drone = function(rig, spec)
	local count = spec.Count or 1
	for i = 1, count do
		local phase = (i - 1) / count * math.pi * 2
		local model, hub = orbitHub(rig, "Drone", rig.root, 3.2, 3.2, 1.4, phase)
		local cf = hub.CFrame
		gearPart(
			rig,
			model,
			{ Name = "Body", Size = Vector3.new(0.9, 0.3, 0.9), CFrame = cf, Color = spec.Color or INK }
		)
		for _, x in { -0.55, 0.55 } do
			for _, z in { -0.55, 0.55 } do
				gearPart(rig, model, {
					Name = "Rotor",
					Size = Vector3.new(0.05, 0.6, 0.6),
					CFrame = cf * CFrame.new(x, 0.2, z) * CFrame.Angles(0, 0, math.rad(90)),
					Color = Color3.fromRGB(200, 200, 210),
					Shape = "Cylinder",
					Transparency = 0.3,
				})
			end
		end
		gearPart(rig, model, {
			Name = "Lens",
			Size = Vector3.new(0.3, 0.3, 0.3),
			CFrame = cf * CFrame.new(0, -0.18, -0.35),
			Color = spec.Color2 or Theme.Colors.Mint,
			Material = Enum.Material.Neon,
			Shape = "Ball",
		})
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d ~= hub then
				local w = Instance.new("WeldConstraint")
				w.Part0 = hub
				w.Part1 = d
				w.Parent = d
			end
		end
	end
end

BUILD.Cape = function(rig, spec)
	local model = Instance.new("Model")
	model.Name = "Cape"
	model.Parent = rig.folder
	local torso = rig.torso
	local top = torso.CFrame * CFrame.new(0, torso.Size.Y / 2 - 0.1, torso.Size.Z / 2 + 0.06)
	local length = 3
	local cf = top * CFrame.Angles(math.rad(8), 0, 0) * CFrame.new(0, -length / 2, 0.05)
	local cape = gearPart(rig, model, {
		Name = "Cape",
		Size = Vector3.new(torso.Size.X * 0.95, length, 0.1),
		CFrame = cf,
		Color = spec.Color or Theme.Colors.Red,
		Material = Enum.Material.Fabric,
	})
	rainbowTag(cape, spec)
	gearPart(rig, model, {
		Name = "Trim",
		Size = Vector3.new(torso.Size.X * 0.97, 0.22, 0.12),
		CFrame = cf * CFrame.new(0, -length / 2 + 0.11, 0),
		Color = spec.Color2 or Theme.Colors.Yellow,
		Material = Enum.Material.Neon,
	})
	weldTo(model, torso)
end

BUILD.Trail = function(rig, spec)
	local a0 = Instance.new("Attachment")
	a0.Name = "GearTrailTop"
	a0.Position = Vector3.new(0, 1, 0.4)
	a0:SetAttribute("Gear", true)
	a0.Parent = rig.root
	local a1 = Instance.new("Attachment")
	a1.Name = "GearTrailBottom"
	a1.Position = Vector3.new(0, -1.6, 0.4)
	a1:SetAttribute("Gear", true)
	a1.Parent = rig.root
	local trail = Instance.new("Trail")
	trail.Name = "GearTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.45
	trail.LightEmission = 0.8
	trail.FaceCamera = true
	trail.MinLength = 0.1
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Color = if spec.Rainbow then Theme.Rainbow else ColorSequence.new(spec.Color or WHITE, spec.Color2 or WHITE)
	trail.Parent = rig.root
end

BUILD.Aura = function(rig, spec)
	local att = Instance.new("Attachment")
	att.Name = "GearAura"
	att.Position = Vector3.new(0, -1, 0)
	att:SetAttribute("Gear", true)
	att.Parent = rig.root
	local p = Instance.new("ParticleEmitter")
	p.Name = "Aura"
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = if spec.Rainbow then Theme.Rainbow else ColorSequence.new(spec.Color or WHITE, spec.Color2 or WHITE)
	p.LightEmission = 1
	p.Rate = 14
	p.Lifetime = NumberRange.new(0.8, 1.4)
	p.Speed = NumberRange.new(2, 4)
	p.SpreadAngle = Vector2.new(25, 25)
	p.EmissionDirection = Enum.NormalId.Top
	p.Shape = Enum.ParticleEmitterShape.Cylinder
	p.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	p.Transparency = NumberSequence.new(0.1, 1)
	p.Parent = att
end

BUILD.Crown = function(rig, spec)
	local count = spec.Count or 5
	local head = rig.head
	for i = 1, count do
		local phase = (i - 1) / count * math.pi * 2
		local model, hub = orbitHub(rig, "CrownScreen", head, 1.0, head.Size.Y / 2 + 0.7, 0.9, phase)
		local cf = hub.CFrame * CFrame.Angles(0, math.rad(90), 0)
		gearPart(
			rig,
			model,
			{ Name = "Frame", Size = Vector3.new(0.62, 0.44, 0.08), CFrame = cf, Color = spec.Color or INK }
		)
		local screen = gearPart(rig, model, {
			Name = "Screen",
			Size = Vector3.new(0.52, 0.34, 0.1),
			CFrame = cf,
			Color = spec.Color2 or Theme.Colors.Yellow,
			Material = Enum.Material.Neon,
		})
		rainbowTag(screen, spec)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d ~= hub then
				local w = Instance.new("WeldConstraint")
				w.Part0 = hub
				w.Part1 = d
				w.Parent = d
			end
		end
	end
end

BUILD.Wings = function(rig, spec)
	local model = Instance.new("Model")
	model.Name = "Wings"
	model.Parent = rig.folder
	local torso = rig.torso
	local back = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.2, torso.Size.Z / 2 + 0.3)
	for _, side in { -1, 1 } do
		local cf = back * CFrame.Angles(0, side * math.rad(-28), side * math.rad(-12)) * CFrame.new(side * 1.5, 0.3, 0)
		local wing = gearPart(rig, model, {
			Name = "Wing",
			Size = Vector3.new(2.6, 3.4, 0.12),
			CFrame = cf,
			Color = spec.Color or INK,
		})
		rainbowTag(wing, spec)
		-- film-strip sprockets along both edges
		for row = 0, 4 do
			for _, edge in { -1, 1 } do
				gearPart(rig, model, {
					Name = "Hole",
					Size = Vector3.new(0.3, 0.38, 0.14),
					CFrame = cf * CFrame.new(edge * 1.05, -1.35 + row * 0.68, 0),
					Color = spec.Color2 or WHITE,
					Material = Enum.Material.Neon,
				})
			end
		end
	end
	weldTo(model, torso)
end

BUILD.Orbiters = function(rig, spec)
	local count = spec.Count or 3
	for i = 1, count do
		local phase = (i - 1) / count * math.pi * 2
		local model, hub = orbitHub(rig, "Orbiter", rig.root, 4.2, 0.8 + (i % 2) * 1.6, 0.7, phase)
		local planet = gearPart(rig, model, {
			Name = "Planet",
			Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = hub.CFrame,
			Color = if i % 2 == 0 then (spec.Color2 or WHITE) else (spec.Color or WHITE),
			Material = Enum.Material.Neon,
			Shape = "Ball",
		})
		rainbowTag(planet, spec)
		gearPart(rig, model, {
			Name = "PlanetRing",
			Size = Vector3.new(0.06, 1.5, 1.5),
			CFrame = hub.CFrame * CFrame.Angles(0, 0, math.rad(70)),
			Color = WHITE,
			Shape = "Cylinder",
			Transparency = 0.4,
		})
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d ~= hub then
				local w = Instance.new("WeldConstraint")
				w.Part0 = hub
				w.Part1 = d
				w.Parent = d
			end
		end
	end
end

-- Remove previously built gear.
function GearBuilder.Clear(char: Model)
	local folder = char:FindFirstChild("EvoGear")
	if folder then
		folder:Destroy()
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		for _, child in root:GetChildren() do
			if child:GetAttribute("Gear") or child.Name == "GearTrail" then
				child:Destroy()
			end
		end
	end
end

-- Effective gear list for a tier (later tiers override earlier ones per Kind).
function GearBuilder.SpecsFor(tier: number): { GearSpec }
	local byKind: { [string]: GearSpec } = {}
	local order: { string } = {}
	for t = 1, math.min(tier, #Evolutions) do
		for _, spec in Evolutions[t].Gear do
			if not byKind[spec.Kind] then
				table.insert(order, spec.Kind)
			end
			byKind[spec.Kind] = spec
		end
	end
	local out = {}
	for _, kind in order do
		table.insert(out, byKind[kind])
	end
	return out
end

-- Build gear for `tier`. Call while the character is at scale 1.
function GearBuilder.Build(char: Model, tier: number)
	GearBuilder.Clear(char)
	local root = find(char, "HumanoidRootPart")
	local head = find(char, "Head")
	local torso = find(char, "UpperTorso", "Torso")
	local leftHand = find(char, "LeftHand", "Left Arm")
	local rightHand = find(char, "RightHand", "Right Arm")
	if not (root and head and torso and leftHand and rightHand) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "EvoGear"
	folder.Parent = char
	local rig: Rig = {
		char = char,
		root = root,
		head = head,
		torso = torso,
		leftHand = leftHand,
		rightHand = rightHand,
		folder = folder,
	}
	for _, spec in GearBuilder.SpecsFor(tier) do
		local fn = BUILD[spec.Kind]
		if fn then
			local ok, err = pcall(fn :: any, rig, spec)
			if not ok then
				warn("[Gear] " .. spec.Kind .. " failed: " .. tostring(err))
			end
		end
	end
end

-- After scaling a character, orbit radii must be scaled too (client reads them).
function GearBuilder.ScaleOrbits(char: Model, scale: number)
	for _, d in char:GetDescendants() do
		if d:IsA("Weld") and d:HasTag("GearOrbit") then
			local base = d:GetAttribute("BaseRadius")
			if typeof(base) ~= "number" then
				base = d:GetAttribute("Radius")
				d:SetAttribute("BaseRadius", base)
				d:SetAttribute("BaseHeight", d:GetAttribute("Height"))
			end
			local h = d:GetAttribute("BaseHeight")
			d:SetAttribute("Radius", (base :: number) * scale)
			d:SetAttribute("Height", (if typeof(h) == "number" then h else 0) * scale)
		end
	end
end

return GearBuilder
