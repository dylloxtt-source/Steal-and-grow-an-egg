--[[
	Взвешенный случайный выбор. Веса не обязаны давать в сумме 100:
	шансы всегда нормализуются (Chances), поэтому таблицы в конфиге легко править.
]]

local WeightedRandom = {}

export type Entry<T> = { Item: T, Weight: number }

function WeightedRandom.Total<T>(entries: { Entry<T> }): number
	local total = 0
	for _, entry in entries do
		if entry.Weight > 0 then
			total += entry.Weight
		end
	end
	return total
end

-- rng — экземпляр Random (на сервере), roll — опционально, число в [0, 1) для тестов
function WeightedRandom.Pick<T>(entries: { Entry<T> }, rng: Random?, roll: number?): T?
	local total = WeightedRandom.Total(entries)
	if total <= 0 then
		return nil
	end
	local r = (roll or (rng or Random.new()):NextNumber()) * total
	local acc = 0
	for _, entry in entries do
		if entry.Weight > 0 then
			acc += entry.Weight
			if r < acc then
				return entry.Item
			end
		end
	end
	-- Защита от погрешности плавающей точки
	for i = #entries, 1, -1 do
		if entries[i].Weight > 0 then
			return entries[i].Item
		end
	end
	return nil
end

-- Нормализованные шансы (0..1) в том же порядке, что и entries
function WeightedRandom.Chances<T>(entries: { Entry<T> }): { number }
	local total = WeightedRandom.Total(entries)
	local result = {}
	for i, entry in entries do
		result[i] = if total > 0 and entry.Weight > 0 then entry.Weight / total else 0
	end
	return result
end

return WeightedRandom
