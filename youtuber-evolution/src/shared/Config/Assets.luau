--!strict
-- Every image/sound the game uses lives here.
-- * Icons: the game ships with emoji icons. Upload your own glossy icon PNGs
--   and paste "rbxassetid://123" into Images to replace any emoji.
-- * Sounds: defaults use sounds built into the Roblox client. Swap in any
--   audio from the Creator Store with "rbxassetid://123".
-- Never paste IDs you don't own or that aren't public, or they won't load.

local Assets = {}

Assets.Images = {
	Shop = "",
	Pets = "",
	Devices = "",
	Rebirth = "",
	Upgrades = "",
	Daily = "",
	Gifts = "",
	Niche = "",
	Settings = "",
	Codes = "",
	Worlds = "",
	Views = "",
	Clout = "",
	Tickets = "",
	-- Grayscale stud texture (tinted per part). Leave empty to use Roblox's
	-- built-in stud surface instead.
	StudTexture = "",
} :: { [string]: string }

Assets.Emoji = {
	Shop = "🛒",
	Pets = "🐾",
	Devices = "📷",
	Rebirth = "🔄",
	Upgrades = "⚡",
	Daily = "📅",
	Gifts = "🎁",
	Niche = "🎲",
	Settings = "⚙️",
	Codes = "🎟️",
	Worlds = "🌍",
	Views = "👁️",
	Clout = "💰",
	Tickets = "🎟️",
	Video = "▶️",
	Rebirths = "🔄",
	Home = "🏠",
	Hide = "👀",
	Admin = "🛠️",
} :: { [string]: string }

Assets.Sounds = {
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5 },
	Hover = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.15, Speed = 1.6 },
	Open = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.35, Speed = 1.3 },
	Close = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.25, Speed = 0.9 },
	Pop = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35 },
	Claim = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Speed = 1.25 },
	Gate = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, Speed = 0.8 },
	Purchase = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Speed = 1.5 },
	Error = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.6, Speed = 0.6 },
	Evolve = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.9, Speed = 0.65 },
	Rebirth = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.9, Speed = 0.7 },
	Hatch = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, Speed = 1.1 },
	Tick = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.3, Speed = 1.2 },
	Win = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 1, Speed = 0.9 },
	Lose = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.6, Speed = 0.5 },
	Whoosh = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.5, Speed = 1 },
} :: { [string]: { Id: string, Volume: number, Speed: number? } }

-- Background music per world. Empty = no music.
Assets.Music = {
	[1] = "",
	[2] = "",
	[3] = "",
	[4] = "",
} :: { [number]: string }

return Assets
