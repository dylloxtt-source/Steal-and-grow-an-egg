--[[
	Схема профиля игрока, значения по умолчанию, миграции и сверка.
	Хранится в DataStore как JSON-совместимая таблица (только строковые ключи
	у словарей и плотные массивы).
]]

local Config = script.Parent.Parent.Config
local Game = require(Config.Game)
local Eggs = require(Config.Eggs)
local Creatures = require(Config.Creatures)
local Foods = require(Config.Foods)
local Upgrades = require(Config.Upgrades)

local Profile = {}

function Profile.Default(): any
	local upgrades = {}
	for _, upgrade in Upgrades.List do
		upgrades[upgrade.Id] = upgrade.Start
	end
	return {
		version = Game.DataVersion,
		coins = Game.StartCoins,
		vault = 0,
		upgrades = upgrades,
		eggs = { { uid = "u1", id = Eggs.StarterEgg } },
		incubators = {}, -- ["1"] = { uid, id, startedAt, duration }
		creatures = {}, -- [uid] = CreatureData
		food = { pellet = 5 },
		seeds = { berry = 2 },
		farm = {}, -- ["1"] = { seed, plantedAt, readyAt }
		index = {}, -- [species] = true
		quests = { day = 0, list = {} },
		stats = { playTime = 0, hatched = 0, stolen = 0, earned = 0, robbed = 0 },
		settings = { slowMode = false },
		tutorial = 1,
		lastOnline = 0,
		nextUid = 2,
	}
end

-- Миграции по версиям: MIGRATIONS[n] переводит профиль с версии n на n + 1
local MIGRATIONS: { [number]: (any) -> () } = {}

local function reconcileTable(target: any, template: any)
	for key, value in template do
		if target[key] == nil then
			if type(value) == "table" then
				target[key] = table.clone(value)
			else
				target[key] = value
			end
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil
			and #value == 0 then
			-- Сверяем только словари-шаблоны (upgrades, stats, settings)
			reconcileTable(target[key], value)
		end
	end
end

-- Приводит загруженный профиль к актуальной схеме и выкидывает неизвестные ID
function Profile.Reconcile(data: any): any
	if type(data) ~= "table" then
		return Profile.Default()
	end
	local version = tonumber(data.version) or 1
	while MIGRATIONS[version] do
		MIGRATIONS[version](data)
		version += 1
	end
	data.version = Game.DataVersion

	local template = Profile.Default()
	template.eggs = {}
	template.food = {}
	template.seeds = {}
	reconcileTable(data, template)

	-- Чистка устаревших/битых записей
	local eggs = {}
	for _, egg in data.eggs do
		if type(egg) == "table" and Eggs.ById[egg.id] and type(egg.uid) == "string" then
			table.insert(eggs, egg)
		end
	end
	data.eggs = eggs

	for slot, record in data.incubators do
		if type(record) ~= "table" or not Eggs.ById[record.id] then
			data.incubators[slot] = nil
		end
	end
	for uid, creature in data.creatures do
		if type(creature) ~= "table" or not Creatures.ById[creature.species] then
			data.creatures[uid] = nil
		end
	end
	for id, count in data.food do
		if not Foods.ById[id] or type(count) ~= "number" or count <= 0 then
			data.food[id] = nil
		end
	end
	for id, count in data.seeds do
		local food = Foods.ById[id]
		if not food or not food.Seed or type(count) ~= "number" or count <= 0 then
			data.seeds[id] = nil
		end
	end
	for slot, record in data.farm do
		local food = type(record) == "table" and Foods.ById[record.seed]
		if not food or not food.Seed then
			data.farm[slot] = nil
		end
	end
	for _, upgrade in Upgrades.List do
		local level = tonumber(data.upgrades[upgrade.Id]) or upgrade.Start
		data.upgrades[upgrade.Id] = math.clamp(math.floor(level), upgrade.Start, upgrade.Max)
	end
	data.coins = math.max(0, tonumber(data.coins) or 0)
	data.vault = math.max(0, tonumber(data.vault) or 0)
	return data
end

function Profile.NewUid(data: any): string
	local uid = "u" .. tostring(data.nextUid)
	data.nextUid += 1
	return uid
end

function Profile.CountCreatures(data: any): (number, number)
	local total, placed = 0, 0
	for _, creature in data.creatures do
		total += 1
		if creature.placed then
			placed += 1
		end
	end
	return total, placed
end

function Profile.AddFood(data: any, foodId: string, amount: number)
	data.food[foodId] = math.min(Game.Inventory.MaxFoodStack, (data.food[foodId] or 0) + amount)
end

function Profile.TakeFood(data: any, foodId: string, amount: number): boolean
	local have = data.food[foodId] or 0
	if have < amount then
		return false
	end
	have -= amount
	data.food[foodId] = if have > 0 then have else nil
	return true
end

return Profile
