--!strict
-- Niche roll: 1 ticket = 1 roll. Better results are kept automatically.

local Shared = game:GetService("ReplicatedStorage").Shared
local Niches = require(Shared.Config.Niches)
local Theme = require(Shared.Config.Theme)
local DataService = require(script.Parent.DataService)
local Comms = require(script.Parent.Comms)

local NicheService = {}

local rng = Random.new()

local function rarityOrder(id: string): number
	return Theme.Rarities[id].Order
end

-- Weighted roll. Lucky pass doubles everything Rare and up. Pity forces Epic+.
function NicheService.Roll(lucky: boolean, pity: boolean): Niches.Niche
	local minOrder = rarityOrder(Niches.PityMinRarity)
	local pool = {}
	local total = 0
	for _, n in Niches.List do
		local order = rarityOrder(n.Rarity)
		if not pity or order >= minOrder then
			local w = n.Chance
			if lucky and order >= rarityOrder("Rare") then
				w *= 2
			end
			table.insert(pool, { niche = n, weight = w })
			total += w
		end
	end
	local roll = rng:NextNumber() * total
	local acc = 0
	for _, entry in pool do
		acc += entry.weight
		if roll <= acc then
			return entry.niche
		end
	end
	return pool[#pool].niche
end

function NicheService.Init()
	Comms.On("RollNiche", 3, function(player)
		local data = DataService.Get(player)
		if not data then
			return Comms.Fail("Loading...")
		end
		if data.Tickets < 1 then
			return Comms.Fail("You need a Niche Ticket! Rebirth or beat rivals to earn more.")
		end
		data.Tickets -= 1
		data.NichePity += 1
		data.Stats.Rolls += 1
		local ctx = DataService.Context(player)
		local pity = data.NichePity >= Niches.PityRolls
		local result = NicheService.Roll(ctx.Passes.LuckyNiche == true, pity)
		if rarityOrder(result.Rarity) >= rarityOrder(Niches.PityMinRarity) then
			data.NichePity = 0
		end
		local current = Niches.ById[data.Niche]
		local kept = not current or result.Mult > current.Mult
		if kept then
			data.Niche = result.Id
		end
		DataService.Dirty(player, "Tickets", "NichePity", "Niche", "Stats")
		if rarityOrder(result.Rarity) >= rarityOrder("Mythic") then
			Comms.NotifyAll(
				"👑 "
					.. player.DisplayName
					.. " rolled the "
					.. string.upper(result.Rarity)
					.. " niche "
					.. result.Name
					.. "!",
				"reward"
			)
		end
		return Comms.Ok({ Niche = result.Id, Kept = kept })
	end)
end

function NicheService.Start() end

return NicheService
