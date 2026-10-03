--!strict
-- Builds every world into Workspace.Map. Runs in two places:
--   * tools/bake.luau (Lune) bakes it straight into YoutuberEvolution.rbxl,
--     so you can see and hand-edit the map in Studio.
--   * the server at startup, only if Workspace.Map is missing.

local Shared = game:GetService("ReplicatedStorage").Shared
local Worlds = require(Shared.Config.Worlds)
local WorldBuilder = require(script.Parent.WorldBuilder)

local MapBuilder = {}

MapBuilder.Version = 1

function MapBuilder.Build(workspaceRoot: Instance): Model
	local map = Instance.new("Model")
	map.Name = "Map"
	map:SetAttribute("MapVersion", MapBuilder.Version)
	for _, world in Worlds do
		WorldBuilder.Build(world, map)
	end
	map.Parent = workspaceRoot
	return map
end

return MapBuilder
