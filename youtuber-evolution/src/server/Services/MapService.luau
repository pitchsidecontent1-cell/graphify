--!strict
-- Finds every tagged map piece (building the map first if it's missing) and
-- offers spatial helpers: which world a position is in, spawns, teleports.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Worlds = require(Shared.Config.Worlds)
local MapBuilder = require(script.Parent.Parent.Map.MapBuilder)

local MapService = {}

export type Gate = { Part: BasePart, World: number, Index: number, Video: number }
export type Pad = { Part: BasePart, World: number, Gate: number, Radius: number }
export type Zone = { Part: BasePart, World: number, Tier: number }

MapService.Spawns = {} :: { [number]: SpawnLocation }
MapService.Gates = {} :: { [number]: { Gate } } -- per world, sorted by index
MapService.Pads = {} :: { [number]: { Pad } }
MapService.Zones = {} :: { [number]: { Zone } }
MapService.RivalSpots = {} :: { [number]: BasePart }
MapService.RivalGates = {} :: { [number]: BasePart }
MapService.Portals = {} :: { [number]: BasePart }
MapService.StationPads = {} :: { BasePart }

local function num(inst: Instance, attr: string): number
	local v = inst:GetAttribute(attr)
	return if typeof(v) == "number" then v else 0
end

function MapService.Init()
	if not Workspace:FindFirstChild("Map") then
		local t = os.clock()
		MapBuilder.Build(Workspace)
		print(string.format("[Map] built at runtime in %.2fs", os.clock() - t))
	end

	for _, inst in CollectionService:GetTagged("WorldSpawn") do
		if inst:IsA("SpawnLocation") then
			MapService.Spawns[num(inst, "World")] = inst
		end
	end
	for w = 1, #Worlds do
		MapService.Gates[w] = {}
		MapService.Pads[w] = {}
		MapService.Zones[w] = {}
	end
	for _, inst in CollectionService:GetTagged("GateBarrier") do
		if inst:IsA("BasePart") then
			local w = num(inst, "World")
			if MapService.Gates[w] then
				table.insert(
					MapService.Gates[w],
					{ Part = inst, World = w, Index = num(inst, "Gate"), Video = num(inst, "Video") }
				)
			end
		end
	end
	for _, list in MapService.Gates do
		table.sort(list, function(a, b)
			return a.Index < b.Index
		end)
	end
	for _, inst in CollectionService:GetTagged("CloutPad") do
		if inst:IsA("BasePart") then
			local w = num(inst, "World")
			if MapService.Pads[w] then
				local radius = num(inst, "Radius")
				table.insert(MapService.Pads[w], {
					Part = inst,
					World = w,
					Gate = num(inst, "Gate"),
					Radius = if radius > 0 then radius else 5,
				})
			end
		end
	end
	for _, inst in CollectionService:GetTagged("TreadmillZone") do
		if inst:IsA("BasePart") then
			local w = num(inst, "World")
			if MapService.Zones[w] then
				table.insert(MapService.Zones[w], { Part = inst, World = w, Tier = num(inst, "Tier") })
			end
		end
	end
	for _, inst in CollectionService:GetTagged("RivalSpot") do
		if inst:IsA("BasePart") then
			MapService.RivalSpots[num(inst, "World")] = inst
		end
	end
	for _, inst in CollectionService:GetTagged("RivalGate") do
		if inst:IsA("BasePart") then
			MapService.RivalGates[num(inst, "World")] = inst
		end
	end
	for _, inst in CollectionService:GetTagged("Portal") do
		if inst:IsA("BasePart") then
			MapService.Portals[num(inst, "World")] = inst
		end
	end
	for _, inst in CollectionService:GetTagged("StationPad") do
		if inst:IsA("BasePart") then
			table.insert(MapService.StationPads, inst)
		end
	end
end

function MapService.Start() end

-- Which world is this position in? (closest world origin on X)
function MapService.WorldAt(pos: Vector3): number
	local best, bestDist = 1, math.huge
	for _, w in Worlds do
		local d = math.abs(pos.X - w.Origin.X)
		if d < bestDist then
			best, bestDist = w.Id, d
		end
	end
	return best
end

function MapService.SpawnCFrame(world: number): CFrame
	local spawn = MapService.Spawns[world]
	if spawn then
		return spawn.CFrame + Vector3.new(0, 3.5, 0)
	end
	return CFrame.new(Worlds[world].Origin + Vector3.new(0, 5, 0))
end

function MapService.Teleport(character: Model?, cf: CFrame)
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(cf)
	end
end

-- Is `pos` within `extra` studs of a station pad of this kind?
function MapService.NearStation(pos: Vector3, station: string, extra: number, filter: ((BasePart) -> boolean)?): boolean
	for _, pad in MapService.StationPads do
		if pad:GetAttribute("Station") == station and (not filter or filter(pad)) then
			local offset = pos - pad.Position
			if
				Vector3.new(offset.X, 0, offset.Z).Magnitude <= num(pad, "Radius") + extra
				and math.abs(offset.Y) < 20
			then
				return true
			end
		end
	end
	return false
end

return MapService
