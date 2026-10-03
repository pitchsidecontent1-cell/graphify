--!strict
-- Core progression numbers. Tuned with tools/simulate.luau (see BALANCE.md):
-- World 1 ~8 min, World 2 ~30 min, World 3 ~80 min, final rival ~5 h for a
-- free player with no pets/niche (pets, niches and passes make it faster).

local Economy = {}

-- Movement / steps -----------------------------------------------------------
Economy.StudsPerStep = 3 -- horizontal studs walked = 1 step = +1 view (x multipliers)
Economy.BaseWalkSpeed = 20
Economy.MaxStepStuds = 1.35 -- allowed studs moved per (WalkSpeed * dt) before we treat it as a teleport

-- Videos (the level bar) -------------------------------------------------------
-- Views needed to go from video n to n+1 = floor(Base * Growth^(n-1)).
-- Views are never spent; your Video level is just how far your views reach.
Economy.Video = {
	Base = 12,
	Growth = 1.25,
	Max = 400,
}

-- Rebirth ---------------------------------------------------------------------
-- Rebirth n (you currently have n) needs Video >= BaseVideo + VideoPerRebirth * n.
-- Rebirthing resets Views + Videos (so gates relock) but doubles your views forever.
Economy.Rebirth = {
	Multiplier = 2,
	BaseVideo = 20,
	VideoPerRebirth = 5,
	CloutBonusPerRebirth = 0.1, -- +10% clout per rebirth
	TicketsPerRebirth = 1,
}

-- Clout pads --------------------------------------------------------------------
-- Pad reward for global gate index g (1..60) = Base * Growth^(g-1)
Economy.Clout = {
	Base = 2,
	Growth = 1.3,
	ClaimCooldown = 2,
}

-- Devices ------------------------------------------------------------------------
-- Device i (1..84) gives floor(Growth^(i-1) + (i-1)*0.5 + 0.5) views per step
-- and costs floor(CostBase * CostGrowth^(i-2)) clout (device 1 is free).
Economy.Devices = {
	Growth = 1.18,
	CostBase = 6,
	CostGrowth = 1.215,
}

-- Treadmills: views/sec = ViewsPerStep * StepsPerSecond * tier multiplier
Economy.Treadmill = {
	StepsPerSecond = 2,
}

-- Boosts -------------------------------------------------------------------------
Economy.Boosts = {
	FriendBonus = 0.1, -- per friend in server
	FriendMax = 0.5,
	PremiumBonus = 0.1,
	GroupBonus = 0.1,
	VIPViews = 1.5,
	PotionMultiplier = 2,
}

Economy.Pets = {
	BaseSlots = 3,
	PassSlots = 2,
	InventoryMax = 60,
}

return Economy
