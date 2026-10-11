--[[
	Яйца. Weight — относительный вес существа; шансы нормализуются автоматически
	(см. Logic/WeightedRandom), поэтому сумма весов может быть любой.

	Price = nil — яйцо нельзя купить, только найти/украсть.
	HatchTime — секунды до вылупления без бонусов.
	StealRefund — доля стоимости, которую получает владелец украденного яйца
	(страховка, чтобы кража не была слишком болезненной).
]]

export type EggEntry = { Creature: string, Weight: number }

export type Egg = {
	Id: string,
	Name: string,
	Rarity: string,
	Price: number?,
	Value: number, -- условная ценность (для страховки и наград), = цене или оценке
	HatchTime: number,
	Shell: Color3,
	Spots: Color3,
	Creatures: { EggEntry },
	Source: string,
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { Egg } = {
	{ Id = "meadow_egg", Name = "Meadow Egg", Rarity = "Common", Price = 100, Value = 100, HatchTime = 30,
		Shell = c(245, 240, 225), Spots = c(120, 200, 90), Source = "Луг, магазин",
		Creatures = {
			{ Creature = "pebblepup", Weight = 45 },
			{ Creature = "mossbun", Weight = 35 },
			{ Creature = "clucklet", Weight = 19 },
			{ Creature = "dunehopper", Weight = 1 },
		} },
	{ Id = "dune_egg", Name = "Dune Egg", Rarity = "Uncommon", Price = 2500, Value = 2500, HatchTime = 90,
		Shell = c(240, 210, 150), Spots = c(190, 120, 60), Source = "Дюны, магазин",
		Creatures = {
			{ Creature = "dunehopper", Weight = 45 },
			{ Creature = "cactoad", Weight = 35 },
			{ Creature = "sandsnap", Weight = 19 },
			{ Creature = "frostpaw", Weight = 1 },
		} },
	{ Id = "frost_egg", Name = "Frost Egg", Rarity = "Rare", Price = 18000, Value = 18000, HatchTime = 240,
		Shell = c(210, 235, 255), Spots = c(90, 160, 240), Source = "Ледяной пик, магазин",
		Creatures = {
			{ Creature = "frostpaw", Weight = 45 },
			{ Creature = "snowpuff", Weight = 35 },
			{ Creature = "glacimoth", Weight = 19 },
			{ Creature = "lavaling", Weight = 1 },
		} },
	{ Id = "magma_egg", Name = "Magma Egg", Rarity = "Epic", Price = 140000, Value = 140000, HatchTime = 600,
		Shell = c(60, 45, 45), Spots = c(255, 110, 30), Source = "Магмовый разлом, магазин",
		Creatures = {
			{ Creature = "lavaling", Weight = 45 },
			{ Creature = "cindercrab", Weight = 35 },
			{ Creature = "emberhorn", Weight = 19 },
			{ Creature = "nebulynx", Weight = 1 },
		} },
	{ Id = "star_egg", Name = "Star Egg", Rarity = "Legendary", Price = 1100000, Value = 1100000, HatchTime = 1500,
		Shell = c(60, 50, 120), Spots = c(255, 220, 90), Source = "Звездопад, магазин",
		Creatures = {
			{ Creature = "nebulynx", Weight = 45 },
			{ Creature = "cometail", Weight = 35 },
			{ Creature = "starwing", Weight = 19 },
			{ Creature = "prismadon", Weight = 1 },
		} },
	{ Id = "prism_egg", Name = "Prism Egg", Rarity = "Mythic", Price = 9000000, Value = 9000000, HatchTime = 3600,
		Shell = c(200, 255, 245), Spots = c(255, 120, 255), Source = "Звездопад (редко), магазин",
		Creatures = {
			{ Creature = "prismadon", Weight = 60 },
			{ Creature = "aurorawl", Weight = 39 },
			{ Creature = "nullwyrm", Weight = 1 },
		} },
	{ Id = "void_egg", Name = "Void Egg", Rarity = "Secret", Price = nil, Value = 60000000, HatchTime = 5400,
		Shell = c(20, 15, 30), Spots = c(170, 60, 255), Source = "Только Звездопад, чаще ночью",
		Creatures = {
			{ Creature = "nullwyrm", Weight = 70 },
			{ Creature = "voidmaw", Weight = 30 },
		} },
}

local byId: { [string]: Egg } = {}
for _, egg in list do
	assert(byId[egg.Id] == nil, "Duplicate egg id " .. egg.Id)
	byId[egg.Id] = egg
end

local byRarity: { [string]: Egg } = {}
for _, egg in list do
	byRarity[egg.Rarity] = egg
end

return {
	List = list,
	ById = byId,
	ByRarity = byRarity,
	StarterEgg = "meadow_egg",
	StealRefund = 0.2,
}
