--[[
	Печатает таблицы баланса (markdown) прямо из конфигов игры.
	Запуск: lune run tools/balance.luau
]]

local Engine = require("../tests/sim/Engine")
local realm = Engine.Realm(true)
local Shared = Engine.SharedNode
local Eggs = realm.require(Shared.Config.Eggs)
local Creatures = realm.require(Shared.Config.Creatures)
local Game = realm.require(Shared.Config.Game)
local Upgrades = realm.require(Shared.Config.Upgrades)
local Format = realm.require(Shared.Logic.Format)

print("| Яйцо | Редкость | Цена | Вылупление | Средний доход Baby/с | Adult/с | Окупаемость Baby | Окупаемость Adult |")
print("|---|---|---|---|---|---|---|---|")
for _, egg in Eggs.List do
	local total, weighted = 0, 0
	for _, entry in egg.Creatures do
		total += entry.Weight
		weighted += Creatures.ById[entry.Creature].BaseIncome * entry.Weight
	end
	local baby = weighted / total
	local adult = baby * Game.Growth.StageIncome.Adult
	local price = egg.Price or egg.Value
	print(string.format("| %s | %s | %s | %s | %s | %s | %s | %s |", egg.Name, egg.Rarity,
		if egg.Price then Format.Money(egg.Price) else "не продаётся", Format.Time(egg.HatchTime),
		Format.Money(baby), Format.Money(adult), Format.Time(price / baby), Format.Time(price / adult)))
end

print("\n| Улучшение | Уровни | Цены по уровням |")
print("|---|---|---|")
for _, upgrade in Upgrades.List do
	local costs = {}
	for level = upgrade.Start, upgrade.Max - 1 do
		if upgrade.Id ~= "speed" or level % 8 == 0 or level == upgrade.Max - 1 then
			table.insert(costs, (if upgrade.Id == "speed" then "ур." .. level .. ": " else "") .. Format.Money(upgrade.Cost(level)))
		end
	end
	print(string.format("| %s | %d → %d | %s |", upgrade.Name, upgrade.Start, upgrade.Max, table.concat(costs, ", ")))
end
require("@lune/process").exit(0)
