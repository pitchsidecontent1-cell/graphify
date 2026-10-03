--!strict
-- "Creator Pop" visual identity. Every UI color, font and rarity style comes
-- from here so the whole game stays consistent.

local Theme = {}

Theme.Colors = {
	Ink = Color3.fromRGB(27, 21, 48),
	InkSoft = Color3.fromRGB(48, 39, 78),
	Panel = Color3.fromRGB(44, 35, 70),
	PanelDark = Color3.fromRGB(30, 24, 50),
	PanelLight = Color3.fromRGB(64, 52, 100),
	White = Color3.fromRGB(255, 255, 255),
	Cream = Color3.fromRGB(255, 248, 235),
	Red = Color3.fromRGB(255, 59, 78),
	Yellow = Color3.fromRGB(255, 210, 63),
	Orange = Color3.fromRGB(255, 145, 48),
	Cyan = Color3.fromRGB(46, 230, 240),
	Blue = Color3.fromRGB(59, 150, 255),
	Purple = Color3.fromRGB(139, 92, 246),
	Pink = Color3.fromRGB(255, 92, 184),
	Mint = Color3.fromRGB(61, 220, 151),
	Green = Color3.fromRGB(88, 214, 84),
	Grey = Color3.fromRGB(140, 136, 160),
	Gold = Color3.fromRGB(255, 196, 46),
	Clout = Color3.fromRGB(255, 196, 46),
	Views = Color3.fromRGB(255, 72, 96),
	Ticket = Color3.fromRGB(120, 200, 255),
}

export type RarityStyle = {
	Name: string,
	Order: number,
	Color: Color3,
	Dark: Color3,
	Animated: boolean?,
}

Theme.Rarities = {
	Common = { Name = "Common", Order = 1, Color = Color3.fromRGB(184, 193, 204), Dark = Color3.fromRGB(110, 118, 132) },
	Uncommon = {
		Name = "Uncommon",
		Order = 2,
		Color = Color3.fromRGB(91, 227, 125),
		Dark = Color3.fromRGB(38, 140, 70),
	},
	Rare = { Name = "Rare", Order = 3, Color = Color3.fromRGB(59, 168, 255), Dark = Color3.fromRGB(28, 96, 180) },
	Epic = { Name = "Epic", Order = 4, Color = Color3.fromRGB(180, 92, 255), Dark = Color3.fromRGB(104, 40, 176) },
	Legendary = {
		Name = "Legendary",
		Order = 5,
		Color = Color3.fromRGB(255, 183, 3),
		Dark = Color3.fromRGB(196, 110, 0),
	},
	Mythic = { Name = "Mythic", Order = 6, Color = Color3.fromRGB(255, 59, 107), Dark = Color3.fromRGB(170, 20, 60) },
	Secret = {
		Name = "Secret",
		Order = 7,
		Color = Color3.fromRGB(255, 255, 255),
		Dark = Color3.fromRGB(60, 40, 90),
		Animated = true,
	},
} :: { [string]: RarityStyle }

Theme.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Theme.Rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 90)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 50)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 230, 110)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(50, 200, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(160, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 90)),
})

Theme.Fonts = {
	Display = Font.fromEnum(Enum.Font.FredokaOne),
	Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
	BodyHeavy = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
}

Theme.Corner = 18
Theme.Stroke = 3

function Theme.Lighten(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

function Theme.Darken(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

return Theme
