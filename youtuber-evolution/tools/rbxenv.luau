-- Minimal Roblox-like environment for running game modules under Lune.
-- Used by bake.luau (to build the map into the place file) and by the
-- test/simulation scripts. Modules are loaded straight from the ModuleScripts
-- inside a Rojo-built place, so `script.Parent.X` style requires just work.

local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local task = require("@lune/task")

local M = {}

function M.loadPlace(path: string)
	return roblox.deserializePlace(fs.readFile(path))
end

function M.savePlace(game, path: string)
	fs.writeFile(path, roblox.serializePlace(game))
end

function M.new(game)
	local cache: { [string]: any } = {}
	local base: { [string]: any } = {
		game = game,
		workspace = game:GetService("Workspace"),
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Rect = roblox.Rect,
		Font = roblox.Font,
		Enum = roblox.Enum,
		BrickColor = roblox.BrickColor,
		PhysicalProperties = roblox.PhysicalProperties,
		typeof = typeof,
		task = task,
		warn = function(...)
			print("[warn]", ...)
		end,
		tick = os.clock,
	}

	local function requireModule(moduleScript)
		local key = moduleScript:GetFullName()
		local cached = cache[key]
		if cached ~= nil then
			return cached
		end
		local env = table.clone(base)
		env.script = moduleScript
		env.require = requireModule
		local chunk = luau.load(moduleScript.Source, { debugName = key, environment = env })
		local result = chunk()
		cache[key] = result
		return result
	end

	base.require = requireModule
	return {
		require = requireModule,
		env = base,
	}
end

return M
