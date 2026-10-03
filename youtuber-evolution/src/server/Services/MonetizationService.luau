--!strict
-- Game passes + developer products. Receipts are idempotent (stored in the
-- profile) and only granted once the profile has saved.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Products = require(Shared.Config.Products)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local Comms = require(script.Parent.Comms)

local MonetizationService = {}

local productById: { [number]: Products.Product } = {}
local passById: { [number]: Products.Pass } = {}

local function setPass(player: Player, key: string)
	local ctx = DataService.Context(player)
	if not ctx.Passes[key] then
		ctx.Passes[key] = true
		DataService.ContextDirty(player)
		if key == "VIP" then
			player:SetAttribute("VIP", true)
		end
	end
end

-- Grant everything in a product (used by receipts and admin test grants).
function MonetizationService.GrantProduct(player: Player, product: Products.Product): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	for _, grant in product.Grants do
		RewardService.Grant(player, grant)
	end
	if product.OneTime then
		data.OneTime[product.Key] = true
		DataService.Dirty(player, "OneTime")
	end
	Comms.Notify(player, "💜 Thanks for supporting the game! " .. product.Emoji .. " " .. product.Name, "reward")
	Comms.Effect(player, "Purchase", { Kind = "Product", Id = product.Key })
	return true
end

-- `quiet` skips the toast + confetti (admin "give every pass").
function MonetizationService.GrantPass(player: Player, key: string, quiet: boolean?)
	setPass(player, key)
	local pass = Products.PassByKey[key]
	if pass and not quiet then
		Comms.Notify(player, pass.Emoji .. " " .. pass.Name .. " unlocked!", "reward")
		Comms.Effect(player, "Purchase", { Kind = "Pass", Id = key })
	end
end

-- Admin testing: take a pass away for this session (ownership is re-checked
-- from Roblox next time the player joins).
function MonetizationService.RevokePass(player: Player, key: string)
	local ctx = DataService.Context(player)
	if ctx.Passes[key] then
		ctx.Passes[key] = nil
		DataService.ContextDirty(player)
	end
	if key == "VIP" then
		player:SetAttribute("VIP", nil)
	end
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(data.Receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = productById[receipt.ProductId]
	if not product then
		warn("[Monetization] unknown product " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok = pcall(MonetizationService.GrantProduct, player, product)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > 100 do
		table.remove(data.Receipts, 1)
	end
	if not DataService.SaveNow(player) then
		-- couldn't persist the receipt; Roblox will retry and our receipt list dedupes
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function checkPasses(player: Player)
	for _, pass in Products.Passes do
		if pass.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns then
				setPass(player, pass.Key)
			end
		end
	end
end

function MonetizationService.Init()
	for _, p in Products.Products do
		if p.Id ~= 0 then
			productById[p.Id] = p
		end
	end
	for _, p in Products.Passes do
		if p.Id ~= 0 then
			passById[p.Id] = p
		end
	end
	MarketplaceService.ProcessReceipt = processReceipt
end

function MonetizationService.Start()
	DataService.Loaded:Connect(function(player: Player)
		task.spawn(checkPasses, player)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			local pass = passById[passId]
			if pass then
				MonetizationService.GrantPass(player, pass.Key)
			end
		end
	end)
end

return MonetizationService
