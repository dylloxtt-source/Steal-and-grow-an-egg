--[[
	Проверка размещения башни. Одна функция и для призрака на клиенте (мгновенная
	подсказка), и для сервера (окончательное решение). Карты плоские (Y = 0),
	поэтому проверка чисто геометрическая и не зависит от физики.
]]

local Config = script.Parent.Parent.Config
local Towers = require(Config.Towers)
local MapLayout = require(script.Parent.MapLayout)

local Placement = {}

Placement.Reasons = {
	Bounds = "Outside the play area",
	Path = "Can't place on the path",
	Blocked = "Blocked by an obstacle",
	Water = "Can't place on water or ice",
	Tower = "Too close to another tower",
	Base = "Too close to the base or portal",
}

-- towers: список { X, Z } уже стоящих башен (локальные координаты карты)
function Placement.Check(mapId: string, x: number, z: number, towers: { { X: number, Z: number } }): (boolean, string?)
	if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z then
		return false, Placement.Reasons.Bounds
	end
	local layout = MapLayout.Get(mapId)
	local map = layout.Map
	local r = Towers.Radius
	if math.abs(x) > map.Bounds.X - r or math.abs(z) > map.Bounds.Y - r then
		return false, Placement.Reasons.Bounds
	end
	local position = Vector3.new(x, 0, z)
	if layout.Path:DistanceTo(position) < map.PathWidth / 2 + r then
		return false, Placement.Reasons.Path
	end
	for _, rect in map.NoBuild do
		if x >= rect.Min.X - r and x <= rect.Max.X + r and z >= rect.Min.Y - r and z <= rect.Max.Y + r then
			return false, Placement.Reasons.Water
		end
	end
	local first, last = map.Waypoints[1], map.Waypoints[#map.Waypoints]
	if (Vector3.new(first.X, 0, first.Z) - position).Magnitude < 9 or (Vector3.new(last.X, 0, last.Z) - position).Magnitude < 11 then
		return false, Placement.Reasons.Base
	end
	for _, blocker in layout.Blockers do
		local dx, dz = blocker.X - x, blocker.Z - z
		if dx * dx + dz * dz < (blocker.R + r) ^ 2 then
			return false, Placement.Reasons.Blocked
		end
	end
	for _, tower in towers do
		local dx, dz = tower.X - x, tower.Z - z
		if dx * dx + dz * dz < (2 * r) ^ 2 then
			return false, Placement.Reasons.Tower
		end
	end
	return true, nil
end

return Placement
