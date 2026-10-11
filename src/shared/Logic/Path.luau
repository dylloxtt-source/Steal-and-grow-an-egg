--[[
	Маршрут врагов: ломаная по waypoints. Положение врага задаётся пройденной
	дистанцией (прогрессом) — она же используется приоритетами First/Last.
]]

local Path = {}
Path.__index = Path

export type Path = typeof(setmetatable({} :: {
	Points: { Vector3 },
	Cumulative: { number },
	Length: number,
}, Path))

function Path.new(points: { Vector3 }): Path
	local cumulative = { 0 }
	local length = 0
	for i = 2, #points do
		length += (points[i] - points[i - 1]).Magnitude
		cumulative[i] = length
	end
	return setmetatable({ Points = points, Cumulative = cumulative, Length = length }, Path)
end

-- Позиция и направление движения на дистанции d (с ограничением концов)
function Path.At(self: Path, d: number): (Vector3, Vector3)
	local points, cumulative = self.Points, self.Cumulative
	if d <= 0 then
		return points[1], (points[2] - points[1]).Unit
	end
	if d >= self.Length then
		local n = #points
		return points[n], (points[n] - points[n - 1]).Unit
	end
	-- бинарный поиск сегмента
	local lo, hi = 1, #points
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if cumulative[mid] <= d then
			lo = mid
		else
			hi = mid
		end
	end
	local a, b = points[lo], points[lo + 1]
	local segment = cumulative[lo + 1] - cumulative[lo]
	local t = if segment > 0 then (d - cumulative[lo]) / segment else 0
	return a:Lerp(b, t), (b - a).Unit
end

-- Кратчайшее расстояние от точки (по XZ) до ломаной
function Path.DistanceTo(self: Path, position: Vector3): number
	local best = math.huge
	local p = Vector3.new(position.X, 0, position.Z)
	local points = self.Points
	for i = 1, #points - 1 do
		local a = Vector3.new(points[i].X, 0, points[i].Z)
		local b = Vector3.new(points[i + 1].X, 0, points[i + 1].Z)
		local ab = b - a
		local lengthSq = ab:Dot(ab)
		local t = if lengthSq > 0 then math.clamp((p - a):Dot(ab) / lengthSq, 0, 1) else 0
		local distance = (p - (a + ab * t)).Magnitude
		if distance < best then
			best = distance
		end
	end
	return best
end

return Path
