--[[
	Постоянный прогресс игрока (DataStore). Матчевое состояние сюда НЕ попадает.
]]

local Config = script.Parent.Parent.Config
local Game = require(Config.Game)
local Towers = require(Config.Towers)
local Maps = require(Config.Maps)
local Economy = require(Config.Economy)

local Profile = {}

function Profile.Default(): any
	local unlocked = {}
	for _, tower in Towers.List do
		unlocked[tower.Id] = true
	end
	return {
		version = Game.DataVersion,
		gems = 0,
		level = 1,
		xp = 0,
		stats = { matches = 0, wins = 0, losses = 0, kills = 0, wavesCleared = 0 },
		bestWave = {}, -- [mapId] = номер волны
		unlocked = unlocked,
	}
end

function Profile.Reconcile(data: any): any
	if type(data) ~= "table" then
		return Profile.Default()
	end
	local template = Profile.Default()
	for key, value in template do
		if type(data[key]) ~= type(value) then
			data[key] = value
		end
	end
	for key, value in template.stats do
		if type(data.stats[key]) ~= "number" then
			data.stats[key] = value
		end
	end
	for mapId, wave in data.bestWave do
		if not Maps.ById[mapId] or type(wave) ~= "number" then
			data.bestWave[mapId] = nil
		end
	end
	-- Все башни доступны в текущей версии; список хранится для будущих разблокировок
	for _, tower in Towers.List do
		data.unlocked[tower.Id] = true
	end
	data.gems = math.max(0, math.floor(tonumber(data.gems) or 0))
	data.level = math.max(1, math.floor(tonumber(data.level) or 1))
	data.xp = math.max(0, tonumber(data.xp) or 0)
	data.version = Game.DataVersion
	return data
end

-- Начисляет опыт и возвращает количество полученных уровней
function Profile.AddXp(data: any, amount: number): number
	data.xp += amount
	local gained = 0
	while data.xp >= Economy.Xp.PerLevel(data.level) do
		data.xp -= Economy.Xp.PerLevel(data.level)
		data.level += 1
		gained += 1
	end
	return gained
end

return Profile
