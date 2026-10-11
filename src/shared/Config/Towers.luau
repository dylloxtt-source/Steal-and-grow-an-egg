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
	Price: number, -- цена в гемах в магазине (0 — стартовая, есть у всех)
	Rarity: string,
	ProjectileSpeed: number?,
	Levels: { Level },
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { Tower } = {
	{
		Id = "swordsman", Name = "Swordsman", Role = "Melee",
		Description = "Slashes enemies in front of him, hitting several at once. Cheap and reliable in the early waves.",
		Price = 0, Rarity = "Starter",
		Attack = "melee", Icon = "⚔️", Accent = c(120, 170, 255),
		Levels = {
			{ Cost = 250, Damage = 12, Range = 7.5, Cooldown = 0.9, Targets = 2, Arc = 120, Tier = 1, Text = "Iron Sword" },
			{ Cost = 200, Damage = 14, Range = 8, Cooldown = 0.85, Targets = 2, Arc = 120, Tier = 1, Text = "+damage, +range" },
			{ Cost = 450, Damage = 22, Range = 8.5, Cooldown = 0.8, Targets = 3, Arc = 140, Tier = 2, Text = "Steel Sword: 3 targets" },
			{ Cost = 900, Damage = 35, Range = 9, Cooldown = 0.75, Targets = 3, Arc = 150, Detect = true, Tier = 2, Text = "Sees hidden enemies" },
			{ Cost = 1800, Damage = 57, Range = 10, Cooldown = 0.7, Targets = 4, Arc = 170, Detect = true, Tier = 3, Text = "Radiant Blade: 4 targets" },
		},
	},
	{
		Id = "archer", Name = "Archer", Role = "Cheap ranged",
		Description = "Fires arrows at a single target, and at several targets at higher levels.",
		Price = 50, Rarity = "Common",
		Attack = "arrow", Icon = "🏹", Accent = c(110, 210, 110), ProjectileSpeed = 70,
		Levels = {
			{ Cost = 300, Damage = 16, Range = 17, Cooldown = 1.0, Tier = 1, Text = "Short Bow" },
			{ Cost = 220, Damage = 21, Range = 19, Cooldown = 0.95, Tier = 1, Text = "+damage, +range" },
			{ Cost = 480, Damage = 25, Range = 21, Cooldown = 0.95, Detect = true, Tier = 2, Text = "Eagle Eye: sees hidden" },
			{ Cost = 950, Damage = 36, Range = 23, Cooldown = 0.9, Targets = 2, Detect = true, Tier = 2, Text = "Two arrows per shot" },
			{ Cost = 1900, Damage = 52, Range = 25, Cooldown = 0.8, Targets = 3, Detect = true, Pierce = 0.3, Tier = 3, Text = "Three armor-piercing arrows" },
		},
	},
	{
		Id = "pistol", Name = "Pistol Shooter", Role = "Fast single target",
		Description = "Shoots one target very often. Great against fast and weak enemies.",
		Price = 250, Rarity = "Common",
		Attack = "hitscan", Icon = "🔫", Accent = c(255, 200, 80),
		Levels = {
			{ Cost = 400, Damage = 6, Range = 13, Cooldown = 0.33, Tier = 1, Text = "Pistol" },
			{ Cost = 320, Damage = 9, Range = 14, Cooldown = 0.31, Tier = 1, Text = "+damage, +range" },
			{ Cost = 650, Damage = 13, Range = 15, Cooldown = 0.29, Tier = 2, Text = "Heavy Rounds" },
			{ Cost = 1250, Damage = 18, Range = 16, Cooldown = 0.27, Detect = true, Tier = 2, Text = "Flashlight: sees hidden" },
			{ Cost = 2300, Damage = 27, Range = 17, Cooldown = 0.22, Detect = true, Tier = 3, Text = "Dual Pistols" },
		},
	},
	{
		Id = "minigunner", Name = "Machine Gunner", Role = "High fire rate",
		Description = "Spins up the gun: the longer it fires, the faster it shoots. Weak against armor.",
		Price = 1300, Rarity = "Epic",
		Attack = "minigun", Icon = "💥", Accent = c(255, 120, 60),
		Levels = {
			{ Cost = 950, Damage = 5, Range = 14, Cooldown = 0.16, SpinMax = 0.6, Tier = 1, Text = "Light Machine Gun" },
			{ Cost = 650, Damage = 6, Range = 15, Cooldown = 0.15, SpinMax = 0.7, Tier = 1, Text = "+damage, faster spin-up" },
			{ Cost = 1300, Damage = 9, Range = 16, Cooldown = 0.13, SpinMax = 0.8, Tier = 2, Text = "Extended Barrel" },
			{ Cost = 2400, Damage = 12, Range = 17, Cooldown = 0.12, SpinMax = 1.0, Detect = true, Tier = 2, Text = "Thermal Scope: sees hidden" },
			{ Cost = 4300, Damage = 17, Range = 18, Cooldown = 0.1, SpinMax = 1.2, Detect = true, Pierce = 0.25, Tier = 3, Text = "Armor-Piercing Belts" },
		},
	},
	{
		Id = "sniper", Name = "Sniper", Role = "Long-range power shot",
		Description = "Huge range and damage, slow fire rate. Pierces armor.",
		Price = 700, Rarity = "Rare",
		Attack = "sniper", Icon = "🎯", Accent = c(170, 140, 255),
		Levels = {
			{ Cost = 700, Damage = 62, Range = 34, Cooldown = 2.6, Pierce = 0.3, Tier = 1, Text = "Rifle" },
			{ Cost = 550, Damage = 98, Range = 38, Cooldown = 2.5, Pierce = 0.4, Detect = true, Tier = 1, Text = "Scope: sees hidden" },
			{ Cost = 1100, Damage = 156, Range = 42, Cooldown = 2.35, Pierce = 0.5, Detect = true, Tier = 2, Text = "Heavy Caliber" },
			{ Cost = 2200, Damage = 240, Range = 46, Cooldown = 2.2, Pierce = 0.65, Detect = true, Tier = 2, Text = "+damage, +pierce" },
			{ Cost = 4000, Damage = 390, Range = 52, Cooldown = 2.0, Pierce = 0.85, Detect = true, Tier = 3, Text = "Anti-Materiel Rifle" },
		},
	},
	{
		Id = "toxic", Name = "Toxic Shooter", Role = "Poison and debuffs",
		Description = "Poisons enemies: poison ignores armor and shields. Later adds a toxic cloud and a slow.",
		Price = 450, Rarity = "Uncommon",
		Attack = "toxic", Icon = "☣️", Accent = c(120, 255, 90), ProjectileSpeed = 45,
		Levels = {
			{ Cost = 650, Damage = 4, Range = 14, Cooldown = 1.1, Poison = { Dps = 9, Duration = 4 }, Tier = 1, Text = "Sprayer" },
			{ Cost = 480, Damage = 5, Range = 15, Cooldown = 1.05, Poison = { Dps = 14, Duration = 4.5 }, Tier = 1, Text = "Strong Poison" },
			{ Cost = 950, Damage = 6, Range = 16, Cooldown = 1.0, Poison = { Dps = 21, Duration = 5 }, Cloud = 4, Detect = true, Tier = 2, Text = "Toxic Cloud" },
			{ Cost = 1900, Damage = 9, Range = 17, Cooldown = 0.95, Poison = { Dps = 32, Duration = 5 }, Cloud = 5, Detect = true, Tier = 2, Text = "+poison, wider cloud" },
			{ Cost = 3400, Damage = 13, Range = 18, Cooldown = 0.9, Poison = { Dps = 52, Duration = 6 }, Cloud = 6,
				Slow = { Factor = 0.2, Duration = 1.5 }, Detect = true, Tier = 3, Text = "Neurotoxin: slows by 20%" },
		},
	},
	{
		Id = "lumberjack", Name = "Lumberjack", Role = "Heavy melee and control",
		Description = "Slow but powerful axe swings. Later hits an area and stuns.",
		Price = 900, Rarity = "Rare",
		Attack = "axe", Icon = "🪓", Accent = c(220, 90, 70),
		Levels = {
			{ Cost = 800, Damage = 39, Range = 7.5, Cooldown = 1.8, Tier = 1, Text = "Axe" },
			{ Cost = 580, Damage = 57, Range = 8, Cooldown = 1.7, Tier = 1, Text = "+damage" },
			{ Cost = 1150, Damage = 78, Range = 8.5, Cooldown = 1.65, Splash = 5, Tier = 2, Text = "Cleave: hits everyone near the target" },
			{ Cost = 2200, Damage = 107, Range = 9, Cooldown = 1.6, Splash = 6, Stun = 0.6, Tier = 2, Text = "Stuns" },
			{ Cost = 4100, Damage = 156, Range = 10, Cooldown = 1.5, Splash = 7, Stun = 0.9, Detect = true, Pierce = 0.4, Tier = 3, Text = "Great Axe" },
		},
	},
	{
		Id = "wolverine", Name = "Wolverine", Role = "Claw combos",
		Description = "Just an R6 body and claws. Lightning-fast combos against nearby enemies.",
		Price = 2000, Rarity = "Legendary",
		Attack = "claws", Icon = "🐾", Accent = c(200, 200, 215),
		Levels = {
			{ Cost = 1000, Damage = 5, Range = 7, Cooldown = 0.8, Hits = 3, Targets = 1, Tier = 1, Text = "Claws" },
			{ Cost = 720, Damage = 8, Range = 7.5, Cooldown = 0.8, Hits = 3, Targets = 2, Tier = 1, Text = "Hits two targets" },
			{ Cost = 1450, Damage = 10, Range = 8, Cooldown = 0.75, Hits = 4, Targets = 2, Detect = true, Tier = 2, Text = "4 hits, senses hidden" },
			{ Cost = 2700, Damage = 14, Range = 8.5, Cooldown = 0.7, Hits = 4, Targets = 2, FrenzyEvery = 4, Detect = true, Tier = 2, Text = "Frenzy: every 4th attack hits all nearby" },
			{ Cost = 4600, Damage = 20, Range = 9, Cooldown = 0.6, Hits = 5, Targets = 3, FrenzyEvery = 3, Detect = true, Tier = 3, Text = "Adamantium Claws" },
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
	Starter = "swordsman", -- есть у каждого нового игрока
	LoadoutSize = 5, -- сколько башен можно взять в матч
	RarityOrder = { "Starter", "Common", "Uncommon", "Rare", "Epic", "Legendary" },
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
