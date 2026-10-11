--[[
	Ежедневные задания. Stat — ключ счётчика, который увеличивают сервисы
	через QuestService:Progress(player, stat, amount).
	Награда = max(MinReward, доход базы/сек * RewardSeconds).
]]

export type Quest = {
	Id: string,
	Text: string,
	Stat: string,
	Target: number,
	RewardSeconds: number,
}

local list: { Quest } = {
	{ Id = "grab_eggs", Text = "Подбери %d яиц на дорожке", Stat = "LaneEgg", Target = 5, RewardSeconds = 180 },
	{ Id = "hatch_eggs", Text = "Высиди %d яиц", Stat = "Hatch", Target = 3, RewardSeconds = 240 },
	{ Id = "feed_pets", Text = "Покорми питомцев %d раз", Stat = "Feed", Target = 10, RewardSeconds = 150 },
	{ Id = "harvest", Text = "Собери урожай %d раз", Stat = "Harvest", Target = 4, RewardSeconds = 150 },
	{ Id = "steal", Text = "Укради %d яйцо у игрока", Stat = "Steal", Target = 1, RewardSeconds = 300 },
	{ Id = "bonk", Text = "Выбей яйцо у %d воров/игроков", Stat = "BonkDrop", Target = 2, RewardSeconds = 200 },
	{ Id = "grow", Text = "Вырасти %d существ до новой стадии", Stat = "StageUp", Target = 3, RewardSeconds = 240 },
	{ Id = "pickup_food", Text = "Подбери %d еды на дорожке", Stat = "PickupFood", Target = 8, RewardSeconds = 120 },
}

local byId: { [string]: Quest } = {}
for _, quest in list do
	byId[quest.Id] = quest
end

return {
	List = list,
	ById = byId,
}
