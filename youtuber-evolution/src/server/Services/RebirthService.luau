--!strict
-- Rebirth: resets Views (so Videos + gates reset) for a permanent x2 views
-- multiplier, bonus clout %, and a Niche Ticket.

local Shared = game:GetService("ReplicatedStorage").Shared
local Stats = require(Shared.Util.Stats)
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Util.Format)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local MovementService = require(script.Parent.MovementService)
local Comms = require(script.Parent.Comms)

local RebirthService = {}

-- `force` skips the Video requirement (Skip Rebirth product).
function RebirthService.Rebirth(player: Player, force: boolean?): Comms.Result
	local data = DataService.Get(player)
	if not data then
		return Comms.Fail("Loading...")
	end
	if not force and not Stats.CanRebirth(data) then
		return Comms.Fail("Reach VIDEO " .. Stats.RebirthVideo(data.Rebirths) .. " to rebirth!")
	end
	data.Rebirths += 1
	data.Views = 0
	data.Tickets += Economy.Rebirth.TicketsPerRebirth
	DataService.Dirty(player, "Rebirths", "Views", "Tickets")
	ProgressService.Check(player, true)
	MovementService.ToSpawn(player)
	Comms.Effect(player, "Rebirth", {
		Rebirths = data.Rebirths,
		Multiplier = Stats.RebirthMultiplier(data.Rebirths),
	})
	Comms.Notify(
		player,
		"🔄 REBIRTH " .. data.Rebirths .. "! Views are now " .. Format.Mult(Stats.RebirthMultiplier(data.Rebirths)),
		"reward"
	)
	return Comms.Ok({ Rebirths = data.Rebirths })
end

function RebirthService.Init()
	Comms.On("Rebirth", 1, function(player)
		return RebirthService.Rebirth(player, false)
	end)
end

function RebirthService.Start() end

return RebirthService
