--!strict
-- Robux items. Create each Game Pass / Developer Product on the Creator Hub,
-- then paste its ID here. Items with Id = 0 show as "Coming soon" in-game
-- (and can be test-granted from the admin panel in Studio).

export type Pass = {
	Key: string,
	Id: number,
	Name: string,
	Emoji: string,
	Description: string,
	Price: number, -- display fallback; the real price comes from Roblox when Id ~= 0
	Color: Color3,
}

export type Product = {
	Key: string,
	Id: number,
	Name: string,
	Emoji: string,
	Description: string,
	Price: number,
	Color: Color3,
	OneTime: boolean?,
	Grants: { { Kind: string, Pads: number?, Amount: number?, Potion: string?, Minutes: number? } },
	OldPrice: number?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Products = {}

Products.Passes = {
	{
		Key = "VIP",
		Id = 0,
		Name = "VIP",
		Emoji = "👑",
		Description = "x1.5 Views forever, the x25 VIP treadmill and a gold VIP chat tag",
		Price = 299,
		Color = rgb(255, 196, 46),
	},
	{
		Key = "MegaTreadmill",
		Id = 0,
		Name = "MEGA Treadmill",
		Emoji = "🏃",
		Description = "Unlock the x100 views treadmill in every world",
		Price = 199,
		Color = rgb(235, 40, 56),
	},
	{
		Key = "DoubleViews",
		Id = 0,
		Name = "x2 Views",
		Emoji = "👁️",
		Description = "Double every view you get, forever",
		Price = 249,
		Color = rgb(255, 72, 96),
	},
	{
		Key = "DoubleClout",
		Id = 0,
		Name = "x2 Clout",
		Emoji = "💰",
		Description = "Double clout from every pad, forever",
		Price = 199,
		Color = rgb(255, 170, 40),
	},
	{
		Key = "PetSlots",
		Id = 0,
		Name = "+2 Pet Slots",
		Emoji = "🐾",
		Description = "Equip 2 more pets at once",
		Price = 149,
		Color = rgb(88, 214, 84),
	},
	{
		Key = "TripleHatch",
		Id = 0,
		Name = "Triple Hatch",
		Emoji = "🥚",
		Description = "Hatch 3 eggs at a time",
		Price = 179,
		Color = rgb(160, 92, 255),
	},
	{
		Key = "LuckyNiche",
		Id = 0,
		Name = "Lucky Niche",
		Emoji = "🍀",
		Description = "x2 luck on rare niches",
		Price = 249,
		Color = rgb(61, 220, 151),
	},
} :: { Pass }

Products.Products = {
	{
		Key = "StarterPack",
		Id = 0,
		Name = "Starter Pack",
		Emoji = "🎁",
		Description = "5 Tickets + 30 min x2 Views + a big clout stack",
		Price = 79,
		OldPrice = 199,
		Color = rgb(46, 210, 200),
		OneTime = true,
		Grants = {
			{ Kind = "Tickets", Amount = 5 },
			{ Kind = "Potion", Potion = "Views", Minutes = 30 },
			{ Kind = "Clout", Pads = 40 },
		},
	},
	{
		Key = "MegaPack",
		Id = 0,
		Name = "Creator Mega Pack",
		Emoji = "💎",
		Description = "30 Tickets + 60 min of both potions + a HUGE clout stack",
		Price = 499,
		OldPrice = 1299,
		Color = rgb(160, 92, 255),
		OneTime = true,
		Grants = {
			{ Kind = "Tickets", Amount = 30 },
			{ Kind = "Potion", Potion = "Views", Minutes = 60 },
			{ Kind = "Potion", Potion = "Clout", Minutes = 60 },
			{ Kind = "Clout", Pads = 400 },
		},
	},
	{
		Key = "SkipRebirth",
		Id = 0,
		Name = "Skip Rebirth",
		Emoji = "⏩",
		Description = "Rebirth right now, no Video requirement",
		Price = 99,
		Color = rgb(255, 210, 63),
		Grants = { { Kind = "Rebirth" } },
	},
	{
		Key = "ViewsPotion",
		Id = 0,
		Name = "x2 Views (15 min)",
		Emoji = "🧪",
		Description = "Double views for 15 minutes",
		Price = 19,
		Color = rgb(255, 72, 96),
		Grants = { { Kind = "Potion", Potion = "Views", Minutes = 15 } },
	},
	{
		Key = "CloutPotion",
		Id = 0,
		Name = "x2 Clout (15 min)",
		Emoji = "🧪",
		Description = "Double clout for 15 minutes",
		Price = 19,
		Color = rgb(255, 170, 40),
		Grants = { { Kind = "Potion", Potion = "Clout", Minutes = 15 } },
	},
	{
		Key = "CloutSmall",
		Id = 0,
		Name = "Clout Stack",
		Emoji = "💰",
		Description = "20 pad claims worth of clout",
		Price = 29,
		Color = rgb(255, 196, 46),
		Grants = { { Kind = "Clout", Pads = 20 } },
	},
	{
		Key = "CloutMedium",
		Id = 0,
		Name = "Clout Vault",
		Emoji = "💰",
		Description = "100 pad claims worth of clout",
		Price = 99,
		Color = rgb(255, 196, 46),
		Grants = { { Kind = "Clout", Pads = 100 } },
	},
	{
		Key = "CloutLarge",
		Id = 0,
		Name = "Clout Mansion",
		Emoji = "🏦",
		Description = "400 pad claims worth of clout",
		Price = 299,
		Color = rgb(255, 196, 46),
		Grants = { { Kind = "Clout", Pads = 400 } },
	},
	{
		Key = "Tickets5",
		Id = 0,
		Name = "5 Niche Tickets",
		Emoji = "🎟️",
		Description = "5 rolls at a better niche",
		Price = 49,
		Color = rgb(120, 200, 255),
		Grants = { { Kind = "Tickets", Amount = 5 } },
	},
	{
		Key = "Tickets25",
		Id = 0,
		Name = "25 Niche Tickets",
		Emoji = "🎟️",
		Description = "25 rolls at a better niche",
		Price = 199,
		Color = rgb(120, 200, 255),
		Grants = { { Kind = "Tickets", Amount = 25 } },
	},
} :: { Product }

Products.PassByKey = {} :: { [string]: Pass }
for _, p in Products.Passes do
	Products.PassByKey[p.Key] = p
end
Products.ProductByKey = {} :: { [string]: Product }
for _, p in Products.Products do
	Products.ProductByKey[p.Key] = p
end

-- Optional Roblox group for the +10% group bonus. 0 = disabled.
Products.GroupId = 0

return Products
