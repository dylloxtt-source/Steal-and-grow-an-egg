--[[
	Общие игровые константы: лобби, лифты, матчи, тайминги.
	Баланс башен/врагов/экономики — в соседних модулях Config.
]]

local Game = {}

Game.DataVersion = 1
Game.AutosaveInterval = 120

Game.Lobby = {
	Origin = Vector3.new(0, 0, 0),
	Spawn = Vector3.new(0, 0, 40),
}

Game.Elevator = {
	Count = 4,
	MinCapacity = 1,
	MaxCapacity = 4,
	DefaultCapacity = 4,
	WaitTime = 25, -- ожидание после входа первого игрока
	StartTime = 5, -- обратный отсчёт, когда группа заполнена / все готовы / лидер нажал Start
	RevertTime = 10, -- если кто-то вышел во время отсчёта
	InMatchHold = 3, -- сколько лифт показывает «Матч запущен», прежде чем снова открыться
}

Game.Match = {
	MaxConcurrent = 8,
	SlotOrigin = Vector3.new(1200, 0, 0),
	SlotSpacing = 400,
	TickRate = 20, -- шагов симуляции в секунду
	PrepTime = 20, -- до первой волны
	Intermission = 7, -- между волнами
	WaveTimeLimitBase = 75, -- волна принудительно сменяется, если длится дольше
	WaveTimeLimitPerWave = 2,
	ResultsTime = 30, -- через сколько игроков автоматически вернёт в лобби
	EnemyLifetimeFactor = 4, -- враг «застрял», если идёт дольше (длина пути / скорость) * фактор
	StateRate = 5, -- снимков состояния матча в секунду
	SyncInterval = 1.5, -- период синхронизации положения врагов с клиентами
	TeamHpScale = 0.5, -- +50 % здоровья врагов за каждого игрока сверх первого
}

return Game
