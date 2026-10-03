-- Dumps every part of the baked map to JSON for tools/preview/render.py
-- Usage: lune run tools/preview/export.luau YoutuberEvolution.rbxl build/parts.json
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local map = game:GetService("Workspace"):FindFirstChild("Map")
local out = {}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 0.95 then
		local cf = d.CFrame
		local p, r, u, l = cf.Position, cf.RightVector, cf.UpVector, cf.LookVector
		local shape = "Block"
		if d.ClassName == "Part" then
			shape = d.Shape.Name
		elseif d.ClassName == "WedgePart" then
			shape = "Wedge"
		end
		local mesh = d:FindFirstChildWhichIsA("SpecialMesh")
		if mesh then
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
print("exported", #out, "parts")
