--!strict
-- Renders every player's equipped pets (from the "Pets" player attribute)
-- following them around with a bouncy hover. Purely client-side.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PetModels = require(Shared.Models.PetModels)
local State = require(script.Parent.State)

local PetFollow = {}

type Follower = { model: Model, cf: CFrame, phase: number, rainbow: { BasePart }? }

local folder: Folder? = nil
local followers: { [Player]: { Follower } } = {}
local signature: { [Player]: string } = {}

local function clear(p: Player)
	local list = followers[p]
	if list then
		for _, f in list do
			f.model:Destroy()
		end
	end
	followers[p] = nil
	signature[p] = nil
end

local function rebuild(p: Player)
	local attr = p:GetAttribute("Pets")
	local sig = if typeof(attr) == "string" then attr else ""
	local showOthers = not State.IsLoaded or State.Data.Settings.OtherPets ~= false
	if p ~= Players.LocalPlayer and not showOthers then
		sig = ""
	end
	if signature[p] == sig then
		return
	end
	clear(p)
	signature[p] = sig
	if sig == "" then
		return
	end
	local list = {}
	for i, id in string.split(sig, ",") do
		local model = PetModels.BuildById(id)
		if model then
			model.Name = p.Name .. "_Pet" .. i
			model.Parent = folder
			local rainbow = nil
			if model:GetAttribute("Rainbow") then
				rainbow = {}
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") and (d.Name == "Handle" or d.Name == "Head") then
						table.insert(rainbow, d :: BasePart)
					end
				end
			end
			table.insert(list, { model = model, cf = CFrame.new(0, -1000, 0), phase = i * 1.7, rainbow = rainbow })
		end
	end
	followers[p] = list
end

local function watch(p: Player)
	p:GetAttributeChangedSignal("Pets"):Connect(function()
		rebuild(p)
	end)
	rebuild(p)
end

function PetFollow.Init()
	local f = Instance.new("Folder")
	f.Name = "ClientPets"
	f.Parent = Workspace
	folder = f
end

function PetFollow.Start()
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	State.On("Settings", function()
		for _, p in Players:GetPlayers() do
			signature[p] = nil
			rebuild(p)
		end
	end)

	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local alpha = 1 - math.exp(-dt * 7)
		for p, list in followers do
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local n = #list
				local scale = if char then char:GetScale() else 1
				for i, f in list do
					-- fan out in an arc behind the owner
					local spread = (i - (n + 1) / 2) * 4.2
					local back = 6 + math.abs(spread) * 0.3
					local bob = math.sin(t * 3 + f.phase) * 0.5
					local target = root.CFrame * CFrame.new(spread * scale, (-1.2 + bob) * scale + 1, back * scale)
					if f.cf.Position.Y < -500 then
						f.cf = target
					end
					f.cf = f.cf:Lerp(target, alpha)
					f.model:PivotTo(f.cf)
					if f.rainbow then
						local color = Color3.fromHSV((t * 0.2 + f.phase) % 1, 0.6, 1)
						for _, part in f.rainbow do
							part.Color = color
						end
					end
				end
			end
		end
	end)
end

return PetFollow
