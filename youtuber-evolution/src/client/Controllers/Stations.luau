--!strict
-- Step on a glowing station pad -> its menu opens (once per visit).

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UI = require(script.Parent.Parent.UI.UI)
local State = require(script.Parent.State)

local Stations = {}

local player = Players.LocalPlayer
local inside: { [Instance]: boolean } = {}

local PANEL_FOR = {
	Devices = "Devices",
	Upgrades = "Upgrades",
	Rebirth = "Rebirth",
	Niche = "Niche",
	Worlds = "Worlds",
	Egg = "Egg",
	Rival = "Rival",
} :: { [string]: string }

local function check()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not State.IsLoaded then
		return
	end
	local pos = root.Position
	for _, pad in CollectionService:GetTagged("StationPad") do
		if pad:IsA("BasePart") then
			local radius = pad:GetAttribute("Radius")
			local r = (if typeof(radius) == "number" then radius else 5) + 1.5
			local offset = pos - pad.Position
			local near = Vector3.new(offset.X, 0, offset.Z).Magnitude <= r and math.abs(offset.Y) < 8
			if near and not inside[pad] then
				inside[pad] = true
				local station = pad:GetAttribute("Station")
				local panel = if typeof(station) == "string" then PANEL_FOR[station] else nil
				if panel then
					local arg: any = nil
					if station == "Egg" then
						arg = pad:GetAttribute("Egg")
					elseif station == "Rival" then
						arg = pad:GetAttribute("World")
					end
					UI.Open(panel, arg)
				end
			elseif not near and inside[pad] then
				inside[pad] = nil
				local station = pad:GetAttribute("Station")
				local panel = if typeof(station) == "string" then PANEL_FOR[station] else nil
				-- walking away closes the shop you opened from this pad
				if panel and UI.Current == panel then
					UI.Close()
				end
			end
		end
	end
end

function Stations.Init() end

function Stations.Start()
	task.spawn(function()
		while true do
			pcall(check)
			task.wait(0.15)
		end
	end)
end

return Stations
