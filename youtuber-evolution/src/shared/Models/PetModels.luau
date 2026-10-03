--!strict
-- Blocky pets built from parts. Each shape is a small recipe; colors come
-- from the pet definition. Pets face -Z; PrimaryPart "Handle" is the body.

local Pets = require(script.Parent.Parent.Config.Pets)
local PropKit = require(script.Parent.PropKit)

type Pet = Pets.Pet

local PetModels = {}

local BLACK = Color3.fromRGB(25, 20, 35)
local WHITE = Color3.fromRGB(255, 255, 255)
local PINK = Color3.fromRGB(255, 140, 170)
local ORANGE = Color3.fromRGB(255, 170, 40)

type Ctx = {
	model: Model,
	o: CFrame,
	pet: Pet,
}

local function part(
	c: Ctx,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: string?
): BasePart
	return PropKit.Part({
		Name = name,
		Size = size,
		CFrame = c.o * offset,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Shape = shape,
		Parent = c.model,
	})
end

local function eyes(c: Ctx, y: number, z: number, spacing: number, size: number)
	local glow = c.pet.Glow
	for _, side in { -1, 1 } do
		part(
			c,
			"Eye",
			Vector3.new(size * 0.75, size, 0.08),
			CFrame.new(side * spacing, y, z),
			if glow then c.pet.Color2 else BLACK,
			if glow then Enum.Material.Neon else nil
		)
		part(
			c,
			"Shine",
			Vector3.new(size * 0.28, size * 0.28, 0.04),
			CFrame.new(side * spacing + size * 0.15, y + size * 0.22, z - 0.05),
			WHITE
		)
	end
end

local function legs(c: Ctx, w: number, front: number, back: number, color: Color3)
	for _, x in { -w, w } do
		for _, z in { front, back } do
			part(c, "Leg", Vector3.new(0.38, 0.55, 0.38), CFrame.new(x, 0.28, z), color)
		end
	end
end

local function quadHead(c: Ctx, headSize: Vector3, headY: number, headZ: number)
	part(c, "Head", headSize, CFrame.new(0, headY, headZ), c.pet.Color)
	local front = headZ - headSize.Z / 2 - 0.02
	eyes(c, headY + 0.08, front, headSize.X * 0.24, 0.3)
end

local SHAPES: { [string]: (Ctx) -> BasePart } = {}

SHAPES.cat = function(c)
	local p = c.pet
	local body = part(c, "Handle", Vector3.new(1.4, 1.1, 1.6), CFrame.new(0, 0.95, 0.2), p.Color)
	part(c, "Belly", Vector3.new(1.0, 0.2, 1.2), CFrame.new(0, 0.42, 0.2), p.Color2)
	quadHead(c, Vector3.new(1.35, 1.2, 1.2), 1.75, -0.65)
	for _, s in { -1, 1 } do
		part(c, "Ear", Vector3.new(0.4, 0.5, 0.3), CFrame.new(s * 0.42, 2.55, -0.65), p.Color, nil, "Wedge")
		part(c, "EarIn", Vector3.new(0.22, 0.3, 0.05), CFrame.new(s * 0.42, 2.48, -0.82), PINK, nil, "Wedge")
	end
	part(c, "Nose", Vector3.new(0.18, 0.12, 0.06), CFrame.new(0, 1.6, -1.27), PINK)
	part(c, "Tail", Vector3.new(0.25, 0.25, 1.1), CFrame.new(0, 1.5, 1.15) * CFrame.Angles(math.rad(35), 0, 0), p.Color)
	part(
		c,
		"TailTip",
		Vector3.new(0.27, 0.27, 0.3),
		CFrame.new(0, 1.85, 1.55) * CFrame.Angles(math.rad(35), 0, 0),
		p.Color2
	)
	legs(c, 0.45, -0.3, 0.7, p.Color)
	return body
end

SHAPES.dog = function(c)
	local p = c.pet
	local body = part(c, "Handle", Vector3.new(1.4, 1.1, 1.7), CFrame.new(0, 0.95, 0.2), p.Color)
	quadHead(c, Vector3.new(1.35, 1.2, 1.2), 1.75, -0.65)
	part(c, "Snout", Vector3.new(0.7, 0.45, 0.4), CFrame.new(0, 1.5, -1.42), p.Color2)
	part(c, "Nose", Vector3.new(0.25, 0.18, 0.08), CFrame.new(0, 1.68, -1.64), BLACK)
	for _, s in { -1, 1 } do
		part(
			c,
			"Ear",
			Vector3.new(0.28, 0.75, 0.5),
			CFrame.new(s * 0.78, 1.65, -0.6) * CFrame.Angles(0, 0, s * math.rad(-12)),
			p.Color2
		)
	end
	part(
		c,
		"Tail",
		Vector3.new(0.25, 0.25, 0.8),
		CFrame.new(0, 1.55, 1.15) * CFrame.Angles(math.rad(50), 0, 0),
		p.Color
	)
	legs(c, 0.45, -0.35, 0.75, p.Color)
	return body
end

SHAPES.bunny = function(c)
	local p = c.pet
	local body = part(c, "Handle", Vector3.new(1.4, 1.3, 1.4), CFrame.new(0, 0.85, 0.15), p.Color)
	quadHead(c, Vector3.new(1.3, 1.15, 1.1), 1.8, -0.4)
	for _, s in { -1, 1 } do
		part(
			c,
			"Ear",
			Vector3.new(0.32, 1.15, 0.25),
			CFrame.new(s * 0.32, 2.9, -0.4) * CFrame.Angles(0, 0, s * math.rad(-8)),
			p.Color
		)
		part(
			c,
			"EarIn",
			Vector3.new(0.18, 0.9, 0.05),
			CFrame.new(s * 0.32, 2.9, -0.54) * CFrame.Angles(0, 0, s * math.rad(-8)),
			p.Color2
		)
	end
	part(c, "Nose", Vector3.new(0.16, 0.12, 0.06), CFrame.new(0, 1.66, -0.98), PINK)
	part(c, "Tail", Vector3.new(0.55, 0.55, 0.55), CFrame.new(0, 0.85, 0.95), p.Color2, nil, "Ball")
	part(c, "Paws", Vector3.new(1.0, 0.3, 0.4), CFrame.new(0, 0.2, -0.45), p.Color)
	return body
end

SHAPES.fox = function(c)
	local p = c.pet
	local body = part(c, "Handle", Vector3.new(1.3, 1.05, 1.7), CFrame.new(0, 0.95, 0.2), p.Color)
	part(c, "Chest", Vector3.new(0.9, 0.7, 0.2), CFrame.new(0, 0.95, -0.66), p.Color2)
	quadHead(c, Vector3.new(1.35, 1.15, 1.15), 1.75, -0.65)
	part(c, "Snout", Vector3.new(0.6, 0.38, 0.45), CFrame.new(0, 1.52, -1.45), p.Color2)
	part(c, "Nose", Vector3.new(0.2, 0.15, 0.06), CFrame.new(0, 1.66, -1.69), BLACK)
	for _, s in { -1, 1 } do
		part(c, "Ear", Vector3.new(0.45, 0.6, 0.3), CFrame.new(s * 0.42, 2.6, -0.65), p.Color, nil, "Wedge")
	end
	part(c, "Tail", Vector3.new(0.6, 0.6, 1.3), CFrame.new(0, 1.35, 1.35) * CFrame.Angles(math.rad(30), 0, 0), p.Color)
	part(
		c,
		"TailTip",
		Vector3.new(0.62, 0.62, 0.4),
		CFrame.new(0, 1.7, 1.95) * CFrame.Angles(math.rad(30), 0, 0),
		p.Color2
	)
	legs(c, 0.42, -0.35, 0.75, BLACK)
	return body
end

SHAPES.bear = function(c)
	local p = c.pet
	local body = part(c, "Handle", Vector3.new(1.7, 1.4, 1.7), CFrame.new(0, 1.0, 0.2), p.Color)
	part(c, "Belly", Vector3.new(1.1, 0.9, 0.2), CFrame.new(0, 0.95, -0.68), p.Color2)
	quadHead(c, Vector3.new(1.5, 1.3, 1.25), 1.95, -0.6)
	part(c, "Snout", Vector3.new(0.65, 0.42, 0.35), CFrame.new(0, 1.72, -1.35), p.Color2)
	part(c, "Nose", Vector3.new(0.25, 0.15, 0.06), CFrame.new(0, 1.85, -1.54), BLACK)
	for _, s in { -1, 1 } do
		PropKit.Tube({
			Name = "Ear",
			Size = Vector3.new(0.5, 0.5, 0.25),
			CFrame = c.o * CFrame.new(s * 0.6, 2.7, -0.6),
			Color = p.Color2,
			Parent = c.model,
		})
		if p.Color2 == BLACK or p.Name == "Panda" then
			part(c, "Patch", Vector3.new(0.45, 0.45, 0.04), CFrame.new(s * 0.34, 2.03, -1.23), p.Color2)
		end
	end
	legs(c, 0.55, -0.35, 0.75, p.Color)
	return body
end

SHAPES.frog = function(c)
	local p = c.pet
	local body = part(c, "Handle", Vector3.new(1.8, 0.9, 1.6), CFrame.new(0, 0.65, 0), p.Color)
	part(c, "Belly", Vector3.new(1.4, 0.15, 1.2), CFrame.new(0, 0.2, 0), p.Color2)
	for _, s in { -1, 1 } do
		part(c, "EyeBall", Vector3.new(0.65, 0.65, 0.65), CFrame.new(s * 0.5, 1.25, -0.45), p.Color, nil, "Ball")
		part(
			c,
			"Pupil",
			Vector3.new(0.3, 0.3, 0.1),
			CFrame.new(s * 0.5, 1.28, -0.78),
			if p.Glow then p.Color2 else BLACK
		)
		part(c, "Foot", Vector3.new(0.6, 0.2, 0.5), CFrame.new(s * 0.75, 0.15, -0.55), p.Color)
	end
	part(c, "Mouth", Vector3.new(1.0, 0.06, 0.05), CFrame.new(0, 0.75, -0.82), BLACK)
	return body
end

local function birdBase(c: Ctx, belly: boolean): BasePart
	local p = c.pet
	local body = part(c, "Handle", Vector3.new(1.3, 1.6, 1.2), CFrame.new(0, 1.0, 0), p.Color)
	if belly then
		part(c, "Belly", Vector3.new(0.95, 1.2, 0.1), CFrame.new(0, 0.9, -0.62), p.Color2)
	end
	eyes(c, 1.45, -0.62, 0.3, 0.26)
	part(
		c,
		"Beak",
		Vector3.new(0.35, 0.3, 0.4),
		CFrame.new(0, 1.15, -0.8) * CFrame.Angles(math.rad(180), 0, 0),
		ORANGE,
		nil,
		"Wedge"
	)
	for _, s in { -1, 1 } do
		part(
			c,
			"Wing",
			Vector3.new(0.18, 1.0, 0.85),
			CFrame.new(s * 0.74, 1.0, 0.05) * CFrame.Angles(0, 0, s * math.rad(-10)),
			p.Color2
		)
		part(c, "Foot", Vector3.new(0.3, 0.12, 0.4), CFrame.new(s * 0.3, 0.12, -0.2), ORANGE)
	end
	return body
end

SHAPES.bird = function(c)
	local body = birdBase(c, true)
	part(c, "Tuft", Vector3.new(0.5, 0.3, 0.3), CFrame.new(0, 1.9, 0), c.pet.Color, nil, "Wedge")
	return body
end

SHAPES.penguin = function(c)
	return birdBase(c, true)
end

SHAPES.phoenix = function(c)
	local p = c.pet
	local body = birdBase(c, false)
	for i = 1, 3 do
		part(
			c,
			"Flame",
			Vector3.new(0.3, 0.3, 1.0 + i * 0.2),
			CFrame.new((i - 2) * 0.28, 0.9 + i * 0.1, 0.9) * CFrame.Angles(math.rad(25 + i * 8), 0, 0),
			p.Color2,
			Enum.Material.Neon
		)
	end
	part(c, "Crest", Vector3.new(0.2, 0.55, 0.45), CFrame.new(0, 2.05, -0.1), p.Color2, Enum.Material.Neon, "Wedge")
	return body
end

SHAPES.mouse = function(c)
	local p = c.pet
	local body = part(c, "Handle", Vector3.new(1.2, 1.0, 1.5), CFrame.new(0, 0.8, 0.2), p.Color)
	quadHead(c, Vector3.new(1.1, 1.0, 1.0), 1.4, -0.55)
	for _, s in { -1, 1 } do
		PropKit.Tube({
			Name = "Ear",
			Size = Vector3.new(0.75, 0.75, 0.15),
			CFrame = c.o * CFrame.new(s * 0.55, 2.05, -0.45),
			Color = p.Color2,
			Parent = c.model,
		})
	end
	part(c, "Nose", Vector3.new(0.16, 0.14, 0.06), CFrame.new(0, 1.28, -1.07), PINK)
	part(c, "Tail", Vector3.new(0.12, 0.12, 1.4), CFrame.new(0, 0.7, 1.55) * CFrame.Angles(math.rad(-15), 0, 0), PINK)
	return body
end

SHAPES.slime = function(c)
	local p = c.pet
	local body =
		part(c, "Handle", Vector3.new(1.9, 1.6, 1.9), CFrame.new(0, 0.85, 0), p.Color, Enum.Material.Glass, "Ball")
	body.Transparency = 0.15
	part(c, "Core", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 0.85, 0.1), p.Color2, Enum.Material.Neon, "Ball").Transparency =
		0.4
	eyes(c, 1.05, -0.92, 0.32, 0.3)
	part(c, "Smile", Vector3.new(0.4, 0.07, 0.05), CFrame.new(0, 0.7, -0.92), BLACK)
	return body
end

SHAPES.robot = function(c)
	local p = c.pet
	local body = part(c, "Handle", Vector3.new(1.3, 1.1, 1.1), CFrame.new(0, 0.85, 0), p.Color, Enum.Material.Metal)
	part(c, "Head", Vector3.new(1.4, 1.1, 1.1), CFrame.new(0, 1.95, 0), p.Color, Enum.Material.Metal)
	part(c, "Face", Vector3.new(1.15, 0.8, 0.05), CFrame.new(0, 1.95, -0.56), BLACK)
	for _, s in { -1, 1 } do
		part(c, "Eye", Vector3.new(0.25, 0.3, 0.04), CFrame.new(s * 0.27, 2.0, -0.6), p.Color2, Enum.Material.Neon)
		part(c, "Arm", Vector3.new(0.25, 0.8, 0.25), CFrame.new(s * 0.8, 0.85, 0), p.Color2)
	end
	part(c, "Antenna", Vector3.new(0.1, 0.5, 0.1), CFrame.new(0, 2.75, 0), p.Color)
	part(c, "Bulb", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 3.05, 0), p.Color2, Enum.Material.Neon, "Ball")
	part(c, "Light", Vector3.new(0.5, 0.35, 0.05), CFrame.new(0, 0.95, -0.56), p.Color2, Enum.Material.Neon)
	return body
end

SHAPES.ghost = function(c)
	local p = c.pet
	local body = part(
		c,
		"Handle",
		Vector3.new(1.7, 1.7, 1.7),
		CFrame.new(0, 1.4, 0),
		p.Color,
		Enum.Material.SmoothPlastic,
		"Ball"
	)
	body.Transparency = 0.1
	part(c, "Skirt", Vector3.new(1.6, 0.9, 1.6), CFrame.new(0, 0.75, 0), p.Color).Transparency = 0.1
	for i = -1, 1 do
		part(c, "Wisp", Vector3.new(0.45, 0.45, 0.45), CFrame.new(i * 0.55, 0.25, 0), p.Color, nil, "Wedge").Transparency =
			0.15
	end
	eyes(c, 1.55, -0.83, 0.33, 0.36)
	part(
		c,
		"Mouth",
		Vector3.new(0.3, 0.3, 0.05),
		CFrame.new(0, 1.15, -0.8),
		p.Color2,
		if p.Glow then Enum.Material.Neon else nil
	)
	return body
end

SHAPES.dragon = function(c)
	local p = c.pet
	local body = part(c, "Handle", Vector3.new(1.5, 1.2, 1.9), CFrame.new(0, 1.0, 0.2), p.Color)
	part(c, "Belly", Vector3.new(1.0, 0.8, 0.2), CFrame.new(0, 0.95, -0.78), p.Color2)
	quadHead(c, Vector3.new(1.35, 1.15, 1.3), 1.9, -0.75)
	part(c, "Snout", Vector3.new(0.85, 0.5, 0.5), CFrame.new(0, 1.65, -1.6), p.Color)
	for _, s in { -1, 1 } do
		part(
			c,
			"Horn",
			Vector3.new(0.22, 0.6, 0.3),
			CFrame.new(s * 0.4, 2.75, -0.55) * CFrame.Angles(math.rad(-20), 0, 0),
			p.Color2,
			nil,
			"Wedge"
		)
		part(
			c,
			"Wing",
			Vector3.new(0.15, 1.1, 1.4),
			CFrame.new(s * 1.1, 1.75, 0.35) * CFrame.Angles(0, 0, s * math.rad(-35)),
			p.Color2,
			if p.Glow then Enum.Material.Neon else nil
		)
	end
	part(c, "Tail", Vector3.new(0.4, 0.4, 1.4), CFrame.new(0, 1.0, 1.65) * CFrame.Angles(math.rad(15), 0, 0), p.Color)
	part(c, "Spike", Vector3.new(0.3, 0.4, 0.4), CFrame.new(0, 1.15, 2.35), p.Color2, nil, "Wedge")
	legs(c, 0.5, -0.4, 0.8, p.Color)
	return body
end

PetModels.Extent = 3.2

function PetModels.Build(pet: Pet, origin: CFrame?): Model
	local model = Instance.new("Model")
	model.Name = pet.Name
	local o = (origin or CFrame.new()) * CFrame.new(0, -1.2, 0)
	local builder = SHAPES[pet.Shape] or SHAPES.cat
	local root = builder({ model = model, o = o, pet = pet })
	model.PrimaryPart = root
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Anchored = true
		end
	end
	if pet.Rainbow then
		model:SetAttribute("Rainbow", true)
	end
	return model
end

function PetModels.BuildById(id: string, origin: CFrame?): Model?
	local pet = Pets.ById[id]
	if not pet then
		return nil
	end
	return PetModels.Build(pet, origin)
end

return PetModels
