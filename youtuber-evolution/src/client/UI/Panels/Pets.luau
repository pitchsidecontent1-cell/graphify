--!strict
-- PETS inventory: equip/unequip/delete, equip best.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Pets = require(Shared.Config.Pets)
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Util.Format)
local Stats = require(Shared.Util.Stats)
local PetModels = require(Shared.Models.PetModels)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)

local C = Theme.Colors

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Pets", Color = C.Blue, Size = Vector2.new(1040, 700) })
	local body = panel.Body

	local header = UIKit.Label({
		Text = "",
		TextSize = 28,
		XAlign = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.62, 0, 0, 40),
		Parent = body,
	})
	local gridHolder =
		UIKit.Frame({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(0.64, 0, 1, -126), Parent = body })
	local grid = UIKit.Grid(gridHolder, Vector2.new(140, 170), 12)

	-- detail card
	local detail = UIKit.Card(body, UDim2.new(0.34, 0, 1, -40), Color3.fromRGB(58, 46, 94))
	detail.AnchorPoint = Vector2.new(1, 0)
	detail.Position = UDim2.new(1, 0, 0, 0)
	local detailView =
		UIKit.Frame({ Size = UDim2.new(1, -20, 0, 250), Position = UDim2.fromOffset(10, 10), Parent = detail })
	local detailName = UIKit.Label({
		Text = "Select a pet",
		TextSize = 34,
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 266),
		Scaled = true,
		Parent = detail,
	})
	local detailRarity = UIKit.Label({
		Text = "",
		TextSize = 26,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 308),
		Parent = detail,
	})
	local detailBonus = UIKit.Label({
		Text = "",
		TextSize = 34,
		Color = C.Mint,
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 342),
		Parent = detail,
	})
	local equipBtn = UIKit.Button({
		Text = "EQUIP",
		Color = C.Green,
		Size = UDim2.new(1, -40, 0, 68),
		Position = UDim2.fromOffset(20, 400),
		TextSize = 32,
		Parent = detail,
	})
	local deleteBtn = UIKit.Button({
		Text = "DELETE",
		Icon = "🗑️",
		Color = C.Red,
		Size = UDim2.new(1, -40, 0, 60),
		Position = UDim2.fromOffset(20, 482),
		TextSize = 28,
		Parent = detail,
	})

	local footer = UIKit.Frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.64, 0, 0, 74),
		Parent = body,
	})
	UIKit.List(footer, 14, true)
	UIKit.Button({
		Text = "EQUIP BEST",
		Icon = "⭐",
		Color = C.Mint,
		Size = UDim2.fromOffset(270, 68),
		Parent = footer,
		OnClick = function()
			Request.Call("EquipBestPets")
		end,
	})
	UIKit.Button({
		Text = "+2 SLOTS",
		Icon = "🐾",
		Color = C.Gold,
		Size = UDim2.fromOffset(240, 68),
		Parent = footer,
		OnClick = function()
			Request.BuyPass("PetSlots")
		end,
	})

	local selected: string? = nil
	local confirmDelete = false
	local tileByUid: { [string]: UIKit.Tile } = {}

	local function showDetail()
		for _, c in detailView:GetChildren() do
			c:Destroy()
		end
		local data = State.Data
		local item = if selected then Stats.FindPet(data, selected) else nil
		local def = item and Pets.ById[item.Pet]
		confirmDelete = false
		deleteBtn:SetText("DELETE")
		if not item or not def then
			detailName.Text = "Select a pet"
			detailRarity.Text = ""
			detailBonus.Text = ""
			equipBtn.Root.Visible = false
			deleteBtn.Root.Visible = false
			return
		end
		local vp = UIKit.Viewport(PetModels.Build(def), PetModels.Extent, detailView, math.rad(30))
		UIKit.Spin(vp, PetModels.Extent, 1)
		detailName.Text = def.Name
		local rarity = Theme.Rarities[def.Rarity]
		detailRarity.Text = string.upper(def.Rarity)
		detailRarity.TextColor3 = rarity.Color
		detailBonus.Text = "+" .. Format.Abbrev(def.Bonus) .. "% VIEWS"
		local equipped = table.find(data.EquippedPets, item.Uid) ~= nil
		equipBtn.Root.Visible = true
		deleteBtn.Root.Visible = true
		equipBtn:SetText(if equipped then "UNEQUIP" else "EQUIP")
		equipBtn:SetColor(if equipped then C.Orange else C.Green)
	end

	local function rebuild()
		for _, c in grid:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		table.clear(tileByUid)
		local data = State.Data
		local ctx = State.Ctx
		local equippedSet: { [string]: boolean } = {}
		for _, uid in data.EquippedPets do
			equippedSet[uid] = true
		end
		local list = table.clone(data.Pets)
		table.sort(list, function(a, b)
			local ea, eb = equippedSet[a.Uid] == true, equippedSet[b.Uid] == true
			if ea ~= eb then
				return ea
			end
			local pa, pb = Pets.ById[a.Pet], Pets.ById[b.Pet]
			return (if pa then pa.Bonus else 0) > (if pb then pb.Bonus else 0)
		end)
		for i, item in list do
			local def = Pets.ById[item.Pet]
			if def then
				local tile = UIKit.Tile({ Rarity = def.Rarity, Parent = grid, LayoutOrder = i })
				tileByUid[item.Uid] = tile
				UIKit.Viewport(PetModels.Build(def), PetModels.Extent, tile.Content, math.rad(30))
				tile.Name.Text = def.Name
				tile.Sub.Text = "+" .. Format.Abbrev(def.Bonus) .. "%"
				tile.Tag.Text = if equippedSet[item.Uid] then "✅ EQUIPPED" else ""
				tile.Tag.TextColor3 = C.Mint
				if equippedSet[item.Uid] then
					tile.Stroke.Color = C.Mint
					tile.Stroke.Thickness = 6
				end
				tile.Root.Activated:Connect(function()
					selected = item.Uid
					showDetail()
				end)
			end
		end
		local slots = Stats.PetSlots(ctx)
		header.Text = "EQUIPPED "
			.. #data.EquippedPets
			.. "/"
			.. slots
			.. "   •   +"
			.. Format.Abbrev(Stats.PetBonus(data))
			.. "% VIEWS   •   "
			.. #data.Pets
			.. "/"
			.. Economy.Pets.InventoryMax
		if selected and not Stats.FindPet(data, selected) then
			selected = nil
		end
		showDetail()
	end

	equipBtn.Activated:Connect(function()
		if not selected then
			return
		end
		local equipped = table.find(State.Data.EquippedPets, selected) ~= nil
		Request.Call(if equipped then "UnequipPet" else "EquipPet", { Uid = selected })
	end)
	deleteBtn.Activated:Connect(function()
		if not selected then
			return
		end
		if not confirmDelete then
			confirmDelete = true
			deleteBtn:SetText("SURE?")
			return
		end
		Request.Call("DeletePets", { Uids = { selected } })
		selected = nil
	end)

	for _, key in { "Pets", "EquippedPets", "Context" } do
		State.On(key, function()
			if UI.IsOpen("Pets") then
				rebuild()
			end
		end)
	end

	return {
		Panel = panel,
		Open = function()
			rebuild()
		end,
	}
end
