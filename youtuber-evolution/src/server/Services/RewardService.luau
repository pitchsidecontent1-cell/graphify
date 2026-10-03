--!strict
-- Free rewards (playtime gifts, daily streak, codes), potion timers and the
-- shared Grant() used by packs/products too.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Rewards = require(Shared.Config.Rewards)
local Stats = require(Shared.Util.Stats)
local Format = require(Shared.Util.Format)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local RebirthService = require(script.Parent.RebirthService)
local Comms = require(script.Parent.Comms)

local RewardService = {}

local sessionStart: { [Player]: number } = {}
local giftsClaimed: { [Player]: { [number]: boolean } } = {}

-- Describe a reward for toasts ("+1.2K Clout", "+3 Tickets", "x2 Views 10m").
function RewardService.Describe(player: Player, reward: Rewards.Reward): string
	local data = DataService.Get(player)
	if reward.Kind == "Clout" and data then
		local amount = Stats.BestPadBase(data)
			* (reward.Pads or 1)
			* Stats.CloutMultiplier(data, DataService.Context(player))
		return "💰 +" .. Format.Abbrev(math.floor(amount)) .. " Clout"
	elseif reward.Kind == "Tickets" then
		return "🎟️ +" .. (reward.Amount or 1) .. " Niche Tickets"
	elseif reward.Kind == "Potion" then
		return "🧪 x2 " .. (reward.Potion or "Views") .. " for " .. (reward.Minutes or 5) .. "m"
	elseif reward.Kind == "Rebirth" then
		return "🔄 Instant Rebirth"
	end
	return "🎁 Reward"
end

function RewardService.Grant(player: Player, reward: Rewards.Reward): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	if reward.Kind == "Clout" then
		local amount = Stats.BestPadBase(data)
			* (reward.Pads or 1)
			* Stats.CloutMultiplier(data, DataService.Context(player))
		ProgressService.AddClout(player, math.floor(amount))
	elseif reward.Kind == "Tickets" then
		ProgressService.AddTickets(player, reward.Amount or 1)
	elseif reward.Kind == "Potion" then
		local key = if reward.Potion == "Clout" then "Clout" else "Views"
		local seconds = (reward.Minutes or 5) * 60
		if key == "Clout" then
			data.Potions.Clout += seconds
		else
			data.Potions.Views += seconds
		end
		DataService.Dirty(player, "Potions")
	elseif reward.Kind == "Rebirth" then
		RebirthService.Rebirth(player, true)
	else
		return false
	end
	return true
end

function RewardService.SessionSeconds(player: Player): number
	local start = sessionStart[player]
	return if start then os.clock() - start else 0
end

function RewardService.Init()
	Comms.On("ClaimGift", 4, function(player, payload)
		local index = Comms.Int(payload.Index, 1, #Rewards.Gifts)
		if not index then
			return Comms.Fail("Bad gift")
		end
		local claimed = giftsClaimed[player]
		if not claimed then
			return Comms.Fail("Loading...")
		end
		if claimed[index] then
			return Comms.Fail("Already claimed!")
		end
		local gift = Rewards.Gifts[index]
		if RewardService.SessionSeconds(player) < gift.Minutes * 60 - 1 then
			return Comms.Fail("Not ready yet!")
		end
		claimed[index] = true
		local text = RewardService.Describe(player, gift.Reward)
		RewardService.Grant(player, gift.Reward)
		Comms.Notify(player, "🎁 " .. text, "reward")
		Comms.Effect(player, "Reward", { Text = text })
		return Comms.Ok({ Claimed = index })
	end)

	Comms.On("ClaimDaily", 2, function(player)
		local data = DataService.Get(player)
		if not data then
			return Comms.Fail("Loading...")
		end
		local now = os.time()
		if now - data.Daily.Last < Rewards.DailyCooldown then
			return Comms.Fail("Come back in " .. Format.Duration(Rewards.DailyCooldown - (now - data.Daily.Last)))
		end
		if data.Daily.Last > 0 and now - data.Daily.Last > Rewards.DailyWindow then
			data.Daily.Streak = 0
		end
		data.Daily.Streak = (data.Daily.Streak % #Rewards.Daily) + 1
		data.Daily.Last = now
		local reward = Rewards.Daily[data.Daily.Streak]
		local text = RewardService.Describe(player, reward)
		RewardService.Grant(player, reward)
		DataService.Dirty(player, "Daily")
		Comms.Notify(player, "📅 Day " .. data.Daily.Streak .. ": " .. text, "reward")
		Comms.Effect(player, "Reward", { Text = text })
		return Comms.Ok({ Day = data.Daily.Streak })
	end)

	Comms.On("RedeemCode", 1, function(player, payload)
		local data = DataService.Get(player)
		local code = Comms.String(payload.Code, 32)
		if not data or not code then
			return Comms.Fail("Enter a code")
		end
		code = string.upper((string.gsub(code, "%s+", "")))
		local reward = Rewards.Codes[code]
		if not reward then
			return Comms.Fail("That code doesn't exist")
		end
		if data.Codes[code] then
			return Comms.Fail("Already redeemed!")
		end
		data.Codes[code] = true
		DataService.Dirty(player, "Codes")
		local text = RewardService.Describe(player, reward)
		RewardService.Grant(player, reward)
		Comms.Notify(player, "✅ Code redeemed: " .. text, "reward")
		return Comms.Ok({ Text = text })
	end)

	Comms.On("SetSetting", 6, function(player, payload)
		local data = DataService.Get(player)
		local key = Comms.String(payload.Key, 24)
		if not data or not key or data.Settings[key] == nil or typeof(payload.Value) ~= "boolean" then
			return Comms.Fail("Bad setting")
		end
		data.Settings[key] = payload.Value
		DataService.Dirty(player, "Settings")
		return Comms.Ok()
	end)

	Comms.On("FinishTutorial", 1, function(player)
		local data = DataService.Get(player)
		if data and not data.Tutorial then
			data.Tutorial = true
			DataService.Dirty(player, "Tutorial")
		end
		return Comms.Ok()
	end)
end

function RewardService.Start()
	DataService.Loaded:Connect(function(player: Player)
		sessionStart[player] = os.clock()
		giftsClaimed[player] = {}
		-- tell the client when its session started (for gift timers)
		DataService.Dirty(player, "Stats")
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessionStart[player] = nil
		giftsClaimed[player] = nil
	end)

	-- 1s tick: potions + playtime
	task.spawn(function()
		while true do
			task.wait(1)
			for player, data in DataService.Players() do
				local potions = data.Potions
				local changed = false
				if potions.Views > 0 then
					potions.Views = math.max(0, potions.Views - 1)
					changed = potions.Views == 0 or potions.Views % 10 == 0
				end
				if potions.Clout > 0 then
					potions.Clout = math.max(0, potions.Clout - 1)
					changed = changed or potions.Clout == 0 or potions.Clout % 10 == 0
				end
				if changed then
					DataService.Dirty(player, "Potions")
				end
				data.Stats.Playtime += 1
			end
		end
	end)
end

-- Gift claim state for the client UI (claimed indices this session).
function RewardService.Claimed(player: Player): { [number]: boolean }
	return giftsClaimed[player] or {}
end

return RewardService
