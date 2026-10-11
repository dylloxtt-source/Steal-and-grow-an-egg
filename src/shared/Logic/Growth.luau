--[[
	Чистая логика роста, голода и дохода существ. Без обращений к сервисам,
	поэтому одинаково работает онлайн (тик раз в секунду) и при расчёте офлайна.

	Данные существа (хранятся в профиле):
	  uid, species, size, sizeId, mutation, growth, fullness, ascended, placed, lastTick
]]

local Config = script.Parent.Parent.Config
local Game = require(Config.Game)
local Rarities = require(Config.Rarities)
local Creatures = require(Config.Creatures)

local Growth = {}

export type CreatureData = {
	uid: string,
	species: string,
	size: number,
	sizeId: string,
	mutation: string,
	growth: number,
	fullness: number,
	ascended: boolean,
	placed: boolean,
	lastTick: number,
}

local mutationById = {}
for _, mutation in Game.Mutations do
	mutationById[mutation.Id] = mutation
end

function Growth.MutationMult(mutationId: string): number
	local mutation = mutationById[mutationId]
	return if mutation then mutation.Mult else 1
end

function Growth.Thresholds(speciesId: string): (number, number)
	local def = Creatures.ById[speciesId]
	local scale = if def then Rarities.ById[def.Rarity].GrowthScale else 1
	return Game.Growth.Juvenile * scale, Game.Growth.Adult * scale
end

function Growth.Stage(data: CreatureData): string
	if data.ascended then
		return "Ascended"
	end
	local juvenile, adult = Growth.Thresholds(data.species)
	if data.growth >= adult then
		return "Adult"
	elseif data.growth >= juvenile then
		return "Juvenile"
	end
	return "Baby"
end

-- Прогресс до следующей стадии (0..1) и подпись следующей стадии
function Growth.Progress(data: CreatureData): (number, string?)
	local stage = Growth.Stage(data)
	local juvenile, adult = Growth.Thresholds(data.species)
	if stage == "Baby" then
		return math.clamp(data.growth / juvenile, 0, 1), "Juvenile"
	elseif stage == "Juvenile" then
		return math.clamp((data.growth - juvenile) / (adult - juvenile), 0, 1), "Adult"
	elseif stage == "Adult" then
		return 1, "Ascended"
	end
	return 1, nil
end

function Growth.DecayPerSecond(speciesId: string): number
	local def = Creatures.ById[speciesId]
	local appetite = if def then Rarities.ById[def.Rarity].Appetite else 1
	return Game.Growth.FullnessDecayPerSecond * appetite
end

-- Доход в секунду, когда существо сыто. bonus — суммарный бонус (индекс + черты), например 0.25
function Growth.IncomePerSecond(data: CreatureData, bonus: number?): number
	local def = Creatures.ById[data.species]
	if not def then
		return 0
	end
	local stage = Growth.Stage(data)
	return def.BaseIncome
		* Game.Growth.StageIncome[stage]
		* data.size
		* Growth.MutationMult(data.mutation)
		* (1 + (bonus or 0))
end

function Growth.SellValue(data: CreatureData): number
	local def = Creatures.ById[data.species]
	if not def then
		return 0
	end
	local stage = Growth.Stage(data)
	return math.floor(def.BaseIncome * Game.SellFactor * Game.Growth.StageSellMult[stage]
		* data.size * Growth.MutationMult(data.mutation))
end

--[[
	Продвигает существо во времени до now (секунды os.time).
	maxSeconds ограничивает учитываемый промежуток (для офлайна).
	Возвращает:
	  elapsed  — учтённые секунды
	  fedTime  — сколько из них существо было сытым (рос и давало полный доход)
	  stageUp  — true, если стадия повысилась
]]
function Growth.Simulate(data: CreatureData, now: number, maxSeconds: number?): (number, number, boolean)
	local elapsed = now - (data.lastTick or now)
	if elapsed <= 0 then
		data.lastTick = now
		return 0, 0, false
	end
	if maxSeconds then
		elapsed = math.min(elapsed, maxSeconds)
	end
	data.lastTick = now

	if not data.placed then
		-- В хранилище существо «спит»: не голодает и не растёт
		return elapsed, 0, false
	end

	local stageBefore = Growth.Stage(data)
	local decay = Growth.DecayPerSecond(data.species)
	local fedTime = math.min(elapsed, data.fullness / decay)

	if not data.ascended then
		local def = Creatures.ById[data.species]
		local rate = if def then def.GrowthRate else 1
		local _, adult = Growth.Thresholds(data.species)
		data.growth = math.min(adult, data.growth + fedTime * rate)
	end
	data.fullness = math.max(0, data.fullness - decay * elapsed)

	return elapsed, fedTime, Growth.Stage(data) ~= stageBefore
end

-- Доход за промежуток с учётом голодной части
function Growth.EarnedOver(data: CreatureData, elapsed: number, fedTime: number, bonus: number?): number
	local rate = Growth.IncomePerSecond(data, bonus)
	return rate * (fedTime + (elapsed - fedTime) * Game.Growth.HungryIncomeMult)
end

export type FeedResult = { ok: boolean, reason: string?, stageUp: boolean? }

-- Применяет еду к существу. Проверки наличия еды — на стороне вызывающего.
function Growth.ApplyFood(data: CreatureData, food: any): FeedResult
	local stageBefore = Growth.Stage(data)

	if food.Catalyst and stageBefore == "Adult" then
		data.ascended = true
		data.fullness = math.min(Game.Growth.FullnessMax, data.fullness + food.Fullness)
		return { ok = true, stageUp = true }
	end

	if not food.IgnoresFullness and data.fullness >= Game.Growth.FeedBlockAt then
		return { ok = false, reason = "Питомец сыт" }
	end

	if data.ascended then
		if food.IgnoresFullness then
			return { ok = false, reason = "Уже максимальная стадия" }
		end
		data.fullness = math.min(Game.Growth.FullnessMax, data.fullness + food.Fullness)
		return { ok = true, stageUp = false }
	end

	local _, adult = Growth.Thresholds(data.species)
	if food.IgnoresFullness and data.growth >= adult then
		return { ok = false, reason = "Нужен Starfruit для следующей стадии" }
	end

	data.fullness = math.min(Game.Growth.FullnessMax, data.fullness + food.Fullness)
	data.growth = math.min(adult, data.growth + food.Growth)
	return { ok = true, stageUp = Growth.Stage(data) ~= stageBefore }
end

return Growth
