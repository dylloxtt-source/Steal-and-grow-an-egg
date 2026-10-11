--[[
	Волны. Состав волн 1..30 задан таблицей (читается и правится легко),
	волны после 30 генерируются формулой — так их можно расширить до 40–50,
	просто увеличив Waves.Max (и, при желании, дописав таблицу).

	Рост сложности плавный: здоровье растёт квадратично-медленно, скорость — на 0.8 % за волну
	(не более +25 %), броня бронированных — на 1 каждые 6 волн.
]]

local Waves = {}

Waves.Max = 30

-- Интервалы между врагами в группе по типам (сек)
local INTERVAL = {
	basic = 1.1, runner = 0.5, tank = 1.8, armored = 1.2, regenerator = 1.1, shielded = 1.2,
	healer = 1.6, stealth = 1.0, elite = 2.6, boss_brute = 1, boss_juggernaut = 1, boss_warlord = 1,
}

-- { тип, количество } в порядке выхода
local TABLE: { [number]: { { any } } } = {
	[1] = { { "basic", 6 } },
	[2] = { { "basic", 9 } },
	[3] = { { "basic", 8 }, { "runner", 4 } },
	[4] = { { "basic", 10 }, { "runner", 6 } },
	[5] = { { "basic", 8 }, { "elite", 1 } },
	[6] = { { "basic", 8 }, { "tank", 2 }, { "runner", 5 } },
	[7] = { { "basic", 8 }, { "armored", 4 } },
	[8] = { { "regenerator", 5 }, { "basic", 8 } },
	[9] = { { "shielded", 5 }, { "runner", 8 } },
	[10] = { { "basic", 10 }, { "boss_brute", 1 } },
	[11] = { { "healer", 3 }, { "tank", 3 }, { "basic", 10 } },
	[12] = { { "stealth", 6 }, { "basic", 10 } },
	[13] = { { "armored", 7 }, { "healer", 2 }, { "runner", 8 } },
	[14] = { { "shielded", 8 }, { "regenerator", 5 } },
	[15] = { { "armored", 6 }, { "elite", 3 } },
	[16] = { { "tank", 6 }, { "healer", 3 }, { "stealth", 5 } },
	[17] = { { "runner", 18 }, { "shielded", 6 } },
	[18] = { { "regenerator", 8 }, { "armored", 8 } },
	[19] = { { "stealth", 8 }, { "healer", 3 }, { "elite", 2 } },
	[20] = { { "tank", 5 }, { "basic", 12 }, { "boss_juggernaut", 1 } },
	[21] = { { "armored", 10 }, { "shielded", 8 } },
	[22] = { { "stealth", 10 }, { "runner", 14 } },
	[23] = { { "tank", 8 }, { "healer", 5 }, { "regenerator", 6 } },
	[24] = { { "shielded", 10 }, { "elite", 4 } },
	[25] = { { "armored", 10 }, { "elite", 6 } },
	[26] = { { "regenerator", 12 }, { "healer", 5 }, { "stealth", 8 } },
	[27] = { { "tank", 12 }, { "armored", 10 } },
	[28] = { { "runner", 16 }, { "stealth", 10 }, { "elite", 6 } },
	[29] = { { "shielded", 14 }, { "healer", 6 }, { "elite", 6 } },
	[30] = { { "armored", 8 }, { "healer", 4 }, { "elite", 4 }, { "boss_warlord", 1 } },
}

Waves.EliteWaves = { [5] = true, [15] = true, [25] = true }
Waves.BossWaves = { [10] = "boss_brute", [20] = "boss_juggernaut", [30] = "boss_warlord" }

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
	if wave % 10 == 0 then
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

function Waves.HealthMult(wave: number): number
	local n = wave - 1
	return 1 + 0.08 * n + 0.0035 * n * n
end

function Waves.SpeedMult(wave: number): number
	return math.min(1.25, 1 + 0.008 * (wave - 1))
end

function Waves.ArmorAdd(wave: number): number
	return math.floor((wave - 1) / 6)
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
