--!strict
-- Each world has its own lighting mood; tween to it when you arrive.

local LightingService = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local State = require(script.Parent.State)

local Lighting = {}

local current = 0

local function apply(world: number, instant: boolean?)
	local w = Worlds[world]
	if not w or world == current then
		return
	end
	current = world
	local p = w.Lighting
	local info = TweenInfo.new(if instant then 0 else 1.6, Enum.EasingStyle.Sine)
	TweenService:Create(LightingService, info, {
		ClockTime = p.ClockTime,
		Brightness = p.Brightness,
		Ambient = p.Ambient,
		OutdoorAmbient = p.OutdoorAmbient,
	}):Play()
	local atmosphere = LightingService:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, {
			Color = p.AtmosphereColor,
			Decay = p.AtmosphereDecay,
			Density = p.AtmosphereDensity,
			Haze = p.AtmosphereHaze,
		}):Play()
	end
	local cc = LightingService:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		TweenService:Create(cc, info, { Saturation = p.Saturation, TintColor = p.Tint }):Play()
	end
	local bloom = LightingService:FindFirstChildOfClass("BloomEffect")
	if bloom then
		TweenService:Create(bloom, info, { Intensity = p.BloomIntensity }):Play()
	end
end

function Lighting.Init() end

function Lighting.Start()
	State.On("World", function(world)
		apply(world, current == 0)
	end)
end

return Lighting
