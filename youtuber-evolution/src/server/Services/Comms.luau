--!strict
-- Small helpers for talking to clients: toasts, effects, and a request
-- router with per-player rate limiting + basic argument validation.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Util.Net)

local Comms = {}

export type Result = { ok: boolean, msg: string?, data: any? }
type Handler = (player: Player, payload: any) -> Result?

local handlers: { [string]: { fn: Handler, rate: number } } = {}
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

-- Toast message on one client. kind: "info" | "success" | "error" | "reward"
function Comms.Notify(player: Player, text: string, kind: string?)
	Net.Event("Notify"):FireClient(player, text, kind or "info")
end

function Comms.NotifyAll(text: string, kind: string?)
	Net.Event("Notify"):FireAllClients(text, kind or "info")
end

-- One-shot visual/audio effect on one client.
function Comms.Effect(player: Player, name: string, data: any?)
	Net.Event("Effect"):FireClient(player, name, data)
end

-- Effect every client sees (e.g. someone evolving nearby).
function Comms.EffectAll(name: string, data: any?)
	Net.Event("Effect"):FireAllClients(name, data)
end

function Comms.Ok(data: any?): Result
	return { ok = true, data = data }
end

function Comms.Fail(msg: string): Result
	return { ok = false, msg = msg }
end

-- Register a handler for Request:InvokeServer(action, payload).
-- `rate` = max calls per second per player (token bucket, burst = rate * 2).
function Comms.On(action: string, rate: number, fn: Handler)
	handlers[action] = { fn = fn, rate = rate }
end

local function allow(player: Player, action: string, rate: number): boolean
	local now = os.clock()
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local b = perPlayer[action]
	if not b then
		b = { tokens = rate * 2, last = now }
		perPlayer[action] = b
	end
	b.tokens = math.min(rate * 2, b.tokens + (now - b.last) * rate)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

function Comms.Init()
	Net.Setup()
	local request = Net.Function("Request")
	request.OnServerInvoke = function(player: Player, action: any, payload: any): Result
		if typeof(action) ~= "string" then
			return Comms.Fail("Bad request")
		end
		local entry = handlers[action]
		if not entry then
			return Comms.Fail("Unknown action")
		end
		if not allow(player, action, entry.rate) then
			return Comms.Fail("Slow down!")
		end
		if payload ~= nil and typeof(payload) ~= "table" then
			return Comms.Fail("Bad payload")
		end
		local ok, result = pcall(entry.fn, player, payload or {})
		if not ok then
			warn("[Request] " .. action .. " failed: " .. tostring(result))
			return Comms.Fail("Something went wrong")
		end
		return result or Comms.Ok()
	end
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

-- Validation helpers ---------------------------------------------------------------
function Comms.String(v: any, maxLen: number?): string?
	if typeof(v) ~= "string" then
		return nil
	end
	if #v > (maxLen or 64) then
		return nil
	end
	return v
end

function Comms.Int(v: any, min: number, max: number): number?
	if typeof(v) ~= "number" or v ~= v or v % 1 ~= 0 then
		return nil
	end
	if v < min or v > max then
		return nil
	end
	return v
end

return Comms
