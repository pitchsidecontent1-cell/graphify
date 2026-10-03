--!strict
-- Eggs (2 per world) and the pets inside them. Equipped pets add their Bonus
-- (in %) to your views: PetMultiplier = 1 + sum(Bonus) / 100.

export type Pet = {
	Id: string,
	Name: string,
	Egg: string,
	Shape: string,
	Rarity: string,
	Chance: number, -- percent
	Bonus: number, -- percent views
	Color: Color3,
	Color2: Color3,
	Glow: boolean?,
	Rainbow: boolean?,
}

export type Egg = {
	Id: string,
	Name: string,
	World: number,
	Cost: number,
	Color: Color3,
	Color2: Color3,
	Pets: { string },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Pets = {}
Pets.Eggs = {} :: { [string]: Egg }
Pets.EggOrder = {} :: { string }
Pets.ById = {} :: { [string]: Pet }

local CHANCES = { 45, 30, 17, 7, 1 }
local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

type PetEntry = {
	Name: string,
	Shape: string,
	Bonus: number,
	Color: Color3,
	Color2: Color3,
	Glow: boolean,
	Rainbow: boolean,
}
type EggEntry = {
	Id: string,
	Name: string,
	World: number,
	Cost: number,
	Color: Color3,
	Color2: Color3,
	Pets: { PetEntry },
}

local function p(
	name: string,
	shape: string,
	bonus: number,
	color: Color3,
	color2: Color3,
	glow: boolean?,
	rainbow: boolean?
): PetEntry
	return {
		Name = name,
		Shape = shape,
		Bonus = bonus,
		Color = color,
		Color2 = color2,
		Glow = glow == true,
		Rainbow = rainbow == true,
	}
end

local function egg(
	id: string,
	name: string,
	world: number,
	cost: number,
	color: Color3,
	color2: Color3,
	pets: { PetEntry }
): EggEntry
	return { Id = id, Name = name, World = world, Cost = cost, Color = color, Color2 = color2, Pets = pets }
end

local DEFS: { EggEntry } = {
	egg("StarterEgg", "Starter Egg", 1, 30, rgb(255, 236, 200), rgb(255, 150, 120), {
		p("Kitten", "cat", 10, rgb(255, 170, 90), rgb(255, 235, 200)),
		p("Puppy", "dog", 15, rgb(214, 170, 120), rgb(120, 80, 60)),
		p("Bunny", "bunny", 25, rgb(250, 250, 255), rgb(255, 170, 200)),
		p("Fox", "fox", 45, rgb(255, 120, 40), rgb(255, 245, 235)),
		p("Golden Kitten", "cat", 100, rgb(255, 200, 46), rgb(255, 245, 190), true),
	}),
	egg("ParkEgg", "Park Egg", 1, 250, rgb(140, 230, 110), rgb(255, 230, 90), {
		p("Frog", "frog", 20, rgb(110, 210, 90), rgb(240, 255, 200)),
		p("Bear", "bear", 35, rgb(160, 105, 70), rgb(230, 190, 150)),
		p("Owl", "bird", 60, rgb(170, 120, 80), rgb(255, 220, 160)),
		p("Panda", "bear", 110, rgb(250, 250, 250), rgb(30, 30, 36)),
		p("Rainbow Bunny", "bunny", 250, rgb(255, 255, 255), rgb(255, 120, 200), true, true),
	}),
	egg("NeonEgg", "Neon Egg", 2, 2500, rgb(60, 40, 110), rgb(255, 64, 190), {
		p("Neon Cat", "cat", 50, rgb(255, 64, 190), rgb(46, 230, 255), true),
		p("Neon Pup", "dog", 80, rgb(46, 230, 255), rgb(255, 64, 190), true),
		p("Synth Bunny", "bunny", 130, rgb(160, 96, 255), rgb(255, 210, 255), true),
		p("Laser Fox", "fox", 240, rgb(255, 40, 90), rgb(255, 200, 220), true),
		p("Disco Dragon", "dragon", 550, rgb(255, 64, 190), rgb(255, 230, 100), true, true),
	}),
	egg("BillboardEgg", "Billboard Egg", 2, 25000, rgb(255, 210, 60), rgb(40, 30, 80), {
		p("Pigeon", "bird", 100, rgb(150, 150, 170), rgb(110, 210, 160)),
		p("Subway Rat", "mouse", 160, rgb(130, 120, 130), rgb(255, 170, 190)),
		p("Neon Bear", "bear", 270, rgb(80, 50, 160), rgb(46, 230, 255), true),
		p("Cyber Wolf", "dog", 500, rgb(60, 70, 100), rgb(46, 230, 255), true),
		p("Neon Phoenix", "phoenix", 1100, rgb(255, 90, 40), rgb(255, 230, 80), true, true),
	}),
	egg("FrostEgg", "Frost Egg", 3, 150000, rgb(200, 240, 255), rgb(90, 170, 255), {
		p("Penguin", "penguin", 200, rgb(30, 34, 50), rgb(250, 250, 255)),
		p("Snow Bunny", "bunny", 320, rgb(240, 248, 255), rgb(150, 210, 255)),
		p("Polar Bear", "bear", 550, rgb(245, 250, 255), rgb(190, 220, 240)),
		p("Ice Fox", "fox", 1000, rgb(150, 220, 255), rgb(255, 255, 255), true),
		p("Frost Dragon", "dragon", 2200, rgb(120, 200, 255), rgb(255, 255, 255), true, true),
	}),
	egg("ServerEgg", "Server Egg", 3, 1500000, rgb(50, 60, 90), rgb(80, 255, 140), {
		p("Bug Bot", "robot", 400, rgb(150, 160, 180), rgb(80, 255, 140)),
		p("USB Slime", "slime", 650, rgb(80, 255, 140), rgb(30, 60, 40), true),
		p("Cooling Cat", "cat", 1100, rgb(90, 180, 255), rgb(220, 245, 255), true),
		p("Glitch Ghost", "ghost", 2000, rgb(230, 255, 240), rgb(255, 60, 200), true),
		p("Mainframe Dragon", "dragon", 4500, rgb(30, 40, 60), rgb(80, 255, 140), true, true),
	}),
	egg("GalaxyEgg", "Galaxy Egg", 4, 15000000, rgb(60, 30, 130), rgb(255, 150, 230), {
		p("Star Slime", "slime", 800, rgb(255, 220, 110), rgb(120, 70, 20), true),
		p("Moon Bunny", "bunny", 1300, rgb(220, 220, 255), rgb(170, 140, 255), true),
		p("Comet Fox", "fox", 2200, rgb(120, 140, 255), rgb(255, 255, 255), true),
		p("Nebula Bear", "bear", 4000, rgb(140, 60, 220), rgb(255, 150, 230), true),
		p("Galaxy Dragon", "dragon", 9000, rgb(40, 20, 100), rgb(255, 150, 230), true, true),
	}),
	egg("AlgorithmEgg", "Algorithm Egg", 4, 250000000, rgb(20, 10, 40), rgb(255, 60, 140), {
		p("Trend Bot", "robot", 1600, rgb(255, 255, 255), rgb(255, 60, 140)),
		p("Like Ghost", "ghost", 2600, rgb(255, 240, 250), rgb(255, 60, 100), true),
		p("Sub Cat", "cat", 4500, rgb(255, 60, 80), rgb(255, 255, 255), true),
		p("Viral Phoenix", "phoenix", 8500, rgb(255, 60, 200), rgb(255, 230, 90), true),
		p("The Algo Pet", "ghost", 40000, rgb(255, 255, 255), rgb(20, 10, 40), true, true),
	}),
}

for _, def in DEFS do
	local eggDef: Egg = {
		Id = def.Id,
		Name = def.Name,
		World = def.World,
		Cost = def.Cost,
		Color = def.Color,
		Color2 = def.Color2,
		Pets = {},
	}
	Pets.Eggs[eggDef.Id] = eggDef
	table.insert(Pets.EggOrder, eggDef.Id)
	for i, entry in def.Pets do
		local rarity = RARITIES[i]
		local chance = CHANCES[i]
		if eggDef.Id == "AlgorithmEgg" and i == 5 then
			rarity = "Secret"
			chance = 0.1
		end
		local pet: Pet = {
			Id = eggDef.Id .. "_" .. i,
			Name = entry.Name,
			Egg = eggDef.Id,
			Shape = entry.Shape,
			Rarity = rarity,
			Chance = chance,
			Bonus = entry.Bonus,
			Color = entry.Color,
			Color2 = entry.Color2,
			Glow = entry.Glow,
			Rainbow = entry.Rainbow,
		}
		Pets.ById[pet.Id] = pet
		table.insert(eggDef.Pets, pet.Id)
	end
	-- normalise so chances always add to exactly 100
	local total = 0
	for _, id in eggDef.Pets do
		total += Pets.ById[id].Chance
	end
	if math.abs(total - 100) > 1e-6 then
		local first = Pets.ById[eggDef.Pets[1]]
		first.Chance += 100 - total
	end
end

return Pets
