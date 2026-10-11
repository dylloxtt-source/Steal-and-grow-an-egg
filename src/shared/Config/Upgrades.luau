--[[
	Улучшения базы. Level хранится в профиле игрока (profile.upgrades[Id]).
	Cost(level) — цена перехода с level на level + 1.
	Стоимость растёт экспоненциально: это главный сток валюты против инфляции.
]]

export type Upgrade = {
	Id: string,
	Name: string,
	Icon: string,
	Start: number,
	Max: number,
	Cost: (level: number) -> number,
	Describe: (level: number) -> string,
}

local function round(n: number): number
	-- Округляем до «красивых» чисел: 2 значащие цифры
	if n < 100 then
		return math.floor(n + 0.5)
	end
	local digits = math.floor(math.log10(n)) - 1
	local p = 10 ^ digits
	return math.floor(n / p + 0.5) * p
end

local list: { Upgrade } = {
	{
		Id = "speed", Name = "Speed", Icon = "👟", Start = 0, Max = 64,
		Cost = function(level)
			return round(25 * 1.28 ^ level)
		end,
		Describe = function(level)
			return string.format("Скорость %d → %d", 16 + level, 17 + level)
		end,
	},
	{
		Id = "incubators", Name = "Incubator Slot", Icon = "🥚", Start = 2, Max = 6,
		Cost = function(level)
			local costs = { [2] = 1500, [3] = 25000, [4] = 400000, [5] = 6000000 }
			return costs[level] or math.huge
		end,
		Describe = function(level)
			return string.format("Инкубаторов %d → %d", level, level + 1)
		end,
	},
	{
		Id = "pens", Name = "Pen Space", Icon = "🐾", Start = 4, Max = 12,
		Cost = function(level)
			return round(800 * 3.2 ^ (level - 4))
		end,
		Describe = function(level)
			return string.format("Мест в загоне %d → %d", level, level + 1)
		end,
	},
	{
		Id = "farms", Name = "Garden Plot", Icon = "🌱", Start = 2, Max = 8,
		Cost = function(level)
			return round(500 * 3 ^ (level - 2))
		end,
		Describe = function(level)
			return string.format("Грядок %d → %d", level, level + 1)
		end,
	},
	{
		Id = "incubatorSpeed", Name = "Warm Incubators", Icon = "🔥", Start = 0, Max = 5,
		Cost = function(level)
			return round(5000 * 4 ^ level)
		end,
		Describe = function(level)
			return string.format("Инкубация быстрее: -%d%% → -%d%%", level * 8, (level + 1) * 8)
		end,
	},
	{
		Id = "bag", Name = "Egg Bag", Icon = "🎒", Start = 1, Max = 3,
		Cost = function(level)
			local costs = { [1] = 3000, [2] = 150000 }
			return costs[level] or math.huge
		end,
		Describe = function(level)
			return string.format("Нести яиц %d → %d", level, level + 1)
		end,
	},
	{
		Id = "lock", Name = "Base Lock", Icon = "🔒", Start = 0, Max = 3,
		Cost = function(level)
			return round(10000 * 5 ^ level)
		end,
		Describe = function(level)
			return string.format("Замок базы %d → %d сек.", 45 + level * 15, 45 + (level + 1) * 15)
		end,
	},
}

local byId: { [string]: Upgrade } = {}
for _, upgrade in list do
	byId[upgrade.Id] = upgrade
end

return {
	List = list,
	ById = byId,
}
