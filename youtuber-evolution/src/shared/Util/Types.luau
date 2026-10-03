--!strict
-- Shared data shapes (saved profile + runtime context).

export type PetItem = {
	Uid: string,
	Pet: string,
}

export type Data = {
	Version: number,
	Views: number, -- this rebirth (never spent; sets your Video level)
	TotalViews: number, -- lifetime
	Clout: number,
	TotalClout: number,
	Rebirths: number,
	Tickets: number,
	Devices: { [string]: boolean },
	Equipped: string,
	Upgrades: { [string]: number },
	Pets: { PetItem },
	EquippedPets: { string }, -- pet uids
	Niche: string,
	NichePity: number,
	PendingNiche: string,
	World: number,
	Unlocked: { [string]: boolean }, -- world id (string) -> true
	RivalsBeaten: { [string]: boolean },
	RivalCooldowns: { [string]: number },
	BestVideo: number,
	BestEvolution: number,
	Daily: { Streak: number, Last: number },
	Potions: { Views: number, Clout: number }, -- seconds remaining
	OneTime: { [string]: boolean },
	Receipts: { string },
	Codes: { [string]: boolean },
	Settings: { [string]: boolean },
	Stats: { Steps: number, Playtime: number, Battles: number, Hatched: number, Claims: number, Rolls: number },
	Tutorial: boolean,
}

-- Things that affect multipliers but aren't saved in the profile.
export type Context = {
	Passes: { [string]: boolean },
	Friends: number,
	Premium: boolean,
	Group: boolean,
}

return nil
