--!strict
-- Client mirror of the player's profile + context, kept in sync by the
-- server's "State" remote. Subscribe with State.On(key, fn).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Util.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Util.Types)

type Data = Types.Data
type Context = Types.Context

local State = {}

State.Data = (nil :: any) :: Data
State.Ctx = { Passes = {}, Friends = 0, Premium = false, Group = false } :: Context
State.IsLoaded = false
State.Loaded = Signal.new()
State.Changed = Signal.new() -- (key)
State.SessionStart = os.clock()

local listeners: { [string]: { (any) -> () } } = {}

-- Call fn(value) whenever `key` changes (and right away if already loaded).
function State.On(key: string, fn: (any) -> ()): () -> ()
	local list = listeners[key]
	if not list then
		list = {}
		listeners[key] = list
	end
	table.insert(list, fn)
	if State.IsLoaded then
		task.spawn(fn, if key == "Context" then State.Ctx else (State.Data :: any)[key])
	end
	return function()
		local l = listeners[key]
		if l then
			local i = table.find(l, fn)
			if i then
				table.remove(l, i)
			end
		end
	end
end

local function fire(key: string)
	State.Changed:Fire(key)
	local list = listeners[key]
	if list then
		local value = if key == "Context" then State.Ctx else (State.Data :: any)[key]
		for _, fn in table.clone(list) do
			task.spawn(fn, value)
		end
	end
end

function State.Wait(): Data
	while not State.IsLoaded do
		task.wait()
	end
	return State.Data
end

function State.Init()
	Net.Event("State").OnClientEvent:Connect(function(kind: string, payload: any, ctx: any)
		if kind == "full" then
			State.Data = payload
			if ctx then
				State.Ctx = ctx
			end
			local first = not State.IsLoaded
			State.IsLoaded = true
			State.SessionStart = os.clock()
			if first then
				State.Loaded:Fire(State.Data)
			end
			for key in payload do
				fire(key)
			end
			fire("Context")
		elseif kind == "set" and State.IsLoaded then
			for key, value in payload do
				(State.Data :: any)[key] = value
			end
			for key in payload do
				fire(key)
			end
		elseif kind == "ctx" then
			State.Ctx = payload
			if State.IsLoaded then
				fire("Context")
			end
		end
	end)
end

function State.Start() end

return State
