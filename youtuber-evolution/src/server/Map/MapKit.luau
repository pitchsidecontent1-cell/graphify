--!strict
-- Reusable map pieces: floors, film-strip curbs, banded walls, arches,
-- lamps, trees and big themed props. All take a world palette so each world
-- looks distinct while sharing one visual language.

local Shared = game:GetService("ReplicatedStorage").Shared
local PropKit = require(Shared.Models.PropKit)
local Worlds = require(Shared.Config.Worlds)
local Rng = require(Shared.Util.Rng)

type Palette = Worlds.Palette
type Rng = Rng.Rng

local MapKit = {}

local INK = Color3.fromRGB(27, 21, 48)
local WHITE = Color3.fromRGB(255, 255, 255)

function MapKit.Floor(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	studs: boolean?,
	name: string?
): BasePart
	return PropKit.Part({
		Name = name or "Floor",
		Size = size,
		CFrame = cf,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Studs = studs ~= false,
		Parent = parent,
	})
end

-- Raised curb with light "sprocket holes" on top: the film-strip border that
-- runs along every walkway. `from`/`to` are world positions at ground level.
function MapKit.FilmCurb(parent: Instance, from: Vector3, to: Vector3, palette: Palette, holeSpacing: number?)
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local mid = from + delta / 2 + Vector3.new(0, 0.6, 0)
	-- yaw-based facing (CFrame.lookAt differs under Lune)
	local cf = CFrame.new(mid) * CFrame.Angles(0, math.atan2(-delta.X, -delta.Z), 0)
	PropKit.Part({
		Name = "Curb",
		Size = Vector3.new(2.4, 1.2, length),
		CFrame = cf,
		Color = palette.Curb,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	local spacing = holeSpacing or 6
	local count = math.floor(length / spacing)
	for i = 0, count - 1 do
		local z = -length / 2 + spacing / 2 + i * spacing
		PropKit.Deco({
			Name = "Hole",
			Size = Vector3.new(1.3, 0.1, 2.4),
			CFrame = cf * CFrame.new(0, 0.62, z),
			Color = palette.CurbHole,
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		})
	end
end

-- Tall wall made of 3 colour bands with a glowing top strip.
function MapKit.BandWall(
	parent: Instance,
	cf: CFrame,
	length: number,
	height: number,
	palette: Palette,
	thickness: number?
)
	local t = thickness or 6
	local band = height / 3
	local colors = { palette.Wall1, palette.Wall2, palette.Wall1 }
	for i = 1, 3 do
		PropKit.Part({
			Name = "Wall",
			Size = Vector3.new(length, band, t),
			CFrame = cf * CFrame.new(0, band * (i - 0.5), 0),
			Color = colors[i],
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		})
	end
	PropKit.Deco({
		Name = "WallGlow",
		Size = Vector3.new(length, 1, t + 0.4),
		CFrame = cf * CFrame.new(0, height + 0.5, 0),
		Color = palette.Wall3,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	PropKit.Deco({
		Name = "WallTrim",
		Size = Vector3.new(length, 0.6, t + 0.6),
		CFrame = cf * CFrame.new(0, band, 0),
		Color = INK,
		Parent = parent,
	})
end

-- Invisible collider used to keep players on walkways.
function MapKit.Barrier(parent: Instance, cf: CFrame, size: Vector3)
	PropKit.Part({
		Name = "Boundary",
		Size = size,
		CFrame = cf,
		Transparency = 1,
		CanQuery = false,
		CastShadow = false,
		Parent = parent,
	})
end

function MapKit.Lamp(parent: Instance, cf: CFrame, palette: Palette)
	PropKit.Part({
		Name = "LampPost",
		Size = Vector3.new(1, 12, 1),
		CFrame = cf * CFrame.new(0, 6, 0),
		Color = INK,
		Parent = parent,
	})
	PropKit.Deco({
		Name = "LampBase",
		Size = Vector3.new(2.4, 1, 2.4),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = palette.Curb,
		Parent = parent,
	})
	local bulb = PropKit.Deco({
		Name = "LampBulb",
		Size = Vector3.new(2.2, 2.2, 2.2),
		CFrame = cf * CFrame.new(0, 13, 0),
		Color = palette.Glow,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	PropKit.Light(bulb, palette.Glow, 1.2, 18)
	PropKit.Deco({
		Name = "LampCap",
		Size = Vector3.new(3, 0.6, 3),
		CFrame = cf * CFrame.new(0, 14.4, 0),
		Color = INK,
		Parent = parent,
	})
end

-- Themed tree / filler prop for a world's decor style.
function MapKit.Tree(parent: Instance, cf: CFrame, decor: string, palette: Palette, rng: Rng)
	local scale = rng:Range(0.8, 1.3)
	if decor == "Park" then
		local h = 10 * scale
		PropKit.Part({
			Name = "Trunk",
			Size = Vector3.new(3 * scale, h, 3 * scale),
			CFrame = cf * CFrame.new(0, h / 2, 0),
			Color = palette.Trunk,
			Parent = parent,
		})
		local leaf = if rng:Chance(0.5) then palette.Leaf else palette.Leaf2
		PropKit.Part({
			Name = "Leaves",
			Size = Vector3.new(13, 8, 13) * scale,
			CFrame = cf * CFrame.new(0, h + 3 * scale, 0) * CFrame.Angles(0, rng:Range(0, 1.5), 0),
			Color = leaf,
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		})
		PropKit.Deco({
			Name = "LeavesTop",
			Size = Vector3.new(8.5, 5, 8.5) * scale,
			CFrame = cf * CFrame.new(0, h + 8.5 * scale, 0) * CFrame.Angles(0, rng:Range(0, 1.5), 0),
			Color = leaf:Lerp(WHITE, 0.15),
			Parent = parent,
		})
	elseif decor == "City" then
		-- neon palm / street tree
		local h = 14 * scale
		PropKit.Part({
			Name = "Trunk",
			Size = Vector3.new(1.6, h, 1.6),
			CFrame = cf * CFrame.new(0, h / 2, 0),
			Color = palette.Trunk,
			Parent = parent,
		})
		local leaf = if rng:Chance(0.5) then palette.Leaf else palette.Leaf2
		for i = 1, 4 do
			local a = i * math.pi / 2 + rng:Range(-0.2, 0.2)
			PropKit.Deco({
				Name = "Frond",
				Size = Vector3.new(1.4, 0.6, 8 * scale),
				CFrame = cf
					* CFrame.new(0, h, 0)
					* CFrame.Angles(0, a, 0)
					* CFrame.new(0, -0.6, -3.5 * scale)
					* CFrame.Angles(math.rad(-18), 0, 0),
				Color = leaf,
				Material = Enum.Material.Neon,
				Parent = parent,
			})
		end
	elseif decor == "Snow" then
		local h = 4 * scale
		PropKit.Part({
			Name = "Trunk",
			Size = Vector3.new(2.2, h, 2.2),
			CFrame = cf * CFrame.new(0, h / 2, 0),
			Color = palette.Trunk,
			Parent = parent,
		})
		for i = 0, 3 do
			local w = (11 - i * 2.4) * scale
			PropKit.Part({
				Name = "Pine",
				Size = Vector3.new(w, 3.4 * scale, w),
				CFrame = cf * CFrame.new(0, h + (1.7 + i * 3) * scale, 0) * CFrame.Angles(0, math.rad(45 * (i % 2)), 0),
				Color = palette.Leaf,
				Parent = parent,
			})
			PropKit.Deco({
				Name = "Snow",
				Size = Vector3.new(w * 0.8, 0.7, w * 0.8),
				CFrame = cf * CFrame.new(0, h + (3.5 + i * 3) * scale, 0) * CFrame.Angles(0, math.rad(45 * (i % 2)), 0),
				Color = palette.Leaf2,
				Parent = parent,
			})
		end
	else
		-- Space: glowing crystal cluster
		for i = 1, 3 do
			local h = rng:Range(6, 14) * scale
			PropKit.Part({
				Name = "Crystal",
				Size = Vector3.new(2.6, h, 2.6),
				CFrame = cf
					* CFrame.new(rng:Range(-2.5, 2.5), h / 2 - 0.5, rng:Range(-2.5, 2.5))
					* CFrame.Angles(rng:Range(-0.35, 0.35), rng:Range(0, 3), rng:Range(-0.35, 0.35)),
				Color = if i == 2 then palette.Leaf2 else palette.Leaf,
				Material = Enum.Material.Neon,
				Transparency = 0.15,
				Parent = parent,
			})
		end
	end
end

function MapKit.Rock(parent: Instance, cf: CFrame, palette: Palette, rng: Rng)
	local s = rng:Range(3, 7)
	PropKit.Part({
		Name = "Rock",
		Size = Vector3.new(s * 1.4, s, s * 1.1),
		CFrame = cf
			* CFrame.new(0, s * 0.35, 0)
			* CFrame.Angles(rng:Range(-0.3, 0.3), rng:Range(0, 3), rng:Range(-0.3, 0.3)),
		Color = palette.Rock,
		Parent = parent,
	})
end

-- Arch with a plaque, used for road start + gates.
function MapKit.Arch(
	parent: Instance,
	cf: CFrame,
	width: number,
	height: number,
	color: Color3,
	material: Enum.Material,
	palette: Palette
): BasePart
	for _, side in { -1, 1 } do
		PropKit.Part({
			Name = "Pillar",
			Size = Vector3.new(5, height, 5),
			CFrame = cf * CFrame.new(side * (width / 2 + 2.5), height / 2, 0),
			Color = color,
			Material = material,
			Parent = parent,
		})
		PropKit.Part({
			Name = "PillarBase",
			Size = Vector3.new(6.5, 2, 6.5),
			CFrame = cf * CFrame.new(side * (width / 2 + 2.5), 1, 0),
			Color = INK,
			Parent = parent,
		})
		PropKit.Deco({
			Name = "PillarCap",
			Size = Vector3.new(6.5, 2.2, 6.5),
			CFrame = cf * CFrame.new(side * (width / 2 + 2.5), height + 6.1, 0),
			Color = palette.Accent2,
			Material = Enum.Material.Neon,
			Parent = parent,
		})
	end
	local beam = PropKit.Part({
		Name = "Beam",
		Size = Vector3.new(width + 12, 5, 6),
		CFrame = cf * CFrame.new(0, height + 2.5, 0),
		Color = color,
		Material = material,
		Parent = parent,
	})
	PropKit.Deco({
		Name = "BeamTrim",
		Size = Vector3.new(width + 12.4, 0.8, 6.4),
		CFrame = cf * CFrame.new(0, height + 0.2, 0),
		Color = INK,
		Parent = parent,
	})
	return beam
end

-- Plaque panel with text on both faces.
function MapKit.Plaque(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	text: string,
	accent: Color3,
	textColor: Color3?
): BasePart
	local plaque = PropKit.Part({
		Name = "Plaque",
		Size = size,
		CFrame = cf,
		Color = INK,
		Parent = parent,
	})
	PropKit.Deco({
		Name = "PlaqueRim",
		Size = size + Vector3.new(0.8, 0.8, -0.2),
		CFrame = cf,
		Color = accent,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		PropKit.SurfaceText(plaque, face, {
			Text = text,
			Color = textColor or WHITE,
			StrokeThickness = 3,
			PixelsPerStud = 30,
		})
	end
	return plaque
end

-- Big floating label (BillboardGui) used over stations and areas.
function MapKit.FloatingLabel(
	parent: Instance,
	text: string,
	height: number,
	top: Color3,
	bottom: Color3,
	size: Vector2?
): BasePart
	local anchor = PropKit.Deco({
		Name = "LabelAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 0, 0),
		Transparency = 1,
		Parent = parent,
	})
	PropKit.Billboard(anchor, {
		Name = "Label",
		Text = text,
		Size = size or Vector2.new(20, 5),
		Offset = Vector3.new(0, height, 0),
		MaxDistance = 260,
		StrokeThickness = 5,
		Gradient = ColorSequence.new(top, bottom),
	})
	return anchor
end

-- Ring of neon segments (portals, rebirth prop, ring lights).
function MapKit.Ring(
	parent: Instance,
	cf: CFrame,
	radius: number,
	thickness: number,
	segments: number,
	color: Color3,
	material: Enum.Material?
)
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		PropKit.Deco({
			Name = "RingSeg",
			Size = Vector3.new(2 * math.pi * radius / segments + 0.3, thickness, thickness),
			CFrame = cf * CFrame.Angles(0, 0, a) * CFrame.new(0, radius, 0),
			Color = color,
			Material = material or Enum.Material.Neon,
			Parent = parent,
		})
	end
end

-- Ellipsoid (eggs, planets) using a sphere SpecialMesh.
function MapKit.Ellipsoid(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	local p = PropKit.Part({
		Name = "Ellipsoid",
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Giant decorative props that sell the "creator" theme.
function MapKit.GiantCamera(parent: Instance, cf: CFrame, palette: Palette, scale: number)
	local s = scale
	PropKit.Part({
		Name = "CamBody",
		Size = Vector3.new(16, 10, 8) * s,
		CFrame = cf * CFrame.new(0, 7 * s, 0),
		Color = INK,
		Parent = parent,
	})
	PropKit.Part({
		Name = "CamGrip",
		Size = Vector3.new(4, 10.4, 8.4) * s,
		CFrame = cf * CFrame.new(-6.5 * s, 7 * s, 0),
		Color = palette.Accent1,
		Parent = parent,
	})
	PropKit.Part({
		Name = "CamTop",
		Size = Vector3.new(6, 3, 6) * s,
		CFrame = cf * CFrame.new(2 * s, 13.5 * s, 0),
		Color = palette.Accent1,
		Parent = parent,
	})
	PropKit.Tube({
		Name = "CamLens",
		Size = Vector3.new(7, 7, 5) * s,
		CFrame = cf * CFrame.new(1.5 * s, 7 * s, -6 * s),
		Color = palette.Curb,
		Parent = parent,
	})
	PropKit.Tube({
		Name = "CamGlass",
		Size = Vector3.new(5, 5, 0.6) * s,
		CFrame = cf * CFrame.new(1.5 * s, 7 * s, -8.6 * s),
		Color = palette.Accent3,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	PropKit.Deco({
		Name = "CamRec",
		Size = Vector3.new(1.5, 1.5, 0.4) * s,
		CFrame = cf * CFrame.new(5.5 * s, 10.5 * s, -4.1 * s),
		Color = Color3.fromRGB(255, 50, 60),
		Material = Enum.Material.Neon,
		Parent = parent,
	})
end

function MapKit.GiantPhone(parent: Instance, cf: CFrame, palette: Palette, scale: number)
	local s = scale
	PropKit.Part({
		Name = "PhoneBody",
		Size = Vector3.new(11, 20, 2) * s,
		CFrame = cf * CFrame.new(0, 10.5 * s, 0),
		Color = INK,
		Parent = parent,
	})
	local screen = PropKit.Deco({
		Name = "PhoneScreen",
		Size = Vector3.new(9.6, 17.6, 0.3) * s,
		CFrame = cf * CFrame.new(0, 10.5 * s, -1.05 * s),
		Color = palette.Accent3,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	PropKit.SurfaceText(screen, Enum.NormalId.Front, { Text = "▶\n+1", PixelsPerStud = 12, StrokeThickness = 6 })
end

function MapKit.ThumbsUp(parent: Instance, cf: CFrame, palette: Palette, scale: number)
	local s = scale
	PropKit.Part({
		Name = "Fist",
		Size = Vector3.new(8, 7, 7) * s,
		CFrame = cf * CFrame.new(0, 4.5 * s, 0),
		Color = palette.Accent2,
		Parent = parent,
	})
	PropKit.Part({
		Name = "Thumb",
		Size = Vector3.new(3, 7, 3) * s,
		CFrame = cf * CFrame.new(-1.5 * s, 11 * s, 0),
		Color = palette.Accent2,
		Parent = parent,
	})
	PropKit.Part({
		Name = "Cuff",
		Size = Vector3.new(8.6, 2.5, 7.6) * s,
		CFrame = cf * CFrame.new(0, 1.25 * s, 0),
		Color = palette.Accent1,
		Parent = parent,
	})
end

function MapKit.Bell(parent: Instance, cf: CFrame, palette: Palette, scale: number)
	local s = scale
	PropKit.Part({
		Name = "BellBody",
		Size = Vector3.new(10, 9, 10) * s,
		CFrame = cf * CFrame.new(0, 7 * s, 0),
		Color = palette.Accent2,
		Parent = parent,
	})
	PropKit.Part({
		Name = "BellTop",
		Size = Vector3.new(6, 3, 6) * s,
		CFrame = cf * CFrame.new(0, 12.5 * s, 0),
		Color = palette.Accent2,
		Parent = parent,
	})
	PropKit.Part({
		Name = "BellLip",
		Size = Vector3.new(12, 1.5, 12) * s,
		CFrame = cf * CFrame.new(0, 2.5 * s, 0),
		Color = palette.Accent2,
		Parent = parent,
	})
	PropKit.Part({
		Name = "BellBall",
		Shape = "Ball",
		Size = Vector3.new(3, 3, 3) * s,
		CFrame = cf * CFrame.new(0, 1.2 * s, 0),
		Color = palette.Accent1,
		Parent = parent,
	})
end

function MapKit.CommentBubble(parent: Instance, cf: CFrame, palette: Palette, text: string)
	local bubble = PropKit.Deco({
		Name = "Bubble",
		Size = Vector3.new(14, 7, 1.2),
		CFrame = cf,
		Color = WHITE,
		Parent = parent,
	})
	PropKit.Deco({
		Name = "BubbleTail",
		Size = Vector3.new(1.2, 2.5, 2.5),
		CFrame = cf * CFrame.new(-4, -4, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = WHITE,
		Shape = "Wedge",
		Parent = parent,
	})
	PropKit.SurfaceText(
		bubble,
		Enum.NormalId.Front,
		{ Text = text, Color = INK, StrokeThickness = 0, PixelsPerStud = 20 }
	)
	PropKit.SurfaceText(
		bubble,
		Enum.NormalId.Back,
		{ Text = text, Color = INK, StrokeThickness = 0, PixelsPerStud = 20 }
	)
	PropKit.Deco({
		Name = "BubbleRim",
		Size = Vector3.new(14.8, 7.8, 1),
		CFrame = cf,
		Color = palette.Accent1,
		Parent = parent,
	})
end

function MapKit.Building(parent: Instance, cf: CFrame, palette: Palette, rng: Rng)
	local w = rng:Range(18, 30)
	local d = rng:Range(18, 30)
	local h = rng:Range(40, 110)
	PropKit.Part({
		Name = "Building",
		Size = Vector3.new(w, h, d),
		CFrame = cf * CFrame.new(0, h / 2, 0),
		Color = if rng:Chance(0.5) then palette.Wall1 else palette.Wall2,
		Parent = parent,
	})
	local floors = math.floor(h / 10)
	local glow = if rng:Chance(0.5) then palette.Accent1 else palette.Accent2
	for i = 1, floors - 1 do
		PropKit.Deco({
			Name = "Windows",
			Size = Vector3.new(w + 0.3, 1.2, d + 0.3),
			CFrame = cf * CFrame.new(0, i * 10, 0),
			Color = glow,
			Material = Enum.Material.Neon,
			Transparency = 0.1,
			Parent = parent,
		})
	end
end

function MapKit.Planet(parent: Instance, cf: CFrame, color: Color3, ring: Color3?, size: number)
	MapKit.Ellipsoid(parent, cf, Vector3.new(size, size, size), color, Enum.Material.SmoothPlastic).CanCollide = false
	if ring then
		local r = PropKit.Disc({
			Name = "PlanetRing",
			Size = Vector3.new(size * 1.9, 0.6, size * 1.9),
			CFrame = cf * CFrame.Angles(math.rad(20), 0, math.rad(12)),
			Color = ring,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
			Parent = parent,
		})
		r.CastShadow = false
	end
end

return MapKit
