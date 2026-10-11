--[[
	IncubatorService — помещение яиц в инкубаторы, таймеры, ускорение и вылупление.

	Таймер хранится как startedAt + duration (os.time), поэтому продолжает идти
	офлайн и не требует тиков. Результат вылупления определяется только на сервере
	в момент открытия. Запись инкубатора удаляется ДО выдачи существа, а обработчик
	не уступает управление (без yield), поэтому повторный запрос не выдаст награду дважды.

	record.transit = userId вора — яйцо сейчас несут (см. StealService). Оно остаётся
	в профиле владельца до доставки на базу вора: так при сбоях яйцо не дублируется.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Rarities = require(Shared.Config.Rarities)
local Creatures = require(Shared.Config.Creatures)
local Game = require(Shared.Config.Game)
local Economy = require(Shared.Logic.Economy)
local Growth = require(Shared.Logic.Growth)
local Profile = require(Shared.Logic.Profile)
local WeightedRandom = require(Shared.Logic.WeightedRandom)
local EggModel = require(Shared.Visual.EggModel)
local Net = require(Shared.Net)

local IncubatorService = {}

local services
local rng = Random.new()
local hatchedEvent: RemoteEvent

local function slotKey(slot: number): string
	return tostring(slot)
end

function IncubatorService:Record(session: any, slot: number): any?
	return session.Profile.incubators[slotKey(slot)]
end

function IncubatorService:IsReady(record: any, now: number?): boolean
	return (now or os.time()) >= record.startedAt + record.duration
end

function IncubatorService:RefreshSlot(session: any, slot: number)
	local plot = session.Plot
	if not plot then
		return
	end
	local inc = plot.Incubators[slot]
	if not inc then
		return
	end
	local model = inc.Model
	local unlocked = slot <= session.Profile.upgrades.incubators
	local record = IncubatorService:Record(session, slot)

	local existing = model:FindFirstChild("Egg")
	local wantEgg = record and not record.transit
	if existing and (not wantEgg or existing:GetAttribute("EggUid") ~= record.uid) then
		existing:Destroy()
		existing = nil
	end
	if wantEgg and not existing then
		local egg = EggModel.Build(record.id, 0.85)
		egg.Name = "Egg"
		egg:SetAttribute("EggUid", record.uid)
		for _, part in egg:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = false
			end
		end
		egg:PivotTo(inc.Anchor.CFrame - Vector3.new(0, 0.5, 0))
		egg.Parent = model
	end

	local state
	if not unlocked then
		state = "locked"
	elseif not record then
		state = "empty"
	elseif record.transit then
		state = "stolen"
	elseif IncubatorService:IsReady(record) then
		state = "ready"
	else
		state = "incubating"
	end
	model:SetAttribute("State", state)
	model:SetAttribute("EggId", if record then record.id else nil)
	model:SetAttribute("StartedAt", if record then record.startedAt else nil)
	model:SetAttribute("Duration", if record then record.duration else nil)

	local prompt = inc.OwnerPrompt
	prompt.Enabled = unlocked and state ~= "stolen"
	if state == "ready" then
		prompt.ActionText = "Hatch"
		prompt.ObjectText = Eggs.ById[record.id].Name
		prompt:SetAttribute("ClientAction", nil)
	else
		prompt.ActionText = if state == "empty" then "Incubate" else "View"
		prompt.ObjectText = if record then Eggs.ById[record.id].Name else "Incubator"
		prompt:SetAttribute("ClientAction", "OpenEggs")
	end

	local steal = inc.StealPrompt
	steal.Enabled = (state == "incubating" or state == "ready") and not services.StealService:IsProtected(session)
	if record then
		local egg = Eggs.ById[record.id]
		steal.ObjectText = egg.Name
		steal.HoldDuration = Rarities.ById[egg.Rarity].StealHold
	end
end

function IncubatorService:RefreshAll(session: any)
	if not session.Plot then
		return
	end
	for slot = 1, #session.Plot.Incubators do
		IncubatorService:RefreshSlot(session, slot)
	end
end

local function freeSlot(session: any): number?
	for slot = 1, session.Profile.upgrades.incubators do
		if not IncubatorService:Record(session, slot) then
			return slot
		end
	end
	return nil
end

-- Положить яйцо из инвентаря в инкубатор. Возвращает слот или nil.
function IncubatorService:Incubate(session: any, eggUid: string, slot: number?): (boolean, string?)
	local profile = session.Profile
	local index
	for i, egg in profile.eggs do
		if egg.uid == eggUid then
			index = i
			break
		end
	end
	if not index then
		return false, "Яйцо не найдено"
	end
	local target = slot or freeSlot(session)
	if not target then
		return false, "Все инкубаторы заняты"
	end
	if target > profile.upgrades.incubators or IncubatorService:Record(session, target) then
		return false, "Инкубатор занят"
	end
	local egg = table.remove(profile.eggs, index)
	local bonuses = services.CreatureService:GetBonuses(session)
	profile.incubators[slotKey(target)] = {
		uid = egg.uid,
		id = egg.id,
		startedAt = os.time(),
		duration = Economy.HatchDuration(egg.id, profile.upgrades.incubatorSpeed, bonuses.Incubate),
	}
	IncubatorService:RefreshSlot(session, target)
	services.TutorialService:Reached(session, "incubate")
	return true, nil
end

-- Автоматически кладёт яйца из инвентаря в свободные инкубаторы
function IncubatorService:AutoFill(session: any)
	local changed = false
	while #session.Profile.eggs > 0 do
		local slot = freeSlot(session)
		if not slot then
			break
		end
		local ok = IncubatorService:Incubate(session, session.Profile.eggs[1].uid, slot)
		if not ok then
			break
		end
		changed = true
	end
	return changed
end

local function rollCreature(eggId: string): any
	local egg = Eggs.ById[eggId]
	local entries = {}
	for _, entry in egg.Creatures do
		table.insert(entries, { Item = entry.Creature, Weight = entry.Weight })
	end
	local species = WeightedRandom.Pick(entries, rng) :: string

	local sizeEntries = {}
	for _, size in Game.Sizes do
		table.insert(sizeEntries, { Item = size, Weight = size.Weight })
	end
	local size = WeightedRandom.Pick(sizeEntries, rng) :: any

	local night = services.DayNightService:IsNight()
	local mutationEntries = {}
	for _, mutation in Game.Mutations do
		local weight = mutation.Weight * (if night then mutation.NightMult else 1)
		table.insert(mutationEntries, { Item = mutation.Id, Weight = weight })
	end
	local mutation = WeightedRandom.Pick(mutationEntries, rng) :: string

	return species, size, mutation
end

function IncubatorService:Hatch(session: any, slot: number): (boolean, string?)
	local profile = session.Profile
	local record = IncubatorService:Record(session, slot)
	if not record then
		return false, "Инкубатор пуст"
	end
	if record.transit then
		return false, "Яйцо сейчас крадут!"
	end
	if not IncubatorService:IsReady(record) then
		return false, "Ещё не готово"
	end
	local total = Profile.CountCreatures(profile)
	if total >= Game.Inventory.MaxCreatures then
		return false, "Слишком много существ — продайте кого-нибудь"
	end

	-- Сначала забираем яйцо, потом выдаём награду
	profile.incubators[slotKey(slot)] = nil
	local species, size, mutation = rollCreature(record.id)
	local _, placedCount = Profile.CountCreatures(profile)
	local now = os.time()
	local creature = {
		uid = Profile.NewUid(profile),
		species = species,
		size = size.Value,
		sizeId = size.Id,
		mutation = mutation,
		growth = 0,
		fullness = Game.Growth.StartFullness,
		ascended = false,
		placed = placedCount < profile.upgrades.pens,
		lastTick = now,
	}
	profile.creatures[creature.uid] = creature
	profile.stats.hatched += 1

	local discovered = false
	local reward = 0
	if not profile.index[species] then
		profile.index[species] = true
		discovered = true
		reward = math.floor(Creatures.ById[species].BaseIncome * Game.Index.DiscoveryRewardSeconds)
		reward = math.max(reward, 50)
		profile.coins += reward
	end

	IncubatorService:RefreshSlot(session, slot)
	services.CreatureService:OnCreatureAdded(session, creature)
	services.QuestService:Progress(session, "Hatch", 1)
	services.TutorialService:Reached(session, "hatch")

	hatchedEvent:FireClient(session.Player, {
		eggId = record.id,
		creature = creature,
		discovered = discovered,
		reward = reward,
		stage = Growth.Stage(creature),
	})
	return true, nil
end

function IncubatorService:OnOwnerPrompt(player: Player, plotIndex: number, slot: number)
	local session = services.DataService:GetSession(player)
	if not session or not session.Plot or session.Plot.Index ~= plotIndex then
		return
	end
	local record = IncubatorService:Record(session, slot)
	if record and not record.transit and IncubatorService:IsReady(record) then
		local ok, message = IncubatorService:Hatch(session, slot)
		if not ok and message then
			services.DataService:Notify(player, message, "error")
		end
		services.DataService:MarkDirty(player)
	end
end

function IncubatorService:Init(registry)
	services = registry
	hatchedEvent = Net.Event("Hatched")
end

function IncubatorService:Start()
	local Net_ = services.NetService
	local Check = Net_.Check

	Net_:Handle("Incubate", function(_player, session, payload)
		if not Check.Table(payload) or not Check.String(payload.uid, 16) then
			return false, "Неверный запрос"
		end
		local slot = payload.slot
		if slot ~= nil and not Check.Int(slot, 1, 6) then
			return false, "Неверный слот"
		end
		return IncubatorService:Incubate(session, payload.uid, slot)
	end)

	Net_:Handle("Hatch", function(_player, session, payload)
		if not Check.Table(payload) or not Check.Int(payload.slot, 1, 6) then
			return false, "Неверный запрос"
		end
		return IncubatorService:Hatch(session, payload.slot)
	end)

	Net_:Handle("HatchAll", function(_player, session)
		local count = 0
		for slot = 1, session.Profile.upgrades.incubators do
			local record = IncubatorService:Record(session, slot)
			if record and not record.transit and IncubatorService:IsReady(record) then
				local ok = IncubatorService:Hatch(session, slot)
				if ok then
					count += 1
				end
			end
		end
		if count == 0 then
			return false, "Нет готовых яиц"
		end
		return true, nil
	end)

	Net_:Handle("SkipHatch", function(_player, session, payload)
		if not Check.Table(payload) or not Check.Int(payload.slot, 1, 6) then
			return false, "Неверный запрос"
		end
		local record = IncubatorService:Record(session, payload.slot)
		if not record or record.transit then
			return false, "Нечего ускорять"
		end
		local now = os.time()
		local remaining = record.startedAt + record.duration - now
		if remaining <= 0 then
			return false, "Уже готово"
		end
		local cost = Economy.SkipCost(record.id, remaining, record.duration)
		if session.Profile.coins < cost then
			return false, "Не хватает монет"
		end
		session.Profile.coins -= cost
		record.startedAt = now - record.duration
		IncubatorService:RefreshSlot(session, payload.slot)
		return true, nil
	end)

	services.DataService:OnLoaded(function(_player, session)
		-- Метки transit не переживают перезапуск сервера
		for _, record in session.Profile.incubators do
			record.transit = nil
		end
		IncubatorService:RefreshAll(session)
	end)

	-- Раз в секунду переключаем визуал «incubating -> ready»
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for _, session in services.DataService.Sessions do
				if session.Loaded and session.Plot then
					for slot = 1, session.Profile.upgrades.incubators do
						local record = IncubatorService:Record(session, slot)
						local inc = session.Plot.Incubators[slot]
						if record and not record.transit and inc and inc.Model:GetAttribute("State") == "incubating"
							and IncubatorService:IsReady(record, now) then
							IncubatorService:RefreshSlot(session, slot)
							services.DataService:MarkDirty(session.Player)
							services.DataService:Notify(session.Player, "🥚 " .. Eggs.ById[record.id].Name .. " готово к вылуплению!", "success")
						end
					end
				end
			end
		end
	end)

	services.DataService:AddViewContributor(function(session, runtime)
		local ready = 0
		for _, record in session.Profile.incubators do
			if not record.transit and IncubatorService:IsReady(record) then
				ready += 1
			end
		end
		runtime.readyEggs = ready
	end)
end

return IncubatorService
