-- Prints the generated progression tables (devices, videos, pads) for review.
-- Usage: lune run tools/inspect.luau build/base.rbxl
local process = require("@lune/process")
local rbxenv = require("./rbxenv")
local game = rbxenv.loadPlace(process.args[1] or "build/base.rbxl")
local env = rbxenv.new(game)
local Shared = game:GetService("ReplicatedStorage").Shared
local Devices = env.require(Shared.Config.Devices)
local Stats = env.require(Shared.Util.Stats)
local Format = env.require(Shared.Util.Format)
local Worlds = env.require(Shared.Config.Worlds)
local Pets = env.require(Shared.Config.Pets)

print("== Devices")
for _, d in Devices.List do
	if d.Tier == 1 or d.Tier % 5 == 0 or d.Tier == 21 then
		print(
			string.format(
				"%-3s W%d T%-2d %-18s %-9s +%-8s cost %s",
				d.Id,
				d.World,
				d.Tier,
				d.Name,
				d.Rarity,
				Format.Abbrev(d.Value),
				Format.Abbrev(d.Cost)
			)
		)
	end
end
print("== Videos")
for _, v in { 2, 5, 10, 20, 30, 50, 78, 100, 142, 170, 206, 210 } do
	print("video", v, Format.Abbrev(Stats.ViewsForVideo(v)))
end
print("== Pads (base)")
for w = 1, 4 do
	print(
		"W" .. w,
		Format.Abbrev(Stats.PadBase(w, 1)),
		Format.Abbrev(Stats.PadBase(w, 15)),
		"rival power",
		Format.Abbrev(Stats.RivalPower(w))
	)
end
print("== Eggs")
for _, id in Pets.EggOrder do
	local e = Pets.Eggs[id]
	local sum = 0
	for _, pid in e.Pets do
		sum += Pets.ById[pid].Chance
	end
	print(id, Format.Abbrev(e.Cost), "chance sum", sum)
end
print("== Format")
for _, n in { 0, 7, 999, 1000, 1500, 12970, 381830, 999999, 1e6, 167.36e9, 1.2e18, 5e66 } do
	print(n, Format.Abbrev(n))
end
