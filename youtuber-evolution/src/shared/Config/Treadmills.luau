--!strict
-- AFK treadmills (one row in every world). Standing on one gives
-- ViewsPerStep * Economy.Treadmill.StepsPerSecond * Mult views per second.

export type Treadmill = {
	Id: string,
	Name: string,
	Mult: number,
	Rebirths: number,
	Pass: string?,
	Color: Color3,
	Stripe: Color3,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Treadmills: { Treadmill } = {
	{ Id = "Blue", Name = "Starter", Mult = 1, Rebirths = 0, Color = rgb(60, 170, 255), Stripe = rgb(150, 220, 255) },
	{ Id = "Orange", Name = "Hustle", Mult = 2, Rebirths = 2, Color = rgb(255, 146, 48), Stripe = rgb(255, 206, 140) },
	{ Id = "Purple", Name = "Grind", Mult = 3, Rebirths = 5, Color = rgb(160, 92, 255), Stripe = rgb(214, 180, 255) },
	{ Id = "Green", Name = "Viral", Mult = 4, Rebirths = 9, Color = rgb(88, 214, 84), Stripe = rgb(180, 245, 170) },
	{
		Id = "Pink",
		Name = "Trending",
		Mult = 5,
		Rebirths = 14,
		Color = rgb(255, 110, 196),
		Stripe = rgb(255, 196, 230),
	},
	{
		Id = "Gold",
		Name = "VIP",
		Mult = 25,
		Rebirths = 0,
		Pass = "VIP",
		Color = rgb(255, 200, 46),
		Stripe = rgb(255, 240, 170),
	},
	{
		Id = "Red",
		Name = "MEGA",
		Mult = 100,
		Rebirths = 0,
		Pass = "MegaTreadmill",
		Color = rgb(235, 40, 56),
		Stripe = rgb(30, 24, 40),
	},
}

return Treadmills
