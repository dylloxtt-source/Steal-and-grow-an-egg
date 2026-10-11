--[[
	Форматирование чисел и времени для интерфейса.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T" }

function Format.Number(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	local text
	if n < 1000 then
		text = tostring(math.floor(n))
	else
		local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
		local scaled = n / 10 ^ (tier * 3)
		text = string.gsub(string.format("%.1f", math.floor(scaled * 10) / 10), "%.0$", "") .. SUFFIXES[tier + 1]
	end
	return (if negative then "-" else "") .. text
end

-- Целое число с разделителями тысяч: 1340 → "1,340"
function Format.Thousands(n: number): string
	local text = tostring(math.floor(math.abs(n)))
	local grouped = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	if string.sub(grouped, 1, 1) == "," then
		grouped = string.sub(grouped, 2)
	end
	return (if n < 0 then "-" else "") .. grouped
end

-- Деньги матча показываются точно (до 100 000), чтобы было видно, хватает ли на покупку
function Format.Cash(n: number): string
	if math.abs(n) >= 100000 then
		return "$" .. Format.Number(n)
	end
	local grouped = Format.Thousands(math.abs(n))
	return (if n < 0 then "-$" else "$") .. grouped
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds < 60 then
		return string.format("0:%02d", seconds)
	end
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Format.Decimal(n: number, digits: number?): string
	local text = string.format("%." .. tostring(digits or 1) .. "f", n)
	return (string.gsub(text, "%.0+$", ""))
end

return Format
