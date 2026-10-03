-- Bakes the procedurally generated map into the Rojo-built place.
-- Usage: lune run tools/bake.luau build/base.rbxl YoutuberEvolution.rbxl
local process = require("@lune/process")
local rbxenv = require("./rbxenv")

local input = process.args[1] or "build/base.rbxl"
local output = process.args[2] or "YoutuberEvolution.rbxl"

local game = rbxenv.loadPlace(input)
local env = rbxenv.new(game)
local workspace = game:GetService("Workspace")

local existing = workspace:FindFirstChild("Map")
if existing then
	existing:Destroy()
end
-- remove the default baseplate if one exists
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end

local MapBuilder = env.require(game:GetService("ServerScriptService").Server.Map.MapBuilder)
local start = os.clock()
local map = MapBuilder.Build(workspace)

local parts, tagged = 0, {}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
	for _, tag in d:GetTags() do
		tagged[tag] = (tagged[tag] or 0) + 1
	end
end
print(string.format("Map built in %.2fs: %d parts", os.clock() - start, parts))
local names = {}
for tag, n in tagged do
	table.insert(names, tag .. "=" .. n)
end
table.sort(names)
print("Tags: " .. table.concat(names, ", "))

rbxenv.savePlace(game, output)
print("Saved " .. output)
