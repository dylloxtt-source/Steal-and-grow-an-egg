--[[
	Восемь башен. Каждая — R6 Dummy со своим оружием (см. Visual/TowerModel).

	Levels[1] — параметры при установке (Cost = цена установки),
	Levels[2..5] — улучшения (Cost = цена этого улучшения).
	Поля уровня:
	  Damage, Range, Cooldown — урон за удар, радиус, секунд между атаками
	  Targets      — сколько врагов задевает одна атака (мили/мультивыстрел)
	  Arc          — угол конуса удара (градусы) для мечника
	  Detect       — видит скрытных врагов (Stealth)
	  Pierce       — доля брони, которую игнорирует удар (0..1)
	  Splash       — радиус круговой атаки вокруг цели (дровосек)
	  Stun         — оглушение врага (сек), у боссов и элиты не работает
	  Poison       — { Dps, Duration } — яд (см. Logic/Combat: не суммируется бесконечно)
	  Cloud        — радиус ядовитого облака в точке попадания
	  Slow         — { Factor, Duration } — замедление
	  Hits         — ударов в серии (росомаха)
	  FrenzyEvery  — каждая N-я атака бьёт всех в радиусе
	  SpinMax      — максимальная прибавка к скорострельности при раскрутке (пулемёт)
	  Tier         — визуальный уровень снаряжения 1..3
]]

export type Level = {
	Cost: number,
	Damage: number,
	Range: number,
	Cooldown: number,
	Targets: number?,
	Arc: number?,
	Detect: boolean?,
	Pierce: number?,
	Splash: number?,
	Stun: number?,
	Poison: { Dps: number, Duration: number }?,
	Cloud: number?,
	Slow: { Factor: number, Duration: number }?,
	Hits: number?,
	FrenzyEvery: number?,
	SpinMax: number?,
	Tier: number,
	Text: string,
}

export type Tower = {
	Id: string,
	Name: string,
	Role: string,
	Description: string,
	Attack: string, -- "melee" | "arrow" | "hitscan" | "minigun" | "sniper" | "toxic" | "axe" | "claws"
	Icon: string,
	Accent: Color3,
	ProjectileSpeed: number?,
	Levels: { Level },
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { Tower } = {
	{
		Id = "swordsman", Name = "Swordsman", Role = "Ближний бой",
		Description = "Рубит врагов перед собой, задевая нескольких сразу. Дешёвый и надёжный на ранних волнах.",
		Attack = "melee", Icon = "⚔️", Accent = c(120, 170, 255),
		Levels = {
			{ Cost = 250, Damage = 12, Range = 7.5, Cooldown = 0.9, Targets = 2, Arc = 120, Tier = 1, Text = "Железный меч" },
			{ Cost = 200, Damage = 14, Range = 8, Cooldown = 0.85, Targets = 2, Arc = 120, Tier = 1, Text = "+урон, +дальность" },
			{ Cost = 450, Damage = 22, Range = 8.5, Cooldown = 0.8, Targets = 3, Arc = 140, Tier = 2, Text = "Стальной меч: 3 цели" },
			{ Cost = 900, Damage = 35, Range = 9, Cooldown = 0.75, Targets = 3, Arc = 150, Detect = true, Tier = 2, Text = "Видит скрытных" },
			{ Cost = 1800, Damage = 57, Range = 10, Cooldown = 0.7, Targets = 4, Arc = 170, Detect = true, Tier = 3, Text = "Сияющий клинок: 4 цели" },
		},
	},
	{
		Id = "archer", Name = "Archer", Role = "Дешёвая дальнобойная",
		Description = "Стреляет стрелами по одной цели, на поздних уровнях — сразу по нескольким.",
		Attack = "arrow", Icon = "🏹", Accent = c(110, 210, 110), ProjectileSpeed = 70,
		Levels = {
			{ Cost = 300, Damage = 16, Range = 17, Cooldown = 1.0, Tier = 1, Text = "Короткий лук" },
			{ Cost = 220, Damage = 21, Range = 19, Cooldown = 0.95, Tier = 1, Text = "+урон, +дальность" },
			{ Cost = 480, Damage = 25, Range = 21, Cooldown = 0.95, Detect = true, Tier = 2, Text = "Зоркий глаз: видит скрытных" },
			{ Cost = 950, Damage = 36, Range = 23, Cooldown = 0.9, Targets = 2, Detect = true, Tier = 2, Text = "Две стрелы за выстрел" },
			{ Cost = 1900, Damage = 52, Range = 25, Cooldown = 0.8, Targets = 3, Detect = true, Pierce = 0.3, Tier = 3, Text = "Три стрелы, пробивают броню" },
		},
	},
	{
		Id = "pistol", Name = "Pistol Shooter", Role = "Быстрая одиночная атака",
		Description = "Часто стреляет по одной цели. Хорош против быстрых и слабых врагов.",
		Attack = "hitscan", Icon = "🔫", Accent = c(255, 200, 80),
		Levels = {
			{ Cost = 400, Damage = 6, Range = 13, Cooldown = 0.33, Tier = 1, Text = "Пистолет" },
			{ Cost = 320, Damage = 9, Range = 14, Cooldown = 0.31, Tier = 1, Text = "+урон, +дальность" },
			{ Cost = 650, Damage = 13, Range = 15, Cooldown = 0.29, Tier = 2, Text = "Тяжёлые патроны" },
			{ Cost = 1250, Damage = 18, Range = 16, Cooldown = 0.27, Detect = true, Tier = 2, Text = "Фонарь: видит скрытных" },
			{ Cost = 2300, Damage = 27, Range = 17, Cooldown = 0.22, Detect = true, Tier = 3, Text = "Два пистолета" },
		},
	},
	{
		Id = "minigunner", Name = "Machine Gunner", Role = "Высокая скорострельность",
		Description = "Раскручивает пулемёт: чем дольше стреляет, тем быстрее. Слаб против брони.",
		Attack = "minigun", Icon = "💥", Accent = c(255, 120, 60),
		Levels = {
			{ Cost = 950, Damage = 5, Range = 14, Cooldown = 0.16, SpinMax = 0.6, Tier = 1, Text = "Ручной пулемёт" },
			{ Cost = 650, Damage = 6, Range = 15, Cooldown = 0.15, SpinMax = 0.7, Tier = 1, Text = "+урон, быстрее раскрутка" },
			{ Cost = 1300, Damage = 9, Range = 16, Cooldown = 0.13, SpinMax = 0.8, Tier = 2, Text = "Удлинённый ствол" },
			{ Cost = 2400, Damage = 12, Range = 17, Cooldown = 0.12, SpinMax = 1.0, Detect = true, Tier = 2, Text = "Тепловизор: видит скрытных" },
			{ Cost = 4300, Damage = 17, Range = 18, Cooldown = 0.1, SpinMax = 1.2, Detect = true, Pierce = 0.25, Tier = 3, Text = "Бронебойные ленты" },
		},
	},
	{
		Id = "sniper", Name = "Sniper", Role = "Дальний мощный выстрел",
		Description = "Огромная дальность и урон, медленная стрельба. Пробивает броню.",
		Attack = "sniper", Icon = "🎯", Accent = c(170, 140, 255),
		Levels = {
			{ Cost = 700, Damage = 62, Range = 34, Cooldown = 2.6, Pierce = 0.3, Tier = 1, Text = "Винтовка" },
			{ Cost = 550, Damage = 98, Range = 38, Cooldown = 2.5, Pierce = 0.4, Detect = true, Tier = 1, Text = "Прицел: видит скрытных" },
			{ Cost = 1100, Damage = 156, Range = 42, Cooldown = 2.35, Pierce = 0.5, Detect = true, Tier = 2, Text = "Крупный калибр" },
			{ Cost = 2200, Damage = 240, Range = 46, Cooldown = 2.2, Pierce = 0.65, Detect = true, Tier = 2, Text = "+урон, +пробитие" },
			{ Cost = 4000, Damage = 390, Range = 52, Cooldown = 2.0, Pierce = 0.85, Detect = true, Tier = 3, Text = "Антиматериальная винтовка" },
		},
	},
	{
		Id = "toxic", Name = "Toxic Shooter", Role = "Яд и ослабление",
		Description = "Отравляет: яд игнорирует броню и щиты. Позже — ядовитое облако и замедление.",
		Attack = "toxic", Icon = "☣️", Accent = c(120, 255, 90), ProjectileSpeed = 45,
		Levels = {
			{ Cost = 650, Damage = 4, Range = 14, Cooldown = 1.1, Poison = { Dps = 9, Duration = 4 }, Tier = 1, Text = "Распылитель" },
			{ Cost = 480, Damage = 5, Range = 15, Cooldown = 1.05, Poison = { Dps = 14, Duration = 4.5 }, Tier = 1, Text = "Крепкий яд" },
			{ Cost = 950, Damage = 6, Range = 16, Cooldown = 1.0, Poison = { Dps = 21, Duration = 5 }, Cloud = 4, Detect = true, Tier = 2, Text = "Ядовитое облако" },
			{ Cost = 1900, Damage = 9, Range = 17, Cooldown = 0.95, Poison = { Dps = 32, Duration = 5 }, Cloud = 5, Detect = true, Tier = 2, Text = "+яд, шире облако" },
			{ Cost = 3400, Damage = 13, Range = 18, Cooldown = 0.9, Poison = { Dps = 52, Duration = 6 }, Cloud = 6,
				Slow = { Factor = 0.2, Duration = 1.5 }, Detect = true, Tier = 3, Text = "Нейротоксин: замедляет на 20 %" },
		},
	},
	{
		Id = "lumberjack", Name = "Lumberjack", Role = "Тяжёлый ближний бой и контроль",
		Description = "Медленный, но мощный удар топором. Позже бьёт по области и оглушает.",
		Attack = "axe", Icon = "🪓", Accent = c(220, 90, 70),
		Levels = {
			{ Cost = 800, Damage = 39, Range = 7.5, Cooldown = 1.8, Tier = 1, Text = "Топор" },
			{ Cost = 580, Damage = 57, Range = 8, Cooldown = 1.7, Tier = 1, Text = "+урон" },
			{ Cost = 1150, Damage = 78, Range = 8.5, Cooldown = 1.65, Splash = 5, Tier = 2, Text = "Размах: бьёт всех рядом с целью" },
			{ Cost = 2200, Damage = 107, Range = 9, Cooldown = 1.6, Splash = 6, Stun = 0.6, Tier = 2, Text = "Оглушает" },
			{ Cost = 4100, Damage = 156, Range = 10, Cooldown = 1.5, Splash = 7, Stun = 0.9, Detect = true, Pierce = 0.4, Tier = 3, Text = "Двуручная секира" },
		},
	},
	{
		Id = "wolverine", Name = "Wolverine", Role = "Серии ударов когтями",
		Description = "Только R6-тело и когти. Очень быстрые серии ударов по ближайшим врагам.",
		Attack = "claws", Icon = "🐾", Accent = c(200, 200, 215),
		Levels = {
			{ Cost = 1000, Damage = 5, Range = 7, Cooldown = 0.8, Hits = 3, Targets = 1, Tier = 1, Text = "Когти" },
			{ Cost = 720, Damage = 8, Range = 7.5, Cooldown = 0.8, Hits = 3, Targets = 2, Tier = 1, Text = "Бьёт двоих" },
			{ Cost = 1450, Damage = 10, Range = 8, Cooldown = 0.75, Hits = 4, Targets = 2, Detect = true, Tier = 2, Text = "4 удара, чует скрытных" },
			{ Cost = 2700, Damage = 14, Range = 8.5, Cooldown = 0.7, Hits = 4, Targets = 2, FrenzyEvery = 4, Detect = true, Tier = 2, Text = "Ярость: каждая 4-я атака по всем" },
			{ Cost = 4600, Damage = 20, Range = 9, Cooldown = 0.6, Hits = 5, Targets = 3, FrenzyEvery = 3, Detect = true, Tier = 3, Text = "Адамантиевые когти" },
		},
	},
}

local byId: { [string]: Tower } = {}
for index, tower in list do
	assert(byId[tower.Id] == nil, "Duplicate tower " .. tower.Id)
	byId[tower.Id] = tower
	tower.Hotkey = index
end

local Towers = {
	List = list,
	ById = byId,
	MaxLevel = 5,
	Priorities = { "First", "Last", "Strongest", "Weakest" },
	Radius = 1.6, -- «следовая» окружность башни для размещения
}

-- Сколько всего потрачено на башню данного уровня
function Towers.TotalSpent(towerId: string, level: number): number
	local tower = byId[towerId]
	local total = 0
	for i = 1, math.min(level, #tower.Levels) do
		total += tower.Levels[i].Cost
	end
	return total
end

function Towers.Dps(level: Level): number
	local hits = (level.Hits or 1) * (level.Targets or 1)
	local dps = level.Damage * hits / level.Cooldown
	if level.Poison then
		dps += level.Poison.Dps
	end
	return dps
end

return Towers
