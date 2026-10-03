--!strict
-- Clout-bought upgrades. Cost(level) = floor(Base * Growth^level).

export type Upgrade = {
	Id: string,
	Name: string,
	Emoji: string,
	Description: string,
	Max: number,
	Per: number,
	Base: number,
	Growth: number,
	Format: string, -- "speed" | "percent"
}

local Upgrades: { Upgrade } = {
	{
		Id = "Speed",
		Name = "Walk Speed",
		Emoji = "👟",
		Description = "Walk faster = more steps = more views",
		Max = 15,
		Per = 1,
		Base = 25,
		Growth = 2.4,
		Format = "speed",
	},
	{
		Id = "Clout",
		Name = "Clout Bonus",
		Emoji = "💰",
		Description = "More clout from every pad",
		Max = 30,
		Per = 0.1,
		Base = 40,
		Growth = 1.8,
		Format = "percent",
	},
	{
		Id = "Treadmill",
		Name = "Treadmill Power",
		Emoji = "🏃",
		Description = "Treadmills give more views per second",
		Max = 30,
		Per = 0.1,
		Base = 30,
		Growth = 1.8,
		Format = "percent",
	},
}

return Upgrades
