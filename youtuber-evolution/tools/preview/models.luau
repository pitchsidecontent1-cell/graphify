-- Builds a showcase grid of devices + pets and exports parts for render.py
-- Usage: lune run tools/preview/models.luau build/base.rbxl build/models.json
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local rbxenv = require("../rbxenv")

local game = rbxenv.loadPlace(process.args[1])
local env = rbxenv.new(game)
local Shared = game:GetService("ReplicatedStorage").Shared
local DeviceModels = env.require(Shared.Models.DeviceModels)
local PetModels = env.require(Shared.Models.PetModels)
local Devices = env.require(Shared.Config.Devices)
local Pets = env.require(Shared.Config.Pets)
local CFrame = roblox.CFrame

local root = roblox.Instance.new("Model")
local which = process.args[3] or "devices"
if which == "devices" then
	local picks = { 1, 5, 9, 13, 17, 21 }
	for w = 1, 4 do
		for i, t in picks do
			local d = Devices.ByWorld[w][t]
			local m =
				DeviceModels.Build(d, CFrame.new((i - 3.5) * 5, 0, (w - 2.5) * 6) * CFrame.Angles(0, math.rad(-25), 0))
			m.Parent = root
		end
	end
else
	local i = 0
	for _, eggId in Pets.EggOrder do
		for _, petId in Pets.Eggs[eggId].Pets do
			i += 1
			local col = (i - 1) % 8
			local row = math.floor((i - 1) / 8)
			local m = PetModels.Build(
				Pets.ById[petId],
				CFrame.new((col - 3.5) * 5, 0, (row - 2) * 6) * CFrame.Angles(0, math.rad(-25), 0)
			)
			m.Parent = root
		end
	end
end
local out = {}
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 0.95 then
		local cf = d.CFrame
		local p, r, u, l = cf.Position, cf.RightVector, cf.UpVector, cf.LookVector
		local shape = "Block"
		if d.ClassName == "Part" then
			shape = d.Shape.Name
		elseif d.ClassName == "WedgePart" then
			shape = "Wedge"
		end
		if d:FindFirstChildWhichIsA("SpecialMesh") then
			shape = "Ball"
		end
		local c = d.Color
		table.insert(out, {
			p = { p.X, p.Y, p.Z },
			r = { r.X, r.Y, r.Z },
			u = { u.X, u.Y, u.Z },
			l = { l.X, l.Y, l.Z },
			s = { d.Size.X, d.Size.Y, d.Size.Z },
			c = { c.R, c.G, c.B },
			t = d.Transparency,
			m = d.Material.Name,
			sh = shape,
		})
	end
end
fs.writeFile(process.args[2], serde.encode("json", out))
print("exported", #out)
