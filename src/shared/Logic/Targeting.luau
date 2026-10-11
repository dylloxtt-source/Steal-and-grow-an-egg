--[[
	Выбор цели по приоритету. Прогресс врага — пройденная дистанция по маршруту,
	поэтому First действительно выбирает самого продвинувшегося, а не ближайшего.
]]

local Targeting = {}

export type Candidate = {
	Progress: number,
	Health: number,
	Shield: number,
	Position: Vector3,
	Stealth: boolean,
	Dead: boolean,
}

-- Подходит ли враг башне: жив, в радиусе (по XZ), видим
function Targeting.InRange(towerPosition: Vector3, range: number, enemy: Candidate, detect: boolean): boolean
	if enemy.Dead or (enemy.Stealth and not detect) then
		return false
	end
	local dx = enemy.Position.X - towerPosition.X
	local dz = enemy.Position.Z - towerPosition.Z
	return dx * dx + dz * dz <= range * range
end

local function better(priority: string, a: Candidate, b: Candidate): boolean
	if priority == "Last" then
		return a.Progress < b.Progress
	elseif priority == "Strongest" then
		local ha, hb = a.Health + a.Shield, b.Health + b.Shield
		if ha ~= hb then
			return ha > hb
		end
		return a.Progress > b.Progress
	elseif priority == "Weakest" then
		local ha, hb = a.Health + a.Shield, b.Health + b.Shield
		if ha ~= hb then
			return ha < hb
		end
		return a.Progress > b.Progress
	end
	return a.Progress > b.Progress -- First
end

-- Лучшая цель из списка врагов (или nil)
function Targeting.Pick<T>(enemies: { T }, towerPosition: Vector3, range: number, detect: boolean, priority: string): T?
	local best = nil
	for _, enemy in enemies do
		local candidate = enemy :: any
		if Targeting.InRange(towerPosition, range, candidate, detect) and (best == nil or better(priority, candidate, best)) then
			best = candidate
		end
	end
	return best
end

-- До count целей, отсортированных по приоритету
function Targeting.PickMany<T>(enemies: { T }, towerPosition: Vector3, range: number, detect: boolean, priority: string, count: number): { T }
	local list = {}
	for _, enemy in enemies do
		if Targeting.InRange(towerPosition, range, enemy :: any, detect) then
			table.insert(list, enemy)
		end
	end
	table.sort(list, function(a, b)
		return better(priority, a :: any, b :: any)
	end)
	while #list > count do
		table.remove(list)
	end
	return list
end

return Targeting
