--!strict
-- Hatching, equipping and deleting pets.

local Shared = game:GetService("ReplicatedStorage").Shared
local Pets = require(Shared.Config.Pets)
local Economy = require(Shared.Config.Economy)
local Stats = require(Shared.Util.Stats)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local CharacterService = require(script.Parent.CharacterService)
local MapService = require(script.Parent.MapService)
local Comms = require(script.Parent.Comms)

local PetService = {}

local rng = Random.new()
local counter = 0

local function newUid(): string
	counter += 1
	return string.format("%x%x%x", os.time(), counter, rng:NextInteger(0, 0xFFFF))
end

local function rollPet(egg: Pets.Egg): string
	local roll = rng:NextNumber() * 100
	local acc = 0
	for _, id in egg.Pets do
		acc += Pets.ById[id].Chance
		if roll <= acc then
			return id
		end
	end
	return egg.Pets[1]
end

local function equippedSet(data: any): { [string]: boolean }
	local set = {}
	for _, uid in data.EquippedPets do
		set[uid] = true
	end
	return set
end

-- Equip the best pets you own (by bonus), up to your slot count.
function PetService.EquipBest(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local list = table.clone(data.Pets)
	table.sort(list, function(a, b)
		local pa, pb = Pets.ById[a.Pet], Pets.ById[b.Pet]
		return (if pa then pa.Bonus else 0) > (if pb then pb.Bonus else 0)
	end)
	local slots = Stats.PetSlots(DataService.Context(player))
	local equipped = {}
	for i = 1, math.min(slots, #list) do
		table.insert(equipped, list[i].Uid)
	end
	data.EquippedPets = equipped
	DataService.Dirty(player, "EquippedPets")
end

local function hatch(player: Player, eggId: string, count: number): Comms.Result
	local data = DataService.Get(player)
	local egg = Pets.Eggs[eggId]
	if not data or not egg then
		return Comms.Fail("Unknown egg")
	end
	if count ~= 1 and count ~= 3 then
		return Comms.Fail("Bad amount")
	end
	local ctx = DataService.Context(player)
	if count == 3 and not ctx.Passes.TripleHatch then
		return Comms.Fail("Triple Hatch needs the gamepass!")
	end
	if not data.Unlocked[tostring(egg.World)] then
		return Comms.Fail("Unlock " .. egg.World .. " first!")
	end
	local root = CharacterService.Root(player)
	if
		not root
		or not MapService.NearStation(root.Position, "Egg", 30, function(pad)
			return pad:GetAttribute("Egg") == eggId
		end)
	then
		return Comms.Fail("Walk up to the egg to hatch it!")
	end
	if #data.Pets + count > Economy.Pets.InventoryMax then
		return Comms.Fail("Your pet inventory is full! Delete some pets.")
	end
	local cost = egg.Cost * count
	if not ProgressService.SpendClout(player, cost) then
		return Comms.Fail("Not enough clout!")
	end
	local results = {}
	local slots = Stats.PetSlots(ctx)
	for _ = 1, count do
		local petId = rollPet(egg)
		local item = { Uid = newUid(), Pet = petId }
		table.insert(data.Pets, item)
		table.insert(results, item)
		if #data.EquippedPets < slots then
			table.insert(data.EquippedPets, item.Uid)
		end
	end
	data.Stats.Hatched += count
	DataService.Dirty(player, "Pets", "EquippedPets", "Stats")
	-- swap in better pets automatically if all slots are full
	local worst, worstBonus = nil, math.huge
	for _, uid in data.EquippedPets do
		local item = Stats.FindPet(data, uid)
		local def = item and Pets.ById[item.Pet]
		if def and def.Bonus < worstBonus then
			worst, worstBonus = uid, def.Bonus
		end
	end
	for _, item in results do
		local def = Pets.ById[item.Pet]
		if worst and def.Bonus > worstBonus and not equippedSet(data)[item.Uid] then
			PetService.EquipBest(player)
			break
		end
	end
	for _, item in results do
		local def = Pets.ById[item.Pet]
		if def.Rarity == "Legendary" or def.Rarity == "Secret" then
			Comms.NotifyAll(
				"🎉 " .. player.DisplayName .. " hatched a " .. string.upper(def.Rarity) .. " " .. def.Name .. "!",
				"reward"
			)
		end
	end
	return Comms.Ok({ Pets = results })
end

-- Admin: one weighted roll from an egg (same odds as a real hatch).
function PetService.Roll(egg: Pets.Egg): string
	return rollPet(egg)
end

-- Admin: add `count` copies of a pet (capped by inventory space), then
-- equip the best. Returns how many were added.
function PetService.Give(player: Player, petId: string, count: number): number
	local data = DataService.Get(player)
	if not data or not Pets.ById[petId] then
		return 0
	end
	local n = math.clamp(math.floor(count), 0, math.max(0, Economy.Pets.InventoryMax - #data.Pets))
	for _ = 1, n do
		table.insert(data.Pets, { Uid = newUid(), Pet = petId })
	end
	if n > 0 then
		DataService.Dirty(player, "Pets")
		PetService.EquipBest(player)
	end
	return n
end

function PetService.Init()
	Comms.On("Hatch", 2, function(player, payload)
		local eggId = Comms.String(payload.Egg, 24)
		local count = Comms.Int(payload.Count, 1, 3)
		if not eggId or not count then
			return Comms.Fail("Bad hatch")
		end
		return hatch(player, eggId, count)
	end)

	Comms.On("EquipPet", 8, function(player, payload)
		local data = DataService.Get(player)
		local uid = Comms.String(payload.Uid, 40)
		if not data or not uid or not Stats.FindPet(data, uid) then
			return Comms.Fail("Unknown pet")
		end
		if table.find(data.EquippedPets, uid) then
			return Comms.Ok()
		end
		if #data.EquippedPets >= Stats.PetSlots(DataService.Context(player)) then
			return Comms.Fail("All pet slots are full!")
		end
		table.insert(data.EquippedPets, uid)
		DataService.Dirty(player, "EquippedPets")
		return Comms.Ok()
	end)

	Comms.On("UnequipPet", 8, function(player, payload)
		local data = DataService.Get(player)
		local uid = Comms.String(payload.Uid, 40)
		if not data or not uid then
			return Comms.Fail("Unknown pet")
		end
		local idx = table.find(data.EquippedPets, uid)
		if idx then
			table.remove(data.EquippedPets, idx)
			DataService.Dirty(player, "EquippedPets")
		end
		return Comms.Ok()
	end)

	Comms.On("EquipBestPets", 2, function(player)
		PetService.EquipBest(player)
		return Comms.Ok()
	end)

	Comms.On("DeletePets", 4, function(player, payload)
		local data = DataService.Get(player)
		if not data or typeof(payload.Uids) ~= "table" then
			return Comms.Fail("Bad request")
		end
		local remove: { [string]: boolean } = {}
		local n = 0
		for _, uid in payload.Uids do
			if typeof(uid) == "string" and #uid <= 40 then
				remove[uid] = true
				n += 1
			end
			if n > 100 then
				break
			end
		end
		local kept = {}
		for _, item in data.Pets do
			if not remove[item.Uid] then
				table.insert(kept, item)
			end
		end
		data.Pets = kept
		local eq = {}
		for _, uid in data.EquippedPets do
			if not remove[uid] then
				table.insert(eq, uid)
			end
		end
		data.EquippedPets = eq
		DataService.Dirty(player, "Pets", "EquippedPets")
		return Comms.Ok()
	end)
end

function PetService.Start() end

return PetService
