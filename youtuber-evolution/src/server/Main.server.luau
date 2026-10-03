--!strict
-- Server entry point: Init every service, then Start them (in order).

local Workspace = game:GetService("Workspace")
local Services = script.Parent.Services

local ORDER = {
	"Comms",
	"DataService",
	"MapService",
	"ProgressService",
	"CharacterService",
	"BoostService",
	"MovementService",
	"ShopService",
	"RebirthService",
	"RewardService",
	"MonetizationService",
	"PetService",
	"NicheService",
	"RivalService",
	"LeaderboardService",
	"AdminService",
}

local loaded = {}
for _, name in ORDER do
	local module = Services:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), "Missing service " .. name)
	loaded[name] = (require :: any)(module)
end

for _, name in ORDER do
	local service = loaded[name]
	if service.Init then
		service.Init()
	end
end

-- Dynamic clouds (no assets needed)
local terrain = Workspace:FindFirstChildOfClass("Terrain")
if terrain and not terrain:FindFirstChildOfClass("Clouds") then
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.65
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = terrain
end

for _, name in ORDER do
	local service = loaded[name]
	if service.Start then
		task.spawn(service.Start)
	end
end

print("[+1 YouTuber Evolution] server ready")
