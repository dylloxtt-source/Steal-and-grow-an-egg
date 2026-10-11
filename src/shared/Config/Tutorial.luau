--[[
	Шаги обучения новичка. Сервер продвигает шаг, когда случается событие Key
	(TutorialService:Reached). Клиент показывает подсказку и стрелку к Target.
]]

return {
	Steps = {
		{ Key = "incubate", Text = "Открой меню 🥚 справа и положи стартовое яйцо в инкубатор", Target = "eggs_button" },
		{ Key = "grab", Text = "Беги по дорожке вперёд и подбери яйцо [E]", Target = "lane" },
		{ Key = "deliver", Text = "Отнеси яйцо на свою базу — следи, чтобы его не выбили!", Target = "base" },
		{ Key = "hatch", Text = "Когда таймер закончится, открой яйцо в инкубаторе", Target = "incubator" },
		{ Key = "feed", Text = "Покорми питомца в загоне — сытые растут и приносят больше", Target = "pen" },
		{ Key = "collect", Text = "Встань на золотую кассу, чтобы забрать доход", Target = "vault" },
	},
	Reward = 250,
}
