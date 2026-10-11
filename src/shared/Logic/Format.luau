--[[
	Форматирование чисел и времени для UI: 1.3M, $481.8M, 4m 42s.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc" }

function Format.Number(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local text = if n == math.floor(n) or n >= 100 then tostring(math.floor(n)) else string.format("%.1f", n)
		text = string.gsub(text, "%.0$", "")
		return (if negative then "-" else "") .. text
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local text = string.format("%.1f", math.floor(scaled * 10) / 10)
	text = string.gsub(text, "%.0$", "")
	return (if negative then "-" else "") .. text .. SUFFIXES[tier + 1]
end

function Format.Money(n: number): string
	return "$" .. Format.Number(n)
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds < 60 then
		return string.format("%ds", seconds)
	end
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm %ds", m, s)
end

function Format.Percent(p: number): string
	local value = p * 100
	if value >= 10 then
		return string.format("%d%%", math.floor(value + 0.5))
	elseif value >= 1 then
		return (string.gsub(string.format("%.1f%%", value), "%.0%%", "%%"))
	end
	return (string.gsub(string.format("%.2f%%", value), "0+%%$", "%%"))
end

return Format
