--!strict
-- Your Evolution comes from your current Video level. Each tier adds gear to
-- your character (built from parts in Models/GearModels) and makes you a bit
-- bigger. Gear is cumulative: a later tier with the same Kind replaces it.

export type GearSpec = {
	Kind: string,
	Color: Color3?,
	Color2: Color3?,
	Count: number?,
	Rainbow: boolean?,
}

export type Evolution = {
	Tier: number,
	Title: string,
	Video: number,
	Rarity: string,
	Scale: number,
	Gear: { GearSpec },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local BRONZE = rgb(205, 127, 50)
local SILVER = rgb(210, 216, 230)
local GOLD = rgb(255, 196, 46)
local DIAMOND = rgb(150, 235, 255)
local RUBY = rgb(230, 30, 70)

local Evolutions: { Evolution } = {
	{ Tier = 1, Title = "Nobody", Video = 1, Rarity = "Common", Scale = 1, Gear = {} },
	{
		Tier = 2,
		Title = "First Upload",
		Video = 3,
		Rarity = "Common",
		Scale = 1,
		Gear = {
			{ Kind = "Sparkles", Color = rgb(255, 255, 255) },
		},
	},
	{
		Tier = 3,
		Title = "Phone Vlogger",
		Video = 6,
		Rarity = "Common",
		Scale = 1.03,
		Gear = {
			{ Kind = "Phone", Color = rgb(40, 40, 50), Color2 = rgb(90, 200, 255) },
		},
	},
	{
		Tier = 4,
		Title = "Webcam Warrior",
		Video = 10,
		Rarity = "Uncommon",
		Scale = 1.06,
		Gear = {
			{ Kind = "Headset", Color = rgb(40, 40, 50), Color2 = rgb(255, 60, 80) },
		},
	},
	{
		Tier = 5,
		Title = "Ring Light Rookie",
		Video = 15,
		Rarity = "Uncommon",
		Scale = 1.09,
		Gear = {
			{ Kind = "RingLight", Color = rgb(255, 250, 225) },
		},
	},
	{
		Tier = 6,
		Title = "Mic Check",
		Video = 20,
		Rarity = "Uncommon",
		Scale = 1.12,
		Gear = {
			{ Kind = "Plaque", Color = BRONZE },
			{ Kind = "Sparkles", Color = rgb(255, 200, 120) },
		},
	},
	{
		Tier = 7,
		Title = "Green Screen Pro",
		Video = 27,
		Rarity = "Rare",
		Scale = 1.15,
		Gear = {
			{ Kind = "Drone", Count = 1, Color = rgb(40, 40, 50), Color2 = rgb(60, 255, 120) },
		},
	},
	{
		Tier = 8,
		Title = "Edit Wizard",
		Video = 34,
		Rarity = "Rare",
		Scale = 1.18,
		Gear = {
			{ Kind = "Plaque", Color = SILVER },
			{ Kind = "Cape", Color = rgb(220, 40, 60), Color2 = rgb(255, 210, 60) },
		},
	},
	{
		Tier = 9,
		Title = "Studio Star",
		Video = 42,
		Rarity = "Rare",
		Scale = 1.21,
		Gear = {
			{ Kind = "Drone", Count = 2, Color = rgb(40, 40, 50), Color2 = rgb(80, 220, 255) },
			{ Kind = "Trail", Color = rgb(80, 220, 255), Color2 = rgb(255, 255, 255) },
		},
	},
	{
		Tier = 10,
		Title = "Trending Titan",
		Video = 50,
		Rarity = "Epic",
		Scale = 1.24,
		Gear = {
			{ Kind = "Plaque", Color = GOLD },
			{ Kind = "Aura", Color = GOLD, Color2 = rgb(255, 240, 180) },
		},
	},
	{
		Tier = 11,
		Title = "Collab King",
		Video = 60,
		Rarity = "Epic",
		Scale = 1.27,
		Gear = {
			{ Kind = "Crown", Count = 5, Color = rgb(30, 30, 40), Color2 = rgb(255, 210, 60) },
		},
	},
	{
		Tier = 12,
		Title = "Viral Legend",
		Video = 72,
		Rarity = "Epic",
		Scale = 1.3,
		Gear = {
			{ Kind = "Plaque", Color = DIAMOND },
			{ Kind = "Aura", Color = rgb(120, 230, 255), Color2 = rgb(255, 255, 255) },
		},
	},
	{
		Tier = 13,
		Title = "Algorithm Whisperer",
		Video = 85,
		Rarity = "Legendary",
		Scale = 1.33,
		Gear = {
			{ Kind = "Wings", Color = rgb(30, 26, 44), Color2 = rgb(255, 240, 200) },
		},
	},
	{
		Tier = 14,
		Title = "Internet Icon",
		Video = 100,
		Rarity = "Legendary",
		Scale = 1.36,
		Gear = {
			{ Kind = "Plaque", Color = RUBY },
			{ Kind = "Trail", Rainbow = true },
		},
	},
	{
		Tier = 15,
		Title = "Meme Lord",
		Video = 115,
		Rarity = "Legendary",
		Scale = 1.39,
		Gear = {
			{ Kind = "Aura", Color = rgb(255, 60, 200), Color2 = rgb(120, 255, 90) },
			{ Kind = "Cape", Color = rgb(120, 40, 220), Color2 = rgb(120, 255, 90) },
		},
	},
	{
		Tier = 16,
		Title = "Cosmic Creator",
		Video = 130,
		Rarity = "Mythic",
		Scale = 1.42,
		Gear = {
			{ Kind = "Orbiters", Count = 3, Color = rgb(255, 150, 230), Color2 = rgb(140, 200, 255) },
		},
	},
	{
		Tier = 17,
		Title = "Multiverse Streamer",
		Video = 150,
		Rarity = "Mythic",
		Scale = 1.46,
		Gear = {
			{ Kind = "Aura", Color = rgb(255, 255, 255), Color2 = rgb(170, 140, 255) },
			{ Kind = "Wings", Color = rgb(40, 20, 90), Color2 = rgb(255, 150, 230) },
		},
	},
	{
		Tier = 18,
		Title = "Reality Bender",
		Video = 170,
		Rarity = "Mythic",
		Scale = 1.5,
		Gear = {
			{ Kind = "Drone", Count = 3, Color = rgb(255, 255, 255), Color2 = rgb(255, 60, 140) },
			{ Kind = "Crown", Count = 7, Color = rgb(20, 10, 40), Color2 = rgb(255, 60, 200) },
		},
	},
	{
		Tier = 19,
		Title = "Living Legend",
		Video = 190,
		Rarity = "Secret",
		Scale = 1.55,
		Gear = {
			{ Kind = "Plaque", Rainbow = true, Color = rgb(255, 255, 255) },
			{ Kind = "Cape", Rainbow = true, Color = rgb(255, 255, 255), Color2 = rgb(255, 255, 255) },
		},
	},
	{
		Tier = 20,
		Title = "THE ALGORITHM",
		Video = 210,
		Rarity = "Secret",
		Scale = 1.6,
		Gear = {
			{ Kind = "Aura", Rainbow = true, Color = rgb(255, 255, 255), Color2 = rgb(255, 255, 255) },
			{ Kind = "Wings", Rainbow = true, Color = rgb(255, 255, 255), Color2 = rgb(255, 255, 255) },
			{ Kind = "Orbiters", Count = 5, Rainbow = true, Color = rgb(255, 255, 255), Color2 = rgb(255, 255, 255) },
		},
	},
}

return Evolutions
