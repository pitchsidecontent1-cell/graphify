--!strict
-- Every progression formula in one place, shared by server (authoritative)
-- and client (display). Pure functions of the player's data + context.

local Config = script.Parent.Parent.Config
local Economy = require(Config.Economy)
local Devices = require(Config.Devices)
local Evolutions = require(Config.Evolutions)
local Pets = require(Config.Pets)
local Niches = require(Config.Niches)
local Worlds = require(Config.Worlds)
local Upgrades = require(Config.Upgrades)
local Types = require(script.Parent.Types)

type Data = Types.Data
type Context = Types.Context

local Stats = {}

Stats.GatesPerWorld = 15

-- Video curve ------------------------------------------------------------------
-- cumulative[n] = total views needed to be at Video n (cumulative[1] = 0)
local cumulative: { number } = { 0 }
do
	local cfg = Economy.Video
	for n = 2, cfg.Max + 1 do
		cumulative[n] = cumulative[n - 1] + math.floor(cfg.Base * cfg.Growth ^ (n - 2))
	end
end

function Stats.ViewsForVideo(level: number): number
	local n = math.clamp(math.floor(level), 1, #cumulative)
	return cumulative[n]
end

-- Returns level, views into current level, views needed for next level
function Stats.Video(views: number): (number, number, number)
	local lo, hi = 1, #cumulative
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if cumulative[mid] <= views then
			lo = mid
		else
			hi = mid - 1
		end
	end
	local level = lo
	local base = cumulative[level]
	local nextAt = cumulative[level + 1] or base
	return level, views - base, nextAt - base
end

function Stats.VideoLevel(views: number): number
	local level = Stats.Video(views)
	return level
end

-- Evolution ------------------------------------------------------------------------
function Stats.EvolutionTier(video: number): number
	local tier = 1
	for _, evo in Evolutions do
		if video >= evo.Video then
			tier = evo.Tier
		end
	end
	return tier
end

function Stats.Evolution(video: number): Evolutions.Evolution
	return Evolutions[Stats.EvolutionTier(video)]
end

function Stats.NextEvolution(video: number): Evolutions.Evolution?
	return Evolutions[Stats.EvolutionTier(video) + 1]
end

-- Rebirth -----------------------------------------------------------------------------
function Stats.RebirthVideo(rebirths: number): number
	local cfg = Economy.Rebirth
	return cfg.BaseVideo + cfg.VideoPerRebirth * rebirths
end

function Stats.RebirthMultiplier(rebirths: number): number
	return Economy.Rebirth.Multiplier ^ rebirths
end

function Stats.CanRebirth(data: Data): boolean
	return Stats.VideoLevel(data.Views) >= Stats.RebirthVideo(data.Rebirths)
end

-- Devices -----------------------------------------------------------------------------
function Stats.DeviceValue(data: Data): number
	local device = Devices.ById[data.Equipped]
	if device and data.Devices[device.Id] then
		return device.Value
	end
	return 1
end

function Stats.BestOwnedDevice(data: Data): Devices.Device
	local best = Devices.ById[Devices.Starter]
	for id in data.Devices do
		local d = Devices.ById[id]
		if d and d.Index > best.Index then
			best = d
		end
	end
	return best
end

-- Pets ----------------------------------------------------------------------------------
function Stats.PetSlots(ctx: Context): number
	local slots = Economy.Pets.BaseSlots
	if ctx.Passes.PetSlots then
		slots += Economy.Pets.PassSlots
	end
	return slots
end

function Stats.FindPet(data: Data, uid: string): Types.PetItem?
	for _, item in data.Pets do
		if item.Uid == uid then
			return item
		end
	end
	return nil
end

function Stats.PetBonus(data: Data): number
	local total = 0
	for _, uid in data.EquippedPets do
		local item = Stats.FindPet(data, uid)
		if item then
			local def = Pets.ById[item.Pet]
			if def then
				total += def.Bonus
			end
		end
	end
	return total
end

function Stats.PetMultiplier(data: Data): number
	return 1 + Stats.PetBonus(data) / 100
end

-- Niche -----------------------------------------------------------------------------------
function Stats.NicheMultiplier(data: Data): number
	local niche = Niches.ById[data.Niche]
	return if niche then niche.Mult else 1
end

-- Upgrades ---------------------------------------------------------------------------------
function Stats.UpgradeLevel(data: Data, id: string): number
	return data.Upgrades[id] or 0
end

function Stats.UpgradeById(id: string): Upgrades.Upgrade?
	for _, u in Upgrades do
		if u.Id == id then
			return u
		end
	end
	return nil
end

function Stats.UpgradeCost(id: string, level: number): number
	local u = Stats.UpgradeById(id)
	if not u then
		return math.huge
	end
	return math.floor(u.Base * u.Growth ^ level)
end

-- Boosts ------------------------------------------------------------------------------------
function Stats.BoostBonus(ctx: Context): number
	local b = Economy.Boosts
	local bonus = math.min(ctx.Friends * b.FriendBonus, b.FriendMax)
	if ctx.Premium then
		bonus += b.PremiumBonus
	end
	if ctx.Group then
		bonus += b.GroupBonus
	end
	return bonus
end

-- Views -------------------------------------------------------------------------------------
function Stats.ViewsMultiplier(data: Data, ctx: Context): number
	local m = Stats.RebirthMultiplier(data.Rebirths)
	m *= Stats.NicheMultiplier(data)
	m *= Stats.PetMultiplier(data)
	m *= 1 + Stats.BoostBonus(ctx)
	if ctx.Passes.DoubleViews then
		m *= 2
	end
	if ctx.Passes.VIP then
		m *= Economy.Boosts.VIPViews
	end
	if data.Potions.Views > 0 then
		m *= Economy.Boosts.PotionMultiplier
	end
	return m
end

function Stats.ViewsPerStep(data: Data, ctx: Context): number
	return Stats.DeviceValue(data) * Stats.ViewsMultiplier(data, ctx)
end

function Stats.TreadmillPerSecond(data: Data, ctx: Context, tierMult: number): number
	local bonus = 1 + Stats.UpgradeLevel(data, "Treadmill") * 0.1
	return Stats.ViewsPerStep(data, ctx) * Economy.Treadmill.StepsPerSecond * tierMult * bonus
end

function Stats.WalkSpeed(data: Data): number
	return Economy.BaseWalkSpeed + Stats.UpgradeLevel(data, "Speed")
end

-- Clout ---------------------------------------------------------------------------------------
function Stats.CloutMultiplier(data: Data, ctx: Context): number
	local m = 1 + data.Rebirths * Economy.Rebirth.CloutBonusPerRebirth
	m *= 1 + Stats.UpgradeLevel(data, "Clout") * 0.1
	if ctx.Passes.DoubleClout then
		m *= 2
	end
	if data.Potions.Clout > 0 then
		m *= Economy.Boosts.PotionMultiplier
	end
	return m
end

function Stats.GlobalGate(world: number, gate: number): number
	return (world - 1) * Stats.GatesPerWorld + gate
end

function Stats.PadBase(world: number, gate: number): number
	local cfg = Economy.Clout
	return math.floor(cfg.Base * cfg.Growth ^ (Stats.GlobalGate(world, gate) - 1))
end

function Stats.PadReward(data: Data, ctx: Context, world: number, gate: number): number
	return math.floor(Stats.PadBase(world, gate) * Stats.CloutMultiplier(data, ctx))
end

-- Deepest gate the player can currently open in a world (0 if none)
function Stats.OpenGates(data: Data, world: number): number
	local w = Worlds[world]
	if not w then
		return 0
	end
	local video = Stats.VideoLevel(data.Views)
	local open = 0
	for i, req in w.Gates do
		if video >= req then
			open = i
		end
	end
	return open
end

-- "Pads" rewards (gifts, packs) scale to the best pad you could currently
-- reach in any unlocked world, so they stay meaningful all game.
function Stats.BestPadBase(data: Data): number
	local best = Stats.PadBase(1, 1)
	for id in data.Unlocked do
		local world = tonumber(id)
		if world and Worlds[world] then
			local open = math.max(Stats.OpenGates(data, world), 1)
			-- use the deepest gate you have ever been able to reach in that world
			best = math.max(best, Stats.PadBase(world, open))
		end
	end
	-- your best device is a good proxy for how far you've come overall
	local device = Stats.BestOwnedDevice(data)
	local fromDevice = Stats.PadBase(device.World, math.clamp(math.floor(device.Tier * 15 / 21), 1, 15))
	return math.max(best, fromDevice)
end

-- Rival -------------------------------------------------------------------------------------
function Stats.RivalPower(world: number): number
	local w = Worlds[world]
	return Stats.ViewsForVideo(w.Rival.Video)
end

return Stats
