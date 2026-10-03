--!strict
-- Player profiles: load/save with session locking, autosave, BindToClose,
-- and replication of changed keys to the owning client.
--
-- Usage from other services:
--   local data = DataService.Get(player)      -- nil until loaded
--   data.Clout += 10
--   DataService.Dirty(player, "Clout")         -- replicate (batched ~8x/sec)

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Util.Net)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Util.Types)
local Comms = require(script.Parent.Comms)

type Data = Types.Data
type Context = Types.Context

local DataService = {}

local STORE_NAME = "YoutuberEvolution_v1"
local AUTOSAVE_INTERVAL = 60
local LOCK_FRESH = 150 -- seconds; a lock newer than this belongs to a live server
local LOCK_WAIT = 18 -- how long we wait for another server to release before taking over
local CURRENT_VERSION = 1

local store: DataStore? = nil
local storeOk = true
local profiles: { [Player]: Data } = {}
local contexts: { [Player]: Context } = {}
local dirty: { [Player]: { [string]: boolean } } = {}
local saving: { [Player]: boolean } = {}
local lostLock: { [Player]: boolean } = {}
local released: { [Player]: boolean } = {}

DataService.Loaded = Signal.new() -- (player, data)
DataService.Changed = Signal.new() -- (player, key)
DataService.Persistent = true

function DataService.Default(): Data
	return {
		Version = CURRENT_VERSION,
		Views = 0,
		TotalViews = 0,
		Clout = 0,
		TotalClout = 0,
		Rebirths = 0,
		Tickets = 0,
		Devices = { d1 = true },
		Equipped = "d1",
		Upgrades = {},
		Pets = {},
		EquippedPets = {},
		Niche = "",
		NichePity = 0,
		PendingNiche = "",
		World = 1,
		Unlocked = { ["1"] = true },
		RivalsBeaten = {},
		RivalCooldowns = {},
		BestVideo = 1,
		BestEvolution = 1,
		Daily = { Streak = 0, Last = 0 },
		Potions = { Views = 0, Clout = 0 },
		OneTime = {},
		Receipts = {},
		Codes = {},
		Settings = {
			Music = true,
			SFX = true,
			Popups = true,
			OtherPets = true,
			Beam = true,
			LowGfx = false,
			Nametags = true,
		},
		Stats = { Steps = 0, Playtime = 0, Battles = 0, Hatched = 0, Claims = 0, Rolls = 0 },
		Tutorial = false,
	}
end

-- Fill in any keys missing from older saves (deep for nested tables).
local function reconcile(target: { [any]: any }, template: { [any]: any })
	for k, v in template do
		if target[k] == nil then
			if typeof(v) == "table" then
				target[k] = table.clone(v)
				reconcile(target[k], v)
			else
				target[k] = v
			end
		elseif typeof(v) == "table" and typeof(target[k]) == "table" and next(v) ~= nil and #v == 0 then
			-- only reconcile dictionaries that have default keys (e.g. Settings, Stats)
			reconcile(target[k], v)
		end
	end
end

local function migrate(data: { [string]: any }): Data
	-- future: if data.Version < 2 then ... end
	data.Version = CURRENT_VERSION
	return (data :: any) :: Data
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

-- Load ------------------------------------------------------------------------------
local function loadProfile(player: Player): Data?
	if not store or not storeOk then
		return DataService.Default()
	end
	local key = keyFor(player)
	local started = os.clock()
	while player.Parent do
		local lockedElsewhere = false
		local loaded: { [string]: any }? = nil
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(old: any)
				local now = os.time()
				if typeof(old) == "table" and old.Lock and old.Lock.Job ~= game.JobId then
					local age = now - (old.Lock.Time or 0)
					if age < LOCK_FRESH and os.clock() - started < LOCK_WAIT then
						lockedElsewhere = true
						return nil -- cancel, try again shortly
					end
				end
				local record = if typeof(old) == "table" then old else {}
				record.Lock = { Job = game.JobId, Time = now }
				loaded = record.Data
				return record
			end)
		end)
		if ok and not lockedElsewhere then
			local data: { [string]: any } = if typeof(loaded) == "table"
				then loaded :: any
				else DataService.Default() :: any
			reconcile(data, DataService.Default() :: any)
			return migrate(data)
		elseif not ok then
			warn("[Data] load failed for " .. player.Name .. ": " .. tostring(err))
			if os.clock() - started > 30 then
				return nil
			end
		end
		task.wait(if lockedElsewhere then 3 else 4)
	end
	return nil
end

-- Save ------------------------------------------------------------------------------
local function saveProfile(player: Player, release: boolean): boolean
	local data = profiles[player]
	if not data or not store or not storeOk or lostLock[player] then
		return false
	end
	if saving[player] then
		-- wait for the in-flight save, then save again so nothing is lost
		local t = os.clock()
		while saving[player] and os.clock() - t < 15 do
			task.wait(0.2)
		end
	end
	saving[player] = true
	local key = keyFor(player)
	local snapshot = HttpService:JSONDecode(HttpService:JSONEncode(data))
	local success = false
	for attempt = 1, 3 do
		local stolen = false
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(old: any)
				if typeof(old) == "table" and old.Lock and old.Lock.Job ~= game.JobId then
					stolen = true
					return nil
				end
				local record = if typeof(old) == "table" then old else {}
				record.Data = snapshot
				record.Lock = if release then nil else { Job = game.JobId, Time = os.time() }
				return record
			end)
		end)
		if ok then
			if stolen then
				-- another server took this profile over; never overwrite it
				lostLock[player] = true
				warn("[Data] session for " .. player.Name .. " was taken over by another server")
			end
			success = not stolen
			break
		end
		warn("[Data] save attempt " .. attempt .. " failed: " .. tostring(err))
		task.wait(attempt * 2)
	end
	saving[player] = false
	return success
end

function DataService.SaveNow(player: Player): boolean
	if not DataService.Persistent then
		return true
	end
	return saveProfile(player, false)
end

-- Access ----------------------------------------------------------------------------
function DataService.Get(player: Player): Data?
	return profiles[player]
end

function DataService.WaitFor(player: Player, timeout: number?): Data?
	local t = os.clock()
	while player.Parent and not profiles[player] and os.clock() - t < (timeout or 30) do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.Context(player: Player): Context
	local ctx = contexts[player]
	if not ctx then
		ctx = { Passes = {}, Friends = 0, Premium = false, Group = false }
		contexts[player] = ctx
	end
	return ctx
end

function DataService.Players(): { [Player]: Data }
	return profiles
end

-- Mark top-level keys as changed; they're sent to the client in the next flush.
function DataService.Dirty(player: Player, ...: string)
	local d = dirty[player]
	if not d then
		d = {}
		dirty[player] = d
	end
	for _, key in { ... } do
		d[key] = true
	end
	for _, key in { ... } do
		DataService.Changed:Fire(player, key)
	end
end

function DataService.ContextDirty(player: Player)
	Net.Event("State"):FireClient(player, "ctx", DataService.Context(player))
	DataService.Changed:Fire(player, "Context")
end

local function flush()
	local stateRemote = Net.Event("State")
	for player, keys in dirty do
		local data = profiles[player]
		if data and player.Parent then
			local patch = {}
			for key in keys do
				patch[key] = (data :: any)[key]
			end
			stateRemote:FireClient(player, "set", patch)
		end
		dirty[player] = nil
	end
end

-- Lifecycle ------------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	local data = loadProfile(player)
	if not player.Parent then
		if data and store and storeOk then
			-- left while loading: release the lock we just took
			profiles[player] = data
			saveProfile(player, true)
			profiles[player] = nil
		end
		return
	end
	if not data then
		player:Kick("Couldn't load your data. Please rejoin in a moment!")
		return
	end
	profiles[player] = data
	Net.Event("State"):FireClient(player, "full", data, DataService.Context(player))
	DataService.Loaded:Fire(player, data)
	if not DataService.Persistent then
		task.delay(4, function()
			if player.Parent then
				Comms.Notify(
					player,
					"Studio test mode: progress won't save. Enable 'Studio Access to API Services' in Game Settings.",
					"error"
				)
			end
		end)
	end
end

local function onPlayerRemoving(player: Player)
	if profiles[player] and not released[player] then
		released[player] = true
		saveProfile(player, true)
	end
	profiles[player] = nil
	contexts[player] = nil
	dirty[player] = nil
	saving[player] = nil
	lostLock[player] = nil
	released[player] = nil
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		-- In Studio without API access, GetDataStore works but requests fail.
		if RunService:IsStudio() then
			local probeOk = pcall(function()
				(store :: DataStore):GetAsync("__probe")
			end)
			if not probeOk then
				storeOk = false
			end
		end
	else
		storeOk = false
	end
	if not storeOk then
		DataService.Persistent = false
		warn("[Data] DataStores unavailable - running without saving (Studio test mode)")
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Players already in game (Studio play-solo): defer so every other service
	-- has connected to DataService.Loaded before the first profile loads.
	for _, p in Players:GetPlayers() do
		task.defer(onPlayerAdded, p)
	end

	-- batched replication
	task.spawn(function()
		while true do
			task.wait(0.12)
			flush()
		end
	end)

	-- staggered autosave
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(saveProfile, player, false)
				task.wait(0.5)
			end
		end
	end)

	game:BindToClose(function()
		if not DataService.Persistent then
			return
		end
		local pending = 0
		for player in profiles do
			if not released[player] then
				released[player] = true
				pending += 1
				task.spawn(function()
					saveProfile(player, true)
					pending -= 1
				end)
			end
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
