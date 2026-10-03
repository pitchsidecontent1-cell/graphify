--!strict
-- Context boosts that aren't saved: friends in server, Premium, group.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Products = require(Shared.Config.Products)
local DataService = require(script.Parent.DataService)

local BoostService = {}

local friendCache: { [Player]: { [number]: boolean } } = {}

local function isFriend(a: Player, b: Player): boolean
	local cache = friendCache[a]
	if not cache then
		cache = {}
		friendCache[a] = cache
	end
	local cached = cache[b.UserId]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(function()
		return a:IsFriendsWithAsync(b.UserId)
	end)
	local value = ok and result == true
	cache[b.UserId] = value
	return value
end

function BoostService.RefreshFriends()
	local list = Players:GetPlayers()
	for _, p in list do
		if DataService.Get(p) then
			local count = 0
			for _, other in list do
				if other ~= p and isFriend(p, other) then
					count += 1
				end
			end
			local ctx = DataService.Context(p)
			if ctx.Friends ~= count then
				ctx.Friends = count
				DataService.ContextDirty(p)
			end
		end
	end
end

local function setup(player: Player)
	local ctx = DataService.Context(player)
	ctx.Premium = player.MembershipType == Enum.MembershipType.Premium
	if Products.GroupId ~= 0 then
		local ok, inGroup = pcall(function()
			return player:IsInGroupAsync(Products.GroupId)
		end)
		ctx.Group = ok and inGroup == true
	end
	DataService.ContextDirty(player)
	BoostService.RefreshFriends()
end

function BoostService.Init() end

function BoostService.Start()
	DataService.Loaded:Connect(function(player: Player)
		task.spawn(setup, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		friendCache[player] = nil
		task.defer(BoostService.RefreshFriends)
	end)
	Players.PlayerMembershipChanged:Connect(function(player)
		if DataService.Get(player) then
			DataService.Context(player).Premium = player.MembershipType == Enum.MembershipType.Premium
			DataService.ContextDirty(player)
		end
	end)
end

return BoostService
