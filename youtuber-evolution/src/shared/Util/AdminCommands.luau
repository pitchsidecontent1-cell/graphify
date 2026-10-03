--!strict
-- Admin command definitions, shared by the server (which runs them, see
-- Services/AdminService) and the client (chat commands, the command bar's
-- autocomplete, and the Commands list in the admin panel).
--
-- Syntax:  command arg1 arg2 [player]
--   numbers accept 1k / 2.5m / 3b / 1t / 1qa / 1e12 / 1,000
--   [player] = me (default) | all | others | part of a name

local AdminCommands = {}

export type ArgKind = "number" | "int" | "word" | "text" | "player"
-- Accept: for an optional word right before [player], says whether a token is
-- this argument (otherwise it's read as the player): "upgrade all bob".
export type Arg = { Name: string, Kind: ArgKind, Optional: boolean?, Accept: ((token: string) -> boolean)? }
export type Command = {
	Name: string,
	Aliases: { string },
	Category: string,
	Args: { Arg },
	Target: boolean, -- accepts a trailing [player] (defaults to you)
	Help: string,
}

AdminCommands.Categories = { "Progress", "World", "Items", "Pets", "Rewards", "Rivals", "Robux", "Server" }

local function a(name: string, kind: ArgKind, optional: boolean?, accept: ((string) -> boolean)?): Arg
	return { Name = name, Kind = kind, Optional = optional, Accept = accept }
end

-- forward declared; defined below (ParseNumber)
local isNumber: (string) -> boolean

local function oneOf(...: string): (string) -> boolean
	local set: { [string]: boolean } = {}
	for _, v in { ... } do
		set[v] = true
	end
	return function(token: string): boolean
		return set[string.lower(token)] == true or isNumber(token)
	end
end

local function cmd(
	category: string,
	name: string,
	aliases: { string },
	args: { Arg },
	target: boolean,
	help: string
): Command
	return { Name = name, Aliases = aliases, Category = category, Args = args, Target = target, Help = help }
end

AdminCommands.List = {
	-- Progress -------------------------------------------------------------------------------
	cmd(
		"Progress",
		"video",
		{ "setvideo", "vid" },
		{ a("level|rebirth|gates", "word") },
		true,
		"Set the Video level (1-400). rebirth / gates = just enough to rebirth / open every gate here"
	),
	cmd("Progress", "addvideo", { "av" }, { a("amount", "int") }, true, "Add (or remove, with -) Video levels"),
	cmd("Progress", "views", { "addviews" }, { a("amount", "number") }, true, "Add views (1k, 2.5m, 1e9...)"),
	cmd(
		"Progress",
		"evo",
		{ "evolve", "tier" },
		{ a("tier|next|prev", "word") },
		true,
		"Jump to an Evolution tier (1-20), or the next / previous one"
	),
	cmd("Progress", "clout", { "setclout" }, { a("amount", "number") }, true, "Set your clout"),
	cmd("Progress", "addclout", { "ac" }, { a("amount", "number") }, true, "Add clout"),
	cmd("Progress", "tickets", { "tix" }, { a("amount", "int") }, true, "Set your Niche Tickets"),
	cmd(
		"Progress",
		"rebirths",
		{ "setrebirths" },
		{ a("count", "int") },
		true,
		"Set the rebirth count, 0-77 (keeps views)"
	),
	cmd("Progress", "rebirth", { "rb" }, {}, true, "Rebirth right now (no Video needed)"),
	cmd(
		"Progress",
		"upgrade",
		{ "upg" },
		{ a("speed|clout|treadmill|all", "word"), a("level|max", "word", true, oneOf("max")) },
		true,
		"Set an upgrade level (default max)"
	),
	cmd(
		"Progress",
		"max",
		{ "maxall" },
		{},
		true,
		"Max everything: worlds, rivals, devices, upgrades, video, clout, passes"
	),
	cmd("Progress", "reset", { "wipe" }, { a("confirm", "word") }, true, "Wipe a save back to a new player"),

	-- World -----------------------------------------------------------------------------------
	cmd("World", "world", { "tpworld" }, { a("1-4", "int") }, true, "Unlock + teleport to a world"),
	cmd("World", "unlockworlds", { "worlds" }, {}, true, "Unlock every world"),
	cmd("World", "gate", { "tpgate" }, { a("1-15", "int") }, true, "Teleport in front of a gate in your world"),
	cmd("World", "pad", { "tppad" }, { a("1-15", "int") }, true, "Teleport onto a clout pad (claims it if open)"),
	cmd(
		"World",
		"goto",
		{ "tp", "to" },
		{ a("place|player", "word") },
		true,
		"Teleport to spawn, arena, treadmills, devices, upgrades, rebirth, niche, eggs, portal - or to a player"
	),
	cmd("World", "bring", {}, { a("player", "player") }, false, "Bring players to you"),
	cmd("World", "spawn", { "home" }, {}, true, "Back to your world's spawn"),
	cmd("World", "speed", { "ws" }, { a("speed", "number", true) }, true, "Walk speed override (no number = normal)"),
	cmd("World", "fly", {}, {}, true, "Toggle flying (WASD + camera, Space/E up, Q/Ctrl down)"),
	cmd("World", "noclip", { "ghost" }, {}, true, "Toggle walking through walls and locked gates"),
	cmd("World", "respawn", { "re", "refresh" }, {}, true, "Respawn your character"),

	-- Items -----------------------------------------------------------------------------------
	cmd("Items", "devices", { "alldevices" }, {}, true, "Own every device + equip the best"),
	cmd("Items", "device", { "givedevice" }, { a("number|id|name", "word") }, true, "Give + equip one device"),
	cmd("Items", "cleardevices", {}, {}, true, "Back to just the starter device"),
	cmd("Items", "niche", { "setniche" }, { a("name|none", "word") }, true, "Set your niche"),
	cmd("Items", "pity", {}, { a("count", "int") }, true, "Set the niche pity counter (50 = next roll Epic+)"),
	cmd(
		"Items",
		"potion",
		{ "boost" },
		{ a("views|clout|all", "word"), a("minutes", "number", true) },
		true,
		"Give an x2 potion (0 minutes clears it)"
	),
	cmd("Items", "friends", {}, { a("count", "int") }, true, "Fake the friends-in-server boost (0-10)"),
	cmd("Items", "premium", {}, {}, true, "Toggle the Premium boost"),
	cmd("Items", "group", {}, {}, true, "Toggle the group boost"),

	-- Pets ------------------------------------------------------------------------------------
	cmd(
		"Pets",
		"pet",
		{ "givepet" },
		{ a("name|id", "word"), a("count", "int", true) },
		true,
		"Give a pet (names without spaces: galaxydragon)"
	),
	cmd("Pets", "allpets", {}, {}, true, "One of every pet (equips the best)"),
	cmd("Pets", "secretpet", { "algopet" }, {}, true, "Give The Algo Pet (Secret)"),
	cmd("Pets", "clearpets", {}, {}, true, "Delete every pet"),
	cmd("Pets", "hatch", {}, { a("egg", "word"), a("count", "int", true) }, true, "Free hatch with the real odds"),

	-- Rewards ---------------------------------------------------------------------------------
	cmd("Rewards", "gifts", { "readygifts" }, {}, true, "Make every playtime gift claimable now"),
	cmd("Rewards", "resetgifts", {}, {}, true, "Lock the gifts again + restart the timer"),
	cmd("Rewards", "daily", {}, { a("day 1-7", "int", true) }, true, "Make the daily reward claimable now"),
	cmd("Rewards", "resetcodes", { "codes" }, {}, true, "Let codes be redeemed again"),
	cmd("Rewards", "tutorial", {}, {}, true, "Replay the tutorial"),

	-- Rivals ----------------------------------------------------------------------------------
	cmd("Rivals", "fight", { "battle", "war" }, {}, true, "Start this world's View War now (no requirements)"),
	cmd("Rivals", "win", {}, {}, true, "Instantly win the current View War"),
	cmd("Rivals", "lose", {}, {}, true, "Instantly lose the current View War"),
	cmd(
		"Rivals",
		"beat",
		{},
		{ a("world|all|here", "word", true, oneOf("all", "here", "this")) },
		true,
		"Mark a rival beaten + unlock the next world (default: this world)"
	),
	cmd("Rivals", "resetrivals", {}, {}, true, "Un-beat every rival and lock worlds 2-4"),
	cmd("Rivals", "nocooldown", { "nocd" }, {}, true, "Clear rival rematch cooldowns"),

	-- Robux -----------------------------------------------------------------------------------
	cmd("Robux", "pass", { "givepass" }, { a("pass|all", "word") }, true, "Give a game pass (this session only)"),
	cmd("Robux", "unpass", { "revokepass" }, { a("pass|all", "word") }, true, "Remove a game pass (this session)"),
	cmd("Robux", "product", { "buy" }, { a("product", "word") }, true, "Test a dev product without paying"),

	-- Server ----------------------------------------------------------------------------------
	cmd("Server", "announce", { "say", "m" }, { a("message", "text") }, false, "Message everyone in the server"),
	cmd(
		"Server",
		"fx",
		{ "effect" },
		{ a("video|evolve|rebirth|claim|world|reward|purchase", "word") },
		true,
		"Play a celebration effect"
	),
	cmd("Server", "stats", { "info" }, {}, true, "Show stats + multipliers"),
	cmd("Server", "save", {}, {}, true, "Save now"),
	cmd("Server", "lb", { "leaderboards" }, {}, false, "Refresh the global leaderboards now"),
	cmd("Server", "cmds", { "commands", "help", "?" }, {}, false, "List every command"),
} :: { Command }

-- Lookup by name or alias (lower case).
AdminCommands.ByName = {} :: { [string]: Command }
for _, c in AdminCommands.List do
	AdminCommands.ByName[c.Name] = c
	for _, alias in c.Aliases do
		AdminCommands.ByName[alias] = c
	end
end

function AdminCommands.Find(name: string): Command?
	return AdminCommands.ByName[string.lower(name)]
end

-- "clout <amount> [player]"
function AdminCommands.Usage(c: Command): string
	local parts = { c.Name }
	for _, arg in c.Args do
		table.insert(parts, if arg.Optional then "[" .. arg.Name .. "]" else "<" .. arg.Name .. ">")
	end
	if c.Target then
		table.insert(parts, "[player]")
	end
	return table.concat(parts, " ")
end

-- Strips a leading / ; : and surrounding spaces.
function AdminCommands.Clean(text: string): string
	local s = string.gsub(text, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	s = string.gsub(s, "^[/;:]+", "")
	return s
end

function AdminCommands.Split(text: string): { string }
	local tokens = {}
	for token in string.gmatch(text, "%S+") do
		table.insert(tokens, token)
	end
	return tokens
end

local SUFFIX: { [string]: number } = {
	k = 1e3,
	m = 1e6,
	b = 1e9,
	t = 1e12,
	qa = 1e15,
	qi = 1e18,
	sx = 1e21,
	sp = 1e24,
	oc = 1e27,
	no = 1e30,
	dc = 1e33,
}

AdminCommands.MaxNumber = 1e60

-- "2.5m" -> 2500000. Returns nil for anything that isn't a finite number.
function AdminCommands.ParseNumber(token: string): number?
	local s = string.lower((string.gsub(token, ",", "")))
	local n = tonumber(s)
	if not n then
		local num, suffix = string.match(s, "^([%+%-]?[%d%.]+)(%a+)$")
		local mult = suffix and SUFFIX[suffix]
		local base = num and tonumber(num)
		if mult and base then
			n = base * mult
		end
	end
	if not n or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return math.clamp(n, -AdminCommands.MaxNumber, AdminCommands.MaxNumber)
end

isNumber = function(token: string): boolean
	return AdminCommands.ParseNumber(token) ~= nil
end

export type Parsed = {
	Command: Command,
	Args: { any }, -- by position; optional args left out are nil
	Target: string?, -- trailing [player] word, if any
	Text: string, -- cleaned input
}

-- Parse "clout 2.5m bob" -> { Command = clout, Args = { 2500000 }, Target = "bob" }.
-- Returns nil + a message that explains the right usage on bad input.
function AdminCommands.Parse(raw: string): (Parsed?, string?)
	local text = AdminCommands.Clean(raw)
	local tokens = AdminCommands.Split(text)
	if #tokens == 0 then
		return nil, "Type a command (try: cmds)"
	end
	local command = AdminCommands.Find(tokens[1])
	if not command then
		return nil, "Unknown command '" .. tokens[1] .. "' (try: cmds)"
	end
	local usage = "Usage: " .. AdminCommands.Usage(command)
	local args: { any } = {}
	local i = 2
	for index, spec in command.Args do
		local token = tokens[i]
		if spec.Kind == "text" then
			local rest = string.match(text, "^%S+%s+(.+)$")
			if not rest then
				return nil, usage
			end
			args[index] = rest
			i = #tokens + 1
		elseif token == nil then
			if not spec.Optional then
				return nil, usage
			end
		elseif spec.Kind == "number" or spec.Kind == "int" then
			local n = AdminCommands.ParseNumber(token)
			if n == nil then
				-- an optional number followed by nothing else: the word is the [player]
				if not (spec.Optional and command.Target and i == #tokens) then
					return nil, "'" .. token .. "' isn't a number. " .. usage
				end
			else
				args[index] = if spec.Kind == "int" then math.floor(n + 0.5) else n
				i += 1
			end
		elseif spec.Optional and command.Target and i == #tokens and spec.Accept and not spec.Accept(token) then
			-- "upgrade all bob": the last word is the [player], not this argument
			continue
		else -- word / player
			args[index] = string.lower(token)
			i += 1
		end
	end
	local target: string? = nil
	if command.Target and tokens[i] then
		target = tokens[i]
		i += 1
	end
	if tokens[i] then
		return nil, "Too many words. " .. usage
	end
	return { Command = command, Args = args, Target = target, Text = text }, nil
end

return AdminCommands
