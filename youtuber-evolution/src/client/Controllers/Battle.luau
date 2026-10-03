--!strict
-- VIEW WAR client: cinematic camera, live view counters, tug-of-war bar,
-- trend bubbles, click/tap input, countdown and the result screen.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Format = require(Shared.Util.Format)
local Worlds = require(Shared.Config.Worlds)
local Net = require(Shared.Util.Net)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local UI = require(script.Parent.Parent.UI.UI)
local HUD = require(script.Parent.Parent.UI.HUD)
local Sound = require(script.Parent.Sound)
local Effects = require(script.Parent.Effects)

local Battle = {}

local C = Theme.Colors
local player = Players.LocalPlayer

type Refs = {
	root: Frame,
	you: TextLabel,
	rival: TextLabel,
	bar: Frame,
	knot: Frame,
	timer: TextLabel,
	warn: TextLabel,
	trend: TextLabel,
	bubbles: Frame,
	hint: TextLabel,
}

local refs: Refs? = nil
local active = false
local clicks = 0
local comments = {
	"W",
	"first!!",
	"🔥🔥🔥",
	"ratio'd",
	"LETS GOOO",
	"+1 sub",
	"W video",
	"😂😂",
	"underrated",
	"who's watching in 2026",
}

local function commentFly(layer: Frame)
	local l = UIKit.Label({
		Text = comments[math.random(1, #comments)],
		TextSize = math.random(26, 40),
		Color = if math.random() < 0.5 then C.White else C.Yellow,
		Size = UDim2.fromOffset(400, 50),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 20, math.random(18, 82) / 100, 0),
		Parent = layer,
	})
	l.ZIndex = 52
	local tw = TweenService:Create(
		l,
		TweenInfo.new(math.random(28, 45) / 10, Enum.EasingStyle.Linear),
		{ Position = UDim2.new(-0.4, 0, l.Position.Y.Scale, 0) }
	)
	tw:Play()
	tw.Completed:Connect(function()
		l:Destroy()
	end)
end

local function build(): Refs
	local layer = UI.Layer(UI.FX)
	local root = UIKit.Frame({ Name = "ViewWar", Size = UDim2.fromScale(1, 1), Parent = layer })
	root.ZIndex = 50
	root.Visible = false

	local top = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(1200, 230),
		Parent = root,
	})
	local function side(x: number, color: Color3, title: string): TextLabel
		local card = UIKit.Card(top, UDim2.fromOffset(440, 130), color)
		card.Position = UDim2.new(x, 0, 0, 0)
		card.AnchorPoint = Vector2.new(x, 0)
		UIKit.Gradient(card, ColorSequence.new(color:Lerp(C.White, 0.3), color:Lerp(C.Ink, 0.3)), 90)
		UIKit.Label({
			Text = title,
			TextSize = 30,
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 6),
			Parent = card,
		})
		local v = UIKit.Label({
			Text = "0",
			TextSize = 58,
			Size = UDim2.new(1, 0, 0, 70),
			Position = UDim2.fromOffset(0, 48),
			Stroke = 4,
			Parent = card,
		})
		return v
	end
	local you = side(0, C.Blue, "👁️ YOU • LIVE VIEWS")
	local rivalLabel = side(1, C.Red, "RIVAL • LIVE VIEWS")
	local timer = UIKit.Label({
		Text = "15",
		TextSize = 70,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.fromOffset(200, 80),
		Parent = top,
	})

	-- tug-of-war bar
	local barBg = Instance.new("Frame")
	barBg.AnchorPoint = Vector2.new(0.5, 0)
	barBg.Position = UDim2.new(0.5, 0, 0, 150)
	barBg.Size = UDim2.new(1, 0, 0, 56)
	barBg.BackgroundColor3 = C.Red
	UIKit.Round(barBg)
	UIKit.Stroke(barBg, 5, C.Ink)
	UIKit.Gradient(barBg, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210)), 90)
	barBg.Parent = top
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0.5, 1)
	bar.BackgroundColor3 = C.Blue
	UIKit.Round(bar)
	UIKit.Gradient(bar, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210)), 90)
	bar.Parent = barBg
	local knot = Instance.new("Frame")
	knot.AnchorPoint = Vector2.new(0.5, 0.5)
	knot.Position = UDim2.fromScale(0.5, 0.5)
	knot.Size = UDim2.fromOffset(88, 88)
	knot.BackgroundColor3 = C.Yellow
	knot.ZIndex = 3
	UIKit.Round(knot)
	UIKit.Stroke(knot, 5, C.Ink)
	local knotIcon = UIKit.Label({ Text = "⚔️", TextSize = 46, Stroke = 0, Parent = knot })
	knotIcon.ZIndex = 4
	knot.Parent = barBg

	local warn = UIKit.Label({
		Text = "",
		TextSize = 46,
		Color = C.Red,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 340),
		Size = UDim2.fromOffset(1000, 60),
		Stroke = 5,
		Parent = root,
	})
	local trend = UIKit.Label({
		Text = "🔥 TRENDING x2 POWER!",
		TextSize = 42,
		Color = C.Yellow,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 400),
		Size = UDim2.fromOffset(1000, 56),
		Stroke = 5,
		Parent = root,
	})
	trend.Visible = false
	local hint = UIKit.Label({
		Text = "TAP / CLICK FAST TO POST!",
		TextSize = 44,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -60),
		Size = UDim2.fromOffset(1000, 56),
		Stroke = 5,
		Parent = root,
	})
	local bubbles = UIKit.Frame({ Size = UDim2.fromScale(1, 1), Parent = root })
	return {
		root = root,
		you = you,
		rival = rivalLabel,
		bar = bar,
		knot = knot,
		timer = timer,
		warn = warn,
		trend = trend,
		bubbles = bubbles,
		hint = hint,
	}
end

local function setCamera(world: number)
	local cam = Workspace.CurrentCamera
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not cam or not root then
		return
	end
	local w = Worlds[world]
	local focus = root.Position + Vector3.new(0, 4, 10) -- between you and the rival (+Z)
	cam.CameraType = Enum.CameraType.Scriptable
	local side = CFrame.lookAt(focus + Vector3.new(34, 10, -6), focus)
	local _ = w
	TweenService:Create(cam, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { CFrame = side, FieldOfView = 60 }):Play()
end

local function resetCamera()
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		TweenService:Create(cam, TweenInfo.new(0.4), { FieldOfView = 70 }):Play()
	end
end

local function countdown(layer: Frame)
	for _, n in { "3", "2", "1", "POST!" } do
		local l = UIKit.Label({
			Text = n,
			TextSize = 160,
			Color = C.Yellow,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromOffset(800, 200),
			Stroke = 8,
			Parent = layer,
		})
		l.ZIndex = 60
		UIKit.Pop(l, 0.3)
		Sound.Play("Tick", if n == "POST!" then 1.6 else 1)
		task.delay(0.7, function()
			l:Destroy()
		end)
		task.wait(0.75)
	end
end

local function showResult(data: any)
	local layer = UI.Layer(UI.FX)
	local win = data.Win == true
	local holder = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(1000, 360),
		Parent = layer,
	})
	holder.ZIndex = 70
	local title = UIKit.Label({
		Text = if win then "VICTORY!" else "DEFEAT",
		TextSize = 130,
		Color = if win then C.Yellow else C.Red,
		Size = UDim2.new(1, 0, 0, 150),
		Stroke = 8,
		Parent = holder,
	})
	title.ZIndex = 71
	local lines = {}
	if win then
		if data.First then
			table.insert(lines, "⚔️ " .. string.upper(Worlds[data.World].Rival.Name) .. " DEFEATED!")
		end
		if data.Clout then
			table.insert(lines, "💰 +" .. Format.Abbrev(data.Clout) .. " CLOUT")
		end
		if data.Tickets then
			table.insert(lines, "🎟️ +" .. data.Tickets .. " NICHE TICKETS")
		end
		if data.Unlocked then
			table.insert(
				lines,
				"🌍 " .. string.upper(Worlds[data.Unlocked].Name) .. " UNLOCKED! (portal behind the screen)"
			)
		end
	else
		table.insert(lines, "SO CLOSE! Get ~" .. Format.Abbrev(data.NeedViews or 0) .. " more views")
		table.insert(lines, "Tip: rebirth, better devices & pets = more views")
	end
	for i, text in lines do
		local l = UIKit.Label({
			Text = text,
			TextSize = 40,
			Color = C.White,
			Size = UDim2.new(1, 0, 0, 48),
			Position = UDim2.fromOffset(0, 150 + (i - 1) * 50),
			Stroke = 4,
			Parent = holder,
		})
		l.ZIndex = 71
	end
	UIKit.Pop(holder, 0.4)
	if win then
		Sound.Play("Win")
		Effects.Confetti(90)
	else
		Sound.Play("Lose")
	end
	task.delay(3.4, function()
		UIKit.Tween(UIKit.ScaleOf(holder), 0.25, { Scale = 0 })
		task.wait(0.3)
		holder:Destroy()
	end)
end

function Battle.Init() end

function Battle.Start()
	local input = Net.Event("BattleInput")
	Net.Event("Battle").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "start" then
			refs = refs or build()
			local r = refs :: Refs
			UI.Close()
			HUD.SetHidden(true)
			r.root.Visible = true
			r.you.Text = Format.Abbrev(data.You)
			r.rival.Text = Format.Abbrev(data.Rival)
			r.timer.Text = tostring(data.Duration)
			r.bar.Size = UDim2.fromScale(0.5, 1)
			r.knot.Position = UDim2.fromScale(0.5, 0.5)
			r.warn.Text = ""
			setCamera(data.World)
			task.spawn(function()
				countdown(r.root)
				active = true
				clicks = 0
			end)
			task.spawn(function()
				while r.root.Visible do
					commentFly(r.root)
					task.wait(math.random(4, 9) / 10)
				end
			end)
		elseif kind == "tick" and refs then
			local r = refs :: Refs
			TweenService:Create(r.bar, TweenInfo.new(0.1), { Size = UDim2.fromScale(data.P, 1) }):Play()
			TweenService:Create(r.knot, TweenInfo.new(0.1), { Position = UDim2.fromScale(data.P, 0.5) }):Play()
			r.you.Text = Format.Abbrev(data.You)
			r.rival.Text = Format.Abbrev(data.Rival)
			r.timer.Text = tostring(math.max(0, math.ceil((tonumber(r.timer:GetAttribute("Duration")) or 0) - data.T)))
			r.warn.Text = if data.Surge
				then "📈 RIVAL IS UPLOADING!"
				elseif data.Warn then "⚠️ RIVAL IS ABOUT TO UPLOAD!"
				else ""
			r.trend.Visible = data.Trend == true
		elseif kind == "bubble" and refs then
			local r = refs :: Refs
			local b = Instance.new("TextButton")
			b.Name = "Bubble" .. data.Id
			b.AnchorPoint = Vector2.new(0.5, 0.5)
			b.Position = UDim2.fromScale(data.X, data.Y)
			b.Size = UDim2.fromOffset(220, 90)
			b.BackgroundColor3 = C.Pink
			b.Text = ""
			b.ZIndex = 55
			UIKit.Round(b)
			UIKit.Stroke(b, 5, C.Ink).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			local l =
				UIKit.Label({ Text = if math.random() < 0.5 then "#TRENDING" else "#VIRAL", TextSize = 38, Parent = b })
			l.ZIndex = 56
			b.Parent = r.bubbles
			UIKit.Pop(b, 0.3)
			b.Activated:Connect(function()
				input:FireServer("bubble", data.Id)
				b:Destroy()
			end)
			task.delay(data.Life, function()
				if b.Parent then
					b:Destroy()
				end
			end)
		elseif kind == "bubblehit" then
			Sound.Play("Claim", 1.4)
		elseif kind == "end" then
			active = false
			if refs then
				(refs :: Refs).root.Visible = false
				for _, c in (refs :: Refs).bubbles:GetChildren() do
					c:Destroy()
				end
			end
			resetCamera()
			HUD.SetHidden(false)
			showResult(data)
		end
		if kind == "start" and refs then
			(refs :: Refs).timer:SetAttribute("Duration", data.Duration)
		end
	end)

	-- clicks / taps anywhere count as posts
	UserInputService.InputBegan:Connect(function(io, processed)
		if not active then
			return
		end
		if
			io.UserInputType == Enum.UserInputType.MouseButton1
			or io.UserInputType == Enum.UserInputType.Touch
			or io.KeyCode == Enum.KeyCode.Space
			or io.KeyCode == Enum.KeyCode.ButtonA
		then
			clicks += 1
			if refs then
				UIKit.Pop((refs :: Refs).knot, 1.15)
			end
			if math.random() < 0.4 then
				Sound.Play("Tick", 1.2 + math.random() * 0.4)
			end
		end
		local _ = processed
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			if active and clicks > 0 then
				input:FireServer("click", clicks)
				clicks = 0
			end
		end
	end)
end

return Battle
