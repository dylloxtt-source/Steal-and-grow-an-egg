--[[
	Детерминированная раскладка декора карты. Один и тот же код (и seed) работает
	на сервере (строит модели) и на клиенте (проверка размещения башен заранее),
	поэтому «следы» препятствий совпадают без передачи по сети.
]]

local Config = script.Parent.Parent.Config
local Maps = require(Config.Maps)
local Path = require(script.Parent.Path)

local MapLayout = {}

export type Item = {
	Kind: string,
	Position: Vector3,
	Rotation: number,
	Scale: number,
	Radius: number,
	Seed: number,
}

export type Layout = {
	Map: any,
	Path: any,
	Items: { Item },
	Blockers: { { X: number, Z: number, R: number } },
}

local cache: { [string]: Layout } = {}

local function inRects(map: any, x: number, z: number, margin: number): boolean
	for _, rect in map.NoBuild do
		if x >= rect.Min.X - margin and x <= rect.Max.X + margin and z >= rect.Min.Y - margin and z <= rect.Max.Y + margin then
			return true
		end
	end
	return false
end

-- Ключевые объекты карты: портал, база и особые элементы (мост, крепость...)
local function fixedItems(map: any, path: any): { Item }
	local items = {}
	local first = map.Waypoints[1]
	local last = map.Waypoints[#map.Waypoints]
	table.insert(items, { Kind = "portal", Position = first, Rotation = 0, Scale = 1, Radius = 6, Seed = 1 })
	table.insert(items, { Kind = "base", Position = last, Rotation = 0, Scale = 1, Radius = 9, Seed = 2 })
	if map.Id == "greenfield" then
		table.insert(items, { Kind = "stream", Position = Vector3.new(20, 0, 0), Rotation = 0, Scale = 1, Radius = 0, Seed = 3 })
		table.insert(items, { Kind = "bridge", Position = Vector3.new(20, 0, -26), Rotation = 0, Scale = 1, Radius = 0, Seed = 4 })
	elseif map.Id == "snow" then
		table.insert(items, { Kind = "frozenStream", Position = Vector3.new(76, 0, 0), Rotation = 0, Scale = 1, Radius = 0, Seed = 3 })
		-- Стены крепости вокруг базы (проход открыт со стороны маршрута)
		for i, offset in { Vector3.new(-12, 0, 0), Vector3.new(0, 0, 11), Vector3.new(0, 0, -11) } do
			table.insert(items, { Kind = "fortWall", Position = last + offset, Rotation = if i == 1 then 90 else 0,
				Scale = 1, Radius = 0, Seed = 10 + i })
		end
	elseif map.Id == "neon" then
		table.insert(items, { Kind = "roadMarks", Position = Vector3.zero, Rotation = 0, Scale = 1, Radius = 0, Seed = 3 })
	end
	local _ = path
	return items
end

function MapLayout.Get(mapId: string): Layout
	if cache[mapId] then
		return cache[mapId]
	end
	local map = Maps.ById[mapId]
	assert(map, "Unknown map " .. tostring(mapId))
	local path = Path.new(map.Waypoints)
	local items = fixedItems(map, path)
	local blockers = {}
	for _, item in items do
		if item.Radius > 0 then
			table.insert(blockers, { X = item.Position.X, Z = item.Position.Z, R = item.Radius })
		end
	end
	-- Стены крепости — отрезки, их представляем цепочкой окружностей
	for _, item in items do
		if item.Kind == "fortWall" then
			local alongX = item.Rotation == 0
			for k = -4, 4 do
				local offset = if alongX then Vector3.new(k * 1.6, 0, 0) else Vector3.new(0, 0, k * 1.6)
				local p = item.Position + offset
				table.insert(blockers, { X = p.X, Z = p.Z, R = 1.4 })
			end
		end
	end

	local rng = Random.new(map.Seed)
	local half = map.Bounds
	local pathHalf = map.PathWidth / 2
	for specIndex, spec in map.Decor do
		local placed = 0
		local attempts = 0
		while placed < spec.Count and attempts < spec.Count * 40 do
			attempts += 1
			local x, z
			local pathDir = nil
			if spec.Zone == "edge" then
				-- полоса шириной 16 у края поля
				local side = rng:NextInteger(1, 4)
				if side <= 2 then
					x = rng:NextNumber(-half.X + 3, half.X - 3)
					z = (if side == 1 then 1 else -1) * rng:NextNumber(half.Y - 14, half.Y - 2)
				else
					z = rng:NextNumber(-half.Y + 3, half.Y - 3)
					x = (if side == 3 then 1 else -1) * rng:NextNumber(half.X - 14, half.X - 2)
				end
			elseif spec.Zone == "path" then
				-- рядом с дорогой (фонари, арки)
				local d = rng:NextNumber(10, path.Length - 10)
				local p, dir = path:At(d)
				local side = if rng:NextNumber() < 0.5 then -1 else 1
				local normal = Vector3.new(-dir.Z, 0, dir.X) * side
				pathDir = dir
				local gap = if spec.Kind == "arch" then 0 else pathHalf + 1.6
				x, z = p.X + normal.X * gap, p.Z + normal.Z * gap
			else
				x = rng:NextNumber(-half.X + 3, half.X - 3)
				z = rng:NextNumber(-half.Y + 3, half.Y - 3)
			end
			local position = Vector3.new(x, 0, z)
			local ok = true
			local distanceToPath = path:DistanceTo(position)
			if spec.Kind == "arch" then
				ok = distanceToPath < 0.5
			elseif spec.Zone == "path" then
				ok = distanceToPath > pathHalf + 0.8
			else
				ok = distanceToPath > pathHalf + spec.Radius + (spec.PathGap or 2)
			end
			if ok and (inRects(map, x, z, spec.Radius) and spec.Kind ~= "icePatch") then
				ok = false
			end
			if ok then
				for _, wp in { map.Waypoints[1], map.Waypoints[#map.Waypoints] } do
					if (Vector3.new(wp.X, 0, wp.Z) - position).Magnitude < 12 then
						ok = false
					end
				end
			end
			if ok then
				for _, blocker in blockers do
					local gap = math.max(spec.Radius, 0.6) + blocker.R + 0.5
					if (Vector3.new(blocker.X, 0, blocker.Z) - position).Magnitude < gap then
						ok = false
						break
					end
				end
			end
			if ok then
				placed += 1
				local item = {
					Kind = spec.Kind,
					Position = position,
					Rotation = rng:NextNumber(0, 360),
					Scale = rng:NextNumber(0.85, 1.25),
					Radius = spec.Radius,
					Seed = specIndex * 1000 + placed,
				}
				if spec.Kind == "arch" and pathDir then
					item.Rotation = math.deg(math.atan2(pathDir.X, pathDir.Z))
				end
				table.insert(items, item)
				if spec.Radius > 0 then
					table.insert(blockers, { X = x, Z = z, R = spec.Radius * item.Scale })
				end
			end
		end
	end

	local layout = { Map = map, Path = path, Items = items, Blockers = blockers }
	cache[mapId] = layout
	return layout
end

return MapLayout
