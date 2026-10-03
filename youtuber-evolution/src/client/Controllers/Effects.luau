--!strict
-- Feedback layer: toasts, "+views" popups, claim bursts, evolve/rebirth/world
-- cutscenes, confetti, light pillars when other players evolve.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Format = require(Shared.Util.Format)
local Evolutions = require(Shared.Config.Evolutions)
local Worlds = require(Shared.Config.Worlds)
local Net = require(Shared.Util.Net)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local UI = require(script.Parent.Parent.UI.UI)
local HUD = require(script.Parent.Parent.UI.HUD)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)
local Request = require(script.Parent.Request)

local Effects = {}

local C = Theme.Colors
local player = Players.LocalPlayer

-- Toasts ------------------------------------------------------------------------------------
local toastHolder: Frame? = nil
local TOAST_COLORS = {
	info = C.Blue,
	success = C.Green,
	error = C.Red,
	reward = C.Gold,
} :: { [string]: Color3 }

function Effects.Toast(text: string, kind: string?)
	local holder = toastHolder
	if not holder then
		return
	end
	local color = TOAST_COLORS[kind or "info"] or C.Blue
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(0, 58)
	f.AutomaticSize = Enum.AutomaticSize.X
	f.BackgroundColor3 = color
	f.LayoutOrder = -math.floor(os.clock() * 100)
	UIKit.Round(f)
	UIKit.Stroke(f, 4, C.Ink)
	UIKit.Gradient(f, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 212)), 90)
	UIKit.Padding(f, 26, 0)
	local l =
		UIKit.Label({ Text = text, TextSize = 28, Size = UDim2.fromScale(0, 1), AutoX = true, Stroke = 3, Parent = f })
	l.TextTransparency = 0
	f.Parent = holder
	UIKit.Pop(f, 0.6)
	-- keep max 4 toasts
	local toasts = {}
	for _, c in holder:GetChildren() do
		if c:IsA("Frame") then
			table.insert(toasts, c)
		end
	end
	if #toasts > 4 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	task.delay(if kind == "error" then 2.4 else 3.2, function()
		if f.Parent then
			UIKit.Tween(UIKit.ScaleOf(f), 0.2, { Scale = 0 })
			task.wait(0.2)
			f:Destroy()
		end
	end)
end

-- "+views" popups above your head -------------------------------------------------------------
local popupGui: BillboardGui? = nil
local lastViews = 0
local pending = 0
local lastPopup = 0

local function ensurePopupGui(): BillboardGui?
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return nil
	end
	if popupGui and popupGui.Parent == head then
		return popupGui
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "ViewPopups"
	gui.Size = UDim2.fromOffset(300, 260)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.Adornee = head :: BasePart
	gui.Parent = player:WaitForChild("PlayerGui")
	popupGui = gui
	return gui
end

local function spawnPopup(amount: number)
	if State.IsLoaded and State.Data.Settings.Popups == false then
		return
	end
	local gui = ensurePopupGui()
	if not gui then
		return
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromOffset(240, 46)
	label.Position = UDim2.new(0.5, math.random(-60, 60), 0.75, math.random(-10, 10))
	label.Text = "+" .. Format.Abbrev(amount)
	label.TextScaled = true
	label.FontFace = Theme.Fonts.Display
	label.TextColor3 = if math.random() < 0.5 then C.White else C.Yellow
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = C.Ink
	s.Parent = label
	label.Parent = gui
	local sc = UIKit.ScaleOf(label)
	sc.Scale = 0.4
	UIKit.Tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	local tween = TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.fromOffset(0, 140),
		TextTransparency = 1,
	})
	TweenService:Create(s, TweenInfo.new(0.9), { Transparency = 1 }):Play()
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

-- Fly little icons from a screen point to a HUD element ----------------------------------------
local function flyIcons(emoji: string, target: GuiObject?, count: number)
	if not target then
		return
	end
	local layer = UI.Layer(UI.FX)
	local center = layer.AbsoluteSize / 2
	local tpos = (target.AbsolutePosition + target.AbsoluteSize / 2 - layer.AbsolutePosition) / math.max(UI.Scale, 0.01)
	local half = center / math.max(UI.Scale, 0.01)
	for i = 1, count do
		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Size = UDim2.fromOffset(58, 58)
		icon.Text = emoji
		icon.TextScaled = true
		icon.FontFace = Theme.Fonts.Display
		icon.Position = UDim2.fromOffset(half.X + math.random(-140, 140), half.Y + math.random(-90, 90))
		icon.ZIndex = 60
		icon.Parent = layer
		local delay = i * 0.03
		task.delay(delay, function()
			local t = TweenService:Create(
				icon,
				TweenInfo.new(0.55 + math.random() * 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Position = UDim2.fromOffset(tpos.X, tpos.Y),
					Size = UDim2.fromOffset(30, 30),
				}
			)
			t:Play()
			t.Completed:Connect(function()
				icon:Destroy()
			end)
		end)
	end
	task.delay(0.7, function()
		UIKit.Pop(target, 1.2)
		Sound.Play("Pop", 1.3)
	end)
end

-- Big centre banner ----------------------------------------------------------------------------
local function banner(top: string, main: string, color: Color3, sub: string?, duration: number?, rainbow: boolean?)
	local layer = UI.Layer(UI.FX)
	local holder = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(900, 260),
		Parent = layer,
	})
	holder.ZIndex = 70
	local t = UIKit.Label({
		Text = top,
		TextSize = 46,
		Color = C.White,
		Size = UDim2.new(1, 0, 0, 56),
		Stroke = 4,
		Parent = holder,
	})
	t.ZIndex = 71
	local m = UIKit.Label({
		Text = main,
		TextSize = 96,
		Color = color,
		Size = UDim2.new(1, 0, 0, 110),
		Position = UDim2.fromOffset(0, 56),
		Stroke = 6,
		Parent = holder,
	})
	m.ZIndex = 71
	if rainbow then
		UIKit.Rainbow(m)
	else
		UIKit.Gradient(m, ColorSequence.new(color:Lerp(C.White, 0.45), color), 90)
	end
	if sub then
		local s = UIKit.Label({
			Text = sub,
			TextSize = 38,
			Color = C.Yellow,
			Size = UDim2.new(1, 0, 0, 48),
			Position = UDim2.fromOffset(0, 170),
			Stroke = 4,
			Parent = holder,
		})
		s.ZIndex = 71
	end
	local sc = UIKit.ScaleOf(holder)
	sc.Scale = 0.3
	UIKit.Tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(duration or 2.2, function()
		UIKit.Tween(sc, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.3)
		holder:Destroy()
	end)
end

local function flash(color: Color3, alpha: number?, time: number?)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = alpha or 0.3
	f.ZIndex = 80
	f.Parent = UI.Layer(UI.Top)
	local tw = TweenService:Create(f, TweenInfo.new(time or 0.6), { BackgroundTransparency = 1 })
	tw:Play()
	tw.Completed:Connect(function()
		f:Destroy()
	end)
end

local function fovPunch(amount: number)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local base = 70
	cam.FieldOfView = base - amount
	TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Back), { FieldOfView = base }):Play()
end

function Effects.Confetti(count: number?)
	local layer = UI.Layer(UI.Top)
	local size = layer.AbsoluteSize / math.max(UI.Scale, 0.01)
	local colors = { C.Red, C.Yellow, C.Cyan, C.Pink, C.Mint, C.Purple }
	for _ = 1, count or 50 do
		local p = Instance.new("Frame")
		p.Size = UDim2.fromOffset(math.random(10, 18), math.random(16, 26))
		p.BackgroundColor3 = colors[math.random(1, #colors)]
		p.BorderSizePixel = 0
		p.Rotation = math.random(0, 360)
		p.Position = UDim2.fromOffset(math.random(0, math.floor(size.X)), -30)
		p.ZIndex = 85
		p.Parent = layer
		local fall = TweenService:Create(
			p,
			TweenInfo.new(math.random(16, 28) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.fromOffset(p.Position.X.Offset + math.random(-200, 200), size.Y + 40),
				Rotation = p.Rotation + math.random(-540, 540),
			}
		)
		fall:Play()
		fall.Completed:Connect(function()
			p:Destroy()
		end)
	end
end

-- 3D light pillar on a character (evolve)
local function pillar(char: Model, color: Color3)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(60, 2, 2)
	beam.CFrame = CFrame.new(root.Position + Vector3.new(0, 26, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Transparency = 0.2
	beam.Parent = Workspace
	TweenService
		:Create(beam, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Size = Vector3.new(60, 12, 12), Transparency = 1 })
		:Play()
	task.delay(1.3, function()
		beam:Destroy()
	end)
end

-- Handlers ---------------------------------------------------------------------------------------
local claimCombo = 0
local lastClaim = 0

local HANDLERS: { [string]: (any) -> () } = {}

HANDLERS.Claim = function(d)
	local now = os.clock()
	claimCombo = if now - lastClaim < 60 then claimCombo + 1 else 0
	lastClaim = now
	Sound.Play("Claim", 1 + math.min(claimCombo, 8) * 0.04)
	banner("GATE " .. tostring(d.Gate) .. " CLOUT!", "+" .. Format.Abbrev(d.Amount), C.Gold, "💰 CLOUT", 1.4)
	flash(C.Gold, 0.55, 0.5)
	local pill = HUD.Pills.Clout
	flyIcons("💰", if pill then pill.Root else nil, 10)
end

HANDLERS.Video = function(d)
	Sound.Play("Pop", 1 + math.min(d.Level, 60) * 0.008)
	Effects.Toast("▶ VIDEO " .. d.Level .. " UPLOADED!", "success")
end

HANDLERS.Evolve = function(d)
	local evo = Evolutions[d.Tier]
	if not evo then
		return
	end
	local rarity = Theme.Rarities[evo.Rarity]
	Sound.Play("Evolve")
	flash(C.White, 0.1, 0.8)
	fovPunch(12)
	banner(
		"✨ EVOLVED! ✨",
		string.upper(evo.Title),
		rarity.Color,
		"EVOLUTION " .. evo.Tier .. " / " .. #Evolutions,
		2.6,
		rarity.Animated == true
	)
	Effects.Confetti(40)
	local char = player.Character
	if char then
		pillar(char, rarity.Color)
	end
end

HANDLERS.EvolveOther = function(d)
	if d.UserId == player.UserId then
		return
	end
	local other = Players:GetPlayerByUserId(d.UserId)
	local evo = Evolutions[d.Tier]
	if other and other.Character and evo then
		pillar(other.Character, Theme.Rarities[evo.Rarity].Color)
	end
end

HANDLERS.Rebirth = function(d)
	Sound.Play("Rebirth")
	flash(C.Purple, 0, 1.2)
	fovPunch(18)
	banner(
		"🔄 REBIRTH " .. tostring(d.Rebirths) .. "!",
		"VIEWS " .. Format.Mult(d.Multiplier),
		C.Purple,
		"+1 🎟️ NICHE TICKET",
		3
	)
	Effects.Confetti(70)
end

HANDLERS.Purchase = function(_d)
	Sound.Play("Purchase")
	Effects.Confetti(30)
end

HANDLERS.Reward = function(d)
	Sound.Play("Claim")
	Effects.Confetti(25)
	local _ = d
end

HANDLERS.World = function(d)
	local w = Worlds[d.World]
	if not w then
		return
	end
	Sound.Play("Whoosh")
	flash(C.White, 0, 0.9)
	banner("WORLD " .. w.Id, string.upper(w.Name), w.Palette.Accent1, w.Tagline, 2.8)
end

function Effects.Init()
	local holder = UIKit.Frame({
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(900, 300),
		Parent = UI.Layer(UI.FX),
	})
	local list = UIKit.List(holder, 10)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	toastHolder = holder
end

function Effects.Start()
	Request.Toast:Connect(Effects.Toast)
	Net.Event("Notify").OnClientEvent:Connect(function(text: string, kind: string)
		Effects.Toast(text, kind)
		if kind == "reward" then
			Sound.Play("Pop")
		end
	end)
	Net.Event("Effect").OnClientEvent:Connect(function(name: string, data: any)
		local fn = HANDLERS[name]
		if fn then
			local ok, err = pcall(fn :: any, data)
			if not ok then
				warn("[Effects] " .. name .. ": " .. tostring(err))
			end
		end
	end)

	-- +views popups: watch the Views value, show batched gains ~6/sec
	State.On("Views", function(v)
		if v > lastViews and lastViews > 0 then
			pending += v - lastViews
		end
		lastViews = v
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if pending > 0 and now - lastPopup > 0.16 then
			lastPopup = now
			spawnPopup(pending)
			pending = 0
		end
	end)
end

return Effects
