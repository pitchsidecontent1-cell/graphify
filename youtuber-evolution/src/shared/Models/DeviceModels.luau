--!strict
-- Builds the blocky 3D model for any device (cameras, phones, laptops,
-- studio rigs). Used for the held item, shop pedestals and UI viewports.
-- The model's PrimaryPart "Handle" sits at `origin`; the device faces -Z.

local Devices = require(script.Parent.Parent.Config.Devices)
local PropKit = require(script.Parent.PropKit)

type Device = Devices.Device

local DeviceModels = {}

local function mat(device: Device): Enum.Material
	return if device.Metal then Enum.Material.Metal else Enum.Material.SmoothPlastic
end

local function accentMat(device: Device): Enum.Material
	return if device.Glow then Enum.Material.Neon else Enum.Material.Glass
end

local function camera(model: Model, d: Device, o: CFrame): BasePart
	local body = PropKit.Part({
		Name = "Handle",
		Size = Vector3.new(2.4, 1.5, 1.1),
		CFrame = o,
		Color = d.Body,
		Material = mat(d),
		Parent = model,
	})
	PropKit.Part({
		Name = "Grip",
		Size = Vector3.new(0.55, 1.55, 1.25),
		CFrame = o * CFrame.new(-1.0, 0, 0.02),
		Color = d.Trim,
		Material = mat(d),
		Parent = model,
	})
	PropKit.Part({
		Name = "Finder",
		Size = Vector3.new(0.9, 0.45, 0.8),
		CFrame = o * CFrame.new(0.35, 0.95, 0.1),
		Color = d.Trim,
		Material = mat(d),
		Parent = model,
	})
	PropKit.Tube({
		Name = "LensBarrel",
		Size = Vector3.new(1.15, 1.15, 0.75),
		CFrame = o * CFrame.new(0.15, -0.05, -0.85),
		Color = d.Trim,
		Material = mat(d),
		Parent = model,
	})
	PropKit.Tube({
		Name = "LensRing",
		Size = Vector3.new(1.3, 1.3, 0.18),
		CFrame = o * CFrame.new(0.15, -0.05, -1.2),
		Color = d.Body,
		Material = mat(d),
		Parent = model,
	})
	PropKit.Tube({
		Name = "Glass",
		Size = Vector3.new(0.8, 0.8, 0.08),
		CFrame = o * CFrame.new(0.15, -0.05, -1.27),
		Color = d.Accent,
		Material = accentMat(d),
		Parent = model,
	})
	PropKit.Disc({
		Name = "Shutter",
		Size = Vector3.new(0.35, 0.18, 0.35),
		CFrame = o * CFrame.new(-0.85, 0.83, 0),
		Color = d.Accent,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	if d.Tier >= 5 then
		PropKit.Part({
			Name = "Flash",
			Size = Vector3.new(0.5, 0.3, 0.12),
			CFrame = o * CFrame.new(0.85, 0.45, -0.57),
			Color = Color3.fromRGB(255, 252, 230),
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end
	if d.Tier >= 9 then
		PropKit.Part({
			Name = "Band",
			Size = Vector3.new(2.42, 0.22, 1.12),
			CFrame = o * CFrame.new(0, -0.35, 0),
			Color = d.Accent,
			Material = accentMat(d),
			Parent = model,
		})
	end
	if d.Tier >= 13 then
		PropKit.Part({
			Name = "TopHandle",
			Size = Vector3.new(1.6, 0.25, 0.3),
			CFrame = o * CFrame.new(0, 1.45, 0),
			Color = d.Trim,
			Material = mat(d),
			Parent = model,
		})
		for _, x in { -0.7, 0.7 } do
			PropKit.Part({
				Name = "HandlePost",
				Size = Vector3.new(0.2, 0.5, 0.2),
				CFrame = o * CFrame.new(x, 1.15, 0),
				Color = d.Trim,
				Material = mat(d),
				Parent = model,
			})
		end
	end
	if d.Tier >= 17 then
		PropKit.Part({
			Name = "Hood",
			Size = Vector3.new(1.5, 1.5, 0.12),
			CFrame = o * CFrame.new(0.15, -0.05, -1.4),
			Color = d.Trim,
			Material = mat(d),
			Transparency = 0.15,
			Parent = model,
		})
	end
	return body
end

local function phone(model: Model, d: Device, o: CFrame): BasePart
	local body = PropKit.Part({
		Name = "Handle",
		Size = Vector3.new(1.2, 2.1, 0.22),
		CFrame = o,
		Color = d.Body,
		Material = mat(d),
		Parent = model,
	})
	PropKit.Part({
		Name = "Screen",
		Size = Vector3.new(1.02, 1.85, 0.04),
		CFrame = o * CFrame.new(0, 0, -0.12),
		Color = d.Accent,
		Material = accentMat(d),
		Parent = model,
	})
	PropKit.Part({
		Name = "Notch",
		Size = Vector3.new(0.35, 0.08, 0.05),
		CFrame = o * CFrame.new(0, 0.86, -0.14),
		Color = d.Body,
		Parent = model,
	})
	PropKit.Part({
		Name = "Bump",
		Size = Vector3.new(0.55, 0.55, 0.1),
		CFrame = o * CFrame.new(-0.25, 0.65, 0.15),
		Color = d.Trim,
		Material = mat(d),
		Parent = model,
	})
	PropKit.Tube({
		Name = "Lens",
		Size = Vector3.new(0.22, 0.22, 0.06),
		CFrame = o * CFrame.new(-0.25, 0.65, 0.22) * CFrame.Angles(0, math.rad(180), 0),
		Color = Color3.fromRGB(20, 20, 30),
		Material = Enum.Material.Glass,
		Parent = model,
	})
	PropKit.Part({
		Name = "Edge",
		Size = Vector3.new(1.26, 2.16, 0.12),
		CFrame = o * CFrame.new(0, 0, 0.02),
		Color = d.Trim,
		Material = mat(d),
		Parent = model,
	})
	if d.Tier >= 10 then
		-- second camera lens + glow strip
		PropKit.Tube({
			Name = "Lens2",
			Size = Vector3.new(0.18, 0.18, 0.06),
			CFrame = o * CFrame.new(-0.25, 0.48, 0.22) * CFrame.Angles(0, math.rad(180), 0),
			Color = Color3.fromRGB(20, 20, 30),
			Material = Enum.Material.Glass,
			Parent = model,
		})
	end
	if d.Tier >= 14 then
		PropKit.Part({
			Name = "Halo",
			Size = Vector3.new(1.4, 2.3, 0.04),
			CFrame = o * CFrame.new(0, 0, 0.14),
			Color = d.Accent,
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			CanCollide = false,
			Parent = model,
		})
	end
	return body
end

local function laptop(model: Model, d: Device, o: CFrame): BasePart
	local base = PropKit.Part({
		Name = "Handle",
		Size = Vector3.new(2.6, 0.18, 1.8),
		CFrame = o,
		Color = d.Body,
		Material = mat(d),
		Parent = model,
	})
	PropKit.Part({
		Name = "Keys",
		Size = Vector3.new(2.2, 0.04, 0.8),
		CFrame = o * CFrame.new(0, 0.1, 0.2),
		Color = Color3.fromRGB(30, 30, 40),
		Parent = model,
	})
	PropKit.Part({
		Name = "Pad",
		Size = Vector3.new(0.8, 0.04, 0.5),
		CFrame = o * CFrame.new(0, 0.1, -0.55),
		Color = d.Trim,
		Parent = model,
	})
	-- lid hinges at the back (+Z) and leans back; the screen faces the viewer (-Z)
	local hinge = o * CFrame.new(0, 0.09, 0.88) * CFrame.Angles(math.rad(14), 0, 0)
	PropKit.Part({
		Name = "Lid",
		Size = Vector3.new(2.6, 1.7, 0.12),
		CFrame = hinge * CFrame.new(0, 0.85, 0),
		Color = d.Body,
		Material = mat(d),
		Parent = model,
	})
	PropKit.Part({
		Name = "Screen",
		Size = Vector3.new(2.35, 1.45, 0.03),
		CFrame = hinge * CFrame.new(0, 0.86, -0.075),
		Color = d.Accent,
		Material = accentMat(d),
		Parent = model,
	})
	PropKit.Part({
		Name = "Logo",
		Size = Vector3.new(0.35, 0.35, 0.03),
		CFrame = hinge * CFrame.new(0, 0.9, 0.075),
		Color = d.Trim,
		Material = if d.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		Parent = model,
	})
	if d.Tier >= 7 then
		PropKit.Part({
			Name = "RGB",
			Size = Vector3.new(2.64, 0.06, 1.84),
			CFrame = o * CFrame.new(0, -0.08, 0),
			Color = d.Trim,
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end
	if d.Tier >= 12 then
		-- second monitor floating beside
		PropKit.Part({
			Name = "Monitor2",
			Size = Vector3.new(1.4, 1.0, 0.1),
			CFrame = hinge * CFrame.new(1.95, 0.9, -0.2) * CFrame.Angles(0, math.rad(25), 0),
			Color = d.Body,
			Material = mat(d),
			Parent = model,
		})
		PropKit.Part({
			Name = "Screen2",
			Size = Vector3.new(1.25, 0.85, 0.03),
			CFrame = hinge * CFrame.new(1.95, 0.9, -0.2) * CFrame.Angles(0, math.rad(25), 0) * CFrame.new(0, 0, -0.06),
			Color = d.Accent,
			Material = accentMat(d),
			Parent = model,
		})
	end
	return base
end

local function studio(model: Model, d: Device, o: CFrame): BasePart
	local pole = PropKit.Part({
		Name = "Handle",
		Size = Vector3.new(0.2, 2.6, 0.2),
		CFrame = o,
		Color = d.Trim,
		Material = mat(d),
		Parent = model,
	})
	local ringCenter = o * CFrame.new(0, 1.9, 0)
	local segments = 12
	local radius = 0.95
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		PropKit.Part({
			Name = "Ring",
			Size = Vector3.new(0.55, 0.22, 0.22),
			CFrame = ringCenter * CFrame.Angles(0, 0, a) * CFrame.new(0, radius, 0),
			Color = d.Accent,
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end
	-- phone in the middle of the ring
	PropKit.Part({
		Name = "Phone",
		Size = Vector3.new(0.6, 1.0, 0.1),
		CFrame = ringCenter,
		Color = d.Body,
		Material = mat(d),
		Parent = model,
	})
	PropKit.Part({
		Name = "PhoneScreen",
		Size = Vector3.new(0.5, 0.88, 0.02),
		CFrame = ringCenter * CFrame.new(0, 0, -0.06),
		Color = d.Trim,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	if d.Tier >= 4 then
		-- boom mic
		PropKit.Part({
			Name = "Boom",
			Size = Vector3.new(1.2, 0.12, 0.12),
			CFrame = o * CFrame.new(0.55, 0.9, 0) * CFrame.Angles(0, 0, math.rad(20)),
			Color = d.Trim,
			Material = mat(d),
			Parent = model,
		})
		PropKit.Part({
			Name = "Mic",
			Shape = "Ball",
			Size = Vector3.new(0.5, 0.5, 0.5),
			CFrame = o * CFrame.new(1.15, 1.15, 0),
			Color = d.Body,
			Material = Enum.Material.Metal,
			Parent = model,
		})
	end
	if d.Tier >= 9 then
		PropKit.Part({
			Name = "Cam",
			Size = Vector3.new(0.7, 0.5, 0.5),
			CFrame = o * CFrame.new(-0.6, 1.1, -0.1),
			Color = d.Body,
			Material = mat(d),
			Parent = model,
		})
		PropKit.Tube({
			Name = "CamLens",
			Size = Vector3.new(0.35, 0.35, 0.3),
			CFrame = o * CFrame.new(-0.6, 1.1, -0.45),
			Color = d.Accent,
			Material = accentMat(d),
			Parent = model,
		})
	end
	if d.Tier >= 15 then
		for i = 1, 3 do
			PropKit.Part({
				Name = "Screen",
				Size = Vector3.new(0.7, 0.45, 0.05),
				CFrame = ringCenter * CFrame.Angles(0, (i - 2) * 0.6, 0) * CFrame.new(0, 1.15, -0.3),
				Color = d.Accent,
				Material = Enum.Material.Neon,
				Transparency = 0.2,
				Parent = model,
			})
		end
	end
	return pole
end

local BUILDERS: { [string]: (Model, Device, CFrame) -> BasePart } = {
	Camera = camera,
	Phone = phone,
	Laptop = laptop,
	Studio = studio,
}

-- Approximate size of each archetype, for framing viewports.
DeviceModels.Extents = {
	Camera = 2.8,
	Phone = 2.4,
	Laptop = 3.2,
	Studio = 3.6,
} :: { [string]: number }

function DeviceModels.Build(device: Device, origin: CFrame?, withEffects: boolean?): Model
	local model = Instance.new("Model")
	model.Name = device.Name
	local root = BUILDERS[device.Kind](model, device, origin or CFrame.new())
	model.PrimaryPart = root
	if withEffects and device.Sparkle then
		PropKit.Sparkles(root, device.Accent, 4, 0.4)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	return model
end

function DeviceModels.BuildById(id: string, origin: CFrame?, withEffects: boolean?): Model?
	local d = Devices.ById[id]
	if not d then
		return nil
	end
	return DeviceModels.Build(d, origin, withEffects)
end

return DeviceModels
