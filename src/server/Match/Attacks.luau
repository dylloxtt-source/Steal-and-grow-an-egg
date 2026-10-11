--[[
	Атаки башен. Каждая функция получает башню и матч, сама выбирает цели
	(Logic/Targeting) и наносит урон через EnemySystem. Возвращает true, если атака
	состоялась (тогда башня уходит на перезарядку).

	Снаряды (стрелы, яд) не создают физических объектов на сервере: урон
	откладывается на время полёта, клиенту уходит визуальное событие.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Logic.Combat)
local Targeting = require(Shared.Logic.Targeting)

local Attacks = {}

local function pick(tower: any, match: any): any?
	local stats = tower.Stats
	return Targeting.Pick(match.Enemies.Alive, tower.Position, stats.Range, stats.Detect == true, tower.Priority)
end

local function pickMany(tower: any, match: any, count: number): { any }
	local stats = tower.Stats
	return Targeting.PickMany(match.Enemies.Alive, tower.Position, stats.Range, stats.Detect == true, tower.Priority, count)
end

local function hit(match: any, tower: any, enemy: any, damage: number)
	return match.Enemies:Damage(enemy, damage, tower.Stats.Pierce, tower)
end

local function face(tower: any, enemy: any)
	tower.TargetUid = enemy.Uid
end

-- Мечник: конус перед собой, несколько целей
function Attacks.melee(tower: any, match: any): boolean
	local primary = pick(tower, match)
	if not primary then
		return false
	end
	face(tower, primary)
	local stats = tower.Stats
	local forward = (primary.Position - tower.Position) * Vector3.new(1, 0, 1)
	forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.new(0, 0, -1)
	local cosHalf = math.cos(math.rad((stats.Arc or 120) / 2))
	local targets = {}
	for _, enemy in Targeting.PickMany(match.Enemies.Alive, tower.Position, stats.Range, stats.Detect == true, tower.Priority, 64) do
		local offset = (enemy.Position - tower.Position) * Vector3.new(1, 0, 1)
		if enemy == primary or (offset.Magnitude < 0.1 or forward:Dot(offset.Unit) >= cosHalf) then
			table.insert(targets, enemy)
			if #targets >= (stats.Targets or 1) then
				break
			end
		end
	end
	for _, enemy in targets do
		hit(match, tower, enemy, stats.Damage)
	end
	match:Fx({ k = "melee", t = tower.Uid, to = match:World(primary.Position), n = #targets })
	return true
end

-- Лучник: стрелы летят ProjectileSpeed, урон — по прилёту
function Attacks.arrow(tower: any, match: any): boolean
	local targets = pickMany(tower, match, tower.Stats.Targets or 1)
	if #targets == 0 then
		return false
	end
	face(tower, targets[1])
	local speed = tower.Def.ProjectileSpeed or 60
	for _, enemy in targets do
		local distance = (enemy.Position - tower.Position).Magnitude
		local flight = distance / speed
		match:Fx({ k = "arrow", t = tower.Uid, e = enemy.Uid, d = flight / match.TimeScale })
		match:Schedule(flight, function()
			if not enemy.Dead then
				hit(match, tower, enemy, tower.Stats.Damage)
			end
		end)
	end
	return true
end

-- Пистолет: мгновенный выстрел по одной цели
function Attacks.hitscan(tower: any, match: any): boolean
	local enemy = pick(tower, match)
	if not enemy then
		return false
	end
	face(tower, enemy)
	tower.Shots += 1
	hit(match, tower, enemy, tower.Stats.Damage)
	match:Fx({ k = "shot", t = tower.Uid, to = match:World(enemy.Position), w = "pistol", h = tower.Shots % 2 })
	return true
end

-- Пулемёт: раскрутка ускоряет стрельбу, пока есть цель
function Attacks.minigun(tower: any, match: any): boolean
	local enemy = pick(tower, match)
	if not enemy then
		tower.Spin = math.max(0, tower.Spin - 0.15)
		return false
	end
	face(tower, enemy)
	tower.Spin = math.min(tower.Stats.SpinMax or 0, tower.Spin + 0.06)
	hit(match, tower, enemy, tower.Stats.Damage)
	match:Fx({ k = "shot", t = tower.Uid, to = match:World(enemy.Position), w = "mg" })
	return true
end

-- Снайпер: мощный выстрел с пробитием брони
function Attacks.sniper(tower: any, match: any): boolean
	local enemy = pick(tower, match)
	if not enemy then
		return false
	end
	face(tower, enemy)
	hit(match, tower, enemy, tower.Stats.Damage)
	match:Fx({ k = "shot", t = tower.Uid, to = match:World(enemy.Position), w = "sniper" })
	return true
end

local function applyToxic(match: any, tower: any, enemy: any)
	local stats = tower.Stats
	local now = match.Time
	Combat.ApplyPoison(enemy, stats.Poison.Dps, stats.Poison.Duration, now)
	if stats.Slow then
		Combat.ApplySlow(enemy, stats.Slow.Factor, stats.Slow.Duration, now)
	end
end

-- Токсичный стрелок: снаряд + яд, облако на высоких уровнях
function Attacks.toxic(tower: any, match: any): boolean
	local enemy = pick(tower, match)
	if not enemy then
		return false
	end
	face(tower, enemy)
	local stats = tower.Stats
	local speed = tower.Def.ProjectileSpeed or 45
	local flight = (enemy.Position - tower.Position).Magnitude / speed
	match:Fx({ k = "toxic", t = tower.Uid, e = enemy.Uid, d = flight / match.TimeScale })
	match:Schedule(flight, function()
		local impact = enemy.Position
		if not enemy.Dead then
			hit(match, tower, enemy, stats.Damage)
			if not enemy.Dead then
				applyToxic(match, tower, enemy)
			end
		end
		if stats.Cloud then
			local r2 = stats.Cloud * stats.Cloud
			for _, other in table.clone(match.Enemies.Alive) do
				local delta = other.Position - impact
				if other ~= enemy and delta.X * delta.X + delta.Z * delta.Z <= r2 and (not other.Stealth or stats.Detect) then
					applyToxic(match, tower, other)
				end
			end
			match:Fx({ k = "cloud", at = match:World(impact), r = stats.Cloud })
		end
	end)
	return true
end

-- Дровосек: тяжёлый удар, на высоких уровнях — по области и с оглушением
function Attacks.axe(tower: any, match: any): boolean
	local primary = pick(tower, match)
	if not primary then
		return false
	end
	face(tower, primary)
	local stats = tower.Stats
	local targets = { primary }
	if stats.Splash then
		local r2 = stats.Splash * stats.Splash
		for _, enemy in match.Enemies.Alive do
			local delta = enemy.Position - primary.Position
			if enemy ~= primary and delta.X * delta.X + delta.Z * delta.Z <= r2 and (not enemy.Stealth or stats.Detect) then
				table.insert(targets, enemy)
			end
		end
	end
	for _, enemy in targets do
		hit(match, tower, enemy, stats.Damage)
		if stats.Stun and not enemy.Dead then
			Combat.ApplyStun(enemy, stats.Stun, match.Time)
		end
	end
	match:Fx({ k = "axe", t = tower.Uid, to = match:World(primary.Position), r = stats.Splash or 0 })
	return true
end

-- Росомаха: серия ударов когтями, «ярость» бьёт всех в радиусе
function Attacks.claws(tower: any, match: any): boolean
	local stats = tower.Stats
	tower.Attacks += 1
	local frenzy = stats.FrenzyEvery ~= nil and tower.Attacks % stats.FrenzyEvery == 0
	local targets = pickMany(tower, match, if frenzy then 64 else (stats.Targets or 1))
	if #targets == 0 then
		tower.Attacks -= 1
		return false
	end
	face(tower, targets[1])
	for _, enemy in targets do
		for _ = 1, stats.Hits or 1 do
			if not enemy.Dead then
				hit(match, tower, enemy, stats.Damage)
			end
		end
	end
	match:Fx({ k = "claws", t = tower.Uid, to = match:World(targets[1].Position), f = frenzy, n = stats.Hits or 1 })
	return true
end

return Attacks
