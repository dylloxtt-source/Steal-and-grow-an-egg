--[[
	Зоны дорожки (биомы). Чем дальше от базы — тем редче яйца и быстрее стражи.

	EggWeights — веса редкостей яиц, появляющихся в зоне (ночью Rare+ умножаются
	на Game.DayNight.NightLuck, Secret — дополнительно на NightSecretMult).
	Guardian — страж зоны: догоняет игроков, несущих яйцо. nil = стражей нет.
]]

export type Guardian = {
	Count: number,
	Speed: number,
	Aggro: number,
	Catch: number,
	Creature: string, -- модель стража берётся из существ
	Scale: number,
}

export type Zone = {
	Id: string,
	Name: string,
	Order: number,
	ZStart: number,
	ZEnd: number,
	Ground: { Color3 },
	Wall: { Color3 },
	EggWeights: { [string]: number },
	MaxEggs: number,
	EggRespawn: number,
	MaxFood: number,
	Guardian: Guardian?,
	RecommendedSpeed: number,
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { Zone } = {
	{ Id = "meadow", Name = "Meadow", Order = 1, ZStart = 40, ZEnd = 260,
		Ground = { c(96, 200, 60), c(110, 215, 70) }, Wall = { c(178, 120, 70), c(160, 104, 58) },
		EggWeights = { Common = 80, Uncommon = 18, Rare = 2 },
		MaxEggs = 10, EggRespawn = 5, MaxFood = 6, Guardian = nil, RecommendedSpeed = 16 },
	{ Id = "dunes", Name = "Dunes", Order = 2, ZStart = 260, ZEnd = 480,
		Ground = { c(236, 206, 140), c(226, 192, 124) }, Wall = { c(200, 160, 100), c(186, 146, 88) },
		EggWeights = { Common = 30, Uncommon = 50, Rare = 17, Epic = 3 },
		MaxEggs = 9, EggRespawn = 7, MaxFood = 5,
		Guardian = { Count = 1, Speed = 20, Aggro = 45, Catch = 5, Creature = "sandsnap", Scale = 2.2 },
		RecommendedSpeed = 24 },
	{ Id = "frost", Name = "Frostpeak", Order = 3, ZStart = 480, ZEnd = 700,
		Ground = { c(235, 245, 255), c(210, 232, 250) }, Wall = { c(160, 190, 220), c(140, 172, 205) },
		EggWeights = { Uncommon = 25, Rare = 50, Epic = 22, Legendary = 3 },
		MaxEggs = 8, EggRespawn = 9, MaxFood = 5,
		Guardian = { Count = 1, Speed = 26, Aggro = 50, Catch = 5, Creature = "frostpaw", Scale = 2.4 },
		RecommendedSpeed = 32 },
	{ Id = "magma", Name = "Magma Rift", Order = 4, ZStart = 700, ZEnd = 920,
		Ground = { c(70, 60, 60), c(56, 48, 50) }, Wall = { c(90, 50, 40), c(70, 38, 32) },
		EggWeights = { Rare = 30, Epic = 50, Legendary = 18, Mythic = 2 },
		MaxEggs = 7, EggRespawn = 11, MaxFood = 4,
		Guardian = { Count = 2, Speed = 33, Aggro = 55, Catch = 5.5, Creature = "emberhorn", Scale = 2.2 },
		RecommendedSpeed = 42 },
	{ Id = "starfall", Name = "Starfall", Order = 5, ZStart = 920, ZEnd = 1140,
		Ground = { c(55, 40, 110), c(42, 30, 90) }, Wall = { c(80, 60, 150), c(64, 46, 128) },
		EggWeights = { Epic = 30, Legendary = 50, Mythic = 18, Secret = 2 },
		MaxEggs = 6, EggRespawn = 14, MaxFood = 3,
		Guardian = { Count = 2, Speed = 42, Aggro = 60, Catch = 6, Creature = "nebulynx", Scale = 2.4 },
		RecommendedSpeed = 55 },
}

local byId: { [string]: Zone } = {}
for _, zone in list do
	byId[zone.Id] = zone
end

local function zoneAtZ(z: number): Zone?
	for _, zone in list do
		if z >= zone.ZStart and z < zone.ZEnd then
			return zone
		end
	end
	return nil
end

return {
	List = list,
	ById = byId,
	AtZ = zoneAtZ,
}
