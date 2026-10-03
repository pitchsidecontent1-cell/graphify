--!strict
-- Guide arrow (beam to your next goal) + first-time tutorial hints.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Devices = require(Shared.Config.Devices)
local Stats = require(Shared.Util.Stats)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local UI = require(script.Parent.Parent.UI.UI)
local State = require(script.Parent.State)
local Request = require(script.Parent.Request)

local Guide = {}

local C = Theme.Colors
local player = Players.LocalPlayer

local targetPart: Part? = nil
local beam: Beam? = nil
local marker: Model? = nil
local hint: Frame? = nil
local hintLabel: TextLabel? = nil

local function findPad(station: string, world: number): BasePart?
	for _, pad in CollectionService:GetTagged("StationPad") do
		if pad:IsA("BasePart") and pad:GetAttribute("Station") == station and pad:GetAttribute("World") == world then
			return pad
		end
	end
	return nil
end

local function findTagged(tag: string, world: number, gate: number?): BasePart?
	for _, p in CollectionService:GetTagged(tag) do
		if
			p:IsA("BasePart")
			and p:GetAttribute("World") == world
			and (gate == nil or p:GetAttribute("Gate") == gate)
		then
			return p
		end
	end
	return nil
end

-- What should the player do next?
local function goal(): (BasePart?, string)
	if not State.IsLoaded then
		return nil, ""
	end
	local data = State.Data
	local world = data.World
	if Stats.CanRebirth(data) then
		return findPad("Rebirth", world), "REBIRTH"
	end
	for _, d in Devices.List do
		if not data.Devices[d.Id] then
			if data.Unlocked[tostring(d.World)] and data.Clout >= d.Cost then
				return findPad("Devices", world), "NEW DEVICE"
			end
			break
		end
	end
	local open = Stats.OpenGates(data, world)
	if open >= Stats.GatesPerWorld and not data.RivalsBeaten[tostring(world)] then
		return findPad("Rival", world), "RIVAL"
	end
	if open > 0 then
		return findTagged("CloutPad", world, open), "CLOUT"
	end
	return findTagged("GateBarrier", world, 1), "GATE"
end

local function ensureVisuals(): (Part, Beam, Model)
	if targetPart and beam and marker then
		return targetPart, beam, marker
	end
	local folder = Instance.new("Folder")
	folder.Name = "Guide"
	folder.Parent = Workspace
	local tp = Instance.new("Part")
	tp.Name = "GuideTarget"
	tp.Anchored = true
	tp.CanCollide = false
	tp.CanQuery = false
	tp.CanTouch = false
	tp.Transparency = 1
	tp.Size = Vector3.new(1, 1, 1)
	tp.Parent = folder
	local a1 = Instance.new("Attachment")
	a1.Parent = tp
	local b = Instance.new("Beam")
	b.Attachment1 = a1
	b.Width0 = 1.4
	b.Width1 = 1.4
	b.FaceCamera = true
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Segments = 1
	b.Color = ColorSequence.new(C.White, C.Yellow)
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.15, 0.35),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	b.Parent = tp
	-- bouncing arrow over the target
	local m = Instance.new("Model")
	m.Name = "GuideArrow"
	local function piece(size: Vector3, offset: CFrame)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = C.Yellow
		p.Size = size
		p.CFrame = offset
		p.Parent = m
		return p
	end
	m.PrimaryPart = piece(Vector3.new(1.2, 3, 1.2), CFrame.new(0, 2, 0))
	piece(Vector3.new(1.2, 2.4, 1.2), CFrame.new(-0.7, 0.4, 0) * CFrame.Angles(0, 0, math.rad(-40)))
	piece(Vector3.new(1.2, 2.4, 1.2), CFrame.new(0.7, 0.4, 0) * CFrame.Angles(0, 0, math.rad(40)))
	m.Parent = folder
	targetPart, beam, marker = tp, b, m
	return tp, b, m
end

-- Tutorial ---------------------------------------------------------------------------------------
type Step = { text: string, done: () -> boolean }
local STEPS: { Step } = {
	{
		text = "🚶 WALK anywhere! Every step = +1 VIEW",
		done = function()
			return State.Data.Views >= 12
		end,
	},
	{
		text = "➡️ Follow the arrow and open the first GATE",
		done = function()
			return Stats.OpenGates(State.Data, State.Data.World) >= 1
		end,
	},
	{
		text = "💰 Step on the GOLD pad behind the gate to claim CLOUT",
		done = function()
			return State.Data.Stats.Claims >= 1
		end,
	},
	{
		text = "📷 Buy a better DEVICE with your clout (DEVICES button)",
		done = function()
			local n = 0
			for _ in State.Data.Devices do
				n += 1
			end
			return n >= 2
		end,
	},
	{
		text = "🔥 Keep walking to EVOLVE! Rebirth at VIDEO 20 for x2 views",
		done = function()
			return false
		end,
	},
}
local step = 0
local lastStepAt = 0

local function showHint(text: string?)
	local h = hint
	local l = hintLabel
	if not h or not l then
		return
	end
	if text then
		l.Text = text
		if not h.Visible then
			h.Visible = true
			UIKit.Pop(h, 0.5)
		end
	else
		h.Visible = false
	end
end

local function tutorialTick()
	if not State.IsLoaded or State.Data.Tutorial then
		showHint(nil)
		return
	end
	if step == 0 then
		step = 1
		lastStepAt = os.clock()
	end
	local s = STEPS[step]
	if not s then
		return
	end
	showHint(s.text)
	if s.done() then
		step += 1
		lastStepAt = os.clock()
		if STEPS[step] then
			showHint(STEPS[step].text)
		end
	elseif step == #STEPS and os.clock() - lastStepAt > 10 then
		showHint(nil)
		Request.Call("FinishTutorial", nil, true)
		step = #STEPS + 1
	end
end

function Guide.Init() end

function Guide.Start()
	-- the admin "tutorial" command sets Tutorial back to false: start over
	State.On("Tutorial", function(done)
		if done == false then
			step = 0
		end
	end)
	local layer = UI.Layer(UI.HUD)
	local h = Instance.new("Frame")
	h.Name = "TutorialHint"
	h.AnchorPoint = Vector2.new(0.5, 1)
	h.Position = UDim2.new(0.5, 0, 1, -250)
	h.Size = UDim2.fromOffset(0, 66)
	h.AutomaticSize = Enum.AutomaticSize.X
	h.BackgroundColor3 = C.Yellow
	h.Visible = false
	UIKit.Round(h)
	UIKit.Stroke(h, 4, C.Ink)
	UIKit.Gradient(h, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 215)), 90)
	UIKit.Padding(h, 30, 0)
	hintLabel = UIKit.Label({
		Text = "",
		TextSize = 32,
		Color = C.Ink,
		StrokeColor = C.White,
		Stroke = 2,
		Size = UDim2.fromScale(0, 1),
		AutoX = true,
		Parent = h,
	})
	h.Parent = layer
	hint = h

	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local m = marker
		local tp = targetPart
		if m and tp and m.Parent and m.PrimaryPart then
			m:PivotTo(
				CFrame.new(tp.Position + Vector3.new(0, 9 + math.sin(t * 4) * 1.2, 0))
					* CFrame.Angles(0, t * 2, math.pi)
			)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.4)
			pcall(tutorialTick)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local enabled = State.IsLoaded and State.Data.Settings.Beam ~= false
			local target, _kind = goal()
			local tp, b, m = ensureVisuals()
			if enabled and root and target and (target.Position - root.Position).Magnitude > 14 then
				tp.Position = target.Position + Vector3.new(0, 2, 0)
				local a0 = root:FindFirstChild("GuideAttachment") :: Attachment?
				if not a0 then
					local na = Instance.new("Attachment")
					na.Name = "GuideAttachment"
					na.Position = Vector3.new(0, -1.5, 0)
					na.Parent = root
					a0 = na
				end
				b.Attachment0 = a0
				b.Enabled = true
				m.Parent = tp.Parent
			else
				b.Enabled = false
				m.Parent = nil
			end
		end
	end)
end

return Guide
