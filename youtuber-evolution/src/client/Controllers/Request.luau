--!strict
-- Calls Request:InvokeServer and shows a toast + error sound on failure.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Util.Net)
local Products = require(Shared.Config.Products)
local Signal = require(Shared.Util.Signal)
local Sound = require(script.Parent.Sound)

local Request = {}

Request.Toast = Signal.new() -- (text, kind) -> picked up by the Toasts UI

export type Result = { ok: boolean, msg: string?, data: any? }

function Request.Call(action: string, payload: { [string]: any }?, quiet: boolean?): Result
	local ok, result = pcall(function()
		return Net.Function("Request"):InvokeServer(action, payload or {})
	end)
	if not ok or typeof(result) ~= "table" then
		if not quiet then
			Request.Toast:Fire("Connection hiccup, try again!", "error")
			Sound.Play("Error")
		end
		return { ok = false, msg = "network" }
	end
	if not result.ok and not quiet then
		Request.Toast:Fire(result.msg or "Can't do that right now", "error")
		Sound.Play("Error")
	end
	return result
end

-- Prompt a game pass / product purchase (or explain it isn't set up yet).
function Request.BuyPass(key: string)
	local pass = Products.PassByKey[key]
	if not pass then
		return
	end
	if pass.Id == 0 then
		Request.Toast:Fire(pass.Name .. " is coming soon!", "info")
		return
	end
	MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.Id)
end

function Request.BuyProduct(key: string)
	local product = Products.ProductByKey[key]
	if not product then
		return
	end
	if product.Id == 0 then
		Request.Toast:Fire(product.Name .. " is coming soon!", "info")
		return
	end
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.Id)
end

local priceCache: { [string]: number } = {}

-- Live Robux price (falls back to the configured display price).
function Request.Price(kind: string, key: string): number
	local cached = priceCache[kind .. key]
	if cached then
		return cached
	end
	local item: any = if kind == "Pass" then Products.PassByKey[key] else Products.ProductByKey[key]
	if not item then
		return 0
	end
	local price = item.Price
	if item.Id ~= 0 then
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(
				item.Id,
				if kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
			)
		end)
		if ok and info and typeof(info.PriceInRobux) == "number" then
			price = info.PriceInRobux
		end
	end
	priceCache[kind .. key] = price
	return price
end

function Request.Init() end
function Request.Start() end

return Request
