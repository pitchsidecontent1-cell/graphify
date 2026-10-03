--!strict
-- Admin tools on the client:
--   * Admin.Run(text) sends a command to the server (AdminService) and shows
--     the result (toast, command bar log, or chat for chat commands)
--   * "/" chat commands with autocomplete for admins (";cmd" also works,
--     handled by the server)
--   * the command bar (press ; or F2)
--   * fly + noclip, switched on by the server via player attributes
-- Only players the server marks with the "Admin" attribute see any of this;
-- the server re-checks every command anyway.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Util.Net)
local AdminCommands = require(Shared.Util.AdminCommands)
local State = require(script.Parent.State)
local Request = require(script.Parent.Request)
local Sound = require(script.Parent.Sound)
local UIFolder = script.Parent.Parent:WaitForChild("UI")
local UI = require(UIFolder:WaitForChild("UI"))
local HUD = require(UIFolder:WaitForChild("HUD"))
local AdminConsole = require(UIFolder:WaitForChild("AdminConsole"))

local Admin = {}

local player = Players.LocalPlayer
local console: AdminConsole.Console? = nil

-- Built-in chat commands we must not shadow.
local RESERVED: { [string]: boolean } = {
	help = true,
	["?"] = true,
	clear = true,
	cls = true,
	console = true,
	team = true,
	t = true,
	whisper = true,
	w = true,
	mute = true,
	m = true,
	unmute = true,
	um = true,
	e = true,
	emote = true,
	version = true,
	ver = true,
	v = true,
}

function Admin.IsAdmin(): boolean
	return player:GetAttribute("Admin") == true
end

local function escape(s: string): string
	s = string.gsub(s, "&", "&amp;")
	s = string.gsub(s, "<", "&lt;")
	s = string.gsub(s, ">", "&gt;")
	return s
end

local function chatSystemMessage(text: string, ok: boolean)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general and general:IsA("TextChannel") then
			local color = if ok then "#3DDC97" else "#FF7882"
			for line in string.gmatch(text, "[^\n]+") do
				general:DisplaySystemMessage(
					'<font color="' .. color .. '">[🛠️ ADMIN] ' .. escape(line) .. "</font>"
				)
			end
		end
	end)
end

-- Run a command. `from`: "panel" | "console" | "chat". Returns (ok, message).
function Admin.Run(text: string, from: string?): (boolean, string)
	local clean = AdminCommands.Clean(text)
	if clean == "" then
		return false, ""
	end
	local command = AdminCommands.Find(string.match(clean, "^%S+") or "")
	if command and command.Name == "cmds" then
		if console and console.IsOpen() then
			console.Close()
		end
		UI.Open("Admin", { Tab = "Commands" })
		return true, "Opened the command list"
	end
	local r = Request.Call("Admin", { Text = clean }, true)
	local ok = r.ok
	local message: string = if ok
		then (if r.data and typeof(r.data.Text) == "string" then r.data.Text else "Done")
		else (r.msg or "Failed")
	if message == "network" then
		message = "Connection hiccup, try again"
	end
	Sound.Play(if ok then "Pop" else "Error")
	if console and from ~= "console" then
		console.Log("› " .. clean, "cmd")
	end
	if console then
		console.Log(message, if ok then "ok" else "error")
	end
	if from == "chat" then
		chatSystemMessage(message, ok)
	elseif from ~= "console" then
		local n = 0
		for line in string.gmatch(message, "[^\n]+") do
			n += 1
			if n > 4 then
				break
			end
			Request.Toast:Fire("🛠️ " .. line, if ok then "success" else "error")
		end
	end
	return ok, message
end

function Admin.OpenConsole(prefill: string?)
	if console and Admin.IsAdmin() then
		console.Open(prefill)
	end
end

function Admin.ToggleConsole()
	if console and Admin.IsAdmin() then
		console.Toggle()
	end
end

-- Chat commands ----------------------------------------------------------------------------------
local chatFolder: Folder? = nil

local function registerChatCommands()
	if chatFolder or not Admin.IsAdmin() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "AdminCommands"
	for _, c in AdminCommands.List do
		local names = {}
		for _, name in { c.Name, table.unpack(c.Aliases) } do
			if not RESERVED[name] then
				table.insert(names, name)
			end
		end
		-- a TextChatCommand holds two aliases, so make one per pair of names
		for i = 1, #names, 2 do
			local ok = pcall(function()
				local tc = Instance.new("TextChatCommand")
				tc.Name = "Admin_" .. c.Name .. (if i > 1 then "_" .. i else "")
				tc.PrimaryAlias = "/" .. names[i]
				if names[i + 1] then
					tc.SecondaryAlias = "/" .. names[i + 1]
				end
				tc.AutocompleteVisible = i == 1
				tc.Triggered:Connect(function(_source: TextSource, message: string)
					task.spawn(Admin.Run, message, "chat")
				end)
				tc.Parent = folder
			end)
			if not ok then
				break
			end
		end
	end
	folder.Parent = TextChatService
	chatFolder = folder
end

-- Fly ----------------------------------------------------------------------------------------------
local flyConn: RBXScriptConnection? = nil
local flyParts: { Instance } = {}
local flyHumanoid: Humanoid? = nil

local function stopFly()
	if flyConn then
		flyConn:Disconnect()
		flyConn = nil
	end
	for _, inst in flyParts do
		inst:Destroy()
	end
	table.clear(flyParts)
	local hum = flyHumanoid
	flyHumanoid = nil
	if hum and hum.Parent then
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function typing(): boolean
	if UserInputService:GetFocusedTextBox() then
		return true
	end
	-- the chat bar is a CoreGui box GetFocusedTextBox can't see
	local bar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	return bar ~= nil and bar.IsFocused
end

local function keyDown(...: Enum.KeyCode): boolean
	if typing() then
		return false
	end
	for _, key in { ... } do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function startFly()
	stopFly()
	local char = player.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or not root:IsA("BasePart") then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "AdminFly"
	att.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "AdminFlyVelocity"
	velocity.Attachment0 = att
	velocity.MaxForce = math.huge
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "AdminFlyAlign"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = att
	align.MaxTorque = math.huge
	align.Responsiveness = 40
	align.CFrame = root.CFrame.Rotation
	align.Parent = root
	table.insert(flyParts, align)
	table.insert(flyParts, velocity)
	table.insert(flyParts, att)
	flyHumanoid = hum
	hum.PlatformStand = true

	local heading = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	heading = if heading.Magnitude > 1e-3 then heading.Unit else Vector3.new(0, 0, -1)
	flyConn = RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		if not cam or not root.Parent or not hum.Parent then
			return
		end
		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 1e-3 then
			heading = flat.Unit
		end
		local right = heading:Cross(Vector3.yAxis)
		local move = hum.MoveDirection
		local forward = move:Dot(heading)
		local strafe = move:Dot(right)
		local up = 0
		if keyDown(Enum.KeyCode.Space, Enum.KeyCode.E) then
			up += 1
		end
		if keyDown(Enum.KeyCode.LeftControl, Enum.KeyCode.Q) then
			up -= 1
		end
		local dir = look * forward + right * strafe + Vector3.yAxis * up
		if dir.Magnitude > 1 then
			dir = dir.Unit
		end
		local speed = math.max(70, hum.WalkSpeed * 2.5)
		velocity.VectorVelocity = dir * speed
		align.CFrame = CFrame.lookAt(Vector3.zero, heading)
		hum.PlatformStand = true
	end)
end

local function applyFly()
	if player:GetAttribute("AdminFly") == true then
		startFly()
	else
		stopFly()
	end
end

-- Noclip -------------------------------------------------------------------------------------------
local noclipConn: RBXScriptConnection? = nil
local noclipParts: { [BasePart]: boolean } = {}

local function applyNoclip()
	local on = player:GetAttribute("AdminNoclip") == true
	if on and not noclipConn then
		noclipConn = RunService.Stepped:Connect(function()
			local char = player.Character
			if not char then
				return
			end
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") and d.CanCollide then
					d.CanCollide = false
					noclipParts[d] = true
				end
			end
		end)
	elseif not on and noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
		for part in noclipParts do
			if part.Parent then
				part.CanCollide = true
			end
		end
		table.clear(noclipParts)
	end
end

-- Lifecycle -----------------------------------------------------------------------------------------
function Admin.Init()
	console = AdminConsole.Build(function(text: string)
		Admin.Run(text, "console")
	end)
end

function Admin.Start()
	if Admin.IsAdmin() then
		registerChatCommands()
	end
	player:GetAttributeChangedSignal("Admin"):Connect(function()
		if Admin.IsAdmin() then
			registerChatCommands()
		elseif console then
			console.Close()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not Admin.IsAdmin() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Semicolon or input.KeyCode == Enum.KeyCode.F2 then
			Admin.ToggleConsole()
		end
	end)

	player:GetAttributeChangedSignal("AdminFly"):Connect(applyFly)
	player:GetAttributeChangedSignal("AdminNoclip"):Connect(applyNoclip)
	player.CharacterAdded:Connect(function(char)
		stopFly()
		table.clear(noclipParts)
		if player:GetAttribute("AdminFly") == true then
			char:WaitForChild("HumanoidRootPart", 10)
			char:WaitForChild("Humanoid", 10)
			task.wait(0.3)
			if player.Character == char then
				applyFly()
			end
		end
	end)
	applyFly()
	applyNoclip()

	-- server -> client admin sync (gift timer jumps)
	Net.Event("Effect").OnClientEvent:Connect(function(name: string, data: any)
		if name ~= "Admin" or typeof(data) ~= "table" then
			return
		end
		if data.Kind == "Gifts" and typeof(data.Elapsed) == "number" then
			State.SessionStart = os.clock() - data.Elapsed
			table.clear(HUD.GiftClaimed)
		end
	end)
end

return Admin
