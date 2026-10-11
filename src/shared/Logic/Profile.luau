--[[
	Постоянный прогресс игрока (DataStore). Матчевое состояние сюда НЕ попадает.

	Версия 2: башни покупаются за гемы в магазине (owned), в матч берётся набор
	до Towers.LoadoutSize башен (loadout). Новый игрок владеет только стартовой
	башней (мечник). Настройки (settings) тоже сохраняются: авто-скип, звук и т.д.
]]

local Config = script.Parent.Parent.Config
local Game = require(Config.Game)
local Towers = require(Config.Towers)
local Maps = require(Config.Maps)
local Economy = require(Config.Economy)

local Profile = {}

Profile.DefaultSettings = {
	autoSkip = false, -- автоматически начинать следующую волну
	sfx = true, -- звуки
	popups = true, -- всплывающие награды за убийства
	lowFx = false, -- упрощённые эффекты для слабых устройств
}

function Profile.Default(): any
	return {
		version = Game.DataVersion,
		gems = 0,
		level = 1,
		xp = 0,
		stats = { matches = 0, wins = 0, losses = 0, kills = 0, wavesCleared = 0 },
		bestWave = {}, -- [mapId] = номер волны
		owned = { [Towers.Starter] = true },
		loadout = { Towers.Starter },
		settings = table.clone(Profile.DefaultSettings),
	}
end

function Profile.Reconcile(data: any): any
	if type(data) ~= "table" then
		return Profile.Default()
	end
	local template = Profile.Default()
	local oldVersion = tonumber(data.version) or 0
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
	-- v1 → v2: раньше все башни были открыты бесплатно; теперь их покупают в магазине
	data.unlocked = nil
	if oldVersion < 2 then
		data.owned = { [Towers.Starter] = true }
		data.loadout = { Towers.Starter }
	end
	-- Только существующие башни; стартовая есть всегда
	for towerId in data.owned do
		if not Towers.ById[towerId] or data.owned[towerId] ~= true then
			data.owned[towerId] = nil
		end
	end
	data.owned[Towers.Starter] = true
	local loadout, seen = {}, {}
	for _, towerId in data.loadout do
		if type(towerId) == "string" and data.owned[towerId] and not seen[towerId] and #loadout < Towers.LoadoutSize then
			table.insert(loadout, towerId)
			seen[towerId] = true
		end
	end
	if #loadout == 0 then
		loadout = { Towers.Starter }
	end
	data.loadout = loadout
	for key, value in Profile.DefaultSettings do
		if type(data.settings[key]) ~= type(value) then
			data.settings[key] = value
		end
	end
	for key in data.settings do
		if Profile.DefaultSettings[key] == nil then
			data.settings[key] = nil
		end
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

-- Магазин: покупка башни за гемы. Возвращает (ok, сообщение для игрока)
function Profile.Buy(data: any, towerId: string): (boolean, string?)
	local def = Towers.ById[towerId]
	if not def then
		return false, "Unknown tower"
	end
	if data.owned[towerId] then
		return false, "You already own " .. def.Name
	end
	if data.gems < def.Price then
		return false, string.format("Not enough gems (need %d more)", def.Price - data.gems)
	end
	data.gems -= def.Price
	data.owned[towerId] = true
	if #data.loadout < Towers.LoadoutSize then
		table.insert(data.loadout, towerId) -- купленная башня сразу берётся в набор, если есть место
	end
	return true, nil
end

-- Набор башен на матч: поставить башню в слот (или в первый свободный)
function Profile.Equip(data: any, towerId: string, slot: number?): (boolean, string?)
	local def = Towers.ById[towerId]
	if not def or not data.owned[towerId] then
		return false, "You don't own this tower yet"
	end
	local current = table.find(data.loadout, towerId)
	if slot then
		if slot < 1 or slot > Towers.LoadoutSize or slot ~= math.floor(slot) then
			return false, "Invalid slot"
		end
		if current then
			table.remove(data.loadout, current)
		end
		if slot > #data.loadout then
			table.insert(data.loadout, towerId)
		else
			data.loadout[slot] = towerId
		end
		return true, nil
	end
	if current then
		return true, nil
	end
	if #data.loadout >= Towers.LoadoutSize then
		return false, string.format("Loadout is full (%d/%d) — unequip a tower first", #data.loadout, Towers.LoadoutSize)
	end
	table.insert(data.loadout, towerId)
	return true, nil
end

function Profile.Unequip(data: any, towerId: string): (boolean, string?)
	local index = table.find(data.loadout, towerId)
	if not index then
		return false, "This tower is not equipped"
	end
	if #data.loadout <= 1 then
		return false, "You need at least one tower in your loadout"
	end
	table.remove(data.loadout, index)
	return true, nil
end

return Profile
