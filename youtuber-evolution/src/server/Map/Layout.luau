--!strict
-- World-local layout (studs). Each world is built around its Origin.
-- +Z points from the plaza down the Gate Road.

local Layout = {}

Layout.IslandHalf = 160 -- island spans -160..160 on X and Z
Layout.GroundThickness = 12
Layout.PlazaRadius = 80
Layout.Spawn = Vector3.new(0, 0, -26)
Layout.Monument = Vector3.new(0, 0, -56)

Layout.Road = {
	HalfWidth = 14, -- walkable road
	StripHalfWidth = 50, -- road + side strips (bounded)
	StartZ = 104,
	EndZ = 900,
	FirstGateZ = 160,
	GateSpacing = 50,
	PadOffsetX = 31,
	PadOffsetZ = 17,
}

Layout.Arena = {
	StartZ = 900,
	EndZ = 1030,
	HalfWidth = 72,
	ChallengeZ = 928,
	RivalZ = 960,
	MonitorZ = 992,
	PortalZ = 1014,
}

Layout.Treadmills = {
	X = -134, -- center of the treadmill row
	FirstZ = -84,
	Spacing = 28,
}

Layout.Stations = {
	Devices = { Position = Vector3.new(-64, 0, 50) },
	Upgrades = { Position = Vector3.new(64, 0, 50) },
	Rebirth = { Position = Vector3.new(-64, 0, -50) },
	Niche = { Position = Vector3.new(64, 0, -50) },
} :: { [string]: { Position: Vector3 } }

Layout.Eggs = {
	{ Position = Vector3.new(134, 0, -38) },
	{ Position = Vector3.new(134, 0, 38) },
}

Layout.WorldsPortal = Vector3.new(0, 0, -98)
Layout.Leaderboards = {
	{ Stat = "TotalViews", Position = Vector3.new(-50, 0, -138), Title = "TOP VIEWS" },
	{ Stat = "Rebirths", Position = Vector3.new(50, 0, -138), Title = "TOP REBIRTHS" },
}
Layout.TopCreator = Vector3.new(0, 0, -146)

function Layout.GateZ(index: number): number
	return Layout.Road.FirstGateZ + (index - 1) * Layout.Road.GateSpacing
end

-- CFrame at `pos` facing horizontally toward `target`. Built from a yaw angle
-- instead of CFrame.lookAt so it is identical under Lune and Roblox.
function Layout.Facing(pos: Vector3, target: Vector3): CFrame
	local dx = target.X - pos.X
	local dz = target.Z - pos.Z
	if dx * dx + dz * dz < 1e-6 then
		return CFrame.new(pos)
	end
	return CFrame.new(pos) * CFrame.Angles(0, math.atan2(-dx, -dz), 0)
end

-- A CFrame at a world-local position, optionally facing a world-local point.
function Layout.At(origin: Vector3, localPos: Vector3, lookAtLocal: Vector3?): CFrame
	local p = origin + localPos
	if lookAtLocal then
		return Layout.Facing(p, origin + lookAtLocal)
	end
	return CFrame.new(p)
end

return Layout
