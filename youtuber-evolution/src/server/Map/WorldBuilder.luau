--!strict
-- Builds one complete world around its Origin. Gameplay code never relies on
-- positions from here: everything interactive is tagged (CollectionService)
-- with attributes, so the map can be hand-edited in Studio afterwards.
--
-- Tags: WorldSpawn, GateBarrier, CloutPad, TreadmillZone, TreadmillBelt,
--       Treadmill, StationPad, EggStand, RivalSpot, RivalGate, Portal,
--       Leaderboard, TopCreatorBoard

local Shared = game:GetService("ReplicatedStorage").Shared
local PropKit = require(Shared.Models.PropKit)
local DeviceModels = require(Shared.Models.DeviceModels)
local Worlds = require(Shared.Config.Worlds)
local Devices = require(Shared.Config.Devices)
local Treadmills = require(Shared.Config.Treadmills)
local Pets = require(Shared.Config.Pets)
local Theme = require(Shared.Config.Theme)
local Rng = require(Shared.Util.Rng)
local Layout = require(script.Parent.Layout)
local MapKit = require(script.Parent.MapKit)

type World = Worlds.World
type Palette = Worlds.Palette

local WorldBuilder = {}

local INK = Color3.fromRGB(27, 21, 48)
local WHITE = Color3.fromRGB(255, 255, 255)

local GATE_STYLES = {
	{ Color = Color3.fromRGB(176, 120, 76), Material = Enum.Material.WoodPlanks }, -- 1-3 wood
	{ Color = Color3.fromRGB(205, 127, 50), Material = Enum.Material.Metal }, -- 4-6 bronze
	{ Color = Color3.fromRGB(205, 210, 222), Material = Enum.Material.Metal }, -- 7-9 silver
	{ Color = Color3.fromRGB(255, 196, 46), Material = Enum.Material.Metal }, -- 10-12 gold
	{ Color = Color3.fromRGB(150, 235, 255), Material = Enum.Material.Glass }, -- 13-15 diamond
}

local STATION_STYLE = {
	Devices = { Title = "📷 DEVICES", Color = Theme.Colors.Cyan },
	Upgrades = { Title = "⚡ UPGRADES", Color = Theme.Colors.Yellow },
	Rebirth = { Title = "🔄 REBIRTH", Color = Theme.Colors.Purple },
	Niche = { Title = "🎲 NICHE ROLL", Color = Theme.Colors.Pink },
} :: { [string]: { Title: string, Color: Color3 } }

local function setAttrs(inst: Instance, attrs: { [string]: any })
	for k, v in attrs do
		inst:SetAttribute(k, v)
	end
end

local function pad(parent: Instance, cf: CFrame, color: Color3, diameter: number): BasePart
	PropKit.Disc({
		Name = "PadBase",
		Size = Vector3.new(diameter + 2.5, 0.8, diameter + 2.5),
		CFrame = cf * CFrame.new(0, 0.4, 0),
		Color = INK,
		Parent = parent,
	})
	PropKit.Disc({
		Name = "PadRing",
		Size = Vector3.new(diameter + 1, 1, diameter + 1),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = WHITE,
		Parent = parent,
	})
	local top = PropKit.Disc({
		Name = "Pad",
		Size = Vector3.new(diameter, 1.2, diameter),
		CFrame = cf * CFrame.new(0, 0.6, 0),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	top:SetAttribute("Radius", diameter / 2)
	return top
end

-- Island + plaza ---------------------------------------------------------------------
local function buildIsland(world: World, root: Instance)
	local O = world.Origin
	local pal = world.Palette
	local half = Layout.IslandHalf
	local folder = PropKit.Folder("Island", root)

	-- checkered ground tiles
	local cells = 10
	local cell = half * 2 / cells
	for i = 0, cells - 1 do
		for j = 0, cells - 1 do
			local x = -half + cell * (i + 0.5)
			local z = -half + cell * (j + 0.5)
			MapKit.Floor(
				folder,
				CFrame.new(O + Vector3.new(x, -Layout.GroundThickness / 2, z)),
				Vector3.new(cell, Layout.GroundThickness, cell),
				if (i + j) % 2 == 0 then pal.Ground else pal.Ground2,
				true,
				"Ground"
			)
		end
	end

	-- plaza rim (film-strip curb ring), with a gap where the road leaves
	local segs = 40
	for i = 0, segs - 1 do
		local a0 = (i / segs) * math.pi * 2
		local a1 = ((i + 1) / segs) * math.pi * 2
		local mid = (a0 + a1) / 2
		local mx = math.sin(mid) * Layout.PlazaRadius
		local mz = math.cos(mid) * Layout.PlazaRadius
		local onRoad = math.abs(mx) < Layout.Road.HalfWidth + 6 and mz > 0
		for _, info in Layout.Stations do
			if math.abs(mx - info.Position.X) < 19 and math.abs(mz - info.Position.Z) < 19 then
				onRoad = true -- leave the stage edge clear
			end
		end
		if not onRoad then
			local p0 = O + Vector3.new(math.sin(a0) * Layout.PlazaRadius, 0, math.cos(a0) * Layout.PlazaRadius)
			local p1 = O + Vector3.new(math.sin(a1) * Layout.PlazaRadius, 0, math.cos(a1) * Layout.PlazaRadius)
			MapKit.FilmCurb(folder, p0, p1, pal, 5)
		end
	end

	-- perimeter walls (gap on +Z for the road)
	local wallH = 26
	local edge = half + 3
	local roadGap = Layout.Road.StripHalfWidth
	local sideLen = (half * 2 - roadGap * 2) / 2
	MapKit.BandWall(folder, CFrame.new(O + Vector3.new(0, 0, -edge)), half * 2 + 12, wallH, pal)
	MapKit.BandWall(
		folder,
		CFrame.new(O + Vector3.new(-edge, 0, 0)) * CFrame.Angles(0, math.rad(90), 0),
		half * 2 + 12,
		wallH,
		pal
	)
	MapKit.BandWall(
		folder,
		CFrame.new(O + Vector3.new(edge, 0, 0)) * CFrame.Angles(0, math.rad(90), 0),
		half * 2 + 12,
		wallH,
		pal
	)
	for _, side in { -1, 1 } do
		local cx = side * (roadGap + sideLen / 2 + 3)
		MapKit.BandWall(folder, CFrame.new(O + Vector3.new(cx, 0, edge)), sideLen + 6, wallH, pal)
	end
	-- invisible ceiling-height colliders so nobody jumps out
	for _, s in
		{
			{ Vector3.new(0, 60, -edge), Vector3.new(half * 2 + 20, 120, 6) },
			{ Vector3.new(-edge, 60, 0), Vector3.new(6, 120, half * 2 + 20) },
			{ Vector3.new(edge, 60, 0), Vector3.new(6, 120, half * 2 + 20) },
		}
	do
		MapKit.Barrier(folder, CFrame.new(O + s[1]), s[2])
	end
	for _, side in { -1, 1 } do
		MapKit.Barrier(
			folder,
			CFrame.new(O + Vector3.new(side * (roadGap + sideLen / 2 + 3), 60, edge)),
			Vector3.new(sideLen + 6, 120, 6)
		)
	end

	-- low ground far below so the road reads as a raised causeway
	if world.Decor ~= "Space" then
		local under = PropKit.Part({
			Name = "Underworld",
			Size = Vector3.new(1600, 4, 2040),
			CFrame = CFrame.new(O + Vector3.new(0, -70, 600)),
			Color = pal.Ground2:Lerp(INK, 0.25),
			CanCollide = true,
			Parent = folder,
		})
		under.CastShadow = false
	end
end

-- Regular hexagon from three overlapping boxes (our "Creator Plaque" shape).
-- `cf` faces the viewer along -Z; radius = centre-to-corner.
local function hexagon(
	parent: Instance,
	cf: CFrame,
	radius: number,
	depth: number,
	color: Color3,
	material: Enum.Material?
)
	for i = 0, 2 do
		PropKit.Part({
			Name = "Hex",
			Size = Vector3.new(radius, radius * math.sqrt(3), depth),
			CFrame = cf * CFrame.Angles(0, 0, math.rad(60 * i)),
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			Parent = parent,
		})
	end
end

-- Film-strip path: dark strip with light sprocket squares on both edges.
local function filmPath(parent: Instance, from: Vector3, to: Vector3, width: number, pal: Palette)
	local delta = to - from
	local length = delta.Magnitude
	local cf = CFrame.new(from + delta / 2 + Vector3.new(0, 0.32, 0))
		* CFrame.Angles(0, math.atan2(-delta.X, -delta.Z), 0)
	PropKit.Part({
		Name = "Path",
		Size = Vector3.new(width, 0.6, length),
		CFrame = cf,
		Color = pal.Road,
		Parent = parent,
	})
	local count = math.floor(length / 5)
	for i = 0, count - 1 do
		local z = -length / 2 + 2.5 + i * 5
		for _, side in { -1, 1 } do
			PropKit.Deco({
				Name = "Sprocket",
				Size = Vector3.new(1.2, 0.1, 2.2),
				CFrame = cf * CFrame.new(side * (width / 2 - 1.3), 0.32, z),
				Color = pal.CurbHole,
				Parent = parent,
			})
		end
	end
end

local function chevron(parent: Instance, cf: CFrame, color: Color3)
	for _, side in { -1, 1 } do
		PropKit.Deco({
			Name = "Chevron",
			Size = Vector3.new(1.6, 0.12, 7),
			CFrame = cf * CFrame.new(side * 2.3, 0, 1.6) * CFrame.Angles(0, side * math.rad(-38), 0),
			Color = color,
			Parent = parent,
		})
	end
end

local function buildPlaza(world: World, root: Instance)
	local O = world.Origin
	local pal = world.Palette
	local folder = PropKit.Folder("Plaza", root)
	local R = Layout.PlazaRadius

	local plaza = PropKit.Disc({
		Name = "Plaza",
		Size = Vector3.new(R * 2, 1, R * 2),
		CFrame = CFrame.new(O + Vector3.new(0, -0.3, 0)),
		Color = pal.Plaza,
		Parent = folder,
	})
	PropKit.Studs(plaza)
	PropKit.Disc({
		Name = "PlazaInner",
		Size = Vector3.new(92, 1, 92),
		CFrame = CFrame.new(O + Vector3.new(0, -0.2, 0)),
		Color = pal.Plaza2,
		Parent = folder,
	})

	-- film-strip paths: to the road, to each station and to the worlds portal
	filmPath(folder, O + Vector3.new(0, 0, -10), O + Vector3.new(0, 0, R + 2), 16, pal)
	for z = 0, R - 8, 13 do
		chevron(folder, CFrame.new(O + Vector3.new(0, 0.7, z)), WHITE)
	end
	for _, info in Layout.Stations do
		local target = info.Position * 0.72
		filmPath(folder, O + target * 0.25, O + target, 10, pal)
	end
	-- short path from behind the monument to the worlds portal
	filmPath(
		folder,
		O + Vector3.new(0, 0, Layout.Monument.Z - 9),
		O + Vector3.new(0, 0, Layout.WorldsPortal.Z + 18),
		10,
		pal
	)

	-- spawn disc with the +1 logo
	PropKit.Disc({
		Name = "LogoRim",
		Size = Vector3.new(30, 0.9, 30),
		CFrame = CFrame.new(O + Vector3.new(0, 0.2, Layout.Spawn.Z)),
		Color = INK,
		Parent = folder,
	})
	PropKit.Disc({
		Name = "Logo",
		Size = Vector3.new(26, 1, 26),
		CFrame = CFrame.new(O + Vector3.new(0, 0.25, Layout.Spawn.Z)),
		Color = pal.Accent1,
		Parent = folder,
	})
	local logoTop = PropKit.Deco({
		Name = "LogoText",
		Size = Vector3.new(20, 0.2, 20),
		CFrame = CFrame.new(O + Vector3.new(0, 0.8, Layout.Spawn.Z)) * CFrame.Angles(0, math.pi, 0),
		Transparency = 1,
		Parent = folder,
	})
	PropKit.SurfaceText(logoTop, Enum.NormalId.Top, { Text = "+1", PixelsPerStud = 12, StrokeThickness = 8 })

	-- giant Creator Plaque monument behind spawn
	local mcf = CFrame.new(O + Layout.Monument) * CFrame.Angles(0, math.pi, 0) -- faces +Z
	PropKit.Part({
		Name = "MonumentBase",
		Size = Vector3.new(20, 3, 12),
		CFrame = mcf * CFrame.new(0, 1.5, 0),
		Color = INK,
		Parent = folder,
	})
	PropKit.Part({
		Name = "MonumentStep",
		Size = Vector3.new(16, 2, 9),
		CFrame = mcf * CFrame.new(0, 4, 0),
		Color = pal.Plaza2,
		Parent = folder,
	})
	local plaqueCf = mcf * CFrame.new(0, 15, 0)
	hexagon(folder, plaqueCf * CFrame.new(0, 0, 0.6), 10.5, 1.6, INK)
	hexagon(folder, plaqueCf, 9.5, 2.2, pal.Accent2, Enum.Material.Metal)
	hexagon(folder, plaqueCf * CFrame.new(0, 0, -1.2), 7.6, 0.4, pal.Accent1)
	local face = PropKit.Deco({
		Name = "PlaqueFace",
		Size = Vector3.new(11, 11, 0.2),
		CFrame = plaqueCf * CFrame.new(0, 0, -1.5),
		Transparency = 1,
		Parent = folder,
	})
	PropKit.SurfaceText(face, Enum.NormalId.Front, { Text = "+1", PixelsPerStud = 16, StrokeThickness = 8 })
	MapKit.Ring(folder, plaqueCf * CFrame.new(0, 0, 1.6), 12.5, 0.9, 24, pal.Glow)
	local mlabel = MapKit.FloatingLabel(
		folder,
		"+1 YOUTUBER EVOLUTION",
		0,
		Theme.Colors.Yellow,
		Theme.Colors.Orange,
		Vector2.new(30, 6)
	)
	mlabel.CFrame = plaqueCf * CFrame.new(0, 17, 0)

	-- planters between the stations
	for i = 0, 5 do
		local a = math.rad(30 + i * 60)
		local x, z = math.sin(a) * (R - 10), math.cos(a) * (R - 10)
		if math.abs(x) > 20 then
			local cf = CFrame.new(O + Vector3.new(x, 0, z))
			PropKit.Part({
				Name = "Planter",
				Size = Vector3.new(8, 3, 8),
				CFrame = cf * CFrame.new(0, 1.5, 0),
				Color = pal.Wall1,
				Parent = folder,
			})
			PropKit.Deco({
				Name = "PlanterTrim",
				Size = Vector3.new(8.6, 0.6, 8.6),
				CFrame = cf * CFrame.new(0, 3.1, 0),
				Color = INK,
				Parent = folder,
			})
			PropKit.Part({
				Name = "Bush",
				Size = Vector3.new(6.4, 4, 6.4),
				CFrame = cf * CFrame.new(0, 5, 0),
				Color = pal.Leaf,
				Parent = folder,
			})
		end
	end
end

local function buildSpawn(world: World, root: Instance)
	local O = world.Origin
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	-- face +Z (towards the road)
	spawn.CFrame = CFrame.new(O + Layout.Spawn + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, math.pi, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = true
	spawn:AddTag("WorldSpawn")
	spawn:SetAttribute("World", world.Id)
	spawn.Parent = root
end

-- Road, gates and clout pads ------------------------------------------------------------
local function gateSideWall(parent: Instance, cf: CFrame, length: number, world: World, rng: Rng.Rng)
	local pal = world.Palette
	local decor = world.Decor
	if decor == "Park" then
		PropKit.Part({
			Name = "Hedge",
			Size = Vector3.new(length, 12, 5),
			CFrame = cf * CFrame.new(0, 6, 0),
			Color = pal.Leaf,
			Material = Enum.Material.Grass,
			Parent = parent,
		})
		PropKit.Deco({
			Name = "HedgeTop",
			Size = Vector3.new(length - 1, 1.2, 4),
			CFrame = cf * CFrame.new(0, 12.6, 0),
			Color = pal.Leaf2,
			Parent = parent,
		})
		for i = 1, 4 do
			PropKit.Deco({
				Name = "Flower",
				Shape = "Ball",
				Size = Vector3.new(1.4, 1.4, 1.4),
				CFrame = cf * CFrame.new(rng:Range(-length / 2 + 2, length / 2 - 2), rng:Range(3, 11), -2.6),
				Color = if i % 2 == 0 then pal.Accent1 else pal.Accent2,
				Parent = parent,
			})
		end
	elseif decor == "City" then
		local panel = PropKit.Part({
			Name = "Billboard",
			Size = Vector3.new(length, 14, 3),
			CFrame = cf * CFrame.new(0, 7, 0),
			Color = pal.Wall2,
			Parent = parent,
		})
		PropKit.Deco({
			Name = "Neon",
			Size = Vector3.new(length + 0.2, 0.8, 3.2),
			CFrame = cf * CFrame.new(0, 13.6, 0),
			Color = pal.Accent1,
			Material = Enum.Material.Neon,
			Parent = parent,
		})
		local ads = { "LIKE", "SUBSCRIBE", "#VIRAL", "FYP", "+1", "LIVE", "TRENDING" }
		PropKit.SurfaceText(
			panel,
			Enum.NormalId.Front,
			{ Text = rng:Pick(ads), Color = pal.Accent2, PixelsPerStud = 10, StrokeThickness = 4 }
		)
		PropKit.SurfaceText(
			panel,
			Enum.NormalId.Back,
			{ Text = rng:Pick(ads), Color = pal.Accent1, PixelsPerStud = 10, StrokeThickness = 4 }
		)
	elseif decor == "Snow" then
		PropKit.Part({
			Name = "IceWall",
			Size = Vector3.new(length, 12, 5),
			CFrame = cf * CFrame.new(0, 6, 0),
			Color = pal.Wall1,
			Material = Enum.Material.Ice,
			Parent = parent,
		})
		PropKit.Deco({
			Name = "SnowCap",
			Size = Vector3.new(length + 0.4, 1.6, 5.6),
			CFrame = cf * CFrame.new(0, 12.6, 0),
			Color = WHITE,
			Material = Enum.Material.Snow,
			Parent = parent,
		})
	else
		PropKit.Part({
			Name = "CrystalWall",
			Size = Vector3.new(length, 13, 4),
			CFrame = cf * CFrame.new(0, 6.5, 0),
			Color = pal.Leaf,
			Material = Enum.Material.Glass,
			Transparency = 0.25,
			Parent = parent,
		})
		PropKit.Deco({
			Name = "CrystalGlow",
			Size = Vector3.new(length + 0.2, 0.8, 4.2),
			CFrame = cf * CFrame.new(0, 13.2, 0),
			Color = pal.Leaf2,
			Material = Enum.Material.Neon,
			Parent = parent,
		})
	end
end

local function buildCloutPad(world: World, gate: number, cf: CFrame, parent: Instance)
	local model = PropKit.Model("CloutPad" .. gate, parent)
	local top = pad(model, cf, Theme.Colors.Gold, 11)
	top:AddTag("CloutPad")
	setAttrs(top, { World = world.Id, Gate = gate })
	PropKit.Light(top, Theme.Colors.Gold, 1.5, 16)
	PropKit.Sparkles(top, Theme.Colors.Gold, 5, 0.7)
	-- little arrow sign so the pad reads from the road
	local sign = PropKit.Deco({
		Name = "PadSign",
		Size = Vector3.new(1, 1, 1),
		CFrame = cf * CFrame.new(0, 2, 0),
		Transparency = 1,
		Parent = model,
	})
	local bb = Instance.new("BillboardGui")
	bb.Name = "PadLabel"
	bb.Size = UDim2.new(12, 0, 4.4, 0)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	bb.Parent = sign
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.55)
	title.Text = "💰 CLAIM CLOUT"
	title.TextScaled = true
	title.TextColor3 = Theme.Colors.Gold
	title.FontFace = Theme.Fonts.Display
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = INK
	stroke.Parent = title
	title.Parent = bb
	local amount = Instance.new("TextLabel")
	amount.Name = "Amount"
	amount.BackgroundTransparency = 1
	amount.Position = UDim2.fromScale(0, 0.55)
	amount.Size = UDim2.fromScale(1, 0.45)
	amount.Text = "+" .. tostring(gate)
	amount.TextScaled = true
	amount.TextColor3 = WHITE
	amount.FontFace = Theme.Fonts.Display
	local stroke2 = Instance.new("UIStroke")
	stroke2.Thickness = 3
	stroke2.Color = INK
	stroke2.Parent = amount
	amount.Parent = bb
	setAttrs(sign, { World = world.Id, Gate = gate })
	sign:AddTag("CloutPadLabel")
end

local function buildRoad(world: World, root: Instance, rng: Rng.Rng)
	local O = world.Origin
	local pal = world.Palette
	local R = Layout.Road
	local folder = PropKit.Folder("Road", root)
	local half = Layout.IslandHalf

	-- side strip platform beyond the island
	local stripLen = R.EndZ - half
	local strip = MapKit.Floor(
		folder,
		CFrame.new(O + Vector3.new(0, -Layout.GroundThickness / 2, half + stripLen / 2)),
		Vector3.new(R.StripHalfWidth * 2, Layout.GroundThickness, stripLen),
		pal.Ground,
		true,
		"SideStrip"
	)
	strip.Name = "SideStrip"
	-- road surface
	local roadStart = Layout.PlazaRadius - 4
	local roadLen = R.EndZ - roadStart
	MapKit.Floor(
		folder,
		CFrame.new(O + Vector3.new(0, 0.1, roadStart + roadLen / 2)),
		Vector3.new(R.HalfWidth * 2, 1, roadLen),
		pal.Road,
		false,
		"Road"
	)
	-- timeline progress strip down the middle
	PropKit.Deco({
		Name = "Timeline",
		Size = Vector3.new(2.2, 0.2, roadLen),
		CFrame = CFrame.new(O + Vector3.new(0, 0.65, roadStart + roadLen / 2)),
		Color = pal.RoadStrip,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	-- edge lines
	for _, side in { -1, 1 } do
		PropKit.Deco({
			Name = "EdgeLine",
			Size = Vector3.new(0.6, 0.2, roadLen),
			CFrame = CFrame.new(O + Vector3.new(side * (R.HalfWidth - 1.8), 0.65, roadStart + roadLen / 2)),
			Color = WHITE,
			Transparency = 0.3,
			Parent = folder,
		})
		MapKit.FilmCurb(
			folder,
			O + Vector3.new(side * (R.HalfWidth + 1.2), 0, roadStart + 6),
			O + Vector3.new(side * (R.HalfWidth + 1.2), 0, R.EndZ),
			pal,
			6
		)
	end

	-- strip boundaries (low wall + invisible high wall)
	for _, side in { -1, 1 } do
		local x = side * (R.StripHalfWidth + 2)
		PropKit.Part({
			Name = "StripWall",
			Size = Vector3.new(4, 7, stripLen),
			CFrame = CFrame.new(O + Vector3.new(x, 3.5, half + stripLen / 2)),
			Color = pal.Wall1,
			Parent = folder,
		})
		PropKit.Deco({
			Name = "StripWallTop",
			Size = Vector3.new(4.4, 1, stripLen),
			CFrame = CFrame.new(O + Vector3.new(x, 7.5, half + stripLen / 2)),
			Color = pal.Wall3,
			Material = Enum.Material.Neon,
			Parent = folder,
		})
		MapKit.Barrier(folder, CFrame.new(O + Vector3.new(x, 60, half + stripLen / 2)), Vector3.new(4, 120, stripLen))
	end

	-- start arch with the game logo
	local startCf = CFrame.new(O + Vector3.new(0, 0, R.StartZ))
	MapKit.Arch(folder, startCf, R.HalfWidth * 2, 22, pal.Accent1, Enum.Material.SmoothPlastic, pal)
	MapKit.Plaque(
		folder,
		startCf * CFrame.new(0, 31, 0),
		Vector3.new(44, 8, 2),
		"+1 YOUTUBER EVOLUTION",
		pal.Accent2,
		Theme.Colors.Yellow
	)
	MapKit.Plaque(
		folder,
		startCf * CFrame.new(0, 24.5, 0),
		Vector3.new(30, 4, 6.6),
		"▶ " .. string.upper(world.Name),
		pal.Accent3
	)

	-- gates
	for k, video in world.Gates do
		local z = Layout.GateZ(k)
		local cf = CFrame.new(O + Vector3.new(0, 0, z))
		local gateModel = PropKit.Model("Gate" .. k, folder)
		local style = GATE_STYLES[math.clamp(math.ceil(k / 3), 1, #GATE_STYLES)]
		MapKit.Arch(gateModel, cf, R.HalfWidth * 2, 22, style.Color, style.Material, pal)
		MapKit.Plaque(
			gateModel,
			cf * CFrame.new(0, 24.5, 0),
			Vector3.new(22, 6, 6.8),
			"▶ VIDEO " .. tostring(video),
			style.Color
		)

		local barrier = PropKit.Part({
			Name = "Barrier",
			Size = Vector3.new(R.HalfWidth * 2, 22, 1.2),
			CFrame = cf * CFrame.new(0, 11, 0),
			Color = pal.Accent1,
			Material = Enum.Material.ForceField,
			CastShadow = false,
			Parent = gateModel,
		})
		barrier:AddTag("GateBarrier")
		setAttrs(barrier, { World = world.Id, Gate = k, Video = video })
		local reqGui = PropKit.SurfaceText(barrier, Enum.NormalId.Front, {
			Name = "Req",
			Text = "🔒 VIDEO " .. tostring(video),
			PixelsPerStud = 8,
			StrokeThickness = 5,
		})
		reqGui.Brightness = 2
		local reqText = reqGui:FindFirstChild("Text") :: TextLabel
		reqText.Size = UDim2.fromScale(1, 0.3)
		reqText.Position = UDim2.fromScale(0, 0.35)

		-- side walls from the pillars to the strip edge
		local wallLen = R.StripHalfWidth - R.HalfWidth - 5
		for _, side in { -1, 1 } do
			local wx = side * (R.HalfWidth + 5 + wallLen / 2)
			gateSideWall(gateModel, cf * CFrame.new(wx, 0, 0), wallLen, world, rng)
		end
		-- chapter stripe across the road
		PropKit.Deco({
			Name = "Chapter",
			Size = Vector3.new(R.HalfWidth * 2, 0.24, 1.6),
			CFrame = cf * CFrame.new(0, 0.66, -4),
			Color = pal.RoadStrip,
			Material = Enum.Material.Neon,
			Parent = gateModel,
		})
		buildCloutPad(world, k, cf * CFrame.new(R.PadOffsetX, 0, R.PadOffsetZ), gateModel)

		-- lamps + trees between gates
		if k % 2 == 1 then
			MapKit.Lamp(folder, CFrame.new(O + Vector3.new(-R.HalfWidth - 6, 0, z + 25)), pal)
		end
		MapKit.Tree(
			folder,
			CFrame.new(O + Vector3.new(-R.StripHalfWidth + 9, 0, z + rng:Range(15, 35))),
			world.Decor,
			pal,
			rng
		)
		MapKit.Tree(folder, CFrame.new(O + Vector3.new(R.StripHalfWidth - 7, 0, z + 34)), world.Decor, pal, rng)
	end

	-- floating comment bubbles along the road
	local comments = {
		"first!",
		"W video",
		"+1 sub 🔥",
		"who's here in 2026?",
		"LETS GOOO",
		"ratio",
		"underrated",
		"🔥🔥🔥",
		"notification squad",
		"pin me pls",
	}
	for i = 1, 8 do
		local z = R.FirstGateZ + (i - 0.5) * (R.EndZ - R.FirstGateZ) / 8
		local side = if i % 2 == 0 then 1 else -1
		MapKit.CommentBubble(
			folder,
			CFrame.new(O + Vector3.new(side * (R.StripHalfWidth + 22), 26 + rng:Range(-4, 6), z))
				* CFrame.Angles(0, side * math.rad(-70), 0),
			pal,
			comments[(i + world.Id) % #comments + 1]
		)
	end
end

-- Rival arena + portal ---------------------------------------------------------------------
local function buildArena(world: World, root: Instance)
	local O = world.Origin
	local pal = world.Palette
	local A = Layout.Arena
	local folder = PropKit.Folder("Arena", root)
	local len = A.EndZ - A.StartZ
	local floor = MapKit.Floor(
		folder,
		CFrame.new(O + Vector3.new(0, -Layout.GroundThickness / 2, A.StartZ + len / 2)),
		Vector3.new(A.HalfWidth * 2, Layout.GroundThickness, len),
		pal.Plaza,
		true,
		"ArenaFloor"
	)
	floor.Name = "ArenaFloor"
	PropKit.Disc({
		Name = "ArenaCircle",
		Size = Vector3.new(80, 0.4, 80),
		CFrame = CFrame.new(O + Vector3.new(0, 0.1, A.RivalZ - 12)),
		Color = pal.Plaza2,
		Parent = folder,
	})
	-- walls
	MapKit.BandWall(
		folder,
		CFrame.new(O + Vector3.new(-A.HalfWidth - 3, 0, A.StartZ + len / 2)) * CFrame.Angles(0, math.rad(90), 0),
		len,
		30,
		pal
	)
	MapKit.BandWall(
		folder,
		CFrame.new(O + Vector3.new(A.HalfWidth + 3, 0, A.StartZ + len / 2)) * CFrame.Angles(0, math.rad(90), 0),
		len,
		30,
		pal
	)
	MapKit.BandWall(folder, CFrame.new(O + Vector3.new(0, 0, A.EndZ + 3)), A.HalfWidth * 2 + 12, 30, pal)
	MapKit.Barrier(
		folder,
		CFrame.new(O + Vector3.new(-A.HalfWidth - 3, 70, A.StartZ + len / 2)),
		Vector3.new(6, 140, len)
	)
	MapKit.Barrier(
		folder,
		CFrame.new(O + Vector3.new(A.HalfWidth + 3, 70, A.StartZ + len / 2)),
		Vector3.new(6, 140, len)
	)
	MapKit.Barrier(folder, CFrame.new(O + Vector3.new(0, 70, A.EndZ + 3)), Vector3.new(A.HalfWidth * 2 + 12, 140, 6))
	-- the strip walls stop at the arena start; close the gaps beside the road
	for _, side in { -1, 1 } do
		local w = A.HalfWidth - Layout.Road.StripHalfWidth
		local cx = side * (Layout.Road.StripHalfWidth + w / 2)
		MapKit.BandWall(folder, CFrame.new(O + Vector3.new(cx, 0, A.StartZ - 3)), w, 30, pal)
		MapKit.Barrier(folder, CFrame.new(O + Vector3.new(cx, 70, A.StartZ - 3)), Vector3.new(w, 140, 6))
	end

	-- podium + rival spot
	PropKit.Disc({
		Name = "Podium",
		Size = Vector3.new(16, 3, 16),
		CFrame = CFrame.new(O + Vector3.new(0, 1.5, A.RivalZ)),
		Color = pal.Accent1,
		Parent = folder,
	})
	PropKit.Disc({
		Name = "PodiumRim",
		Size = Vector3.new(18, 2.4, 18),
		CFrame = CFrame.new(O + Vector3.new(0, 1.2, A.RivalZ)),
		Color = INK,
		Parent = folder,
	})
	local spot = PropKit.Part({
		Name = "RivalSpot",
		Size = Vector3.new(2, 1, 2),
		-- the rival faces the player (towards -Z)
		CFrame = CFrame.new(O + Vector3.new(0, 3.5, A.RivalZ)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = folder,
	})
	spot:AddTag("RivalSpot")
	spot:SetAttribute("World", world.Id)

	-- boss-stage dressing: neon floor ring, crowd bleachers, light towers
	MapKit.Ring(
		folder,
		CFrame.new(O + Vector3.new(0, 0.35, A.RivalZ)) * CFrame.Angles(math.rad(90), 0, 0),
		13,
		0.6,
		28,
		pal.Accent2
	)
	local crowdRng = Rng.new(world.Id * 31 + 5)
	local crowdColors = { pal.Accent1, pal.Accent2, pal.Accent3, WHITE, pal.Wall3 }
	local benchStart = A.StartZ + 18
	local benchLen = A.MonitorZ - 14 - benchStart
	for _, side in { -1, 1 } do
		for step = 0, 2 do
			local x = side * (A.HalfWidth - 6 - step * 7)
			local h = 2 + step * 2.2
			PropKit.Part({
				Name = "Bleacher",
				Size = Vector3.new(8, h, benchLen),
				CFrame = CFrame.new(O + Vector3.new(x, h / 2, benchStart + benchLen / 2)),
				Color = if step % 2 == 0 then pal.Wall2 else pal.Wall1,
				Parent = folder,
			})
		end
		for i = 1, 26 do
			local step = crowdRng:Int(0, 2)
			local x = side * (A.HalfWidth - 6 - step * 7) + crowdRng:Range(-2.5, 2.5)
			local z = benchStart + crowdRng:Range(3, benchLen - 3)
			local y = 2 + step * 2.2
			local color = crowdRng:Pick(crowdColors)
			PropKit.Deco({
				Name = "Fan",
				Size = Vector3.new(1.8, 2.4, 1.4),
				CFrame = CFrame.new(O + Vector3.new(x, y + 1.2, z)),
				Color = color,
				Parent = folder,
			})
			PropKit.Deco({
				Name = "FanHead",
				Size = Vector3.new(1.4, 1.4, 1.4),
				CFrame = CFrame.new(O + Vector3.new(x, y + 3.1, z)),
				Color = Color3.fromRGB(255, 214, 170),
				Parent = folder,
			})
			if i % 4 == 0 then
				-- a fan holding up a glowing phone
				PropKit.Deco({
					Name = "FanPhone",
					Size = Vector3.new(0.6, 1, 0.15),
					CFrame = CFrame.new(O + Vector3.new(x - side * 0.6, y + 4.4, z)),
					Color = pal.Glow,
					Material = Enum.Material.Neon,
					Parent = folder,
				})
			end
		end
		for _, z in { A.StartZ + 14, A.MonitorZ - 10 } do
			local base = CFrame.new(O + Vector3.new(side * (A.HalfWidth - 4), 0, z))
			PropKit.Part({
				Name = "LightTower",
				Size = Vector3.new(2, 34, 2),
				CFrame = base * CFrame.new(0, 17, 0),
				Color = INK,
				Parent = folder,
			})
			local head = PropKit.Deco({
				Name = "LightHead",
				Size = Vector3.new(5, 3, 3),
				CFrame = base * CFrame.new(-side * 1.5, 34, 0),
				Color = pal.Glow,
				Material = Enum.Material.Neon,
				Parent = folder,
			})
			local sl = Instance.new("SpotLight")
			sl.Color = pal.Glow
			sl.Brightness = 3
			sl.Range = 60
			sl.Angle = 45
			sl.Face = Enum.NormalId.Bottom
			sl.Parent = head
		end
	end

	local challenge = pad(folder, CFrame.new(O + Vector3.new(0, 0, A.ChallengeZ)), Theme.Colors.Red, 12)
	challenge:AddTag("StationPad")
	setAttrs(challenge, { Station = "Rival", World = world.Id })
	local labelAnchor = MapKit.FloatingLabel(
		folder,
		"⚔️ VIEW WAR ⚔️",
		9,
		Theme.Colors.Yellow,
		Theme.Colors.Orange,
		Vector2.new(22, 5)
	)
	labelAnchor.CFrame = CFrame.new(O + Vector3.new(0, 1, A.ChallengeZ))

	-- giant monitor that blocks the way until you beat the rival
	local mz = A.MonitorZ
	local mw, mh = 60, 30
	local frameColor = INK
	PropKit.Part({
		Name = "MonitorTop",
		Size = Vector3.new(mw + 8, 4, 5),
		CFrame = CFrame.new(O + Vector3.new(0, mh + 2, mz)),
		Color = frameColor,
		Parent = folder,
	})
	for _, side in { -1, 1 } do
		PropKit.Part({
			Name = "MonitorSide",
			Size = Vector3.new(4, mh + 4, 5),
			CFrame = CFrame.new(O + Vector3.new(side * (mw / 2 + 2), (mh + 4) / 2, mz)),
			Color = frameColor,
			Parent = folder,
		})
		local wallLen = A.HalfWidth - mw / 2 - 4
		MapKit.BandWall(
			folder,
			CFrame.new(O + Vector3.new(side * (mw / 2 + 4 + wallLen / 2), 0, mz)),
			wallLen,
			mh + 4,
			pal,
			5
		)
		MapKit.Barrier(
			folder,
			CFrame.new(O + Vector3.new(side * (mw / 2 + 4 + wallLen / 2), 70, mz)),
			Vector3.new(wallLen, 140, 5)
		)
	end
	PropKit.Deco({
		Name = "MonitorGlow",
		Size = Vector3.new(mw + 8.4, 1, 5.4),
		CFrame = CFrame.new(O + Vector3.new(0, mh + 4.5, mz)),
		Color = pal.Accent1,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	local screen = PropKit.Part({
		Name = "Screen",
		Size = Vector3.new(mw, mh, 1.5),
		CFrame = CFrame.new(O + Vector3.new(0, mh / 2, mz)),
		Color = Color3.fromRGB(16, 12, 30),
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})
	screen:AddTag("RivalGate")
	screen:SetAttribute("World", world.Id)
	local rival = world.Rival
	local gui = Instance.new("SurfaceGui")
	gui.Name = "RivalScreen"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 16
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Parent = screen
	local function line(name: string, text: string, y: number, h: number, color: Color3)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.05, y)
		l.Size = UDim2.fromScale(0.9, h)
		l.Text = text
		l.TextScaled = true
		l.TextColor3 = color
		l.FontFace = Theme.Fonts.Display
		local s = Instance.new("UIStroke")
		s.Thickness = 5
		s.Color = INK
		s.Parent = l
		l.Parent = gui
	end
	line("Live", "● LIVE", 0.04, 0.12, Theme.Colors.Red)
	line("Face", rival.Emoji, 0.16, 0.36, WHITE)
	line("Name", string.upper(rival.Name), 0.53, 0.17, Theme.Colors.Yellow)
	line("Title", rival.Title, 0.71, 0.1, WHITE)
	line("Hint", "BEAT ME IN A VIEW WAR TO PASS", 0.84, 0.09, Theme.Colors.Cyan)

	-- portal / trophy behind the monitor
	local pz = A.PortalZ
	if world.Id < #Worlds then
		local nextWorld = Worlds[world.Id + 1]
		local ringCf = CFrame.new(O + Vector3.new(0, 12, pz))
		MapKit.Ring(folder, ringCf, 10, 2, 20, nextWorld.Palette.Accent1)
		local swirl = PropKit.Part({
			Name = "PortalSwirl",
			Size = Vector3.new(18, 18, 0.6),
			CFrame = ringCf,
			Color = nextWorld.Palette.Accent3,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
			Parent = folder,
		})
		local swirlPart = swirl :: Part
		swirlPart.Shape = Enum.PartType.Cylinder
		swirl.Size = Vector3.new(0.6, 18, 18)
		swirl.CFrame = ringCf * CFrame.Angles(0, math.rad(90), 0)
		swirl:AddTag("Portal")
		setAttrs(swirl, { World = world.Id, Target = world.Id + 1 })
		local anchor = MapKit.FloatingLabel(
			folder,
			"WORLD " .. (world.Id + 1) .. ": " .. string.upper(nextWorld.Name) .. " ▶",
			12,
			WHITE,
			nextWorld.Palette.Accent2,
			Vector2.new(26, 4)
		)
		anchor.CFrame = ringCf * CFrame.new(0, 2, 0)
	else
		-- final world: champion trophy
		local base = CFrame.new(O + Vector3.new(0, 0, pz))
		PropKit.Part({
			Name = "TrophyBase",
			Size = Vector3.new(10, 4, 10),
			CFrame = base * CFrame.new(0, 2, 0),
			Color = INK,
			Parent = folder,
		})
		PropKit.Part({
			Name = "TrophyStem",
			Size = Vector3.new(2.5, 8, 2.5),
			CFrame = base * CFrame.new(0, 8, 0),
			Color = Theme.Colors.Gold,
			Material = Enum.Material.Metal,
			Parent = folder,
		})
		PropKit.Part({
			Name = "TrophyCup",
			Size = Vector3.new(9, 8, 9),
			CFrame = base * CFrame.new(0, 15, 0),
			Color = Theme.Colors.Gold,
			Material = Enum.Material.Metal,
			Parent = folder,
		})
		local anchor = MapKit.FloatingLabel(
			folder,
			"👑 ALGORITHM BEATEN 👑",
			24,
			Theme.Colors.Yellow,
			Theme.Colors.Orange,
			Vector2.new(24, 5)
		)
		anchor.CFrame = base
	end
end

-- Treadmills ---------------------------------------------------------------------------------
local function buildTreadmills(world: World, root: Instance)
	local O = world.Origin
	local pal = world.Palette
	local T = Layout.Treadmills
	local folder = PropKit.Folder("Treadmills", root)
	-- gym platform
	local gymMinX = -Layout.IslandHalf
	local gymMaxX = -102
	local gymW = gymMaxX - gymMinX
	local gym = MapKit.Floor(
		folder,
		CFrame.new(O + Vector3.new((gymMinX + gymMaxX) / 2, 0.25, 0)),
		Vector3.new(gymW, 1, 214),
		pal.Plaza2,
		true,
		"Gym"
	)
	gym.Name = "Gym"
	MapKit.FilmCurb(folder, O + Vector3.new(gymMaxX, 0.5, -107), O + Vector3.new(gymMaxX, 0.5, 107), pal, 6)
	local label = MapKit.FloatingLabel(folder, "🏃 AFK TREADMILLS", 20, WHITE, pal.Accent3, Vector2.new(24, 5))
	label.CFrame = CFrame.new(O + Vector3.new(-104, 0, 0))

	for i, t in Treadmills do
		local z = T.FirstZ + (i - 1) * T.Spacing
		-- player runs towards -X, so the treadmill's local -Z points to -X
		local base = CFrame.new(O + Vector3.new(T.X, 0.75, z)) * CFrame.Angles(0, math.rad(90), 0)
		local model = PropKit.Model("Treadmill_" .. t.Id, folder)
		model:AddTag("Treadmill")
		setAttrs(model, { World = world.Id, Tier = i })
		PropKit.Part({
			Name = "Base",
			Size = Vector3.new(14, 1.4, 26),
			CFrame = base * CFrame.new(0, 0.7, 0),
			Color = t.Color,
			Parent = model,
		})
		local belt = PropKit.Part({
			Name = "Belt",
			Size = Vector3.new(10, 0.3, 22),
			CFrame = base * CFrame.new(0, 1.55, 0),
			Color = Color3.fromRGB(34, 30, 46),
			Parent = model,
		})
		belt:AddTag("TreadmillBelt")
		setAttrs(belt, { Stripe = t.Stripe })
		for _, side in { -1, 1 } do
			PropKit.Part({
				Name = "Rail",
				Size = Vector3.new(1.4, 1.2, 24),
				CFrame = base * CFrame.new(side * 5.7, 2, 0),
				Color = t.Stripe,
				Parent = model,
			})
			PropKit.Part({
				Name = "Post",
				Size = Vector3.new(0.9, 6.5, 0.9),
				CFrame = base * CFrame.new(side * 5.2, 4.6, -11.6),
				Color = INK,
				Parent = model,
			})
			PropKit.Deco({
				Name = "Handle",
				Size = Vector3.new(0.7, 0.7, 6),
				CFrame = base * CFrame.new(side * 5.2, 6.2, -9),
				Color = INK,
				Parent = model,
			})
		end
		local console = PropKit.Part({
			Name = "Console",
			Size = Vector3.new(11, 3.6, 1.2),
			CFrame = base * CFrame.new(0, 8.4, -11.8) * CFrame.Angles(math.rad(-20), 0, 0),
			Color = t.Color,
			Parent = model,
		})
		PropKit.SurfaceText(
			console,
			Enum.NormalId.Back,
			{ Text = "x" .. tostring(t.Mult), PixelsPerStud = 20, StrokeThickness = 4 }
		)
		-- floating sign (Req label gets personalised on the client)
		local anchor = PropKit.Deco({
			Name = "SignAnchor",
			Size = Vector3.new(1, 1, 1),
			CFrame = base * CFrame.new(0, 10, 0),
			Transparency = 1,
			Parent = model,
		})
		local bb = Instance.new("BillboardGui")
		bb.Name = "TreadmillSign"
		bb.Size = UDim2.new(11, 0, 4.4, 0)
		bb.StudsOffset = Vector3.new(0, 5, 0)
		bb.MaxDistance = 160
		bb.LightInfluence = 0
		bb.Parent = anchor
		local multLabel = Instance.new("TextLabel")
		multLabel.Name = "Mult"
		multLabel.BackgroundTransparency = 1
		multLabel.Size = UDim2.fromScale(1, 0.6)
		multLabel.Text = "x" .. tostring(t.Mult) .. " VIEWS"
		multLabel.TextScaled = true
		multLabel.TextColor3 = t.Color:Lerp(WHITE, 0.25)
		multLabel.FontFace = Theme.Fonts.Display
		local s1 = Instance.new("UIStroke")
		s1.Thickness = 4
		s1.Color = INK
		s1.Parent = multLabel
		multLabel.Parent = bb
		local reqLabel = Instance.new("TextLabel")
		reqLabel.Name = "Req"
		reqLabel.BackgroundTransparency = 1
		reqLabel.Position = UDim2.fromScale(0, 0.6)
		reqLabel.Size = UDim2.fromScale(1, 0.4)
		reqLabel.Text = if t.Pass
			then "REQUIRES GAMEPASS"
			elseif t.Rebirths > 0 then t.Rebirths .. " REBIRTHS"
			else "FREE"
		reqLabel.TextScaled = true
		reqLabel.TextColor3 = WHITE
		reqLabel.FontFace = Theme.Fonts.Display
		local s2 = Instance.new("UIStroke")
		s2.Thickness = 3
		s2.Color = INK
		s2.Parent = reqLabel
		reqLabel.Parent = bb

		local zone = PropKit.Part({
			Name = "Zone",
			Size = Vector3.new(10, 8, 22),
			CFrame = base * CFrame.new(0, 5.5, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = model,
		})
		zone:AddTag("TreadmillZone")
		setAttrs(zone, { World = world.Id, Tier = i })
	end
end

-- Stations (shops) ---------------------------------------------------------------------------
local function stationProp(kind: string, model: Model, cf: CFrame, world: World, color: Color3)
	local pal = world.Palette
	if kind == "Devices" then
		local list = Devices.ByWorld[world.Id]
		local picks = { list[1], list[11], list[21] }
		for i, d in picks do
			local x = (i - 2) * 8
			PropKit.Disc({
				Name = "Pedestal",
				Size = Vector3.new(5, 5, 5),
				CFrame = cf * CFrame.new(x, 4, 2),
				Color = INK,
				Parent = model,
			})
			PropKit.Disc({
				Name = "PedestalTop",
				Size = Vector3.new(5.6, 0.6, 5.6),
				CFrame = cf * CFrame.new(x, 6.8, 2),
				Color = Theme.Rarities[d.Rarity].Color,
				Material = Enum.Material.Neon,
				Parent = model,
			})
			-- lens faces the plaza (station local -Z), angled slightly outwards
			local dm = DeviceModels.Build(d, cf * CFrame.new(x, 9.2, 2) * CFrame.Angles(0, math.rad(-(i - 2) * 20), 0))
			dm.Parent = model
		end
	elseif kind == "Upgrades" then
		-- giant lightning bolt
		local bolt = { { 0, 13, 0, 25 }, { -1.5, 9, 0, -30 }, { 0.5, 5, 0, 25 } }
		for _, b in bolt do
			PropKit.Part({
				Name = "Bolt",
				Size = Vector3.new(2.5, 6, 2.5),
				CFrame = cf * CFrame.new(b[1], b[2], 3) * CFrame.Angles(0, 0, math.rad(b[4])),
				Color = color,
				Material = Enum.Material.Neon,
				Parent = model,
			})
		end
		PropKit.Part({
			Name = "Anvil",
			Size = Vector3.new(10, 3, 5),
			CFrame = cf * CFrame.new(0, 2.9, -2),
			Color = INK,
			Parent = model,
		})
		PropKit.Part({
			Name = "AnvilTop",
			Size = Vector3.new(13, 1.4, 5),
			CFrame = cf * CFrame.new(0, 5.1, -2),
			Color = pal.Rock,
			Material = Enum.Material.Metal,
			Parent = model,
		})
	elseif kind == "Rebirth" then
		local ringCf = cf * CFrame.new(0, 10, 3)
		MapKit.Ring(model, ringCf, 6.5, 1.6, 16, color)
		local swirl = PropKit.Part({
			Name = "Swirl",
			Size = Vector3.new(0.4, 12, 12),
			CFrame = ringCf * CFrame.Angles(0, math.rad(90), 0),
			Color = color:Lerp(WHITE, 0.3),
			Material = Enum.Material.Neon,
			Transparency = 0.45,
			CanCollide = false,
			Parent = model,
		})
		local swirlPart = swirl :: Part
		swirlPart.Shape = Enum.PartType.Cylinder
		PropKit.SurfaceText(swirl, Enum.NormalId.Right, { Text = "🔄", PixelsPerStud = 12, StrokeThickness = 0 })
	elseif kind == "Niche" then
		local dice = PropKit.Part({
			Name = "Dice",
			Size = Vector3.new(8, 8, 8),
			CFrame = cf * CFrame.new(0, 7, 2) * CFrame.Angles(math.rad(20), math.rad(35), math.rad(10)),
			Color = WHITE,
			Parent = model,
		})
		for _, face in
			{ Enum.NormalId.Front, Enum.NormalId.Top, Enum.NormalId.Right, Enum.NormalId.Left, Enum.NormalId.Back }
		do
			PropKit.SurfaceText(dice, face, { Text = "⚃", Color = color, PixelsPerStud = 12, StrokeThickness = 0 })
		end
	end
end

local function buildStations(world: World, root: Instance)
	local O = world.Origin
	local pal = world.Palette
	local folder = PropKit.Folder("Stations", root)
	for kind, info in Layout.Stations do
		local style = STATION_STYLE[kind]
		local cf = Layout.At(O, info.Position, Vector3.new(0, 0, 0))
		local model = PropKit.Model("Station_" .. kind, folder)
		model:AddTag("Station")
		model:SetAttribute("Station", kind)
		local plat = PropKit.Part({
			Name = "Stage",
			Size = Vector3.new(30, 1.6, 20),
			CFrame = cf * CFrame.new(0, 0.8, 2),
			Color = pal.Plaza2,
			Parent = model,
		})
		PropKit.Studs(plat)
		PropKit.Deco({
			Name = "StageTrim",
			Size = Vector3.new(30.6, 0.6, 20.6),
			CFrame = cf * CFrame.new(0, 1.4, 2),
			Color = INK,
			Parent = model,
		})
		PropKit.Part({
			Name = "Backdrop",
			Size = Vector3.new(30, 18, 2),
			CFrame = cf * CFrame.new(0, 10, 12),
			Color = style.Color:Lerp(INK, 0.15),
			Parent = model,
		})
		PropKit.Deco({
			Name = "BackdropGlow",
			Size = Vector3.new(30.4, 1, 2.4),
			CFrame = cf * CFrame.new(0, 19.4, 12),
			Color = style.Color,
			Material = Enum.Material.Neon,
			Parent = model,
		})
		for _, side in { -1, 1 } do
			PropKit.Part({
				Name = "Truss",
				Size = Vector3.new(1.4, 20, 1.4),
				CFrame = cf * CFrame.new(side * 14.5, 10, 12),
				Color = INK,
				Parent = model,
			})
			local spot = PropKit.Deco({
				Name = "Spotlight",
				Size = Vector3.new(2, 2, 2),
				CFrame = cf * CFrame.new(side * 12, 19, 9),
				Color = style.Color,
				Material = Enum.Material.Neon,
				Parent = model,
			})
			local sl = Instance.new("SpotLight")
			sl.Color = style.Color
			sl.Brightness = 2
			sl.Range = 24
			sl.Angle = 50
			sl.Face = Enum.NormalId.Bottom
			sl.Parent = spot
		end
		stationProp(kind, model, cf * CFrame.new(0, 1.6, 0), world, style.Color)
		local padTop = pad(model, cf * CFrame.new(0, 0, -15), style.Color, 10)
		padTop:AddTag("StationPad")
		padTop:SetAttribute("Station", kind)
		padTop:SetAttribute("World", world.Id)
		local anchor = MapKit.FloatingLabel(model, style.Title, 24, WHITE, style.Color, Vector2.new(20, 5))
		anchor.CFrame = cf * CFrame.new(0, 0, 4)
	end
end

local function buildEggs(world: World, root: Instance)
	local O = world.Origin
	local pal = world.Palette
	local folder = PropKit.Folder("Eggs", root)
	for i, eggId in world.Eggs do
		local egg = Pets.Eggs[eggId]
		local info = Layout.Eggs[i]
		local cf = Layout.At(O, info.Position, Vector3.new(0, 0, info.Position.Z))
		local model = PropKit.Model("Egg_" .. eggId, folder)
		model:AddTag("EggStand")
		model:SetAttribute("Egg", eggId)
		PropKit.Disc({
			Name = "Pedestal",
			Size = Vector3.new(16, 3, 16),
			CFrame = cf * CFrame.new(0, 1.5, 0),
			Color = INK,
			Parent = model,
		})
		PropKit.Disc({
			Name = "PedestalRing",
			Size = Vector3.new(17, 1, 17),
			CFrame = cf * CFrame.new(0, 2.6, 0),
			Color = egg.Color2,
			Material = Enum.Material.Neon,
			Parent = model,
		})
		local shell = MapKit.Ellipsoid(model, cf * CFrame.new(0, 9.5, 0), Vector3.new(9, 12, 9), egg.Color)
		shell.Name = "EggShell"
		for s = 1, 6 do
			local a = s * math.pi / 3
			MapKit.Ellipsoid(
				model,
				cf * CFrame.new(math.sin(a) * 4.1, 9.5 + ((s % 3) - 1) * 2.6, math.cos(a) * 4.1),
				Vector3.new(2.4, 2.4, 2.4),
				egg.Color2
			).Name =
				"Spot"
		end
		PropKit.Sparkles(shell, egg.Color2, 4, 0.9)
		local anchor = PropKit.Deco({
			Name = "SignAnchor",
			Size = Vector3.new(1, 1, 1),
			CFrame = cf * CFrame.new(0, 16, 0),
			Transparency = 1,
			Parent = model,
		})
		local bb = Instance.new("BillboardGui")
		bb.Name = "EggSign"
		bb.Size = UDim2.new(14, 0, 5, 0)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.MaxDistance = 160
		bb.LightInfluence = 0
		bb.Parent = anchor
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "EggName"
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.fromScale(1, 0.55)
		nameLabel.Text = string.upper(egg.Name)
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = WHITE
		nameLabel.FontFace = Theme.Fonts.Display
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(WHITE, egg.Color2:Lerp(WHITE, 0.2))
		g.Rotation = 90
		g.Parent = nameLabel
		local s1 = Instance.new("UIStroke")
		s1.Thickness = 4
		s1.Color = INK
		s1.Parent = nameLabel
		nameLabel.Parent = bb
		local price = Instance.new("TextLabel")
		price.Name = "Price"
		price.BackgroundTransparency = 1
		price.Position = UDim2.fromScale(0, 0.55)
		price.Size = UDim2.fromScale(1, 0.45)
		price.Text = "💰 " .. tostring(egg.Cost)
		price.TextScaled = true
		price.TextColor3 = Theme.Colors.Gold
		price.FontFace = Theme.Fonts.Display
		local s2 = Instance.new("UIStroke")
		s2.Thickness = 3
		s2.Color = INK
		s2.Parent = price
		price.Parent = bb
		local padTop = pad(model, cf * CFrame.new(0, 0, -13), egg.Color2, 9)
		padTop:AddTag("StationPad")
		setAttrs(padTop, { Station = "Egg", Egg = eggId, World = world.Id })
	end
	local label = MapKit.FloatingLabel(folder, "🥚 PET EGGS", 24, WHITE, Theme.Colors.Mint, Vector2.new(20, 5))
	label.CFrame = CFrame.new(O + Vector3.new(150, 0, 0))
	-- egg area floor
	local floor = MapKit.Floor(
		folder,
		CFrame.new(O + Vector3.new(131, 0.25, 0)),
		Vector3.new(58, 1, 150),
		pal.Plaza2,
		true,
		"EggFloor"
	)
	floor.Name = "EggFloor"
	MapKit.FilmCurb(folder, O + Vector3.new(102, 0.5, -75), O + Vector3.new(102, 0.5, 75), pal, 6)
end

-- Plaza extras: worlds portal, leaderboards, live board -----------------------------------------
local function buildPlazaExtras(world: World, root: Instance)
	local O = world.Origin
	local pal = world.Palette
	local folder = PropKit.Folder("PlazaExtras", root)

	-- worlds portal
	local pcf = CFrame.new(O + Layout.WorldsPortal + Vector3.new(0, 11, 0))
	MapKit.Ring(folder, pcf, 9, 2, 20, pal.Accent3)
	local swirl = PropKit.Part({
		Name = "WorldsSwirl",
		Size = Vector3.new(0.5, 16, 16),
		CFrame = pcf * CFrame.Angles(0, math.rad(90), 0),
		Color = pal.Accent3:Lerp(WHITE, 0.3),
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
		Shape = "Cylinder",
		Parent = folder,
	})
	local swirlPart = swirl :: Part
	swirlPart.Shape = Enum.PartType.Cylinder
	local anchor = MapKit.FloatingLabel(folder, "🌍 WORLDS", 13, WHITE, pal.Accent3, Vector2.new(16, 4))
	anchor.CFrame = pcf
	local padTop = pad(folder, CFrame.new(O + Layout.WorldsPortal + Vector3.new(0, 0, 12)), pal.Accent3, 10)
	padTop:AddTag("StationPad")
	setAttrs(padTop, { Station = "Worlds", World = world.Id })

	-- leaderboards
	for _, lb in Layout.Leaderboards do
		local cf = Layout.At(O, lb.Position, Vector3.new(lb.Position.X, 0, 0))
		for _, side in { -1, 1 } do
			PropKit.Part({
				Name = "BoardLeg",
				Size = Vector3.new(2, 8, 2),
				CFrame = cf * CFrame.new(side * 12, 4, 0),
				Color = INK,
				Parent = folder,
			})
		end
		local board = PropKit.Part({
			Name = "Leaderboard",
			Size = Vector3.new(30, 26, 1.6),
			CFrame = cf * CFrame.new(0, 21, 0),
			Color = Color3.fromRGB(36, 28, 60),
			Parent = folder,
		})
		PropKit.Deco({
			Name = "BoardRim",
			Size = Vector3.new(31.6, 27.6, 1.2),
			CFrame = cf * CFrame.new(0, 21, 0.4),
			Color = pal.Accent2,
			Material = Enum.Material.Neon,
			Parent = folder,
		})
		board:AddTag("Leaderboard")
		setAttrs(board, { Stat = lb.Stat, Title = lb.Title, World = world.Id })
	end
	-- top creator live board
	local tcf = Layout.At(O, Layout.TopCreator, Vector3.new(0, 0, 0))
	local live = PropKit.Part({
		Name = "TopCreator",
		Size = Vector3.new(36, 16, 1.6),
		CFrame = tcf * CFrame.new(0, 30, 0),
		Color = Color3.fromRGB(20, 14, 36),
		Parent = folder,
	})
	PropKit.Deco({
		Name = "TopRim",
		Size = Vector3.new(37.6, 17.6, 1.2),
		CFrame = tcf * CFrame.new(0, 30, 0.4),
		Color = Theme.Colors.Red,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	PropKit.Part({
		Name = "TopLeg",
		Size = Vector3.new(3, 22, 3),
		CFrame = tcf * CFrame.new(0, 11, 1),
		Color = INK,
		Parent = folder,
	})
	live:AddTag("TopCreatorBoard")
	live:SetAttribute("World", world.Id)

	-- lamps around the plaza
	for i = 0, 11 do
		local a = (i / 12) * math.pi * 2 + math.pi / 12
		local x = math.sin(a) * (Layout.PlazaRadius + 6)
		local z = math.cos(a) * (Layout.PlazaRadius + 6)
		local nearRoad = math.abs(x) < 30 and z > 0
		local nearPortal = math.abs(x) < 20 and z < 0
		for _, info in Layout.Stations do
			if math.abs(x - info.Position.X) < 20 and math.abs(z - info.Position.Z) < 20 then
				nearPortal = true
			end
		end
		if not nearRoad and not nearPortal then
			MapKit.Lamp(folder, CFrame.new(O + Vector3.new(x, 0, z)), pal)
		end
	end
end

-- Decoration ------------------------------------------------------------------------------------
local function blocked(x: number, z: number): boolean
	if x < -96 and math.abs(z) < 112 then
		return true -- treadmills
	end
	if x > 96 and math.abs(z) < 84 then
		return true -- eggs
	end
	if math.abs(x) < 60 and z > 60 then
		return true -- road
	end
	if math.abs(x) < 80 and z < -120 then
		return true -- boards
	end
	if math.abs(x) < 26 and z < -40 then
		return true -- monument + portal
	end
	if x * x + z * z < (Layout.PlazaRadius + 12) ^ 2 then
		return true -- plaza
	end
	for _, info in Layout.Stations do
		if math.abs(x - info.Position.X) < 24 and math.abs(z - info.Position.Z) < 24 then
			return true
		end
	end
	return false
end

local function buildDecor(world: World, root: Instance, rng: Rng.Rng)
	local O = world.Origin
	local pal = world.Palette
	local folder = PropKit.Folder("Decor", root)
	local half = Layout.IslandHalf - 12
	local placed = 0
	local tries = 0
	while placed < 26 and tries < 600 do
		tries += 1
		local x = rng:Range(-half, half)
		local z = rng:Range(-half, half)
		if not blocked(x, z) then
			placed += 1
			if rng:Chance(0.8) then
				MapKit.Tree(folder, CFrame.new(O + Vector3.new(x, 0, z)), world.Decor, pal, rng)
			else
				MapKit.Rock(folder, CFrame.new(O + Vector3.new(x, 0, z)), pal, rng)
			end
		end
	end

	-- big themed props in the corners
	local function facingCenter(x: number, z: number): CFrame
		return Layout.At(O, Vector3.new(x, 0, z), Vector3.new(0, 0, 0))
	end
	MapKit.GiantCamera(folder, facingCenter(-118, 118), pal, 1.3)
	MapKit.GiantPhone(folder, facingCenter(122, 118), pal, 1.2)
	MapKit.ThumbsUp(folder, facingCenter(-122, -122), pal, 1.4)
	MapKit.Bell(folder, facingCenter(122, -122), pal, 1.2)

	-- scenery outside the walls
	if world.Decor == "City" then
		for i = 1, 26 do
			local side = if i % 2 == 0 then 1 else -1
			local z = -200 + (i // 2) * 95
			MapKit.Building(folder, CFrame.new(O + Vector3.new(side * rng:Range(240, 300), -70, z)), pal, rng)
		end
	elseif world.Decor == "Space" then
		MapKit.Planet(folder, CFrame.new(O + Vector3.new(-420, 160, 400)), pal.Accent2, pal.Accent1, 90)
		MapKit.Planet(folder, CFrame.new(O + Vector3.new(460, 120, 900)), pal.Accent3, nil, 60)
		MapKit.Planet(folder, CFrame.new(O + Vector3.new(-300, 220, -350)), pal.Accent1, pal.Accent3, 50)
		for _ = 1, 18 do
			local x = rng:Range(-500, 500)
			local z = rng:Range(-400, 1400)
			if math.abs(x) > 240 then
				MapKit.Tree(folder, CFrame.new(O + Vector3.new(x, rng:Range(-60, 40), z)), "Space", pal, rng)
			end
		end
	else
		for _ = 1, 30 do
			local x = rng:Range(-520, 520)
			local z = rng:Range(-400, 1400)
			if math.abs(x) > 240 or (z > 260 and math.abs(x) > 80) then
				MapKit.Tree(folder, CFrame.new(O + Vector3.new(x, -68, z)) * CFrame.new(0, 0, 0), world.Decor, pal, rng)
			end
		end
	end
end

function WorldBuilder.Build(world: World, parent: Instance): Model
	local root = PropKit.Model("World" .. world.Id .. "_" .. world.Name, parent)
	root:SetAttribute("World", world.Id)
	local rng = Rng.new(world.Id * 7919 + 17)
	buildIsland(world, root)
	buildPlaza(world, root)
	buildSpawn(world, root)
	buildRoad(world, root, rng)
	buildArena(world, root)
	buildTreadmills(world, root)
	buildStations(world, root)
	buildEggs(world, root)
	buildPlazaExtras(world, root)
	buildDecor(world, root, rng)
	return root
end

return WorldBuilder
