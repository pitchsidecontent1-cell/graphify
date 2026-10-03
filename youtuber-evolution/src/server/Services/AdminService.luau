--!strict
-- Admin / testing commands. Run them from:
--   * the admin panel (🛠️ ADMIN button, top right),
--   * the command bar (press ; or F2),
--   * chat: "/clout 1m" (autocompletes) or ";clout 1m".
-- Names, arguments and help text live in Shared/Util/AdminCommands; the
-- implementations are below. Admins: everyone in Studio, the game owner,
-- Config/Admin.UserIds and (group games) ranks >= Config/Admin.GroupMinRank.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local GroupService = game:GetService("GroupService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Admin = require(Shared.Config.Admin)
local Products = require(Shared.Config.Products)
local Worlds = require(Shared.Config.Worlds)
local Devices = require(Shared.Config.Devices)
local Evolutions = require(Shared.Config.Evolutions)
local Pets = require(Shared.Config.Pets)
local Niches = require(Shared.Config.Niches)
local Upgrades = require(Shared.Config.Upgrades)
local Economy = require(Shared.Config.Economy)
local Rewards = require(Shared.Config.Rewards)
local Stats = require(Shared.Util.Stats)
local Format = require(Shared.Util.Format)
local Types = require(Shared.Util.Types)
local AdminCommands = require(Shared.Util.AdminCommands)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local RebirthService = require(script.Parent.RebirthService)
local MonetizationService = require(script.Parent.MonetizationService)
local MapService = require(script.Parent.MapService)
local MovementService = require(script.Parent.MovementService)
local CharacterService = require(script.Parent.CharacterService)
local RivalService = require(script.Parent.RivalService)
local PetService = require(script.Parent.PetService)
local RewardService = require(script.Parent.RewardService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local Comms = require(script.Parent.Comms)

type Data = Types.Data
type Args = { any }
type Impl = (target: Player, args: Args, caller: Player) -> (boolean, string)

local AdminService = {}

-- Who is an admin -------------------------------------------------------------------------------
local adminCache: { [Player]: boolean } = {}

-- nil = couldn't tell right now (group lookup failed); not cached, retried later
local function computeAdmin(player: Player): boolean?
	if RunService:IsStudio() then
		return true
	end
	if table.find(Admin.UserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return game.CreatorId == player.UserId
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, groups = pcall(function()
			return GroupService:GetGroupsAsync(player.UserId)
		end)
		if not ok or typeof(groups) ~= "table" then
			return nil
		end
		for _, g in groups do
			if typeof(g) == "table" and g.Id == game.CreatorId then
				return typeof(g.Rank) == "number" and g.Rank >= Admin.GroupMinRank
			end
		end
	end
	return false
end

function AdminService.IsAdmin(player: Player): boolean
	local cached: boolean? = adminCache[player]
	if cached == nil then
		local result = computeAdmin(player)
		if result ~= nil then
			adminCache[player] = result
		end
		cached = result
	end
	return cached == true
end

-- Helpers ---------------------------------------------------------------------------------------------
local function done(msg: string): (boolean, string)
	return true, msg
end

local function nope(msg: string): (boolean, string)
	return false, msg
end

-- lower case, letters + digits only: "Galaxy Dragon" -> "galaxydragon"
local function squash(s: string): string
	return (string.gsub(string.lower(s), "[^%w]", ""))
end

local function setViews(player: Player, data: Data, views: number)
	local old = data.Views
	data.Views = math.clamp(math.floor(views), 0, AdminCommands.MaxNumber)
	if data.Views > old then
		data.TotalViews += data.Views - old
	end
	DataService.Dirty(player, "Views", "TotalViews")
	-- quiet when going down (no "VIDEO UPLOADED" toasts for a drop)
	ProgressService.Check(player, data.Views < old)
end

local function setVideo(player: Player, data: Data, level: number): number
	local clamped = math.clamp(math.floor(level), 1, Economy.Video.Max)
	setViews(player, data, Stats.ViewsForVideo(clamped))
	return clamped
end

local function setClout(player: Player, data: Data, amount: number)
	local old = data.Clout
	data.Clout = math.clamp(math.floor(amount), 0, AdminCommands.MaxNumber)
	if data.Clout > old then
		data.TotalClout += data.Clout - old
	end
	DataService.Dirty(player, "Clout", "TotalClout")
end

-- The world the player is standing in (falls back to their saved world).
local function worldOf(player: Player, data: Data): number
	local root = CharacterService.Root(player)
	return if root then MapService.WorldAt(root.Position) else data.World
end

-- Index of the locked gate that `pos` is behind (the one that would push the
-- player back), or nil. Mirrors MovementService's push-back check.
local function lockedGateBehind(data: Data, pos: Vector3): number?
	local world = MapService.WorldAt(pos)
	local video = Stats.VideoLevel(data.Views)
	for _, gate in (MapService.Gates[world] or {}) :: { MapService.Gate } do
		if gate.Video > video then
			local p = gate.Part.CFrame:PointToObjectSpace(pos)
			if p.Z > 1.5 and math.abs(p.X) < 60 and p.Y > -10 and p.Y < 40 then
				return gate.Index
			end
			return nil
		end
	end
	return nil
end

-- Returns (ok, note). The note is "" or explains that noclip was switched on
-- because the spot is behind a gate the player hasn't opened yet.
local function teleport(player: Player, cf: CFrame): (boolean, string)
	if RivalService.InBattle(player) then
		return nope("is in a View War (use win / lose first)")
	end
	if not CharacterService.Root(player) then
		return nope("has no character right now")
	end
	local note = ""
	local data = DataService.Get(player)
	local bypass = player:GetAttribute("AdminFly") == true or player:GetAttribute("AdminNoclip") == true
	local gate = if data and not bypass then lockedGateBehind(data, cf.Position) else nil
	if gate then
		player:SetAttribute("AdminNoclip", true)
		note = " (noclip ON: you're past locked gate " .. gate .. ")"
	end
	MovementService.Grace(player, 1.5)
	MapService.Teleport(player.Character, cf)
	return done(note)
end

local function stationPad(world: number, station: string): BasePart?
	for _, pad in MapService.StationPads do
		if pad:GetAttribute("Station") == station and pad:GetAttribute("World") == world then
			return pad
		end
	end
	return nil
end

local function above(part: BasePart, height: number?): CFrame
	return CFrame.new(part.Position + Vector3.new(0, height or 4, 0))
end

local PLACE_ALIASES: { [string]: string } = {
	spawn = "spawn",
	home = "spawn",
	arena = "arena",
	rival = "arena",
	treadmills = "treadmills",
	treadmill = "treadmills",
	tm = "treadmills",
	devices = "devices",
	device = "devices",
	shop = "devices",
	upgrades = "upgrades",
	upgrade = "upgrades",
	rebirth = "rebirth",
	niche = "niche",
	eggs = "eggs",
	egg = "eggs",
	pets = "eggs",
	portal = "portal",
	worlds = "portal",
}

local function placeCFrame(place: string, world: number): CFrame?
	if place == "spawn" then
		return MapService.SpawnCFrame(world)
	elseif place == "arena" then
		local pad = stationPad(world, "Rival")
		return if pad then above(pad) else nil
	elseif place == "treadmills" then
		for _, zone in (MapService.Zones[world] or {}) :: { MapService.Zone } do
			if zone.Tier == 1 then
				return above(zone.Part, 3)
			end
		end
		return nil
	elseif place == "eggs" then
		local pad = stationPad(world, "Egg")
		return if pad then above(pad) else nil
	elseif place == "portal" then
		local pad = stationPad(world, "Worlds")
		return if pad then above(pad) else nil
	end
	-- Devices / Upgrades / Rebirth / Niche stations
	local station = string.upper(string.sub(place, 1, 1)) .. string.sub(place, 2)
	local pad = stationPad(world, station)
	return if pad then above(pad) else nil
end

-- me / all / others / part of a name
local function resolvePlayers(caller: Player, token: string?): ({ Player }?, string?)
	local q = if token then string.lower(token) else "me"
	-- "@name" = exactly this username (what the panel sends)
	if string.sub(q, 1, 1) == "@" then
		local name = string.sub(q, 2)
		for _, p in Players:GetPlayers() do
			if string.lower(p.Name) == name then
				return { p }, nil
			end
		end
		return nil, "No player named '" .. name .. "'"
	end
	if q == "" or q == "me" then
		return { caller }, nil
	end
	if q == "all" or q == "everyone" then
		return Players:GetPlayers(), nil
	end
	if q == "others" then
		local list = {}
		for _, p in Players:GetPlayers() do
			if p ~= caller then
				table.insert(list, p)
			end
		end
		if #list == 0 then
			return nil, "Nobody else is in the server"
		end
		return list, nil
	end
	-- exact username, then exact display name, then the start of either
	for _, p in Players:GetPlayers() do
		if string.lower(p.Name) == q then
			return { p }, nil
		end
	end
	local matches = {}
	for _, p in Players:GetPlayers() do
		if string.lower(p.DisplayName) == q then
			table.insert(matches, p)
		end
	end
	if #matches == 0 then
		for _, p in Players:GetPlayers() do
			local name, display = string.lower(p.Name), string.lower(p.DisplayName)
			if string.sub(name, 1, #q) == q or string.sub(display, 1, #q) == q then
				table.insert(matches, p)
			end
		end
	end
	if #matches == 1 then
		return matches, nil
	elseif #matches == 0 then
		return nil, "No player matches '" .. (token or "") .. "'"
	end
	local names = {}
	for _, p in matches do
		table.insert(names, "@" .. p.Name)
	end
	return nil, "'" .. (token or "") .. "' matches " .. table.concat(names, ", ") .. " - use @username"
end

-- Lookups ------------------------------------------------------------------------------------------
local function findDevice(q: string): Devices.Device?
	local n = tonumber(q)
	if n then
		return Devices.List[math.floor(n)]
	end
	if Devices.ById[string.lower(q)] then
		return Devices.ById[string.lower(q)]
	end
	local key = squash(q)
	if key == "" then
		return nil
	end
	for _, d in Devices.List do
		if squash(d.Name) == key then
			return d
		end
	end
	for _, d in Devices.List do
		if string.find(squash(d.Name), key, 1, true) then
			return d
		end
	end
	return nil
end

local function allPetIds(): { string }
	local list = {}
	for _, eggId in Pets.EggOrder do
		for _, petId in Pets.Eggs[eggId].Pets do
			table.insert(list, petId)
		end
	end
	return list
end

local function findPet(q: string): Pets.Pet?
	local key = squash(q)
	if key == "" then
		return nil
	end
	local ids = allPetIds()
	for _, id in ids do
		if squash(id) == key or squash(Pets.ById[id].Name) == key then
			return Pets.ById[id]
		end
	end
	for _, id in ids do
		if string.find(squash(Pets.ById[id].Name), key, 1, true) then
			return Pets.ById[id]
		end
	end
	return nil
end

local function findEgg(q: string): Pets.Egg?
	local key = squash(q)
	if key == "" then
		return nil
	end
	for _, id in Pets.EggOrder do
		local egg = Pets.Eggs[id]
		if squash(id) == key or squash(egg.Name) == key then
			return egg
		end
	end
	for _, id in Pets.EggOrder do
		if string.find(squash(Pets.Eggs[id].Name), key, 1, true) then
			return Pets.Eggs[id]
		end
	end
	return nil
end

local function findNiche(q: string): Niches.Niche?
	local key = squash(q)
	if key == "" then
		return nil
	end
	for _, n in Niches.List do
		if squash(n.Id) == key or squash(n.Name) == key then
			return n
		end
	end
	for _, n in Niches.List do
		if string.find(squash(n.Name), key, 1, true) or string.find(squash(n.Id), key, 1, true) then
			return n
		end
	end
	return nil
end

-- "vip" / "x2 views" / "DoubleViews" -> pass key; "all" -> every pass
local function findPasses(q: string): { string }?
	local key = squash(q)
	if key == "all" then
		local all = {}
		for _, p in Products.Passes do
			table.insert(all, p.Key)
		end
		return all
	end
	for _, p in Products.Passes do
		if squash(p.Key) == key or squash(p.Name) == key then
			return { p.Key }
		end
	end
	for _, p in Products.Passes do
		if string.find(squash(p.Key), key, 1, true) or string.find(squash(p.Name), key, 1, true) then
			return { p.Key }
		end
	end
	return nil
end

local function findProduct(q: string): Products.Product?
	local key = squash(q)
	for _, p in Products.Products do
		if squash(p.Key) == key or squash(p.Name) == key then
			return p
		end
	end
	for _, p in Products.Products do
		if string.find(squash(p.Key), key, 1, true) or string.find(squash(p.Name), key, 1, true) then
			return p
		end
	end
	return nil
end

local function listKeys(list: { any }, field: string): string
	local out = {}
	for _, item in list do
		table.insert(out, string.lower(item[field]))
	end
	return table.concat(out, ", ")
end

-- Highest Video that matters: every gate open and the final evolution.
local function endgameVideo(): number
	local best = Evolutions[#Evolutions].Video
	for _, w in Worlds do
		best = math.max(best, w.Gates[#w.Gates])
	end
	return best
end

-- Commands ----------------------------------------------------------------------------------------
local IMPL: { [string]: Impl } = {}

local function withData(fn: (target: Player, data: Data, args: Args, caller: Player) -> (boolean, string)): Impl
	return function(target: Player, args: Args, caller: Player): (boolean, string)
		local data = DataService.Get(target)
		if not data then
			return nope("isn't loaded yet")
		end
		return fn(target, data, args, caller)
	end
end

-- Progress ---------------------------------------------------------------------------------------------
IMPL.video = withData(function(target, data, args)
	local word: string = args[1]
	local current = Stats.VideoLevel(data.Views)
	if word == "rebirth" then
		local need = Stats.RebirthVideo(data.Rebirths)
		if need > Economy.Video.Max then
			return nope("can't reach the next rebirth (needs Video " .. need .. ") - use: rebirth")
		end
		local level = setVideo(target, data, math.max(current, need))
		return done("Video " .. level .. " - ready to rebirth")
	elseif word == "gates" then
		local w = Worlds[worldOf(target, data)]
		local level = setVideo(target, data, math.max(current, w.Gates[#w.Gates]))
		return done("Video " .. level .. " - every gate in " .. w.Name .. " is open")
	end
	local n = AdminCommands.ParseNumber(word)
	if not n then
		return nope("Video must be a number, rebirth or gates")
	end
	local level = setVideo(target, data, math.floor(n + 0.5))
	local capped = if n > Economy.Video.Max then " (max is " .. Economy.Video.Max .. ")" else ""
	return done("Video set to " .. level .. capped)
end)

IMPL.addvideo = withData(function(target, data, args)
	local level = setVideo(target, data, Stats.VideoLevel(data.Views) + args[1])
	return done("Video is now " .. level)
end)

IMPL.views = withData(function(target, data, args)
	local amount: number = args[1]
	if amount >= 0 then
		ProgressService.AddViews(target, amount)
	else
		setViews(target, data, data.Views + amount)
	end
	return done((if amount >= 0 then "+" else "") .. Format.Abbrev(amount) .. " views")
end)

IMPL.evo = withData(function(target, data, args)
	local word: string = args[1]
	local current = ProgressService.Tier(target)
	local n = if word == "next" or word == "+1"
		then current + 1
		elseif word == "prev" or word == "previous" or word == "-1" then current - 1
		else AdminCommands.ParseNumber(word)
	if not n then
		return nope("Evolution must be 1-" .. #Evolutions .. ", next or prev")
	end
	local tier = math.clamp(math.floor(n + 0.5), 1, #Evolutions)
	local evo = Evolutions[tier]
	setVideo(target, data, evo.Video)
	return done("Evolution " .. tier .. ": " .. evo.Title .. " (Video " .. evo.Video .. ")")
end)

IMPL.clout = withData(function(target, data, args)
	setClout(target, data, args[1])
	return done("Clout set to " .. Format.Abbrev(data.Clout))
end)

IMPL.addclout = withData(function(target, data, args)
	setClout(target, data, data.Clout + args[1])
	return done("Clout is now " .. Format.Abbrev(data.Clout))
end)

IMPL.tickets = withData(function(target, data, args)
	data.Tickets = math.clamp(math.floor(args[1]), 0, 1e6)
	DataService.Dirty(target, "Tickets")
	return done("Tickets set to " .. data.Tickets)
end)

IMPL.rebirths = withData(function(target, data, args)
	-- past this many rebirths the next one needs more than the max Video
	local cap = math.floor((Economy.Video.Max - Economy.Rebirth.BaseVideo) / Economy.Rebirth.VideoPerRebirth) + 1
	data.Rebirths = math.clamp(math.floor(args[1]), 0, cap)
	DataService.Dirty(target, "Rebirths")
	return done(
		"Rebirths set to " .. data.Rebirths .. " (views " .. Format.Mult(Stats.RebirthMultiplier(data.Rebirths)) .. ")"
	)
end)

IMPL.rebirth = function(target)
	if RivalService.InBattle(target) then
		return nope("is in a View War")
	end
	local r = RebirthService.Rebirth(target, true)
	return r.ok, if r.ok then "Rebirthed!" else (r.msg or "Couldn't rebirth")
end

IMPL.upgrade = withData(function(target, data, args)
	local which: string = args[1]
	local levelArg: string? = args[2]
	local chosen = {}
	for _, u in Upgrades do
		if which == "all" or squash(u.Id) == squash(which) or squash(u.Name) == squash(which) then
			table.insert(chosen, u)
		end
	end
	if #chosen == 0 then
		return nope("Upgrades: " .. listKeys(Upgrades, "Id") .. ", all")
	end
	local n = if levelArg and levelArg ~= "max" then AdminCommands.ParseNumber(levelArg) else nil
	if levelArg and levelArg ~= "max" and not n then
		return nope("Level must be a number or max")
	end
	local parts = {}
	for _, u in chosen do
		local level = if n then math.clamp(math.floor(n), 0, u.Max) else u.Max
		data.Upgrades[u.Id] = level
		table.insert(parts, u.Name .. " " .. level .. "/" .. u.Max)
	end
	DataService.Dirty(target, "Upgrades")
	return done(table.concat(parts, ", "))
end)

IMPL.max = withData(function(target, data)
	for _, w in Worlds do
		data.Unlocked[tostring(w.Id)] = true
		data.RivalsBeaten[tostring(w.Id)] = true
	end
	for _, d in Devices.List do
		data.Devices[d.Id] = true
	end
	data.Equipped = Devices.List[#Devices.List].Id
	for _, u in Upgrades do
		data.Upgrades[u.Id] = u.Max
	end
	data.Tickets = math.max(data.Tickets, 999)
	DataService.Dirty(target, "Unlocked", "RivalsBeaten", "Devices", "Equipped", "Upgrades", "Tickets")
	setClout(target, data, math.max(data.Clout, 1e15))
	for _, pass in Products.Passes do
		MonetizationService.GrantPass(target, pass.Key, true)
	end
	setVideo(target, data, math.max(Stats.VideoLevel(data.Views), endgameVideo()))
	return done("MAXED OUT! (undo passes with: unpass all)")
end)

IMPL.reset = withData(function(target, data, args)
	if args[1] ~= "confirm" then
		return nope("To wipe the save type: reset confirm")
	end
	if RivalService.InBattle(target) then
		return nope("is in a View War (use lose first)")
	end
	local fresh = DataService.Default()
	for k in data :: any do
		(data :: any)[k] = nil
	end
	local keys = {}
	for k, v in fresh :: any do
		(data :: any)[k] = v
		table.insert(keys, k)
	end
	DataService.Dirty(target, table.unpack(keys))
	ProgressService.Check(target, true)
	RewardService.SetGiftClock(target, 0)
	for _, attr in { "AdminSpeed", "AdminFly", "AdminNoclip" } do
		target:SetAttribute(attr, nil)
	end
	CharacterService.UpdatePetAttribute(target)
	CharacterService.SendToWorld(target, 1)
	task.spawn(function()
		if target.Parent then
			target:LoadCharacterAsync()
		end
	end)
	return done("Save wiped - fresh start!")
end)

-- World ----------------------------------------------------------------------------------------------
IMPL.world = withData(function(target, data, args)
	local n = math.floor(args[1])
	local w = Worlds[n]
	if not w then
		return nope("Worlds are 1-" .. #Worlds)
	end
	if RivalService.InBattle(target) then
		return nope("is in a View War")
	end
	if not data.Unlocked[tostring(n)] then
		data.Unlocked[tostring(n)] = true
		DataService.Dirty(target, "Unlocked")
	end
	MovementService.Grace(target, 1.5)
	CharacterService.SendToWorld(target, n)
	Comms.Effect(target, "World", { World = n })
	return done("Teleported to World " .. n .. ": " .. w.Name)
end)

IMPL.unlockworlds = withData(function(target, data)
	for _, w in Worlds do
		data.Unlocked[tostring(w.Id)] = true
	end
	DataService.Dirty(target, "Unlocked")
	return done("All " .. #Worlds .. " worlds unlocked")
end)

IMPL.gate = withData(function(target, data, args)
	local n = math.floor(args[1])
	local world = worldOf(target, data)
	local gate = (MapService.Gates[world] or {})[n]
	if not gate then
		return nope("Gates are 1-" .. #(MapService.Gates[world] or {}))
	end
	local ok, msg = teleport(target, gate.Part.CFrame * CFrame.new(0, -7, -12) * CFrame.Angles(0, math.pi, 0))
	if not ok then
		return ok, msg
	end
	local open = Stats.VideoLevel(data.Views) >= gate.Video
	return done("At gate " .. n .. " (needs Video " .. gate.Video .. (if open then ", open)" else ", locked)") .. msg)
end)

IMPL.pad = withData(function(target, data, args)
	local n = math.floor(args[1])
	local world = worldOf(target, data)
	for _, pad in (MapService.Pads[world] or {}) :: { MapService.Pad } do
		if pad.Gate == n then
			local ok, msg = teleport(target, above(pad.Part, 3.5))
			if not ok then
				return ok, msg
			end
			local open = Stats.OpenGates(data, world) >= n
			return done("On clout pad " .. n .. (if open then "" else " - its gate is locked, so no clout") .. msg)
		end
	end
	return nope("Pads are 1-" .. Stats.GatesPerWorld)
end)

IMPL["goto"] = withData(function(target, data, args, caller)
	local q: string = args[1]
	local place = PLACE_ALIASES[q]
	if place then
		local cf = placeCFrame(place, worldOf(target, data))
		if not cf then
			return nope("Couldn't find the " .. place .. " in this world")
		end
		local ok, msg = teleport(target, cf)
		return ok, if ok then "Teleported to " .. place .. msg else msg
	end
	-- not a place: teleport to a player
	local list, err = resolvePlayers(caller, q)
	if not list then
		return nope(
			(err or "") .. ". Places: spawn, arena, treadmills, devices, upgrades, rebirth, niche, eggs, portal"
		)
	end
	local other = list[1]
	if other == target then
		return nope("can't teleport to themselves")
	end
	local root = CharacterService.Root(other)
	if not root then
		return nope(other.Name .. " has no character")
	end
	local ok, msg = teleport(target, root.CFrame * CFrame.new(0, 0, 4))
	return ok, if ok then "Teleported to " .. other.DisplayName .. msg else msg
end)

IMPL.bring = function(caller, args)
	local list, err = resolvePlayers(caller, args[1])
	if not list then
		return nope(err or "No players")
	end
	local root = CharacterService.Root(caller)
	if not root then
		return nope("You have no character")
	end
	local names = {}
	for i, p in list do
		if p ~= caller then
			local ok = teleport(p, root.CFrame * CFrame.new((i - 1) * 4 - 6, 0, -5))
			if ok then
				table.insert(names, p.DisplayName)
				Comms.Notify(p, "🛠️ " .. caller.DisplayName .. " brought you to them", "info")
			end
		end
	end
	if #names == 0 then
		return nope("Nobody to bring")
	end
	return done("Brought " .. table.concat(names, ", "))
end

IMPL.spawn = withData(function(target, data)
	if RivalService.InBattle(target) then
		return nope("is in a View War")
	end
	MovementService.ToSpawn(target)
	return done("Back to spawn in " .. Worlds[data.World].Name)
end)

IMPL.speed = function(target, args)
	local v: number? = args[1]
	if v == nil or v <= 0 then
		target:SetAttribute("AdminSpeed", nil)
		CharacterService.ApplySpeed(target)
		return done("Normal walk speed")
	end
	local speed = math.clamp(math.floor(v), 1, 500)
	target:SetAttribute("AdminSpeed", speed)
	CharacterService.ApplySpeed(target)
	return done("Walk speed " .. speed .. " (type speed to reset)")
end

IMPL.fly = function(target)
	local on = target:GetAttribute("AdminFly") ~= true
	target:SetAttribute("AdminFly", if on then true else nil)
	return done(if on then "Flying ON (Space/E up, Q/Ctrl down)" else "Flying OFF")
end

IMPL.noclip = function(target)
	local on = target:GetAttribute("AdminNoclip") ~= true
	target:SetAttribute("AdminNoclip", if on then true else nil)
	return done(if on then "Noclip ON - walk through walls + locked gates" else "Noclip OFF")
end

IMPL.respawn = function(target)
	if RivalService.InBattle(target) then
		return nope("is in a View War")
	end
	task.spawn(function()
		if target.Parent then
			target:LoadCharacterAsync()
		end
	end)
	return done("Respawned")
end

-- Items -----------------------------------------------------------------------------------------------
IMPL.devices = withData(function(target, data)
	for _, d in Devices.List do
		data.Devices[d.Id] = true
	end
	data.Equipped = Devices.List[#Devices.List].Id
	DataService.Dirty(target, "Devices", "Equipped")
	return done("All " .. #Devices.List .. " devices (holding the " .. Devices.List[#Devices.List].Name .. ")")
end)

IMPL.device = withData(function(target, data, args)
	local d = findDevice(args[1])
	if not d then
		return nope("No device matches '" .. tostring(args[1]) .. "' (try 1-" .. #Devices.List .. ")")
	end
	data.Devices[d.Id] = true
	data.Equipped = d.Id
	DataService.Dirty(target, "Devices", "Equipped")
	return done("#" .. d.Index .. " " .. d.Name .. " (" .. Format.Mult(d.Value) .. " views per step)")
end)

IMPL.cleardevices = withData(function(target, data)
	data.Devices = { [Devices.Starter] = true }
	data.Equipped = Devices.Starter
	DataService.Dirty(target, "Devices", "Equipped")
	return done("Devices cleared")
end)

IMPL.niche = withData(function(target, data, args)
	if args[1] == "none" then
		data.Niche = ""
		DataService.Dirty(target, "Niche")
		return done("Niche removed")
	end
	local n = findNiche(args[1])
	if not n then
		return nope("Niches: none, " .. listKeys(Niches.List, "Id"))
	end
	data.Niche = n.Id
	DataService.Dirty(target, "Niche")
	return done("Niche: " .. n.Emoji .. " " .. n.Name .. " (" .. n.Rarity .. ", " .. Format.Mult(n.Mult) .. ")")
end)

IMPL.pity = withData(function(target, data, args)
	data.NichePity = math.clamp(math.floor(args[1]), 0, Niches.PityRolls)
	DataService.Dirty(target, "NichePity")
	return done("Niche pity " .. data.NichePity .. "/" .. Niches.PityRolls)
end)

IMPL.potion = withData(function(target, data, args)
	local kind: string = args[1]
	if kind ~= "views" and kind ~= "clout" and kind ~= "all" then
		return nope("Potions: views, clout, all")
	end
	local minutes: number = if args[2] ~= nil then args[2] else 15
	local seconds = math.clamp(math.floor(minutes * 60), 0, 7 * 86400)
	if kind == "views" or kind == "all" then
		data.Potions.Views = seconds
	end
	if kind == "clout" or kind == "all" then
		data.Potions.Clout = seconds
	end
	DataService.Dirty(target, "Potions")
	if seconds == 0 then
		return done("Potions cleared")
	end
	return done("x2 " .. string.upper(kind) .. " potion for " .. Format.Duration(seconds))
end)

IMPL.friends = function(target, args)
	local ctx = DataService.Context(target)
	ctx.Friends = math.clamp(math.floor(args[1]), 0, 10)
	DataService.ContextDirty(target)
	return done("Friends boost: " .. ctx.Friends .. " friends (resets when someone joins or leaves)")
end

IMPL.premium = function(target)
	local ctx = DataService.Context(target)
	ctx.Premium = not ctx.Premium
	DataService.ContextDirty(target)
	return done("Premium boost " .. (if ctx.Premium then "ON" else "OFF"))
end

IMPL.group = function(target)
	local ctx = DataService.Context(target)
	ctx.Group = not ctx.Group
	DataService.ContextDirty(target)
	return done("Group boost " .. (if ctx.Group then "ON" else "OFF"))
end

-- Pets --------------------------------------------------------------------------------------------------
IMPL.pet = withData(function(target, data, args)
	local pet = findPet(args[1])
	if not pet then
		return nope("No pet matches '" .. tostring(args[1]) .. "'")
	end
	local count = math.clamp(math.floor(args[2] or 1), 1, Economy.Pets.InventoryMax)
	local given = PetService.Give(target, pet.Id, count)
	if given == 0 then
		return nope("has a full pet inventory (" .. #data.Pets .. "/" .. Economy.Pets.InventoryMax .. ")")
	end
	return done("+" .. given .. " " .. pet.Name .. " (" .. pet.Rarity .. ", +" .. Format.Abbrev(pet.Bonus) .. "%)")
end)

IMPL.allpets = withData(function(target, data)
	local given = 0
	for _, id in allPetIds() do
		given += PetService.Give(target, id, 1)
	end
	if given == 0 then
		return nope("has a full pet inventory (" .. #data.Pets .. "/" .. Economy.Pets.InventoryMax .. ")")
	end
	return done("+" .. given .. " pets (best ones equipped)")
end)

IMPL.secretpet = withData(function(target)
	for _, id in allPetIds() do
		local pet = Pets.ById[id]
		if pet.Rarity == "Secret" then
			if PetService.Give(target, id, 1) == 0 then
				return nope("has a full pet inventory")
			end
			return done("+1 " .. pet.Name .. " (SECRET, +" .. Format.Abbrev(pet.Bonus) .. "%)")
		end
	end
	return nope("No Secret pet in Config/Pets")
end)

IMPL.clearpets = withData(function(target, data)
	data.Pets = {}
	data.EquippedPets = {}
	DataService.Dirty(target, "Pets", "EquippedPets")
	return done("All pets deleted")
end)

IMPL.hatch = withData(function(target, data, args)
	local egg = findEgg(args[1])
	if not egg then
		return nope("Eggs: " .. table.concat(Pets.EggOrder, ", "))
	end
	local space = Economy.Pets.InventoryMax - #data.Pets
	if space < 1 then
		return nope("has a full pet inventory")
	end
	local count = math.clamp(math.floor(args[2] or 1), 1, space)
	local names: { [string]: number } = {}
	local order = {}
	local best = ""
	local bestChance = math.huge
	for _ = 1, count do
		local id = PetService.Roll(egg)
		if PetService.Give(target, id, 1) == 1 then
			local pet = Pets.ById[id]
			if not names[pet.Name] then
				table.insert(order, pet.Name)
			end
			names[pet.Name] = (names[pet.Name] or 0) + 1
			if pet.Chance < bestChance then
				best, bestChance = pet.Rarity .. " " .. pet.Name, pet.Chance
			end
		end
	end
	data.Stats.Hatched += count
	DataService.Dirty(target, "Stats")
	local parts = {}
	for _, name in order do
		table.insert(parts, names[name] .. "x " .. name)
	end
	return done("Hatched " .. table.concat(parts, ", ") .. " - best: " .. best)
end)

-- Rewards ------------------------------------------------------------------------------------------------
IMPL.gifts = function(target)
	if not RewardService.SetGiftClock(target, RewardService.LastGiftSeconds() + 5) then
		return nope("isn't loaded yet")
	end
	return done("All " .. #Rewards.Gifts .. " gifts are ready - open GIFTS")
end

IMPL.resetgifts = function(target)
	if not RewardService.SetGiftClock(target, 0) then
		return nope("isn't loaded yet")
	end
	return done("Gifts locked, timer restarted")
end

IMPL.daily = withData(function(target, data, args)
	local day: number? = args[1]
	if day ~= nil then
		local d = math.clamp(math.floor(day), 1, #Rewards.Daily)
		data.Daily.Streak = d - 1
	end
	-- just past the cooldown, still inside the streak window
	data.Daily.Last = math.max(1, os.time() - Rewards.DailyCooldown - 5)
	DataService.Dirty(target, "Daily")
	return done("Daily reward ready (next claim = Day " .. (data.Daily.Streak % #Rewards.Daily) + 1 .. ")")
end)

IMPL.resetcodes = withData(function(target, data)
	data.Codes = {}
	DataService.Dirty(target, "Codes")
	return done("Codes can be redeemed again")
end)

IMPL.tutorial = withData(function(target, data)
	data.Tutorial = false
	DataService.Dirty(target, "Tutorial")
	return done("Tutorial restarted")
end)

-- Rivals ---------------------------------------------------------------------------------------------------
IMPL.fight = withData(function(target, data)
	local world = worldOf(target, data)
	local r = RivalService.ForceStart(target, world)
	if not r.ok then
		return nope(r.msg or "Couldn't start the View War")
	end
	return done("VIEW WAR vs " .. Worlds[world].Rival.Name .. "! (win / lose to end it)")
end)

IMPL.win = function(target)
	if not RivalService.ForceResult(target, true) then
		return nope("isn't in a View War (start one with fight)")
	end
	return done("Winning the View War...")
end

IMPL.lose = function(target)
	if not RivalService.ForceResult(target, false) then
		return nope("isn't in a View War (start one with fight)")
	end
	return done("Losing the View War...")
end

IMPL.beat = withData(function(target, data, args)
	local which: string? = args[1]
	local list = {}
	if which == nil or which == "here" or which == "this" then
		table.insert(list, worldOf(target, data))
	elseif which == "all" then
		for _, w in Worlds do
			table.insert(list, w.Id)
		end
	else
		local n = tonumber(which)
		if not n or not Worlds[math.floor(n)] then
			return nope("beat <1-" .. #Worlds .. " | all | here>")
		end
		table.insert(list, math.floor(n))
	end
	local names = {}
	for _, w in list do
		data.RivalsBeaten[tostring(w)] = true
		local nextWorld = Worlds[w + 1]
		if nextWorld then
			data.Unlocked[tostring(nextWorld.Id)] = true
		end
		table.insert(names, Worlds[w].Rival.Name)
	end
	DataService.Dirty(target, "RivalsBeaten", "Unlocked")
	return done("Beaten: " .. table.concat(names, ", "))
end)

IMPL.resetrivals = withData(function(target, data)
	if RivalService.InBattle(target) then
		return nope("is in a View War")
	end
	data.RivalsBeaten = {}
	data.RivalCooldowns = {}
	data.Unlocked = { ["1"] = true }
	DataService.Dirty(target, "RivalsBeaten", "RivalCooldowns", "Unlocked")
	if data.World ~= 1 then
		MovementService.Grace(target, 1.5)
		CharacterService.SendToWorld(target, 1)
	end
	return done("Rivals reset - worlds 2-" .. #Worlds .. " locked again")
end)

IMPL.nocooldown = withData(function(target, data)
	data.RivalCooldowns = {}
	DataService.Dirty(target, "RivalCooldowns")
	return done("Rival cooldowns cleared")
end)

-- Robux ---------------------------------------------------------------------------------------------------
IMPL.pass = function(target, args)
	local keys = findPasses(args[1])
	if not keys then
		return nope("Passes: " .. listKeys(Products.Passes, "Key") .. ", all")
	end
	for _, key in keys do
		MonetizationService.GrantPass(target, key, #keys > 1)
	end
	return done("Gave " .. table.concat(keys, ", ") .. " (this session)")
end

IMPL.unpass = function(target, args)
	local keys = findPasses(args[1])
	if not keys then
		return nope("Passes: " .. listKeys(Products.Passes, "Key") .. ", all")
	end
	for _, key in keys do
		MonetizationService.RevokePass(target, key)
	end
	-- fewer pet slots? unequip the extras
	local data = DataService.Get(target)
	if data then
		local slots = Stats.PetSlots(DataService.Context(target))
		if #data.EquippedPets > slots then
			while #data.EquippedPets > slots do
				table.remove(data.EquippedPets)
			end
			DataService.Dirty(target, "EquippedPets")
		end
	end
	return done("Removed " .. table.concat(keys, ", ") .. " (this session)")
end

IMPL.product = function(target, args)
	local product = findProduct(args[1])
	if not product then
		return nope("Products: " .. listKeys(Products.Products, "Key"))
	end
	if not MonetizationService.GrantProduct(target, product) then
		return nope("isn't loaded yet")
	end
	return done("Test purchase: " .. product.Name)
end

-- Server ----------------------------------------------------------------------------------------------------
IMPL.announce = function(caller, args)
	local message = string.sub(args[1], 1, 150)
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(message, caller.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or typeof(filtered) ~= "string" then
		return nope("Couldn't filter that message, try again")
	end
	Comms.NotifyAll("📢 " .. caller.DisplayName .. ": " .. filtered, "reward")
	return done("Announced")
end

IMPL.fx = withData(function(target, data, args)
	local name: string = args[1]
	local ctx = DataService.Context(target)
	local world = worldOf(target, data)
	if name == "video" then
		local level = Stats.VideoLevel(data.Views)
		Comms.Effect(target, "Video", { Level = level, From = level - 1 })
	elseif name == "evolve" then
		Comms.Effect(target, "Evolve", { Tier = ProgressService.Tier(target) })
		Comms.EffectAll("EvolveOther", { UserId = target.UserId, Tier = ProgressService.Tier(target) })
	elseif name == "rebirth" then
		Comms.Effect(
			target,
			"Rebirth",
			{ Rebirths = data.Rebirths, Multiplier = Stats.RebirthMultiplier(data.Rebirths) }
		)
	elseif name == "claim" then
		local gate = math.max(Stats.OpenGates(data, world), 1)
		Comms.Effect(target, "Claim", { Amount = Stats.PadReward(data, ctx, world, gate), World = world, Gate = gate })
	elseif name == "world" then
		Comms.Effect(target, "World", { World = world })
	elseif name == "reward" then
		Comms.Effect(target, "Reward", { Text = "🎁 Test reward" })
	elseif name == "purchase" then
		Comms.Effect(target, "Purchase", { Kind = "Pass", Id = "VIP" })
	else
		return nope("Effects: video, evolve, rebirth, claim, world, reward, purchase")
	end
	return done("Played " .. name .. " effect")
end)

IMPL.stats = withData(function(target, data)
	local ctx = DataService.Context(target)
	local level, into, need = Stats.Video(data.Views)
	local tier = ProgressService.Tier(target)
	local niche = Niches.ById[data.Niche]
	local passes = {}
	for key, owned in ctx.Passes do
		if owned then
			table.insert(passes, key)
		end
	end
	table.sort(passes)
	local lines = {
		string.format(
			"VIDEO %d (%s/%s) • EVO %d %s • World %d",
			level,
			Format.Abbrev(into),
			Format.Abbrev(need),
			tier,
			Evolutions[tier].Title,
			data.World
		),
		string.format(
			"Views %s (lifetime %s) • Clout %s • Tickets %d",
			Format.Abbrev(data.Views),
			Format.Abbrev(data.TotalViews),
			Format.Abbrev(data.Clout),
			data.Tickets
		),
		string.format(
			"Rebirths %d • Views/step %s (%s) • Clout %s • Pets +%s%% • Niche %s",
			data.Rebirths,
			Format.Abbrev(Stats.ViewsPerStep(data, ctx)),
			Format.Mult(Stats.ViewsMultiplier(data, ctx)),
			Format.Mult(Stats.CloutMultiplier(data, ctx)),
			Format.Abbrev(Stats.PetBonus(data)),
			if niche then niche.Name else "none"
		),
		"Passes: " .. (if #passes > 0 then table.concat(passes, ", ") else "none"),
	}
	return done(table.concat(lines, "\n"))
end)

IMPL.save = function(target)
	if not DataService.Persistent then
		return nope("Saving is off in Studio test mode (turn on Studio Access to API Services)")
	end
	if DataService.SaveNow(target) then
		return done("Saved")
	end
	return nope("Save failed - check the Output window")
end

IMPL.lb = function()
	if not LeaderboardService.RefreshNow() then
		return nope("Global leaderboards need a published game with API access")
	end
	return done("Refreshing the global leaderboards...")
end

IMPL.cmds = function()
	return done("Open the 🛠️ ADMIN panel → COMMANDS, or press ; and start typing")
end

-- Parsing + running ---------------------------------------------------------------------------------
-- Returns (ok, message). Never errors.
function AdminService.Run(caller: Player, raw: string): (boolean, string)
	local parsed, err = AdminCommands.Parse(raw)
	if not parsed then
		return nope(err or "Bad command")
	end
	local command = parsed.Command
	local args = parsed.Args
	local text = parsed.Text
	local impl = IMPL[command.Name]
	if not impl then
		return nope(command.Name .. " isn't implemented")
	end
	local targets = { caller }
	if parsed.Target then
		local list, targetErr = resolvePlayers(caller, parsed.Target)
		if not list then
			return nope(targetErr or "Unknown player")
		end
		targets = list
	end

	print("[Admin] " .. caller.Name .. " > " .. text)
	local okCount = 0
	local messages = {}
	for _, target in targets do
		local ran, ok, msg = pcall(impl, target, args, caller)
		if not ran then
			warn("[Admin] " .. command.Name .. " failed: " .. tostring(ok))
			ok, msg = false, "error (see Output)"
		end
		if ok then
			okCount += 1
			if target ~= caller then
				Comms.Notify(
					target,
					"🛠️ " .. caller.DisplayName .. " used '" .. command.Name .. "' on you",
					"info"
				)
			end
		end
		-- failures like "is in a View War" read as "<name> is in a View War"
		local line = msg or ""
		if not ok and string.match(line, "^%l") then
			line = target.DisplayName .. " " .. line
		elseif target ~= caller then
			line = target.DisplayName .. ": " .. line
		end
		if #targets == 1 or not ok then
			table.insert(messages, line)
		end
	end
	if #targets > 1 then
		table.insert(messages, 1, command.Name .. " ran for " .. okCount .. "/" .. #targets .. " players")
	end
	return okCount > 0, table.concat(messages, "\n")
end

-- Lifecycle ---------------------------------------------------------------------------------------------
local function watchChat(player: Player)
	-- ";clout 1m" in chat (the "/" versions are client chat commands)
	player.Chatted:Connect(function(message: string)
		if string.sub(message, 1, 1) == ";" and AdminService.IsAdmin(player) then
			local ok, msg = AdminService.Run(player, message)
			Comms.Notify(player, "🛠️ " .. msg, if ok then "success" else "error")
		end
	end)
end

function AdminService.Init()
	for _, c in AdminCommands.List do
		if not IMPL[c.Name] then
			warn("[Admin] no implementation for command '" .. c.Name .. "'")
		end
	end
	Comms.On("Admin", 10, function(player, payload)
		if not AdminService.IsAdmin(player) then
			return Comms.Fail("Not an admin")
		end
		local text = Comms.String(payload.Text, 300)
		if not text then
			return Comms.Fail("Bad command")
		end
		local ok, msg = AdminService.Run(player, text)
		if ok then
			return Comms.Ok({ Text = msg })
		end
		return Comms.Fail(msg)
	end)
end

function AdminService.Start()
	DataService.Loaded:Connect(function(player: Player)
		-- a failed group lookup isn't cached, so retry a few times
		for _ = 1, 4 do
			if AdminService.IsAdmin(player) then
				player:SetAttribute("Admin", true)
				return
			end
			if adminCache[player] ~= nil or not player.Parent then
				return
			end
			task.wait(5)
		end
	end)
	Players.PlayerAdded:Connect(watchChat)
	for _, player in Players:GetPlayers() do
		watchChat(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		adminCache[player] = nil
	end)
end

return AdminService
