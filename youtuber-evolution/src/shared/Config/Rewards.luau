--!strict
-- Free rewards: playtime gifts (per session), daily streak, codes.
-- Reward kinds:
--   { Kind = "Clout", Pads = n }        n x your current best clout-pad reward
--   { Kind = "Tickets", Amount = n }
--   { Kind = "Potion", Potion = "Views" | "Clout", Minutes = n }

export type Reward = {
	Kind: string,
	Pads: number?,
	Amount: number?,
	Potion: string?,
	Minutes: number?,
}

local Rewards = {}

Rewards.Gifts = {
	{ Minutes = 1, Reward = { Kind = "Clout", Pads = 2 } },
	{ Minutes = 3, Reward = { Kind = "Potion", Potion = "Views", Minutes = 3 } },
	{ Minutes = 5, Reward = { Kind = "Clout", Pads = 4 } },
	{ Minutes = 8, Reward = { Kind = "Tickets", Amount = 1 } },
	{ Minutes = 12, Reward = { Kind = "Clout", Pads = 6 } },
	{ Minutes = 15, Reward = { Kind = "Potion", Potion = "Clout", Minutes = 5 } },
	{ Minutes = 20, Reward = { Kind = "Clout", Pads = 10 } },
	{ Minutes = 25, Reward = { Kind = "Tickets", Amount = 2 } },
	{ Minutes = 30, Reward = { Kind = "Potion", Potion = "Views", Minutes = 10 } },
	{ Minutes = 40, Reward = { Kind = "Clout", Pads = 20 } },
	{ Minutes = 50, Reward = { Kind = "Tickets", Amount = 3 } },
	{ Minutes = 60, Reward = { Kind = "Clout", Pads = 40 } },
} :: { { Minutes: number, Reward: Reward } }

Rewards.Daily = {
	{ Kind = "Clout", Pads = 4 },
	{ Kind = "Tickets", Amount = 1 },
	{ Kind = "Potion", Potion = "Views", Minutes = 10 },
	{ Kind = "Clout", Pads = 10 },
	{ Kind = "Tickets", Amount = 3 },
	{ Kind = "Potion", Potion = "Clout", Minutes = 15 },
	{ Kind = "Tickets", Amount = 6 },
} :: { Reward }

Rewards.DailyWindow = 48 * 3600 -- miss more than this and the streak resets
Rewards.DailyCooldown = 20 * 3600

-- Codes are case-insensitive. Add new ones here.
Rewards.Codes = {
	RELEASE = { Kind = "Tickets", Amount = 3 },
	PLUSONE = { Kind = "Potion", Potion = "Views", Minutes = 15 },
	CLOUT = { Kind = "Clout", Pads = 6 },
	CREATOR = { Kind = "Tickets", Amount = 2 },
} :: { [string]: Reward }

return Rewards
