--[[
	Модульные тесты: конфиги (башни, враги, волны, карты, экономика), логика
	(маршрут, размещение, выбор цели, урон/яд/оглушение, профиль, форматирование),
	модели R6 (башни, враги, интеграция Dummy) и сетевой контракт.

	Запуск: lune run tests/unit.luau
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local Engine = require("./sim/Engine")

local Vector3 = roblox.Vector3
local Instance = roblox.Instance
local Color3 = roblox.Color3

local passed, failed = 0, 0
local failures = {}

local function check(name: string, condition: any, detail: any?)
	if condition then
		passed += 1
	else
		failed += 1
		local text = name .. (if detail ~= nil then "  —  " .. tostring(detail) else "")
		table.insert(failures, text)
		print("  ✘ " .. text)
	end
end

local function section(name: string)
	print("== " .. name)
end

local realm = Engine.Realm(true)
local Shared = Engine.SharedNode
local Towers = realm.require(Shared.Config.Towers)
local Enemies = realm.require(Shared.Config.Enemies)
local Waves = realm.require(Shared.Config.Waves)
local Maps = realm.require(Shared.Config.Maps)
local Economy = realm.require(Shared.Config.Economy)
local Sounds = realm.require(Shared.Config.Sounds)
local Path = realm.require(Shared.Logic.Path)
local MapLayout = realm.require(Shared.Logic.MapLayout)
local Placement = realm.require(Shared.Logic.Placement)
local Targeting = realm.require(Shared.Logic.Targeting)
local Combat = realm.require(Shared.Logic.Combat)
local Profile = realm.require(Shared.Logic.Profile)
local Format = realm.require(Shared.Logic.Format)
local Net = realm.require(Shared.Net)
local TowerModel = realm.require(Shared.Visual.TowerModel)
local EnemyModel = realm.require(Shared.Visual.EnemyModel)

------------------------------------------------------------------------
section("Башни")
------------------------------------------------------------------------

local REQUIRED_TOWERS = { "swordsman", "archer", "pistol", "minigunner", "sniper", "toxic", "lumberjack", "wolverine" }
check("ровно 8 башен", #Towers.List == 8, #Towers.List)
local attackKinds = {}
for _, id in REQUIRED_TOWERS do
	local def = Towers.ById[id]
	check("башня " .. id .. " есть", def ~= nil)
	if def then
		attackKinds[def.Attack] = true
		check(id .. ": описание, роль, иконка", #def.Description > 10 and #def.Role > 0 and #def.Icon > 0)
		check(id .. ": 5 уровней (установка + 4 улучшения)", #def.Levels == 5)
		local prevDps, prevRange = 0, 0
		for level, stats in def.Levels do
			check(string.format("%s L%d: стоимость/урон/радиус/перезарядка > 0", id, level),
				stats.Cost > 0 and stats.Damage > 0 and stats.Range > 0 and stats.Cooldown > 0)
			local dps = Towers.Dps(stats)
			check(string.format("%s L%d: урон в секунду растёт", id, level), dps > prevDps, string.format("%.1f -> %.1f", prevDps, dps))
			check(string.format("%s L%d: радиус не уменьшается", id, level), stats.Range >= prevRange)
			check(string.format("%s L%d: текст улучшения", id, level), type(stats.Text) == "string" and #stats.Text > 0)
			prevDps, prevRange = dps, stats.Range
		end
	end
end
local kinds = 0
for _ in attackKinds do
	kinds += 1
end
check("у всех 8 башен разные типы атаки", kinds == 8, kinds)
check("снайпер пробивает броню (отдельная механика)", Towers.ById.sniper.Levels[1].Pierce ~= nil and Towers.ById.sniper.Levels[1].Pierce > 0)
check("снайпер — самая большая дальность", (function()
	for _, def in Towers.List do
		if def.Id ~= "sniper" and def.Levels[5].Range >= Towers.ById.sniper.Levels[5].Range then
			return false
		end
	end
	return true
end)())
check("токсик: яд с ограничением + облако на высоком уровне", Towers.ById.toxic.Levels[1].Poison ~= nil and Towers.ById.toxic.Levels[5].Cloud ~= nil)
check("дровосек: область (L3) и оглушение (L4)", Towers.ById.lumberjack.Levels[3].Splash ~= nil and Towers.ById.lumberjack.Levels[4].Stun ~= nil)
check("пулемётчик: высокая скорострельность", Towers.ById.minigunner.Levels[1].Cooldown < Towers.ById.pistol.Levels[1].Cooldown)
check("лучник: несколько целей на высоком уровне", (Towers.ById.archer.Levels[5].Targets or 1) > 1)
check("кто-то видит скрытных уже на 2–3 уровне", (function()
	for _, def in Towers.List do
		for level = 1, 3 do
			if def.Levels[level].Detect then
				return true
			end
		end
	end
	return false
end)())
check("стартовых денег хватает на дешёвую башню", (function()
	for _, def in Towers.List do
		if def.Levels[1].Cost <= Economy.StartCash then
			return true
		end
	end
	return false
end)())
check("возврат при продаже 0..1", Economy.SellRefund > 0 and Economy.SellRefund < 1)
check("TotalSpent суммирует уровни", Towers.TotalSpent("archer", 3) == Towers.ById.archer.Levels[1].Cost + Towers.ById.archer.Levels[2].Cost + Towers.ById.archer.Levels[3].Cost)

------------------------------------------------------------------------
section("Враги")
------------------------------------------------------------------------

local REQUIRED_ENEMIES = { "basic", "runner", "tank", "armored", "regenerator", "shielded", "healer", "stealth", "elite" }
for _, id in REQUIRED_ENEMIES do
	check("враг " .. id .. " есть", Enemies.ById[id] ~= nil)
end
local bosses = 0
for _, def in Enemies.List do
	if def.Boss then
		bosses += 1
		check("босс " .. def.Id .. ": способности", #def.Abilities >= 1)
		check("босс " .. def.Id .. ": иммунитет к контролю", def.CcImmune == true)
	end
	check(def.Id .. ": здоровье/скорость/награда > 0", def.Health > 0 and def.Speed > 0 and def.Reward > 0 and def.Leak > 0)
	check(def.Id .. ": внешний вид R6 задан", def.Look and def.Look.Head and def.Look.Torso and def.Look.Legs)
end
check("минимум 10 типов врагов", #Enemies.List >= 10, #Enemies.List)
check("минимум один босс", bosses >= 1)
local E = Enemies.ById
local function hasAbility(def, kind)
	for _, ability in def.Abilities do
		if ability.Kind == kind then
			return true
		end
	end
	return false
end
check("бегун быстрее обычного", E.runner.Speed > E.basic.Speed * 1.4)
check("танк медленнее и крепче", E.tank.Speed < E.basic.Speed and E.tank.Health > E.basic.Health * 4)
check("бронированный — броня", E.armored.Armor > 0)
check("регенератор — регенерация", hasAbility(E.regenerator, "Regen"))
check("щитоносец — щит", E.shielded.Shield > 0)
check("лекарь — лечит союзников", hasAbility(E.healer, "Heal"))
check("скрытный — Stealth", E.stealth.Stealth == true)
check("элита — элитный и без оглушения", E.elite.Elite == true and E.elite.CcImmune == true)

------------------------------------------------------------------------
section("Волны")
------------------------------------------------------------------------

check("30 волн", Waves.Max == 30)
local prevHp = 0
local firstStealth = nil
for n = 1, 50 do
	local wave = Waves.Get(n)
	check("волна " .. n .. " собирается", wave and wave.Total > 0 and #wave.Groups > 0)
	for _, group in wave.Groups do
		check(string.format("волна %d: враг %s существует", n, group.Enemy), Enemies.ById[group.Enemy] ~= nil)
		if group.Enemy == "stealth" and not firstStealth then
			firstStealth = n
		end
	end
	check("волна " .. n .. ": здоровье растёт", wave.HealthMult >= prevHp)
	prevHp = wave.HealthMult
end
check("боссы на 10/20/30 волнах", Waves.Get(10).Boss and Waves.Get(20).Boss and Waves.Get(30).Boss)
check("элитные волны есть", (function()
	for n = 1, 30 do
		if Waves.Get(n).Elite then
			return true
		end
	end
	return false
end)())
check("скрытные появляются не с первых волн", firstStealth == nil or firstStealth >= 4, firstStealth)
check("волны 31–50 генерируются (расширение)", Waves.Get(45).Total > Waves.Get(30).Total * 0.5)

------------------------------------------------------------------------
section("Карты")
------------------------------------------------------------------------

check("5 карт", #Maps.List == 5)
local themes = {}
for _, map in Maps.List do
	themes[map.Theme] = true
	local layout = MapLayout.Get(map.Id)
	check(map.Id .. ": маршрут ≥ 3 точек", #map.Waypoints >= 3)
	local inside = true
	for _, p in map.Waypoints do
		if math.abs(p.X) > map.Bounds.X + 0.01 or math.abs(p.Z) > map.Bounds.Y + 0.01 or p.Y ~= 0 then
			inside = false
		end
	end
	check(map.Id .. ": маршрут в пределах поля", inside)
	check(map.Id .. ": длина маршрута разумная", layout.Path.Length > 150 and layout.Path.Length < 800, layout.Path.Length)
	local blocking = 0
	for _, item in layout.Items do
		if item.Radius > 0 and item.Kind ~= "portal" and item.Kind ~= "base" and item.Kind ~= "bridge" and item.Kind ~= "stream"
			and item.Kind ~= "frozenStream" and item.Kind ~= "roadMarks" then
			if layout.Path:DistanceTo(item.Position) < map.PathWidth / 2 + item.Radius * 0.5 then
				blocking += 1
			end
		end
	end
	check(map.Id .. ": декор не перекрывает дорогу", blocking == 0, blocking)
	local spots = 0
	for x = -map.Bounds.X, map.Bounds.X, 3 do
		for z = -map.Bounds.Y, map.Bounds.Y, 3 do
			if Placement.Check(map.Id, x, z, {}) and layout.Path:DistanceTo(Vector3.new(x, 0, z)) <= 12 then
				spots += 1
			end
		end
	end
	check(map.Id .. ": достаточно мест для башен у дороги", spots >= 60, spots)
	check(map.Id .. ": точка появления игрока в поле", math.abs(map.PlayerSpawn.X) <= map.Bounds.X and math.abs(map.PlayerSpawn.Z) <= map.Bounds.Y)
	check(map.Id .. ": камера и освещение заданы", map.Camera and map.Lighting and map.Lighting.ClockTime ~= nil)
	check(map.Id .. ": детерминированная раскладка", #MapLayout.Get(map.Id).Items == #layout.Items)
end
local themeCount = 0
for _ in themes do
	themeCount += 1
end
check("у карт разные темы", themeCount == 5)

-- Физика карты (эмулятор её не симулирует, проверяем настройки деталей)
local MapBuilder = realm.require(Engine.ServerNode.Match.MapBuilder)
for _, map in Maps.List do
	local container = Instance.new("Folder")
	local folder = MapBuilder.Build(map.Id, Vector3.new(0, 0, 0), container)
	local groundSolid, grounds, walls = true, 0, 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Ground" then
				grounds += 1
				groundSolid = groundSolid and d.CanCollide and d.Anchored
			elseif d.Name == "Boundary" then
				walls += 1
			end
		end
	end
	check(map.Id .. ": земля твёрдая и закреплена (персонаж не провалится)", grounds > 0 and groundSolid)
	check(map.Id .. ": невидимые стены по краю поля", walls == 4)
end

------------------------------------------------------------------------
section("Маршрут и размещение")
------------------------------------------------------------------------

local path = Path.new({ Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 0, 10) })
check("длина маршрута", math.abs(path.Length - 20) < 1e-6)
check("At(0) — начало", (path:At(0) - Vector3.new(0, 0, 0)).Magnitude < 1e-6)
check("At(15) — на втором отрезке", (path:At(15) - Vector3.new(10, 0, 5)).Magnitude < 1e-6)
check("At(>длины) — конец", (path:At(99) - Vector3.new(10, 0, 10)).Magnitude < 1e-6)
local _, dir = path:At(5)
check("направление по отрезку", (dir - Vector3.new(1, 0, 0)).Magnitude < 1e-6)
check("расстояние до маршрута", math.abs(path:DistanceTo(Vector3.new(5, 0, 3)) - 3) < 1e-6)

local green = Maps.ById.greenfield
local greenPath = MapLayout.Get("greenfield").Path
local onRoad = greenPath:At(40)
local ok, reason = Placement.Check("greenfield", onRoad.X, onRoad.Z, {})
check("на дороге нельзя", not ok and reason == Placement.Reasons.Path, reason)
ok, reason = Placement.Check("greenfield", green.Bounds.X + 5, 0, {})
check("за краем нельзя", not ok and reason == Placement.Reasons.Bounds, reason)
ok, reason = Placement.Check("greenfield", 20, 50, {})
check("в ручье нельзя", not ok and (reason == Placement.Reasons.Water or reason == Placement.Reasons.Path), reason)
ok, reason = Placement.Check("greenfield", 0 / 0, 0, {})
check("NaN нельзя", not ok)
local free = nil
for x = -60, 60, 2 do
	for z = -50, 50, 2 do
		if not free and Placement.Check("greenfield", x, z, {}) then
			free = Vector3.new(x, 0, z)
		end
	end
end
check("свободная точка найдена", free ~= nil)
ok, reason = Placement.Check("greenfield", free.X + 1, free.Z, { { X = free.X, Z = free.Z } })
check("вплотную к башне нельзя", not ok and reason == Placement.Reasons.Tower, reason)

------------------------------------------------------------------------
section("Выбор цели")
------------------------------------------------------------------------

local function enemy(progress, health, x, extra)
	local e = { Progress = progress, Health = health, Shield = 0, Position = Vector3.new(x, 0, 0), Stealth = false, Dead = false }
	for k, v in extra or {} do
		e[k] = v
	end
	return e
end
local list = {
	enemy(10, 100, 1), enemy(30, 20, 2), enemy(20, 300, 3), enemy(5, 50, 4),
	enemy(50, 999, 50), -- вне радиуса
	enemy(60, 10, 1, { Stealth = true }),
	enemy(70, 10, 1, { Dead = true }),
}
local origin = Vector3.new(0, 0, 0)
check("First — дальше всех по маршруту", Targeting.Pick(list, origin, 10, false, "First") == list[2])
check("Last — меньше всех прошёл", Targeting.Pick(list, origin, 10, false, "Last") == list[4])
check("Strongest — больше всего здоровья", Targeting.Pick(list, origin, 10, false, "Strongest") == list[3])
check("Weakest — меньше всего здоровья", Targeting.Pick(list, origin, 10, false, "Weakest") == list[2])
check("скрытный виден только с обнаружением", Targeting.Pick(list, origin, 10, true, "First") == list[6])
check("мёртвые и дальние игнорируются", Targeting.Pick({ list[5], list[7] }, origin, 10, true, "First") == nil)
local many = Targeting.PickMany(list, origin, 10, false, "First", 2)
check("PickMany: 2 цели по приоритету", #many == 2 and many[1] == list[2] and many[2] == list[3])
local shielded = { enemy(1, 10, 1, { Shield = 500 }), enemy(2, 100, 1) }
check("Strongest учитывает щит", Targeting.Pick(shielded, origin, 10, false, "Strongest") == shielded[1])

------------------------------------------------------------------------
section("Урон, яд, оглушение")
------------------------------------------------------------------------

local function target(extra)
	local t = { Health = 100, MaxHealth = 100, Shield = 0, Armor = 0, CcImmune = false, PoisonDps = 0, PoisonUntil = 0,
		SlowFactor = 0, SlowUntil = 0, StunUntil = 0, StunImmuneUntil = 0, LastHit = 0 }
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end
check("броня снижает урон", Combat.Mitigate(10, 3) == 7)
check("минимум 20 % урона", Combat.Mitigate(10, 50) == 2)
check("пробитие игнорирует броню", Combat.Mitigate(10, 4, 0.5) == 8)
local t = target({ Shield = 30 })
local dealt = Combat.Hit(t, 50, 0, 0)
check("щит поглощает, излишек — в здоровье", t.Shield == 0 and t.Health == 80 and dealt == 50)
t = target({ Health = 5 })
check("урон не больше остатка здоровья", Combat.Hit(t, 50, 0, 0) == 5 and t.Health == 0)
check("мёртвому урон не наносится", Combat.Hit(t, 50, 0, 0) == 0)

t = target({ Health = 10000, MaxHealth = 10000, Armor = 50, Shield = 1000 })
for i = 1, 50 do
	Combat.ApplyPoison(t, 10, 3, i * 0.1)
end
check("яд не суммируется (DPS не растёт от повторов)", t.PoisonDps == 10)
check("длительность яда ограничена (не копится)", t.PoisonUntil <= 5 * 1 + 3 + 1e-9, t.PoisonUntil)
Combat.ApplyPoison(t, 25, 2, 5)
check("сильный яд заменяет слабый", t.PoisonDps == 25)
local total = 0
local now = 5
for _ = 1, 100 do
	now += 0.1
	total += Combat.TickPoison(t, 0.1, now)
end
check("яд игнорирует щит и броню и заканчивается", t.Shield == 1000 and total > 0 and t.PoisonDps == 0, total)
check("урон яда ограничен временем действия", total <= 25 * 3.1 + 10 * 0.1, total)

t = target()
check("оглушение срабатывает", Combat.ApplyStun(t, 1, 0) and Combat.SpeedFactor(t, 0.5) == 0)
check("повторное оглушение сразу — нельзя (иммунитет)", not Combat.ApplyStun(t, 1, 1.2))
check("после иммунитета — снова можно", Combat.ApplyStun(t, 1, 1 + Combat.StunImmunity + 0.01))
check("элита/боссы не оглушаются", not Combat.ApplyStun(target({ CcImmune = true }), 1, 0))
t = target()
Combat.ApplySlow(t, 0.3, 2, 0)
Combat.ApplySlow(t, 0.1, 5, 0)
check("замедление: берётся сильнейшее", t.SlowFactor == 0.3 and math.abs(Combat.SpeedFactor(t, 1) - 0.7) < 1e-9)
t = target({ Health = 50 })
Combat.Heal(t, 80)
check("лечение не выше максимума", t.Health == 100)

------------------------------------------------------------------------
section("Профиль и форматирование")
------------------------------------------------------------------------

local default = Profile.Default()
check("профиль по умолчанию", default.gems == 0 and default.level == 1 and default.stats.matches == 0)
for _, junk in { nil, 5, "x", { gems = "много", level = -3, stats = 7, bestWave = { fake_map = 3, greenfield = "x" } } } do
	local fixed = Profile.Reconcile(junk)
	check("Reconcile чинит повреждённые данные: " .. typeof(junk), fixed.gems == 0 and fixed.level >= 1 and type(fixed.stats) == "table"
		and fixed.bestWave.fake_map == nil and fixed.owned.swordsman == true and fixed.loadout[1] == "swordsman"
		and type(fixed.settings) == "table" and fixed.settings.autoSkip == false)
end
check("новый игрок владеет только мечником", (function()
	local count = 0
	for _ in default.owned do
		count += 1
	end
	return count == 1 and default.owned.swordsman == true and #default.loadout == 1 and default.loadout[1] == "swordsman"
end)())
check("стартовая башня бесплатна, остальные стоят гемов", (function()
	for _, def in Towers.List do
		if (def.Id == Towers.Starter) ~= (def.Price == 0) or not def.Rarity then
			return false
		end
	end
	return true
end)())
local migrated = Profile.Reconcile({ version = 1, gems = 500, level = 4, xp = 10, unlocked = { archer = true, wolverine = true },
	stats = { matches = 3, wins = 1, losses = 2, kills = 50, wavesCleared = 20 }, bestWave = { greenfield = 12 } })
check("перенос профиля v1: прогресс сохранён, башни — только стартовая", migrated.gems == 500 and migrated.level == 4
	and migrated.stats.wins == 1 and migrated.bestWave.greenfield == 12 and migrated.owned.wolverine == nil
	and migrated.unlocked == nil and migrated.version == 2)
local bad = Profile.Reconcile({ version = 2, owned = { archer = true, dragon = true, sniper = "yes" }, loadout = { "sniper", "archer", "archer", "dragon", 5 },
	settings = { autoSkip = "on", hack = true } })
check("Reconcile: набор только из купленных, без дублей", #bad.loadout == 1 and bad.loadout[1] == "archer" and bad.owned.dragon == nil
	and bad.owned.sniper == nil and bad.owned.swordsman == true)
check("Reconcile: неизвестные/неверные настройки убраны", bad.settings.hack == nil and bad.settings.autoSkip == false)

local shop = Profile.Default()
local okBuy, why = Profile.Buy(shop, "archer")
check("нельзя купить без гемов", not okBuy and why ~= nil and shop.owned.archer == nil, why)
shop.gems = Towers.ById.archer.Price + 10
okBuy = Profile.Buy(shop, "archer")
check("покупка списывает гемы и добавляет в набор", okBuy and shop.gems == 10 and shop.owned.archer and table.find(shop.loadout, "archer") ~= nil)
check("повторная покупка невозможна", not (Profile.Buy(shop, "archer")) and shop.gems == 10)
check("неизвестную башню купить нельзя", not (Profile.Buy(shop, "dragon")))
check("нельзя взять некупленную башню", not (Profile.Equip(shop, "wolverine")))
check("снять башню из набора", (Profile.Unequip(shop, "archer")) and table.find(shop.loadout, "archer") == nil)
check("последнюю башню снять нельзя", not (Profile.Unequip(shop, "swordsman")) and #shop.loadout == 1)
check("взять башню в слот", (Profile.Equip(shop, "archer", 1)) and shop.loadout[1] == "archer")
for _, def in Towers.List do
	shop.owned[def.Id] = true
end
shop.loadout = { "swordsman" }
for _, id in { "archer", "pistol", "sniper", "toxic" } do
	Profile.Equip(shop, id)
end
check("набор ограничен " .. Towers.LoadoutSize .. " башнями", #shop.loadout == Towers.LoadoutSize and not (Profile.Equip(shop, "wolverine")))
check("замена башни в занятом слоте", (Profile.Equip(shop, "wolverine", 2)) and shop.loadout[2] == "wolverine"
	and #shop.loadout == Towers.LoadoutSize and table.find(shop.loadout, "archer") == nil)
check("неверный слот отклонён", not (Profile.Equip(shop, "archer", 9)) and not (Profile.Equip(shop, "archer", 1.5)))
local p = Profile.Default()
local gained = Profile.AddXp(p, Economy.Xp.PerLevel(1) + 5)
check("опыт повышает уровень", gained == 1 and p.level == 2 and p.xp == 5)
check("Format.Number", Format.Number(950) == "950" and Format.Number(1500) == "1.5K" and Format.Number(2000000) == "2M")
check("Format.Time", Format.Time(5) == "0:05" and Format.Time(65) == "1:05")
check("Format.Cash", Format.Cash(800) == "$800" and Format.Cash(1250) == "$1,250" and Format.Cash(99999) == "$99,999"
	and Format.Cash(250000) == "$250K" and Format.Cash(-1500) == "-$1,500", Format.Cash(1250))

------------------------------------------------------------------------
section("Модели R6")
------------------------------------------------------------------------

local R6_PARTS = { "HumanoidRootPart", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local function isR6(model): (boolean, string?)
	for _, name in R6_PARTS do
		if not model:FindFirstChild(name) then
			return false, "нет " .. name
		end
	end
	local motors = 0
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors += 1
		end
	end
	local torso = model:FindFirstChild("Torso")
	if torso.Size ~= Vector3.new(2, 2, 1) then
		return false, "размер торса " .. tostring(torso.Size)
	end
	return motors >= 6, "Motor6D: " .. motors
end
for _, def in Towers.List do
	for level = 1, 5 do
		local okBuild, model = pcall(TowerModel.Build, def.Id, level)
		check(string.format("модель башни %s L%d собирается", def.Id, level), okBuild, model)
		if okBuild then
			local r6, why = isR6(model)
			check(string.format("модель %s L%d — R6", def.Id, level), r6, why)
			local scripts = 0
			for _, d in model:GetDescendants() do
				if d:IsA("LuaSourceContainer") then
					scripts += 1
				end
			end
			check(string.format("модель %s L%d без скриптов", def.Id, level), scripts == 0)
		end
	end
end
-- Росомаха: только тело R6 и когти (без костюма, маски, брони, аксессуаров)
local wolverine = TowerModel.Build("wolverine", 5)
local allowed = { Pedestal = true, ClawsRight = true, ClawsLeft = true }
for _, name in R6_PARTS do
	allowed[name] = true
end
local extra = {}
for _, child in wolverine:GetChildren() do
	if (child:IsA("BasePart") or child:IsA("Model") or child:IsA("Accoutrement") or child:IsA("Clothing")) and not allowed[child.Name] then
		table.insert(extra, child.Name)
	end
end
check("Росомаха: только тело R6 + когти, без скина", #extra == 0, table.concat(extra, ","))
check("Росомаха: цвета референса (жёлтая кожа, синий торс, зелёные ноги)",
	wolverine.Head.Color == Color3.fromRGB(245, 205, 48) and wolverine.Torso.Color == Color3.fromRGB(13, 105, 172)
		and wolverine["Left Leg"].Color == Color3.fromRGB(164, 189, 71))
check("Росомаха: когти на обеих руках", wolverine:FindFirstChild("ClawsRight") ~= nil and wolverine:FindFirstChild("ClawsLeft") ~= nil)

for _, def in Enemies.List do
	local okBuild, model = pcall(EnemyModel.Build, def.Id)
	check("модель врага " .. def.Id .. " собирается", okBuild, model)
	if okBuild then
		local r6, why = isR6(model)
		check("модель врага " .. def.Id .. " — R6", r6, why)
	end
end

-- Интеграция пользовательского Dummy: скрипты, одежда и аксессуары отбрасываются
do
	local assets = Instance.new("Folder")
	assets.Name = "Assets"
	local dummy = TowerModel.Build("swordsman", 1)
	dummy.Name = "R6Dummy"
	for _, child in dummy:GetChildren() do
		if not table.find(R6_PARTS, child.Name) and not child:IsA("Humanoid") then
			child.Parent = nil
		end
	end
	local script = Instance.new("Script")
	script.Parent = dummy
	local shirt = Instance.new("Shirt")
	shirt.Parent = dummy
	local hat = Instance.new("Accessory")
	hat.Parent = dummy
	local colors = Instance.new("BodyColors")
	colors.Parent = dummy
	dummy.Parent = assets
	assets.Parent = Engine.ReplicatedStorage
	local built = TowerModel.Build("wolverine", 1)
	local junkLeft = {}
	for _, d in built:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Clothing") or d:IsA("Accoutrement") or d:IsA("BodyColors") then
			table.insert(junkLeft, d.ClassName)
		end
	end
	check("Dummy пользователя: скрипты/одежда/аксессуары удалены", #junkLeft == 0, table.concat(junkLeft, ","))
	check("Dummy пользователя: модель R6 с когтями", isR6(built) and built:FindFirstChild("ClawsRight") ~= nil)
	assets.Parent = nil
end

------------------------------------------------------------------------
section("Звуки, анимации, ассеты")
------------------------------------------------------------------------

local badSounds = {}
for key, id in Sounds do
	if id ~= "" and string.sub(id, 1, 18) ~= "rbxasset://sounds/" then
		table.insert(badSounds, key)
	end
end
check("звуки: только встроенные rbxasset или пустые места", #badSounds == 0, table.concat(badSounds, ","))
local idHits = {}
local function scan(dir)
	for _, name in fs.readDir(dir) do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			scan(full)
		elseif string.match(name, "%.luau$") then
			local source = fs.readFile(full)
			if string.find(source, "rbxassetid://%d") or string.find(source, "AnimationId") then
				table.insert(idHits, full)
			end
		end
	end
end
scan("src")
check("в коде нет выдуманных asset/animation ID", #idHits == 0, table.concat(idHits, ","))

-- Игра на английском: в строках кода (не в комментариях) нет кириллицы
local cyrillic = {}
local function scanText(dir)
	for _, name in fs.readDir(dir) do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			scanText(full)
		elseif string.match(name, "%.luau$") then
			local inBlock = false
			local lineNo = 0
			for line in string.gmatch(fs.readFile(full) .. "\n", "(.-)\n") do
				lineNo += 1
				if inBlock then
					if string.find(line, "]]", 1, true) then
						inBlock = false
					end
				elseif string.match(line, "^%s*%-%-%[%[") then
					inBlock = not string.find(line, "]]", 1, true)
				else
					local code = string.match(line, "^(.-)%-%-") or line
					for text in string.gmatch(code, '"([^"]*)"') do
						-- кириллица в UTF-8: первый байт 0xD0 или 0xD1
						if string.find(text, "[\208\209][\128-\191]") then
							table.insert(cyrillic, full .. ":" .. lineNo)
						end
					end
				end
			end
		end
	end
end
scanText("src")
check("весь текст игры на английском", #cyrillic == 0, table.concat(cyrillic, ", "))

------------------------------------------------------------------------
section("Сетевой контракт")
------------------------------------------------------------------------

local server = Engine.Realm(true)
server.require(Engine.ServerNode)
local player = Engine.NewPlayer("Contract")
Engine.Join(player)
Engine.SpawnCharacter(player, Vector3.new(0, 3, 40))
task.wait(0.3)
for name in Net.Actions do
	local result = Engine.InvokeAs(player, name, nil)
	check("действие " .. name .. " обрабатывается сервером", type(result) == "table" and result.message ~= "Неизвестное действие", result.message)
end
for _, name in Net.Events do
	check("событие " .. name .. " создано при старте", Engine.ReplicatedStorage.Remotes:FindFirstChild(name) ~= nil)
end

print(string.format("\nИТОГО: %d проверок пройдено, %d провалено", passed, failed))
for _, text in failures do
	print("  ✘ " .. text)
end
process.exit(if failed == 0 then 0 else 1)
