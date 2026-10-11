--[[
	CreatureService — существа: рост, голод, доход в кассу базы, кормление,
	размещение в загоне / хранилище, продажа, офлайн-прогресс и модели в загоне.

	Существа в загоне (placed) растут, голодают и приносят доход.
	Существа в хранилище «спят»: не голодают, не растут и не приносят дохода.
	Вылупившихся существ украсть нельзя — это осознанное правило честности.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Foods = require(Shared.Config.Foods)
local Game = require(Shared.Config.Game)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Logic.Format)
local Growth = require(Shared.Logic.Growth)
local Profile = require(Shared.Logic.Profile)
local CreatureModel = require(Shared.Visual.CreatureModel)

local CreatureService = {}

local services
local rng = Random.new()

function CreatureService:GetBonuses(session: any): Economy.Bonuses
	if not session.Bonuses then
		session.Bonuses = Economy.Bonuses(session.Profile, Growth.Stage)
	end
	return session.Bonuses
end

function CreatureService:InvalidateBonuses(session: any)
	session.Bonuses = nil
	services.CarryService:RefreshSpeed(session.Player)
end

function CreatureService:IncomePerSecond(session: any): number
	local bonus = CreatureService:GetBonuses(session).Income
	local total = 0
	for _, creature in session.Profile.creatures do
		if creature.placed then
			local rate = Growth.IncomePerSecond(creature, bonus)
			if creature.fullness <= 0 then
				rate *= Game.Growth.HungryIncomeMult
			end
			total += rate
		end
	end
	return total
end

------------------------------------------------------------------------
-- Модели в загоне
------------------------------------------------------------------------

local function modelFor(session: any, uid: string): Model?
	local plot = session.Plot
	return plot and plot.Pen:FindFirstChild(uid) :: Model?
end

local function updateAttributes(session: any, creature: any)
	local model = modelFor(session, creature.uid)
	if not model then
		return
	end
	local progress = Growth.Progress(creature)
	model:SetAttribute("Fullness", math.floor(creature.fullness))
	model:SetAttribute("Progress", progress)
	model:SetAttribute("Stage", Growth.Stage(creature))
end

function CreatureService:SpawnModel(session: any, creature: any)
	local plot = session.Plot
	if not plot or not creature.placed then
		return
	end
	local old = modelFor(session, creature.uid)
	if old then
		old:Destroy()
	end
	local def = Creatures.ById[creature.species]
	local stage = Growth.Stage(creature)
	local model = CreatureModel.Build(creature.species, {
		Stage = stage,
		Size = creature.size,
		Mutation = creature.mutation,
	})
	model.Name = creature.uid
	local x = rng:NextNumber(plot.PenMin.X, plot.PenMax.X)
	local z = rng:NextNumber(plot.PenMin.Z, plot.PenMax.Z)
	model:PivotTo(CFrame.new(x, 0.2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))

	model:SetAttribute("Uid", creature.uid)
	model:SetAttribute("OwnerId", session.UserId)
	model:SetAttribute("DisplayName", def.Name)
	model:SetAttribute("Rarity", def.Rarity)
	model:SetAttribute("Mutation", creature.mutation)
	model:SetAttribute("SizeId", creature.sizeId)
	model:SetAttribute("PenMin", plot.PenMin)
	model:SetAttribute("PenMax", plot.PenMax)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FeedPrompt"
	prompt.ActionText = "Feed"
	prompt.ObjectText = def.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ClientAction", "OpenFeed")
	prompt:SetAttribute("Uid", creature.uid)
	prompt:SetAttribute("OwnerOnly", session.UserId)
	prompt.Parent = model.PrimaryPart

	model.Parent = plot.Pen
	CollectionService:AddTag(model, "PenCreature")
	updateAttributes(session, creature)
end

function CreatureService:RemoveModel(session: any, uid: string)
	local model = modelFor(session, uid)
	if model then
		model:Destroy()
	end
end

function CreatureService:OnCreatureAdded(session: any, creature: any)
	if creature.placed then
		CreatureService:SpawnModel(session, creature)
	end
	CreatureService:InvalidateBonuses(session)
	services.DataService:MarkDirty(session.Player)
end

local function onStageUp(session: any, creature: any)
	local def = Creatures.ById[creature.species]
	local stage = Growth.Stage(creature)
	CreatureService:SpawnModel(session, creature)
	CreatureService:InvalidateBonuses(session)
	services.QuestService:Progress(session, "StageUp", 1)
	local text = string.format("✨ %s вырос: %s!", def.Name, stage)
	if stage == "Adult" and def.Trait then
		text ..= " Бонус: " .. def.Trait.Text
	end
	services.DataService:Notify(session.Player, text, "success")
end

------------------------------------------------------------------------
-- Касса
------------------------------------------------------------------------

function CreatureService:CollectVault(player: Player)
	local session = services.DataService:GetSession(player)
	if not session then
		return
	end
	local profile = session.Profile
	local amount = math.floor(profile.vault)
	if amount < 1 then
		return
	end
	profile.vault -= amount
	profile.coins += amount
	profile.stats.earned += amount
	if session.Plot then
		session.Plot.Model:SetAttribute("Vault", math.floor(profile.vault))
	end
	services.DataService:Notify(player, "+" .. Format.Money(amount), "money")
	services.TutorialService:Reached(session, "collect")
	services.DataService:MarkDirty(player)
end

------------------------------------------------------------------------
-- Тик роста и дохода
------------------------------------------------------------------------

local function tickSession(session: any, now: number, maxSeconds: number?, incomeMult: number): number
	local profile = session.Profile
	local bonus = CreatureService:GetBonuses(session).Income
	local earned = 0
	local stageUps = {}
	for _, creature in profile.creatures do
		local elapsed, fedTime, stageUp = Growth.Simulate(creature, now, maxSeconds)
		if creature.placed and elapsed > 0 then
			earned += Growth.EarnedOver(creature, elapsed, fedTime, bonus) * incomeMult
		end
		if stageUp then
			table.insert(stageUps, creature)
		end
	end
	profile.vault += earned
	for _, creature in stageUps do
		onStageUp(session, creature)
	end
	return earned
end

------------------------------------------------------------------------
-- Действия
------------------------------------------------------------------------

local function feed(session: any, uid: string, foodId: string): (boolean, string?)
	local profile = session.Profile
	local creature = profile.creatures[uid]
	local food = Foods.ById[foodId]
	if not creature or not food then
		return false, "Неверный запрос"
	end
	if (profile.food[foodId] or 0) < 1 then
		return false, "Нет этой еды"
	end
	Growth.Simulate(creature, os.time())
	local result = Growth.ApplyFood(creature, food)
	if not result.ok then
		return false, result.reason
	end
	Profile.TakeFood(profile, foodId, 1)
	services.QuestService:Progress(session, "Feed", 1)
	services.TutorialService:Reached(session, "feed")
	if result.stageUp then
		onStageUp(session, creature)
	else
		updateAttributes(session, creature)
	end
	return true, nil
end

function CreatureService:Init(registry)
	services = registry
end

function CreatureService:Start()
	local NetService = services.NetService
	local Check = NetService.Check

	NetService:Handle("Feed", function(_player, session, payload)
		if not Check.Table(payload) or not Check.String(payload.uid, 16) or not Check.String(payload.food, 32) then
			return false, "Неверный запрос"
		end
		return feed(session, payload.uid, payload.food)
	end)

	NetService:Handle("Place", function(_player, session, payload)
		if not Check.Table(payload) or not Check.String(payload.uid, 16) then
			return false, "Неверный запрос"
		end
		local profile = session.Profile
		local creature = profile.creatures[payload.uid]
		if not creature then
			return false, "Существо не найдено"
		end
		if creature.placed then
			return false, "Уже в загоне"
		end
		local _, placed = Profile.CountCreatures(profile)
		if placed >= profile.upgrades.pens then
			return false, "Загон полон — улучшите его"
		end
		creature.placed = true
		creature.lastTick = os.time()
		CreatureService:SpawnModel(session, creature)
		CreatureService:InvalidateBonuses(session)
		return true, nil
	end)

	NetService:Handle("Store", function(_player, session, payload)
		if not Check.Table(payload) or not Check.String(payload.uid, 16) then
			return false, "Неверный запрос"
		end
		local creature = session.Profile.creatures[payload.uid]
		if not creature or not creature.placed then
			return false, "Существо не в загоне"
		end
		-- Досчитываем доход до момента перемещения
		tickSession(session, os.time(), nil, 1)
		creature.placed = false
		CreatureService:RemoveModel(session, creature.uid)
		CreatureService:InvalidateBonuses(session)
		return true, nil
	end)

	NetService:Handle("Sell", function(player, session, payload)
		if not Check.Table(payload) or not Check.String(payload.uid, 16) then
			return false, "Неверный запрос"
		end
		local profile = session.Profile
		local creature = profile.creatures[payload.uid]
		if not creature then
			return false, "Существо не найдено"
		end
		tickSession(session, os.time(), nil, 1)
		local value = Growth.SellValue(creature)
		profile.creatures[payload.uid] = nil
		profile.coins += value
		profile.stats.earned += value
		CreatureService:RemoveModel(session, payload.uid)
		CreatureService:InvalidateBonuses(session)
		services.DataService:Notify(player, "Продано за " .. Format.Money(value), "money")
		return true, nil, { value = value }
	end)

	services.DataService:OnLoaded(function(player, session)
		local profile = session.Profile
		local now = os.time()
		local offline = if profile.lastOnline > 0 then now - profile.lastOnline else 0
		local earned = tickSession(session, now, Game.Offline.MaxSeconds, Game.Offline.IncomeMult)
		if offline > 60 and earned >= 1 then
			services.DataService:Notify(player, string.format("Пока вас не было (%s): +%s в кассе базы",
				Format.Time(math.min(offline, Game.Offline.MaxSeconds)), Format.Money(earned)), "money")
		end
		for _, creature in profile.creatures do
			if creature.placed then
				CreatureService:SpawnModel(session, creature)
			end
		end
		CreatureService:InvalidateBonuses(session)
	end)

	services.DataService:OnRemoving(function(_player, session)
		tickSession(session, os.time(), nil, 1)
	end)

	services.DataService:AddViewContributor(function(session, runtime)
		runtime.incomePerSecond = CreatureService:IncomePerSecond(session)
		runtime.bonuses = CreatureService:GetBonuses(session)
	end)

	-- Тик: раз в секунду рост/голод/доход, обновление атрибутов моделей
	task.spawn(function()
		local syncCounter = 0
		while true do
			task.wait(1)
			syncCounter += 1
			local now = os.time()
			for _, session in services.DataService.Sessions do
				if session.Loaded and not session.Released then
					tickSession(session, now, 5, 1)
					if session.Plot then
						session.Plot.Model:SetAttribute("Vault", math.floor(session.Profile.vault))
						for _, creature in session.Profile.creatures do
							if creature.placed then
								updateAttributes(session, creature)
							end
						end
					end
					-- Голод влияет на доход, поэтому периодически отправляем свежий снимок
					if syncCounter % 10 == 0 then
						services.DataService:MarkDirty(session.Player)
					end
				end
			end
		end
	end)
end

return CreatureService
