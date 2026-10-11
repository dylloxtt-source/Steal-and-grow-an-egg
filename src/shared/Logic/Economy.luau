--[[
	Формулы экономики, общие для сервера (расчёт) и клиента (отображение).
	Сервер — единственный источник истины; клиент лишь показывает те же числа.
]]

local Config = script.Parent.Parent.Config
local Game = require(Config.Game)
local Eggs = require(Config.Eggs)
local Creatures = require(Config.Creatures)
local Upgrades = require(Config.Upgrades)

local Economy = {}

export type Bonuses = {
	Speed: number,
	Luck: number,
	Incubate: number,
	Income: number,
	Lock: number,
	Forage: number,
}

function Economy.EmptyBonuses(): Bonuses
	return { Speed = 0, Luck = 0, Incubate = 0, Income = 0, Lock = 0, Forage = 0 }
end

-- Бонусы черт размещённых взрослых существ + бонус индекса
function Economy.Bonuses(profile: any, stageOf: (any) -> string): Bonuses
	local bonuses = Economy.EmptyBonuses()
	for _, creature in profile.creatures do
		if creature.placed then
			local def = Creatures.ById[creature.species]
			local stage = stageOf(creature)
			if def and def.Trait and (stage == "Adult" or stage == "Ascended") then
				local value = def.Trait.Value * (if stage == "Ascended" then 1.5 else 1)
				bonuses[def.Trait.Kind] += value
			end
		end
	end
	local discovered = 0
	for _ in profile.index do
		discovered += 1
	end
	bonuses.Income += discovered * Game.Index.IncomeBonusPerSpecies
	-- Ограничения, чтобы стек черт не ломал баланс
	bonuses.Incubate = math.min(bonuses.Incubate, 0.3)
	bonuses.Luck = math.min(bonuses.Luck, 1)
	bonuses.Forage = math.min(bonuses.Forage, 0.5)
	return bonuses
end

function Economy.HatchDuration(eggId: string, incubatorSpeedLevel: number, incubateBonus: number): number
	local egg = Eggs.ById[eggId]
	if not egg then
		return math.huge
	end
	local mult = (1 - 0.08 * incubatorSpeedLevel) * (1 - incubateBonus)
	return math.max(5, math.floor(egg.HatchTime * mult))
end

function Economy.SkipCost(eggId: string, remaining: number, duration: number): number
	local egg = Eggs.ById[eggId]
	if not egg or remaining <= 0 then
		return 0
	end
	local fraction = math.clamp(remaining / math.max(duration, 1), 0, 1)
	return math.max(Game.Hatch.MinSkipCost, math.ceil(egg.Value * fraction * Game.Hatch.SkipCostFactor))
end

function Economy.UpgradeCost(upgradeId: string, level: number): number?
	local upgrade = Upgrades.ById[upgradeId]
	if not upgrade or level >= upgrade.Max then
		return nil
	end
	return upgrade.Cost(level)
end

function Economy.WalkSpeed(speedLevel: number, speedBonus: number): number
	return math.min(Game.Movement.MaxWalkSpeed,
		Game.Movement.BaseWalkSpeed + speedLevel * Game.Movement.SpeedPerLevel + speedBonus)
end

function Economy.LockDuration(lockLevel: number, lockBonus: number): number
	return Game.Steal.LockBase + lockLevel * Game.Steal.LockPerLevel + lockBonus
end

function Economy.QuestReward(incomePerSecond: number, rewardSeconds: number): number
	return math.max(Game.Quests.MinReward, math.floor(incomePerSecond * rewardSeconds))
end

function Economy.StealRefund(eggId: string): number
	local egg = Eggs.ById[eggId]
	return if egg then math.floor(egg.Value * Eggs.StealRefund) else 0
end

return Economy
