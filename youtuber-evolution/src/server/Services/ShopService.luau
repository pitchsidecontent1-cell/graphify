--!strict
-- Devices (bought with clout, kept forever) and clout upgrades.

local Shared = game:GetService("ReplicatedStorage").Shared
local Devices = require(Shared.Config.Devices)
local Stats = require(Shared.Util.Stats)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local Comms = require(script.Parent.Comms)

local ShopService = {}

local function buyDevice(player: Player, id: string): Comms.Result
	local data = DataService.Get(player)
	local device = Devices.ById[id]
	if not data or not device then
		return Comms.Fail("Unknown device")
	end
	if data.Devices[id] then
		return Comms.Fail("You already own this")
	end
	if not data.Unlocked[tostring(device.World)] then
		return Comms.Fail("Unlock World " .. device.World .. " first!")
	end
	local prev = Devices.List[device.Index - 1]
	if prev and not data.Devices[prev.Id] then
		return Comms.Fail("Buy the " .. prev.Name .. " first!")
	end
	if not ProgressService.SpendClout(player, device.Cost) then
		return Comms.Fail("Not enough clout!")
	end
	data.Devices[id] = true
	local equipped = Devices.ById[data.Equipped]
	local autoEquip = not equipped or device.Index > equipped.Index
	if autoEquip then
		data.Equipped = id
	end
	DataService.Dirty(player, "Devices")
	if autoEquip then
		DataService.Dirty(player, "Equipped")
	end
	Comms.Effect(player, "Purchase", { Kind = "Device", Id = id })
	return Comms.Ok({ Equipped = autoEquip })
end

function ShopService.Init()
	Comms.On("BuyDevice", 6, function(player, payload)
		local id = Comms.String(payload.Id, 8)
		if not id then
			return Comms.Fail("Bad device")
		end
		return buyDevice(player, id)
	end)

	-- Buys as many devices in order as you can afford (one click "Buy All").
	Comms.On("BuyBestDevices", 2, function(player)
		local data = DataService.Get(player)
		if not data then
			return Comms.Fail("Loading...")
		end
		local bought = 0
		for _, device in Devices.List do
			if not data.Devices[device.Id] then
				if not data.Unlocked[tostring(device.World)] or data.Clout < device.Cost then
					break
				end
				local r = buyDevice(player, device.Id)
				if not r.ok then
					break
				end
				bought += 1
			end
		end
		if bought == 0 then
			return Comms.Fail("Nothing you can afford yet!")
		end
		return Comms.Ok({ Bought = bought })
	end)

	Comms.On("EquipDevice", 6, function(player, payload)
		local data = DataService.Get(player)
		local id = Comms.String(payload.Id, 8)
		if not data or not id or not data.Devices[id] then
			return Comms.Fail("You don't own that")
		end
		if data.Equipped ~= id then
			data.Equipped = id
			DataService.Dirty(player, "Equipped")
		end
		return Comms.Ok()
	end)

	Comms.On("EquipBestDevice", 2, function(player)
		local data = DataService.Get(player)
		if not data then
			return Comms.Fail("Loading...")
		end
		local best = Stats.BestOwnedDevice(data)
		if data.Equipped ~= best.Id then
			data.Equipped = best.Id
			DataService.Dirty(player, "Equipped")
		end
		return Comms.Ok()
	end)

	Comms.On("BuyUpgrade", 6, function(player, payload)
		local data = DataService.Get(player)
		local id = Comms.String(payload.Id, 16)
		if not data or not id then
			return Comms.Fail("Bad upgrade")
		end
		local upgrade = Stats.UpgradeById(id)
		if not upgrade then
			return Comms.Fail("Bad upgrade")
		end
		local level = Stats.UpgradeLevel(data, id)
		if level >= upgrade.Max then
			return Comms.Fail("Already maxed!")
		end
		local cost = Stats.UpgradeCost(id, level)
		if not ProgressService.SpendClout(player, cost) then
			return Comms.Fail("Not enough clout!")
		end
		data.Upgrades[id] = level + 1
		DataService.Dirty(player, "Upgrades")
		Comms.Effect(player, "Purchase", { Kind = "Upgrade", Id = id })
		return Comms.Ok({ Level = level + 1 })
	end)
end

function ShopService.Start() end

return ShopService
