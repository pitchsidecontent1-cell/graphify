--!strict
-- Niche roll (our take on "races"). Costs 1 ticket per roll. Odds are always
-- shown in the roll UI (Roblox requires odds for random items you can buy).

export type Niche = {
	Id: string,
	Name: string,
	Emoji: string,
	Rarity: string,
	Chance: number, -- percent
	Mult: number, -- views multiplier
}

local Niches = {}

Niches.List = {
	{ Id = "Vlogger", Name = "Vlogger", Emoji = "🎥", Rarity = "Common", Chance = 40, Mult = 1.1 },
	{ Id = "Gamer", Name = "Gamer", Emoji = "🎮", Rarity = "Common", Chance = 28, Mult = 1.25 },
	{ Id = "Cooking", Name = "Cooking", Emoji = "🍳", Rarity = "Uncommon", Chance = 15, Mult = 1.5 },
	{ Id = "Tech", Name = "Tech Reviewer", Emoji = "💻", Rarity = "Rare", Chance = 9, Mult = 2 },
	{ Id = "ASMR", Name = "ASMR", Emoji = "🎧", Rarity = "Rare", Chance = 4.5, Mult = 3 },
	{ Id = "Speedrun", Name = "Speedrunner", Emoji = "⏱️", Rarity = "Epic", Chance = 2, Mult = 5 },
	{ Id = "Horror", Name = "Horror", Emoji = "👻", Rarity = "Epic", Chance = 1, Mult = 8 },
	{ Id = "Animator", Name = "Animator", Emoji = "✏️", Rarity = "Legendary", Chance = 0.4, Mult = 15 },
	{ Id = "Music", Name = "Music Producer", Emoji = "🎹", Rarity = "Mythic", Chance = 0.09, Mult = 25 },
	{ Id = "Chosen", Name = "Algorithm's Chosen", Emoji = "👑", Rarity = "Secret", Chance = 0.01, Mult = 50 },
} :: { Niche }

Niches.ById = {} :: { [string]: Niche }
for _, n in Niches.List do
	Niches.ById[n.Id] = n
end

Niches.PityRolls = 50 -- guaranteed Epic or better every 50 rolls
Niches.PityMinRarity = "Epic"

return Niches
