--[[
	Тексты характеристик башен для интерфейса (магазин, окно башни, подсказки).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Config.Towers)
local Format = require(Shared.Logic.Format)

local Theme = require(script.Parent.Theme)

local TowerText = {}

-- Особые свойства уровня списком коротких фраз
function TowerText.Specials(level: any): { string }
	local parts = {}
	if level.Targets and level.Targets > 1 then
		table.insert(parts, level.Targets .. " targets")
	end
	if level.Hits then
		table.insert(parts, level.Hits .. "-hit combo")
	end
	if level.Poison then
		table.insert(parts, string.format("poison %d/s for %ss", level.Poison.Dps, Format.Decimal(level.Poison.Duration)))
	end
	if level.Cloud then
		table.insert(parts, "toxic cloud " .. level.Cloud)
	end
	if level.Slow then
		table.insert(parts, string.format("slow %d%%", level.Slow.Factor * 100))
	end
	if level.Splash then
		table.insert(parts, "splash " .. level.Splash)
	end
	if level.Stun then
		table.insert(parts, "stun " .. Format.Decimal(level.Stun) .. "s")
	end
	if level.Pierce then
		table.insert(parts, string.format("%d%% armor pierce", level.Pierce * 100))
	end
	if level.SpinMax then
		table.insert(parts, string.format("spin-up +%d%%", level.SpinMax * 100))
	end
	if level.FrenzyEvery then
		table.insert(parts, "frenzy every " .. level.FrenzyEvery .. " attacks")
	end
	if level.Detect then
		table.insert(parts, "sees hidden")
	end
	return parts
end

function TowerText.SpecialLine(level: any): string
	local parts = TowerText.Specials(level)
	return if #parts > 0 then table.concat(parts, ", ") else ""
end

function TowerText.FireRate(level: any): string
	return Format.Decimal(1 / level.Cooldown, 2) .. "/s"
end

function TowerText.RarityColor(def: any): Color3
	return Theme.Rarity[def.Rarity] or Theme.Rarity.Common
end

-- Короткая подсказка (RichText) для карточек
function TowerText.Tooltip(def: any): string
	local l1 = def.Levels[1]
	return string.format('<font size="15"><b>%s</b></font>\n<font color="#C4D2F0">%s</font>\nDamage %s   Range %s   %s\nDPS %s (max %s)',
		def.Name, def.Role, Format.Number(l1.Damage), Format.Decimal(l1.Range), TowerText.FireRate(l1),
		Format.Number(Towers.Dps(l1)), Format.Number(Towers.Dps(def.Levels[#def.Levels])))
end

return TowerText
