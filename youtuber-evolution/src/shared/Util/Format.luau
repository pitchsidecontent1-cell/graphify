--!strict
-- Number + time formatting: 999, 1.2K, 381.83K, 12.97B, 167.36B, 1.5Qa ...

local Format = {}

local SUFFIXES = {
	"",
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
	"Sx",
	"Sp",
	"Oc",
	"No",
	"Dc",
	"Ud",
	"Dd",
	"Td",
	"Qad",
	"Qid",
	"Sxd",
	"Spd",
	"Ocd",
	"Nod",
	"Vg",
}

local function trim(s: string): string
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

function Format.Abbrev(n: number?): string
	local value = n or 0
	if value ~= value then
		return "0"
	end
	if value == math.huge then
		return "∞"
	end
	local sign = ""
	if value < 0 then
		sign = "-"
		value = -value
	end
	if value < 1000 then
		if value < 10 and value ~= math.floor(value) then
			return sign .. trim(string.format("%.1f", math.floor(value * 10) / 10))
		end
		return sign .. tostring(math.floor(value))
	end
	local group = math.floor(math.log10(value) / 3)
	if group >= #SUFFIXES then
		return sign .. string.format("%.2e", value)
	end
	local scaled = value / 10 ^ (group * 3)
	-- log10 can land just under an integer (e.g. 2.9999) -> fix the group
	while scaled >= 1000 and group + 1 < #SUFFIXES do
		group += 1
		scaled = value / 10 ^ (group * 3)
	end
	local text = trim(string.format("%.2f", math.floor(scaled * 100 + 1e-6) / 100))
	return sign .. text .. SUFFIXES[group + 1]
end

function Format.Commas(n: number): string
	if math.abs(n) >= 1e15 then
		return Format.Abbrev(n)
	end
	local s = string.format("%.0f", math.floor(n))
	local formatted = s
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

-- Short numbers keep full precision ("1,234"), big ones abbreviate.
function Format.Smart(n: number): string
	if math.abs(n) < 10000 then
		return Format.Commas(n)
	end
	return Format.Abbrev(n)
end

function Format.Mult(n: number): string
	if n < 1000 then
		local r = math.floor(n * 100 + 0.5) / 100
		return "x" .. trim(string.format("%.2f", r))
	end
	return "x" .. Format.Abbrev(n)
end

function Format.Percent(n: number): string
	return "+" .. Format.Abbrev(math.floor(n + 0.5)) .. "%"
end

function Format.Time(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = math.floor(s / 3600)
	local m = math.floor((s % 3600) / 60)
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

function Format.Duration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return string.format("%dh %02dm", math.floor(s / 3600), math.floor((s % 3600) / 60))
	elseif s >= 60 then
		return string.format("%dm %02ds", math.floor(s / 60), s % 60)
	end
	return string.format("%ds", s)
end

return Format
