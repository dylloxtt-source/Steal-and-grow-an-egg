--[[
	ShopService — магазин башен за гемы, набор башен на матч и настройки игрока.
	Все проверки на сервере (Logic/Profile): нельзя купить дважды, купить без гемов,
	взять в матч некупленную башню или оставить набор пустым.
	Набор меняется только в лобби; настройки (авто-скип и др.) — где угодно,
	авто-скип сразу применяется к текущему матчу.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Config.Towers)
local Profile = require(Shared.Logic.Profile)

local ShopService = {}

local services

function ShopService:Init(registry)
	services = registry
end

function ShopService:Start()
	local NetService = services.NetService
	local Check = NetService.Check

	local function changed(player: Player)
		services.DataService:SendProfile(player) -- автосохранение и выход сохранят изменения
	end

	NetService:Handle("BuyTower", function(player, session, payload)
		if not Check.Table(payload) or not Check.String(payload.tower, 24) or not Towers.ById[payload.tower] then
			return false, "Unknown tower"
		end
		local ok, message = Profile.Buy(session.Profile, payload.tower)
		if not ok then
			return false, message
		end
		changed(player)
		services.DataService:SaveNow(player) -- покупка за гемы сохраняется сразу
		return true, "Unlocked " .. Towers.ById[payload.tower].Name .. "!"
	end)

	NetService:Handle("EquipTower", function(player, session, payload)
		if not Check.Table(payload) or not Check.String(payload.tower, 24) or not Towers.ById[payload.tower] then
			return false, "Unknown tower"
		end
		if player:GetAttribute("MatchId") then
			return false, "You can change your loadout in the lobby"
		end
		local slot = payload.slot
		if slot ~= nil and not Check.Int(slot, 1, Towers.LoadoutSize) then
			return false, "Invalid slot"
		end
		local ok, message = Profile.Equip(session.Profile, payload.tower, slot)
		if not ok then
			return false, message
		end
		changed(player)
		return true, nil
	end)

	NetService:Handle("UnequipTower", function(player, session, payload)
		if not Check.Table(payload) or not Check.String(payload.tower, 24) then
			return false, "Unknown tower"
		end
		if player:GetAttribute("MatchId") then
			return false, "You can change your loadout in the lobby"
		end
		local ok, message = Profile.Unequip(session.Profile, payload.tower)
		if not ok then
			return false, message
		end
		changed(player)
		return true, nil
	end)

	NetService:Handle("SetSetting", function(player, session, payload)
		if not Check.Table(payload) or not Check.String(payload.key, 24) or type(payload.value) ~= "boolean" then
			return false, "Invalid setting"
		end
		if Profile.DefaultSettings[payload.key] == nil then
			return false, "Unknown setting"
		end
		session.Profile.settings[payload.key] = payload.value
		if payload.key == "autoSkip" then
			local match = services.MatchService:MatchOf(player)
			if match and not match.Closed then
				match:SetAutoSkip(player, payload.value)
			end
		end
		changed(player)
		return true, nil
	end)
end

return ShopService
