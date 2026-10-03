--!strict
-- Admin/testing commands for the in-game admin panel. Available in Studio,
-- to the game owner, and to UserIds listed in Config/Admin.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Admin = require(Shared.Config.Admin)
local Products = require(Shared.Config.Products)
local Worlds = require(Shared.Config.Worlds)
local Devices = require(Shared.Config.Devices)
local Stats = require(Shared.Util.Stats)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local RebirthService = require(script.Parent.RebirthService)
local MonetizationService = require(script.Parent.MonetizationService)
local Comms = require(script.Parent.Comms)

local AdminService = {}

function AdminService.IsAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(Admin.UserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId then
		return true
	end
	return false
end

local COMMANDS: { [string]: (Player, any) -> string } = {
	Views = function(player)
		local data = DataService.Get(player)
		if not data then
			return "no data"
		end
		-- jump to the next video level
		local video = Stats.VideoLevel(data.Views)
		local need = Stats.ViewsForVideo(video + 1) - data.Views + 1
		ProgressService.AddViews(player, need)
		return "+1 Video"
	end,
	Views10 = function(player)
		local data = DataService.Get(player)
		if not data then
			return "no data"
		end
		local video = Stats.VideoLevel(data.Views)
		ProgressService.AddViews(player, Stats.ViewsForVideo(video + 10) - data.Views + 1)
		return "+10 Videos"
	end,
	Clout = function(player)
		local data = DataService.Get(player)
		if not data then
			return "no data"
		end
		local amount = math.max(1000, data.Clout * 9)
		ProgressService.AddClout(player, amount)
		return "Clout x10"
	end,
	Tickets = function(player)
		ProgressService.AddTickets(player, 10)
		return "+10 tickets"
	end,
	Rebirth = function(player)
		RebirthService.Rebirth(player, true)
		return "Rebirthed"
	end,
	UnlockWorlds = function(player)
		local data = DataService.Get(player)
		if not data then
			return "no data"
		end
		for _, w in Worlds do
			data.Unlocked[tostring(w.Id)] = true
		end
		DataService.Dirty(player, "Unlocked")
		return "All worlds unlocked"
	end,
	AllDevices = function(player)
		local data = DataService.Get(player)
		if not data then
			return "no data"
		end
		for _, d in Devices.List do
			data.Devices[d.Id] = true
		end
		data.Equipped = Devices.List[#Devices.List].Id
		DataService.Dirty(player, "Devices", "Equipped")
		return "All devices"
	end,
	ResetData = function(player)
		local data = DataService.Get(player)
		if not data then
			return "no data"
		end
		local fresh = DataService.Default()
		for k in data :: any do
			(data :: any)[k] = nil
		end
		for k, v in fresh :: any do
			(data :: any)[k] = v
		end
		local keys = {}
		for k in fresh :: any do
			table.insert(keys, k)
		end
		DataService.Dirty(player, table.unpack(keys))
		ProgressService.Check(player, true)
		player:LoadCharacterAsync()
		return "Data reset"
	end,
	GrantPass = function(player, arg)
		if typeof(arg) ~= "string" or not Products.PassByKey[arg] then
			return "unknown pass"
		end
		MonetizationService.GrantPass(player, arg)
		return "Pass " .. arg
	end,
	GrantProduct = function(player, arg)
		if typeof(arg) ~= "string" or not Products.ProductByKey[arg] then
			return "unknown product"
		end
		MonetizationService.GrantProduct(player, Products.ProductByKey[arg])
		return "Product " .. arg
	end,
}

function AdminService.Init()
	Comms.On("Admin", 10, function(player, payload)
		if not AdminService.IsAdmin(player) then
			return Comms.Fail("Not an admin")
		end
		local cmd = Comms.String(payload.Cmd, 32)
		local fn = cmd and COMMANDS[cmd]
		if not fn then
			return Comms.Fail("Unknown command")
		end
		return Comms.Ok({ Text = fn(player, payload.Arg) })
	end)
end

function AdminService.Start()
	DataService.Loaded:Connect(function(player: Player)
		if AdminService.IsAdmin(player) then
			player:SetAttribute("Admin", true)
		end
	end)
	Players.PlayerAdded:Connect(function() end)
end

return AdminService
