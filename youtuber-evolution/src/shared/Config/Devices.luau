--!strict
-- 84 devices (21 per world). Your best owned device sets your base views per
-- step. Values/costs come from Economy.Devices so the whole curve is tunable.

local Economy = require(script.Parent.Economy)

export type Device = {
	Id: string,
	Index: number, -- 1..84 global tier
	Tier: number, -- 1..21 inside its world
	World: number,
	Kind: string,
	Name: string,
	Rarity: string,
	Value: number, -- views per step
	Cost: number, -- clout
	Body: Color3,
	Trim: Color3,
	Accent: Color3,
	Glow: boolean,
	Sparkle: boolean,
	Metal: boolean,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

type Entry = { Name: string, Body: Color3, Trim: Color3, Accent: Color3 }

local function e(name: string, body: Color3, trim: Color3, accent: Color3): Entry
	return { Name = name, Body = body, Trim = trim, Accent = accent }
end

local NAMES: { { Entry } } = {
	-- World 1: Cameras
	{
		e("Potato Cam", rgb(150, 120, 90), rgb(90, 70, 50), rgb(60, 60, 70)),
		e("Toy Camera", rgb(255, 120, 120), rgb(255, 230, 120), rgb(80, 180, 255)),
		e("Point & Shoot", rgb(200, 200, 210), rgb(70, 70, 80), rgb(40, 40, 50)),
		e("Film Camera", rgb(60, 60, 70), rgb(220, 220, 225), rgb(30, 30, 40)),
		e("Disposable Cam", rgb(255, 210, 60), rgb(40, 140, 80), rgb(30, 30, 40)),
		e("Instant Camera", rgb(240, 240, 245), rgb(255, 120, 160), rgb(40, 40, 60)),
		e("Compact Zoom", rgb(80, 150, 255), rgb(230, 230, 240), rgb(30, 30, 50)),
		e("Webcam", rgb(40, 40, 50), rgb(120, 120, 140), rgb(80, 220, 255)),
		e("Action Cam", rgb(255, 140, 40), rgb(40, 40, 50), rgb(60, 200, 255)),
		e("Vlog Cam", rgb(255, 80, 110), rgb(255, 255, 255), rgb(40, 40, 60)),
		e("Entry DSLR", rgb(50, 50, 60), rgb(255, 80, 80), rgb(20, 20, 30)),
		e("Mirrorless", rgb(180, 190, 210), rgb(50, 50, 60), rgb(90, 160, 255)),
		e("Camcorder", rgb(70, 70, 90), rgb(255, 200, 60), rgb(255, 60, 60)),
		e("Prosumer Cam", rgb(30, 30, 40), rgb(255, 180, 40), rgb(80, 220, 255)),
		e("Studio DSLR", rgb(110, 60, 200), rgb(255, 255, 255), rgb(255, 210, 60)),
		e("Cinema Cam", rgb(20, 20, 30), rgb(255, 60, 80), rgb(255, 60, 80)),
		e("Golden Lens", rgb(255, 196, 46), rgb(255, 240, 180), rgb(40, 30, 10)),
		e("Diamond DSLR", rgb(140, 230, 255), rgb(255, 255, 255), rgb(60, 140, 255)),
		e("Neon Rig", rgb(30, 20, 50), rgb(255, 60, 200), rgb(60, 240, 255)),
		e("Ruby Cine Rig", rgb(220, 20, 60), rgb(255, 210, 90), rgb(255, 120, 140)),
		e("Legendary Lens", rgb(20, 10, 40), rgb(255, 255, 255), rgb(255, 255, 255)),
	},
	-- World 2: Phones
	{
		e("Brick Phone", rgb(90, 90, 100), rgb(60, 200, 90), rgb(120, 200, 120)),
		e("Flip Phone", rgb(180, 180, 200), rgb(80, 80, 100), rgb(80, 160, 255)),
		e("Slide Phone", rgb(255, 120, 60), rgb(40, 40, 50), rgb(100, 200, 255)),
		e("Cracked Phone", rgb(60, 60, 70), rgb(200, 200, 210), rgb(140, 200, 255)),
		e("Budget Phone", rgb(80, 200, 140), rgb(30, 30, 40), rgb(160, 230, 255)),
		e("Camera Phone", rgb(240, 240, 250), rgb(40, 40, 60), rgb(90, 170, 255)),
		e("Selfie Phone", rgb(255, 150, 200), rgb(255, 255, 255), rgb(255, 200, 230)),
		e("Gaming Phone", rgb(30, 30, 40), rgb(255, 60, 60), rgb(255, 80, 80)),
		e("Pro Phone", rgb(60, 70, 100), rgb(200, 200, 220), rgb(120, 180, 255)),
		e("Fold Phone", rgb(100, 80, 200), rgb(220, 220, 240), rgb(160, 120, 255)),
		e("Glass Phone", rgb(180, 240, 255), rgb(255, 255, 255), rgb(120, 230, 255)),
		e("Neon Phone", rgb(30, 20, 50), rgb(255, 64, 190), rgb(46, 230, 255)),
		e("Gold Phone", rgb(255, 196, 46), rgb(255, 245, 200), rgb(255, 230, 120)),
		e("Hologram Phone", rgb(120, 255, 240), rgb(255, 255, 255), rgb(160, 255, 255)),
		e("Quantum Phone", rgb(40, 10, 80), rgb(160, 90, 255), rgb(200, 140, 255)),
		e("Ruby Phone", rgb(220, 20, 60), rgb(255, 200, 210), rgb(255, 90, 120)),
		e("Diamond Phone", rgb(170, 240, 255), rgb(255, 255, 255), rgb(90, 200, 255)),
		e("Galaxy Phone", rgb(30, 10, 70), rgb(255, 120, 230), rgb(140, 120, 255)),
		e("Plasma Phone", rgb(255, 90, 30), rgb(255, 230, 90), rgb(255, 160, 40)),
		e("Infinity Phone", rgb(10, 10, 20), rgb(255, 255, 255), rgb(255, 255, 255)),
		e("Mythic Phone", rgb(255, 255, 255), rgb(255, 60, 140), rgb(255, 200, 60)),
	},
	-- World 3: Laptops / PCs
	{
		e("Ancient Laptop", rgb(200, 190, 160), rgb(120, 110, 90), rgb(60, 120, 80)),
		e("Clunky Laptop", rgb(70, 70, 80), rgb(160, 160, 170), rgb(80, 140, 255)),
		e("School Laptop", rgb(60, 120, 220), rgb(230, 230, 240), rgb(160, 220, 255)),
		e("Budget Laptop", rgb(200, 200, 210), rgb(60, 60, 70), rgb(140, 200, 255)),
		e("Office PC", rgb(230, 230, 235), rgb(90, 90, 100), rgb(100, 180, 255)),
		e("Gaming Laptop", rgb(30, 30, 40), rgb(255, 60, 60), rgb(255, 80, 80)),
		e("RGB Laptop", rgb(30, 30, 40), rgb(80, 255, 120), rgb(255, 80, 220)),
		e("Editing Laptop", rgb(190, 200, 215), rgb(255, 255, 255), rgb(90, 160, 255)),
		e("Tower PC", rgb(40, 40, 55), rgb(80, 220, 255), rgb(80, 220, 255)),
		e("Dual Monitor PC", rgb(50, 50, 70), rgb(255, 210, 60), rgb(120, 200, 255)),
		e("Liquid-Cooled PC", rgb(20, 30, 50), rgb(60, 200, 255), rgb(60, 255, 220)),
		e("Streamer PC", rgb(120, 60, 220), rgb(255, 255, 255), rgb(200, 140, 255)),
		e("Render Beast", rgb(30, 30, 30), rgb(255, 120, 30), rgb(255, 140, 40)),
		e("Frost Rig", rgb(200, 240, 255), rgb(80, 160, 255), rgb(140, 230, 255)),
		e("Glitch PC", rgb(20, 20, 30), rgb(120, 255, 90), rgb(255, 60, 200)),
		e("Gold Workstation", rgb(255, 196, 46), rgb(60, 40, 10), rgb(255, 240, 160)),
		e("Server Rack", rgb(40, 50, 70), rgb(80, 255, 140), rgb(80, 255, 140)),
		e("Quantum PC", rgb(30, 10, 70), rgb(170, 110, 255), rgb(200, 160, 255)),
		e("AI Supercomputer", rgb(230, 240, 255), rgb(60, 140, 255), rgb(80, 255, 255)),
		e("Hyper Core", rgb(220, 20, 60), rgb(255, 220, 120), rgb(255, 120, 140)),
		e("The Mainframe", rgb(10, 10, 20), rgb(255, 255, 255), rgb(255, 255, 255)),
	},
	-- World 4: Full studio setups
	{
		e("Messy Desk", rgb(160, 110, 70), rgb(90, 60, 40), rgb(120, 180, 255)),
		e("Bedroom Setup", rgb(120, 140, 200), rgb(255, 230, 180), rgb(160, 210, 255)),
		e("Ring Light Setup", rgb(240, 240, 250), rgb(60, 60, 80), rgb(255, 250, 220)),
		e("Mic Setup", rgb(40, 40, 50), rgb(200, 200, 210), rgb(255, 80, 80)),
		e("Green Screen", rgb(60, 220, 90), rgb(40, 40, 50), rgb(200, 255, 200)),
		e("Podcast Desk", rgb(110, 70, 40), rgb(255, 200, 80), rgb(255, 100, 100)),
		e("Gaming Throne", rgb(30, 30, 40), rgb(255, 60, 60), rgb(255, 80, 80)),
		e("Twin Ring Lights", rgb(255, 255, 255), rgb(255, 120, 200), rgb(255, 230, 250)),
		e("Studio Lights", rgb(60, 60, 70), rgb(255, 210, 60), rgb(255, 240, 180)),
		e("Sound Booth", rgb(80, 60, 130), rgb(220, 220, 240), rgb(160, 120, 255)),
		e("Neon Studio", rgb(20, 10, 40), rgb(255, 64, 190), rgb(46, 230, 255)),
		e("Broadcast Desk", rgb(40, 60, 120), rgb(255, 255, 255), rgb(120, 200, 255)),
		e("TV Studio", rgb(60, 60, 80), rgb(255, 80, 80), rgb(255, 220, 120)),
		e("Concert Stage", rgb(30, 20, 60), rgb(255, 200, 60), rgb(255, 120, 220)),
		e("Hologram Stage", rgb(120, 255, 240), rgb(255, 255, 255), rgb(170, 255, 255)),
		e("Golden Studio", rgb(255, 196, 46), rgb(255, 245, 200), rgb(255, 240, 150)),
		e("Galaxy Studio", rgb(40, 20, 90), rgb(255, 150, 230), rgb(140, 120, 255)),
		e("Satellite Uplink", rgb(220, 225, 240), rgb(60, 120, 255), rgb(120, 220, 255)),
		e("Mega Broadcast", rgb(220, 20, 60), rgb(255, 220, 120), rgb(255, 140, 160)),
		e("Cosmic Network", rgb(10, 10, 30), rgb(255, 230, 120), rgb(255, 255, 255)),
		e("THE ALGORITHM", rgb(255, 255, 255), rgb(20, 10, 40), rgb(255, 60, 140)),
	},
}

local KINDS = { "Camera", "Phone", "Laptop", "Studio" }

local function rarityForTier(tier: number): string
	if tier <= 5 then
		return "Common"
	elseif tier <= 9 then
		return "Uncommon"
	elseif tier <= 13 then
		return "Rare"
	elseif tier <= 16 then
		return "Epic"
	elseif tier <= 19 then
		return "Legendary"
	elseif tier == 20 then
		return "Mythic"
	end
	return "Secret"
end

local function valueFor(i: number): number
	local cfg = Economy.Devices
	return math.floor(cfg.Growth ^ (i - 1) + (i - 1) * 0.5 + 0.5)
end

local function costFor(i: number): number
	if i <= 1 then
		return 0
	end
	local cfg = Economy.Devices
	return math.floor(cfg.CostBase * cfg.CostGrowth ^ (i - 2))
end

-- Rounds big numbers to 2 significant digits so prices read cleanly (1.2K, 45M).
local function nice(n: number): number
	if n < 100 then
		return math.floor(n)
	end
	local digits = math.floor(math.log10(n)) + 1
	local scale = 10 ^ (digits - 2)
	return math.floor(n / scale + 0.5) * scale
end

local Devices = {}
Devices.List = {} :: { Device }
Devices.ById = {} :: { [string]: Device }
Devices.ByWorld = {} :: { [number]: { Device } }

local prevValue, prevCost = 0, -1
for w = 1, 4 do
	Devices.ByWorld[w] = {}
	for t = 1, 21 do
		local entry = NAMES[w][t]
		local index = (w - 1) * 21 + t
		local rarity = rarityForTier(t)
		local value = math.max(nice(valueFor(index)), prevValue + 1)
		local cost = math.max(nice(costFor(index)), prevCost + 1)
		prevValue, prevCost = value, cost
		local device: Device = {
			Id = "d" .. index,
			Index = index,
			Tier = t,
			World = w,
			Kind = KINDS[w],
			Name = entry.Name,
			Rarity = rarity,
			Value = value,
			Cost = cost,
			Body = entry.Body,
			Trim = entry.Trim,
			Accent = entry.Accent,
			Glow = t >= 11,
			Sparkle = t >= 17,
			Metal = t >= 8,
		}
		table.insert(Devices.List, device)
		table.insert(Devices.ByWorld[w], device)
		Devices.ById[device.Id] = device
	end
end

Devices.Starter = "d1"

return Devices
