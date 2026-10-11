--[[
	Волны. Состав волн 1..20 задан таблицей (читается и правится легко),
	волны после 20 генерируются формулой — их можно добавить, увеличив Waves.Max.

	Рост сложности плавный: здоровье растёт квадратично-медленно, скорость — до +25 %,
	броня бронированных — на 1 каждые 7 волн. Боссы: 10 — Brute, 15 — Juggernaut, 20 — Warlord.
]]

local Waves = {}

Waves.Max = 20
Waves.HealthScale = 0.8 -- общий множитель здоровья обычных врагов (баланс под 3 жизни базы)

-- Интервалы между врагами в группе по типам (сек)
local INTERVAL = {
	basic = 1.1, runner = 0.5, tank = 1.8, armored = 1.2, regenerator = 1.1, shielded = 1.2,
	healer = 1.6, stealth = 1.0, elite = 2.6, boss_brute = 1, boss_juggernaut = 1, boss_warlord = 1,
}

-- { тип, количество } в порядке выхода
local TABLE: { [number]: { { any } } } = {
	[1] = { { "basic", 6 } },
	[2] = { { "basic", 9 }, { "runner", 3 } },
	[3] = { { "basic", 10 }, { "runner", 6 } },
	[4] = { { "basic", 8 }, { "tank", 2 }, { "runner", 5 } },
	[5] = { { "basic", 8 }, { "elite", 1 } },
	[6] = { { "basic", 8 }, { "armored", 4 } },
	[7] = { { "regenerator", 5 }, { "basic", 8 }, { "shielded", 3 } },
	[8] = { { "healer", 3 }, { "tank", 3 }, { "basic", 10 } },
	[9] = { { "stealth", 6 }, { "basic", 10 } },
	[10] = { { "basic", 10 }, { "boss_brute", 1 } },
	[11] = { { "armored", 7 }, { "healer", 2 }, { "runner", 8 } },
	[12] = { { "shielded", 8 }, { "regenerator", 5 } },
	[13] = { { "tank", 6 }, { "healer", 3 }, { "stealth", 5 } },
	[14] = { { "runner", 18 }, { "shielded", 6 } },
	[15] = { { "tank", 5 }, { "basic", 12 }, { "boss_juggernaut", 1 } },
	[16] = { { "regenerator", 8 }, { "armored", 8 }, { "stealth", 6 } },
	[17] = { { "armored", 10 }, { "elite", 4 } },
	[18] = { { "tank", 10 }, { "healer", 5 }, { "regenerator", 6 } },
	[19] = { { "runner", 16 }, { "stealth", 10 }, { "elite", 5 } },
	[20] = { { "armored", 8 }, { "healer", 4 }, { "elite", 4 }, { "boss_warlord", 1 } },
}

Waves.EliteWaves = { [5] = true, [17] = true }
Waves.BossWaves = { [10] = "boss_brute", [15] = "boss_juggernaut", [20] = "boss_warlord" }

local POOL = { "basic", "runner", "tank", "armored", "regenerator", "shielded", "healer", "stealth", "elite" }

-- Волны после таблицы: детерминированная смесь из пула, количество растёт с номером
local function generated(wave: number): { { any } }
	local groups = {}
	local seed = wave * 7919
	for i = 1, 3 do
		seed = (seed * 48271) % 2147483647
		local enemy = POOL[seed % #POOL + 1]
		local count = if enemy == "elite" then 4 + math.floor(wave / 10) else 8 + math.floor(wave / 3)
		table.insert(groups, { enemy, count })
	end
	if wave % 5 == 0 then
		table.insert(groups, { "boss_warlord", 1 })
	end
	return groups
end

export type Group = { Enemy: string, Count: number, Interval: number, Start: number }
export type Wave = {
	Number: number,
	Groups: { Group },
	HealthMult: number,
	SpeedMult: number,
	ArmorAdd: number,
	Elite: boolean,
	Boss: string?,
	Total: number,
}

-- Кривая рассчитана на 20 волн (раньше было 30): шаг по «старой» шкале ×1.5
function Waves.HealthMult(wave: number): number
	local n = (wave - 1) * 1.5
	return Waves.HealthScale * (1 + 0.05 * n + 0.0045 * n * n)
end

function Waves.SpeedMult(wave: number): number
	return math.min(1.25, 1 + 0.012 * (wave - 1))
end

function Waves.ArmorAdd(wave: number): number
	return math.floor((wave - 1) / 7)
end

-- Полное описание волны: группы со временем старта (сек от начала волны)
function Waves.Get(wave: number): Wave
	local source = TABLE[wave] or generated(wave)
	local groups = {}
	local start = 0
	local total = 0
	for index, entry in source do
		local enemy, count = entry[1], entry[2]
		local interval = INTERVAL[enemy] or 1
		table.insert(groups, { Enemy = enemy, Count = count, Interval = interval, Start = start })
		total += count
		-- Следующая группа выходит, когда текущая выпустила половину
		start += math.max(2, interval * count * 0.5) + (if index == 1 then 0 else 1)
	end
	return {
		Number = wave,
		Groups = groups,
		HealthMult = Waves.HealthMult(wave),
		SpeedMult = Waves.SpeedMult(wave),
		ArmorAdd = Waves.ArmorAdd(wave),
		Elite = Waves.EliteWaves[wave] == true,
		Boss = Waves.BossWaves[wave],
		Total = total,
	}
end

-- Время, за которое выпускается вся волна
function Waves.SpawnDuration(wave: Wave): number
	local last = 0
	for _, group in wave.Groups do
		last = math.max(last, group.Start + group.Interval * (group.Count - 1))
	end
	return last
end

return Waves
