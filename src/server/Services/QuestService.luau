--[[
	QuestService — ежедневные задания (сброс по UTC-суткам).
	Набор на день детерминирован (seed = userId + день), награда масштабируется
	от текущего дохода базы, чтобы задания оставались полезны на всех этапах.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Quests = require(Shared.Config.Quests)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Logic.Format)

local QuestService = {}

local services

local function today(): number
	return math.floor(os.time() / 86400)
end

local function ensureQuests(session: any)
	local quests = session.Profile.quests
	local day = today()
	if quests.day == day and #quests.list > 0 then
		return
	end
	local rng = Random.new(session.UserId * 1000 + day)
	local pool = table.clone(Quests.List)
	local list = {}
	for _ = 1, math.min(Game.Quests.PerDay, #pool) do
		local quest = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, { id = quest.Id, progress = 0, claimed = false })
	end
	quests.day = day
	quests.list = list
end

function QuestService:Progress(session: any, stat: string, amount: number)
	ensureQuests(session)
	for _, entry in session.Profile.quests.list do
		local quest = Quests.ById[entry.id]
		if quest and quest.Stat == stat and entry.progress < quest.Target then
			entry.progress = math.min(quest.Target, entry.progress + amount)
			if entry.progress >= quest.Target then
				services.DataService:Notify(session.Player, "📜 Задание выполнено! Забери награду", "success")
			end
		end
	end
end

function QuestService:Init(registry)
	services = registry
end

function QuestService:Start()
	services.NetService:Handle("ClaimQuest", function(player, session, payload)
		if type(payload) ~= "table" or type(payload.id) ~= "string" then
			return false, "Неверный запрос"
		end
		ensureQuests(session)
		for _, entry in session.Profile.quests.list do
			if entry.id == payload.id then
				local quest = Quests.ById[entry.id]
				if entry.claimed then
					return false, "Уже получено"
				end
				if entry.progress < quest.Target then
					return false, "Задание не выполнено"
				end
				entry.claimed = true
				local reward = Economy.QuestReward(services.CreatureService:IncomePerSecond(session), quest.RewardSeconds)
				session.Profile.coins += reward
				services.DataService:Notify(player, "📜 +" .. Format.Money(reward), "money")
				return true, nil
			end
		end
		return false, "Задание не найдено"
	end)

	services.DataService:OnLoaded(function(_player, session)
		ensureQuests(session)
	end)

	services.DataService:AddViewContributor(function(session, runtime)
		ensureQuests(session)
		runtime.questDay = session.Profile.quests.day
	end)
end

return QuestService
