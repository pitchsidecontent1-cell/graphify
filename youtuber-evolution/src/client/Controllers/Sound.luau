--!strict
-- UI/feedback sounds from Config/Assets (respects the SFX setting).

local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Assets = require(Shared.Config.Assets)
local State = require(script.Parent.State)

local Sound = {}

local folder: Folder? = nil
local cache: { [string]: Sound } = {}
local music: Sound? = nil

local function getSound(name: string): Sound?
	local def = Assets.Sounds[name]
	if not def or def.Id == "" then
		return nil
	end
	local existing = cache[name]
	if existing then
		return existing
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = def.Id
	s.Volume = def.Volume
	s.Parent = folder
	cache[name] = s
	return s
end

-- pitch: multiplier on top of the configured speed (for rising combos)
function Sound.Play(name: string, pitch: number?)
	if State.IsLoaded and State.Data.Settings.SFX == false then
		return
	end
	local s = getSound(name)
	if not s then
		return
	end
	local def = Assets.Sounds[name]
	s.PlaybackSpeed = (def.Speed or 1) * (pitch or 1)
	SoundService:PlayLocalSound(s)
end

function Sound.SetWorldMusic(world: number)
	local id = Assets.Music[world] or ""
	if music then
		music:Stop()
		music:Destroy()
		music = nil
	end
	if id == "" then
		return
	end
	local m = Instance.new("Sound")
	m.Name = "Music"
	m.SoundId = id
	m.Looped = true
	m.Volume = if State.IsLoaded and State.Data.Settings.Music == false then 0 else 0.35
	m.Parent = folder
	m:Play()
	music = m
end

function Sound.Init()
	local f = Instance.new("Folder")
	f.Name = "UISounds"
	f.Parent = SoundService
	folder = f
end

function Sound.Start()
	State.On("Settings", function(settings)
		if music then
			music.Volume = if settings.Music == false then 0 else 0.35
		end
	end)
	State.On("World", function(world)
		Sound.SetWorldMusic(world)
	end)
end

return Sound
