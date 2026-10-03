--!strict
-- All remotes live in ReplicatedStorage.Remotes. The server creates them;
-- clients wait for them.
--   State       S->C  full snapshot / partial updates of your data
--   Notify      S->C  toast messages
--   Effect      S->C  one-shot effects (claim, evolve, rebirth, hatch...)
--   Battle      S->C  View War state ticks
--   BattleInput C->S  clicks + trend-bubble taps during a View War
--   Request     C->S  every other player intent (buy, equip, roll, claim...)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local EVENTS = { "State", "Notify", "Effect", "Battle", "BattleInput" }
local FUNCTIONS = { "Request" }

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		local f: Folder
		if existing and existing:IsA("Folder") then
			f = existing
		else
			f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = ReplicatedStorage
		end
		for _, name in EVENTS do
			if not f:FindFirstChild(name) then
				local r = Instance.new("RemoteEvent")
				r.Name = name
				r.Parent = f
			end
		end
		for _, name in FUNCTIONS do
			if not f:FindFirstChild(name) then
				local r = Instance.new("RemoteFunction")
				r.Name = name
				r.Parent = f
			end
		end
		folder = f
		return f
	end
	local f = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	folder = f
	return f
end

function Net.Event(name: string): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return getFolder():WaitForChild(name) :: RemoteFunction
end

function Net.Setup()
	getFolder()
end

return Net
