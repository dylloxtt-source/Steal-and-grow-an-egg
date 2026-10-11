--[[
	Экономика. Матчевая валюта (Cash) живёт только внутри матча; постоянная (Gems)
	и опыт сохраняются в DataStore. Все изменения делает сервер.
]]

return {
	StartCash = 800,
	SellRefund = 0.6, -- доля от всего потраченного на башню (покупка + улучшения)
	TowerLimit = 15, -- на игрока
	-- Награда за убийство выдаётся КАЖДОМУ игроку матча (нет «кражи убийств»)
	KillRewardWaveScale = 0.04, -- +4 % к награде за волну
	WaveBonusBase = 120,
	WaveBonusPerWave = 30,
	BossBonus = 250, -- дополнительно каждому за убитого босса

	-- Гемы тратятся в магазине башен (цены — Config/Towers, поле Price)
	Gems = {
		PerWave = 4,
		Victory = 150,
		PerKills = 0.15,
	},
	Xp = {
		PerWave = 10,
		Victory = 200,
		PerLevel = function(level: number): number
			return 250 + level * 150
		end,
	},
}
