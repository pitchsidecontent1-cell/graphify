--!strict
-- Owns Views/Clout changes and detects Video-level and Evolution changes.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Stats = require(Shared.Util.Stats)
local Signal = require(Shared.Util.Signal)
local DataService = require(script.Parent.DataService)
local Comms = require(script.Parent.Comms)

local ProgressService = {}

ProgressService.VideoChanged = Signal.new() -- (player, new, old)
ProgressService.TierChanged = Signal.new() -- (player, new, old)

local lastVideo: { [Player]: number } = {}
local lastTier: { [Player]: number } = {}

function ProgressService.Tier(player: Player): number
	return lastTier[player] or 1
end

function ProgressService.Video(player: Player): number
	return lastVideo[player] or 1
end

-- Re-evaluate video level + evolution after Views changed.
-- `quiet` suppresses celebration effects (used after rebirth).
function ProgressService.Check(player: Player, quiet: boolean?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local video = Stats.VideoLevel(data.Views)
	local oldVideo = lastVideo[player] or video
	lastVideo[player] = video
	if video > data.BestVideo then
		data.BestVideo = video
		DataService.Dirty(player, "BestVideo")
	end
	if video ~= oldVideo then
		ProgressService.VideoChanged:Fire(player, video, oldVideo)
		if video > oldVideo and not quiet then
			Comms.Effect(player, "Video", { Level = video, From = oldVideo })
		end
	end
	local tier = Stats.EvolutionTier(video)
	local oldTier = lastTier[player] or tier
	lastTier[player] = tier
	if player:GetAttribute("Evo") ~= tier then
		player:SetAttribute("Evo", tier)
	end
	if tier ~= oldTier then
		if tier > data.BestEvolution then
			data.BestEvolution = tier
			DataService.Dirty(player, "BestEvolution")
		end
		ProgressService.TierChanged:Fire(player, tier, oldTier)
		if tier > oldTier and not quiet then
			Comms.Effect(player, "Evolve", { Tier = tier })
			Comms.EffectAll("EvolveOther", { UserId = player.UserId, Tier = tier })
		end
	end
end

function ProgressService.AddViews(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount ~= amount or amount <= 0 then
		return
	end
	data.Views += amount
	data.TotalViews += amount
	DataService.Dirty(player, "Views", "TotalViews")
	ProgressService.Check(player)
end

function ProgressService.AddClout(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount ~= amount or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	data.Clout += amount
	data.TotalClout += amount
	DataService.Dirty(player, "Clout", "TotalClout")
end

function ProgressService.SpendClout(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or amount ~= amount or amount < 0 or data.Clout < amount then
		return false
	end
	data.Clout -= amount
	DataService.Dirty(player, "Clout")
	return true
end

function ProgressService.AddTickets(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Tickets += math.floor(amount)
	DataService.Dirty(player, "Tickets")
end

function ProgressService.Init() end

function ProgressService.Start()
	DataService.Loaded:Connect(function(player: Player, data)
		local video = Stats.VideoLevel(data.Views)
		lastVideo[player] = video
		lastTier[player] = Stats.EvolutionTier(video)
		player:SetAttribute("Evo", lastTier[player])
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastVideo[player] = nil
		lastTier[player] = nil
	end)
end

return ProgressService
