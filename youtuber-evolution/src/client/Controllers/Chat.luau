--!strict
-- Chat tags: [👑 VIP] for VIP owners and everyone's Evolution title in its
-- rarity colour (set by the server as player attributes "VIP" / "Evo").

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Evolutions = require(Shared.Config.Evolutions)

local Chat = {}

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

function Chat.Init() end

function Chat.Start()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		if not source then
			return props
		end
		local player = Players:GetPlayerByUserId(source.UserId)
		if not player then
			return props
		end
		local prefix = ""
		if player:GetAttribute("VIP") then
			prefix ..= '<font color="#FFC42E">[👑 VIP]</font> '
		end
		local tier = player:GetAttribute("Evo")
		local evo = if typeof(tier) == "number" then Evolutions[tier] else nil
		if evo and evo.Tier > 1 then
			local rarity = Theme.Rarities[evo.Rarity]
			local color = if rarity.Animated then Theme.Colors.Pink else rarity.Color
			prefix ..= '<font color="' .. hex(color) .. '">[' .. evo.Title .. "]</font> "
		end
		props.PrefixText = prefix .. message.PrefixText
		return props
	end
end

return Chat
