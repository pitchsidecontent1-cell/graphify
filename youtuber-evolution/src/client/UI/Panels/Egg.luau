--!strict
-- Egg hatch panel (opened by stepping on an egg pad) + the hatch animation.

local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Pets = require(Shared.Config.Pets)
local Format = require(Shared.Util.Format)
local PetModels = require(Shared.Models.PetModels)
local PropKit = require(Shared.Models.PropKit)
local UIKit = require(script.Parent.Parent.UIKit)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local Request = require(script.Parent.Parent.Parent.Controllers.Request)
local Sound = require(script.Parent.Parent.Parent.Controllers.Sound)

local C = Theme.Colors

local function eggModel(egg: Pets.Egg): Model
	local m = Instance.new("Model")
	local shell = PropKit.Part({
		Name = "Shell",
		Size = Vector3.new(3, 4, 3),
		CFrame = CFrame.new(),
		Color = egg.Color,
		Parent = m,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = shell
	for i = 1, 5 do
		local a = i * 1.3
		local spot = PropKit.Part({
			Name = "Spot",
			Size = Vector3.new(0.8, 0.8, 0.8),
			CFrame = CFrame.new(math.sin(a) * 1.25, (i % 3 - 1) * 0.9, -math.cos(a) * 1.25),
			Color = egg.Color2,
			Parent = m,
		})
		local sm = Instance.new("SpecialMesh")
		sm.MeshType = Enum.MeshType.Sphere
		sm.Parent = spot
	end
	m.PrimaryPart = shell
	return m
end

-- Full-screen hatch animation: eggs shake, crack in a flash, pets reveal.
local function playHatch(egg: Pets.Egg, results: { { Uid: string, Pet: string } })
	local layer = UI.Layer(UI.Top)
	local overlay = Instance.new("Frame")
	overlay.Name = "Hatch"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = C.Ink
	overlay.BackgroundTransparency = 1
	overlay.ZIndex = 100
	overlay.Parent = layer
	UIKit.Tween(overlay, 0.25, { BackgroundTransparency = 0.35 })

	local n = #results
	local slots: { Frame } = {}
	for i = 1, n do
		local slot = Instance.new("Frame")
		slot.BackgroundTransparency = 1
		slot.AnchorPoint = Vector2.new(0.5, 0.5)
		slot.Size = UDim2.fromOffset(340, 420)
		slot.Position = UDim2.new(0.5, (i - (n + 1) / 2) * 360, 0.5, 0)
		slot.ZIndex = 101
		slot.Parent = overlay
		table.insert(slots, slot)
		local vpHolder = UIKit.Frame({ Size = UDim2.fromOffset(340, 340), Parent = slot })
		local vp = UIKit.Viewport(eggModel(egg), 4.2, vpHolder, math.rad(180))
		vp.ZIndex = 101
		vp.Name = "EggView"
	end
	-- shake with rising intensity
	local t0 = os.clock()
	while os.clock() - t0 < 1.6 do
		local k = (os.clock() - t0) / 1.6
		for _, slot in slots do
			slot.Rotation = math.sin(os.clock() * (20 + k * 30)) * (4 + k * 14)
		end
		if math.random() < 0.15 + k * 0.3 then
			Sound.Play("Tick", 0.8 + k)
		end
		task.wait()
	end
	-- flash
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.ZIndex = 110
	flash.Parent = overlay
	UIKit.Tween(flash, 0.5, { BackgroundTransparency = 1 })
	Sound.Play("Hatch")
	local bestOrder = 0
	for i, item in results do
		local slot = slots[i]
		slot.Rotation = 0
		local view = slot:FindFirstChild("EggView", true)
		if view then
			view:Destroy()
		end
		local def = Pets.ById[item.Pet]
		local rarity = Theme.Rarities[def.Rarity]
		bestOrder = math.max(bestOrder, rarity.Order)
		-- glow burst behind the pet
		local glow = Instance.new("Frame")
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromOffset(170, 170)
		glow.Size = UDim2.fromOffset(60, 60)
		glow.BackgroundColor3 = rarity.Color
		glow.BackgroundTransparency = 0.3
		glow.ZIndex = 101
		UIKit.Round(glow)
		if rarity.Animated then
			UIKit.Rainbow(glow)
		end
		glow.Parent = slot
		UIKit.Tween(
			glow,
			0.6,
			{ Size = UDim2.fromOffset(320, 320), BackgroundTransparency = 0.65 },
			Enum.EasingStyle.Back
		)
		local holder = UIKit.Frame({ Size = UDim2.fromOffset(340, 340), Parent = slot })
		local vp = UIKit.Viewport(PetModels.Build(def), PetModels.Extent, holder, math.rad(30))
		vp.ZIndex = 102
		UIKit.Spin(vp, PetModels.Extent, 1.2)
		UIKit.Pop(holder, 0.3)
		local name = UIKit.Label({
			Text = def.Name,
			TextSize = 40,
			Size = UDim2.new(1, 0, 0, 44),
			Position = UDim2.fromOffset(0, 330),
			Parent = slot,
		})
		name.ZIndex = 103
		local rl = UIKit.Label({
			Text = string.upper(def.Rarity) .. "  •  +" .. Format.Abbrev(def.Bonus) .. "%",
			TextSize = 30,
			Color = rarity.Color,
			Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.fromOffset(0, 376),
			Parent = slot,
		})
		rl.ZIndex = 103
		if rarity.Animated then
			UIKit.Rainbow(rl)
		end
	end
	if bestOrder >= Theme.Rarities.Legendary.Order then
		Sound.Play("Win")
	end
	task.wait(2.4)
	UIKit.Tween(overlay, 0.3, { BackgroundTransparency = 1 })
	for _, d in overlay:GetDescendants() do
		if d:IsA("GuiObject") then
			TweenService:Create(d, TweenInfo.new(0.3), { Size = UDim2.new() }):Play()
		end
	end
	task.wait(0.3)
	overlay:Destroy()
end

return function(): UI.PanelHandle
	local panel = UIKit.Panel({ Title = "Egg", Color = C.Mint, Size = Vector2.new(980, 600) })
	local body = panel.Body
	local current: Pets.Egg? = nil
	local hatching = false

	local priceLabel =
		UIKit.Label({ Text = "", TextSize = 34, Color = C.Gold, Size = UDim2.new(1, 0, 0, 40), Parent = body })
	local odds = UIKit.Frame({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 300), Parent = body })
	UIKit.List(odds, 14, true)
	local footer = UIKit.Frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 120),
		Parent = body,
	})
	UIKit.List(footer, 20, true)

	local function hatch(count: number)
		if hatching or not current then
			return
		end
		local egg = current
		hatching = true
		local r = Request.Call("Hatch", { Egg = egg.Id, Count = count })
		if r.ok and r.data then
			UI.Close()
			playHatch(egg, r.data.Pets)
		end
		hatching = false
	end

	local one = UIKit.Button({
		Text = "HATCH 1",
		Icon = "🥚",
		Color = C.Green,
		Size = UDim2.fromOffset(300, 84),
		TextSize = 34,
		Parent = footer,
		OnClick = function()
			hatch(1)
		end,
	})
	local three = UIKit.Button({
		Text = "HATCH 3",
		Icon = "🥚",
		Color = C.Purple,
		Size = UDim2.fromOffset(300, 84),
		TextSize = 34,
		Parent = footer,
		OnClick = function()
			if State.Ctx.Passes.TripleHatch then
				hatch(3)
			else
				Request.BuyPass("TripleHatch")
			end
		end,
	})
	local hint = UIKit.Label({
		Text = "Hatched pets boost your VIEWS. Equip them in the PETS menu!",
		TextSize = 22,
		Font = Theme.Fonts.Body,
		Stroke = 0,
		Color = Color3.fromRGB(210, 205, 230),
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 356),
		Parent = body,
	})
	local _ = hint

	local function show(eggId: string)
		local egg = Pets.Eggs[eggId]
		if not egg then
			return
		end
		current = egg
		panel.Title.Text = string.upper(egg.Name)
		priceLabel.Text = "💰 " .. Format.Abbrev(egg.Cost) .. " CLOUT EACH"
		for _, c in odds:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, petId in egg.Pets do
			local def = Pets.ById[petId]
			local tile = UIKit.Tile({ Rarity = def.Rarity, Parent = odds, LayoutOrder = i })
			tile.Root.Size = UDim2.fromOffset(168, 290)
			UIKit.Viewport(PetModels.Build(def), PetModels.Extent, tile.Content, math.rad(30))
			tile.Name.Text = def.Name
			tile.Sub.Text = "+" .. Format.Abbrev(def.Bonus) .. "%"
			tile.Tag.Text = (
				if def.Chance < 1
					then string.format("%.2f", def.Chance)
					else tostring(math.floor(def.Chance * 10 + 0.5) / 10)
			) .. "%"
		end
		one:SetText("HATCH 1  💰" .. Format.Abbrev(egg.Cost))
		three:SetText(
			if State.Ctx.Passes.TripleHatch then ("HATCH 3  💰" .. Format.Abbrev(egg.Cost * 3)) else "HATCH 3 🔒"
		)
	end

	return {
		Panel = panel,
		Open = function(eggId: any)
			if typeof(eggId) == "string" then
				show(eggId)
			end
		end,
	}
end
