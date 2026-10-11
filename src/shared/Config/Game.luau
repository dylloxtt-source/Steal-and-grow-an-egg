--[[
	Общие игровые константы и баланс. Все «магические числа» — здесь.
]]

local Game = {}

Game.DataVersion = 1
Game.StartCoins = 100
Game.AutosaveInterval = 90

Game.Movement = {
	BaseWalkSpeed = 16,
	SpeedPerLevel = 1,
	SlowModeSpeed = 16,
	MaxWalkSpeed = 100,
	StolenExtraPenalty = 0.1, -- украденное яйцо тяжелее
}

Game.Carry = {
	LaneEggDespawn = 30, -- упавшее яйцо с дорожки исчезает через N сек.
	StolenEggReturn = 25, -- упавшее украденное яйцо возвращается владельцу через N сек.
	GrabHold = 0.6,
}

Game.Bonk = {
	Cooldown = 0.8,
	Range = 8,
	StunTime = 1.2,
	Knockback = 55,
}

Game.Steal = {
	VictimCooldown = 60, -- одного игрока нельзя обокрасть чаще
	NewbieProtection = 900, -- секунд общего игрового времени
	LockBase = 45,
	LockPerLevel = 15,
	LockCooldown = 90, -- после окончания замка
}

Game.Growth = {
	-- Пороги очков роста (умножаются на Rarity.GrowthScale)
	Juvenile = 120,
	Adult = 600,
	Stages = { "Baby", "Juvenile", "Adult", "Ascended" },
	StageIncome = { Baby = 1, Juvenile = 2.5, Adult = 6, Ascended = 15 },
	StageScale = { Baby = 0.55, Juvenile = 0.75, Adult = 1, Ascended = 1.2 },
	StageSellMult = { Baby = 1, Juvenile = 2.5, Adult = 6, Ascended = 15 },
	FullnessMax = 100,
	FullnessDecayPerSecond = 100 / 1500, -- 25 минут от полной до пустой
	StartFullness = 60,
	FeedBlockAt = 95, -- выше — существо отказывается от обычной еды
	HungryIncomeMult = 0.5,
}

Game.Offline = {
	MaxSeconds = 8 * 3600,
	IncomeMult = 0.3,
}

Game.Sizes = {
	{ Id = "Tiny", Value = 0.8, Weight = 20 },
	{ Id = "Normal", Value = 1, Weight = 55 },
	{ Id = "Big", Value = 1.2, Weight = 20 },
	{ Id = "Huge", Value = 1.5, Weight = 5 },
}

Game.Mutations = {
	{ Id = "None", Name = "", Mult = 1, Weight = 880, NightMult = 1, Color = nil },
	{ Id = "Silver", Name = "Silver", Mult = 1.25, Weight = 70, NightMult = 1, Color = Color3.fromRGB(210, 220, 235) },
	{ Id = "Golden", Name = "Golden", Mult = 2, Weight = 40, NightMult = 2, Color = Color3.fromRGB(255, 205, 40) },
	{ Id = "Rainbow", Name = "Rainbow", Mult = 3, Weight = 10, NightMult = 2, Color = Color3.fromRGB(255, 100, 200) },
}

Game.SellFactor = 45 -- цена продажи = доход/сек * SellFactor * множители

Game.Index = {
	IncomeBonusPerSpecies = 0.02,
	DiscoveryRewardSeconds = 60, -- награда = BaseIncome * N
}

Game.DayNight = {
	DaySeconds = 270,
	NightSeconds = 90,
	NightLuck = 2, -- множитель весов редкостей Rare+ ночью
	NightSecretMult = 3,
}

Game.Hatch = {
	SkipCostFactor = 0.6, -- цена ускорения = доля оставшегося времени * Value * фактор
	MinSkipCost = 10,
}

Game.Inventory = {
	MaxEggs = 30,
	MaxCreatures = 60,
	MaxFoodStack = 9999,
}

Game.Quests = {
	PerDay = 3,
	MinReward = 150,
}

return Game
