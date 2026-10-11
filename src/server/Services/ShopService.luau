--[[
	ShopService — покупки за монеты (яйца, еда, семена), улучшения базы и настройки.
	Цены берутся только из конфигов на сервере — клиент присылает лишь ID.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Foods = require(Shared.Config.Foods)
local Game = require(Shared.Config.Game)
local Upgrades = require(Shared.Config.Upgrades)
local Economy = require(Shared.Logic.Economy)
local Profile = require(Shared.Logic.Profile)

local ShopService = {}

local services

local function buy(session: any, category: string, id: string, amount: number): (boolean, string?)
	local profile = session.Profile
	local price
	if category == "egg" then
		local egg = Eggs.ById[id]
		if not egg or not egg.Price then
			return false, "Не продаётся"
		end
		if #profile.eggs + amount > Game.Inventory.MaxEggs then
			return false, "Инвентарь яиц полон"
		end
		price = egg.Price
	elseif category == "food" then
		local food = Foods.ById[id]
		if not food or not food.BuyPrice then
			return false, "Не продаётся"
		end
		price = food.BuyPrice
	elseif category == "seed" then
		local food = Foods.ById[id]
		if not food or not food.Seed then
			return false, "Не продаётся"
		end
		price = food.Seed.Price
	else
		return false, "Неверная категория"
	end

	local total = price * amount
	if profile.coins < total then
		return false, "Не хватает монет"
	end
	profile.coins -= total

	if category == "egg" then
		for _ = 1, amount do
			table.insert(profile.eggs, { uid = Profile.NewUid(profile), id = id })
		end
		services.IncubatorService:AutoFill(session)
	elseif category == "food" then
		Profile.AddFood(profile, id, amount)
	else
		profile.seeds[id] = math.min(Game.Inventory.MaxFoodStack, (profile.seeds[id] or 0) + amount)
	end
	return true, nil
end

local function upgrade(session: any, id: string): (boolean, string?)
	local profile = session.Profile
	local def = Upgrades.ById[id]
	if not def then
		return false, "Неизвестное улучшение"
	end
	local level = profile.upgrades[id]
	local cost = Economy.UpgradeCost(id, level)
	if not cost then
		return false, "Максимальный уровень"
	end
	if profile.coins < cost then
		return false, "Не хватает монет"
	end
	profile.coins -= cost
	profile.upgrades[id] = level + 1

	if id == "incubators" or id == "farms" then
		services.PlotService:RefreshSlots(session)
		services.IncubatorService:RefreshAll(session)
		services.FarmService:RefreshAll(session)
		if id == "incubators" then
			services.IncubatorService:AutoFill(session)
		end
	elseif id == "speed" then
		services.CarryService:RefreshSpeed(session.Player)
	elseif id == "bag" then
		services.CarryService:RefreshSpeed(session.Player)
	end
	return true, nil
end

function ShopService:Init(registry)
	services = registry
end

function ShopService:Start()
	local NetService = services.NetService
	local Check = NetService.Check

	NetService:Handle("Buy", function(_player, session, payload)
		if not Check.Table(payload) or not Check.String(payload.category, 8) or not Check.String(payload.id, 32) then
			return false, "Неверный запрос"
		end
		local amount = payload.amount or 1
		if not Check.Int(amount, 1, 10) then
			return false, "Неверное количество"
		end
		return buy(session, payload.category, payload.id, amount)
	end)

	NetService:Handle("Upgrade", function(_player, session, payload)
		if not Check.Table(payload) or not Check.String(payload.id, 32) then
			return false, "Неверный запрос"
		end
		return upgrade(session, payload.id)
	end)

	NetService:Handle("SetSetting", function(player, session, payload)
		if not Check.Table(payload) or payload.key ~= "slowMode" or type(payload.value) ~= "boolean" then
			return false, "Неверная настройка"
		end
		session.Profile.settings.slowMode = payload.value
		services.CarryService:RefreshSpeed(player)
		return true, nil
	end)

	NetService:Handle("RequestState", function()
		return true, nil
	end)
end

return ShopService
