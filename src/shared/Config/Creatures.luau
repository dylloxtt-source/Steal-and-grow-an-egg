--[[
	Существа. Все имена и дизайн — собственные.

	Archetype определяет, из каких блоков строится модель (см. Visual/CreatureModel):
	  "quad"   — четвероногое
	  "bird"   — птица с крыльями
	  "blob"   — круглый слайм/жук
	  "wyrm"   — змей/дракон из сегментов

	BaseIncome — монет в секунду на стадии Baby при размере 1.0 без мутации.
	GrowthRate — множитель пассивного роста (1 = 1 очко роста в секунду, пока сыт).
	Trait — бонус, который начинает работать со стадии Adult, пока существо в загоне.
]]

export type Trait = {
	Kind: string, -- "Speed" | "Luck" | "Incubate" | "Income" | "Lock" | "Forage"
	Value: number,
	Text: string,
}

export type Creature = {
	Id: string,
	Name: string,
	Rarity: string,
	Archetype: string,
	Body: Color3,
	Accent: Color3,
	BaseIncome: number,
	GrowthRate: number,
	Trait: Trait?,
	Description: string,
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { Creature } = {
	-- Common (Meadow Egg)
	{ Id = "pebblepup", Name = "Pebblepup", Rarity = "Common", Archetype = "quad",
		Body = c(150, 150, 160), Accent = c(95, 95, 105), BaseIncome = 1, GrowthRate = 1.2,
		Description = "Каменный щенок. Грызёт гальку и обожает гранулы." },
	{ Id = "mossbun", Name = "Mossbun", Rarity = "Common", Archetype = "quad",
		Body = c(120, 190, 90), Accent = c(70, 130, 50), BaseIncome = 1.5, GrowthRate = 1,
		Trait = { Kind = "Forage", Value = 0.05, Text = "+5% шанс двойной еды при сборе" },
		Description = "Пушистый кролик, поросший мхом." },
	{ Id = "clucklet", Name = "Clucklet", Rarity = "Common", Archetype = "bird",
		Body = c(255, 240, 200), Accent = c(255, 150, 40), BaseIncome = 2.5, GrowthRate = 0.9,
		Description = "Цыплёнок, который считает себя драконом." },

	-- Uncommon (Dune Egg)
	{ Id = "dunehopper", Name = "Dunehopper", Rarity = "Uncommon", Archetype = "quad",
		Body = c(230, 190, 120), Accent = c(170, 120, 60), BaseIncome = 7, GrowthRate = 1.1,
		Trait = { Kind = "Speed", Value = 1, Text = "+1 к скорости" },
		Description = "Пустынный тушканчик-спринтер." },
	{ Id = "cactoad", Name = "Cactoad", Rarity = "Uncommon", Archetype = "blob",
		Body = c(80, 170, 90), Accent = c(250, 120, 170), BaseIncome = 9, GrowthRate = 1,
		Description = "Жаба-кактус. Колючая, но добрая." },
	{ Id = "sandsnap", Name = "Sandsnap", Rarity = "Uncommon", Archetype = "wyrm",
		Body = c(210, 160, 90), Accent = c(120, 80, 40), BaseIncome = 13, GrowthRate = 0.9,
		Trait = { Kind = "Lock", Value = 5, Text = "+5 сек. к замку базы" },
		Description = "Песчаный змей, охраняющий норы." },

	-- Rare (Frost Egg)
	{ Id = "frostpaw", Name = "Frostpaw", Rarity = "Rare", Archetype = "quad",
		Body = c(220, 240, 255), Accent = c(110, 170, 230), BaseIncome = 45, GrowthRate = 1.1,
		Trait = { Kind = "Speed", Value = 2, Text = "+2 к скорости" },
		Description = "Снежный лис с ледяными лапами." },
	{ Id = "snowpuff", Name = "Snowpuff", Rarity = "Rare", Archetype = "blob",
		Body = c(250, 250, 255), Accent = c(150, 200, 255), BaseIncome = 60, GrowthRate = 1,
		Trait = { Kind = "Incubate", Value = 0.03, Text = "-3% время инкубации" },
		Description = "Снежок, который случайно ожил." },
	{ Id = "glacimoth", Name = "Glacimoth", Rarity = "Rare", Archetype = "bird",
		Body = c(150, 220, 255), Accent = c(60, 120, 220), BaseIncome = 85, GrowthRate = 0.9,
		Description = "Ледяной мотылёк с хрустальными крыльями." },

	-- Epic (Magma Egg)
	{ Id = "lavaling", Name = "Lavaling", Rarity = "Epic", Archetype = "blob",
		Body = c(255, 110, 30), Accent = c(60, 30, 30), BaseIncome = 300, GrowthRate = 1.1,
		Description = "Капля живой лавы." },
	{ Id = "cindercrab", Name = "Cindercrab", Rarity = "Epic", Archetype = "quad",
		Body = c(200, 60, 40), Accent = c(255, 180, 60), BaseIncome = 400, GrowthRate = 1,
		Trait = { Kind = "Lock", Value = 10, Text = "+10 сек. к замку базы" },
		Description = "Краб с панцирем из застывшего пепла." },
	{ Id = "emberhorn", Name = "Emberhorn", Rarity = "Epic", Archetype = "quad",
		Body = c(70, 40, 40), Accent = c(255, 90, 20), BaseIncome = 600, GrowthRate = 0.9,
		Trait = { Kind = "Speed", Value = 3, Text = "+3 к скорости" },
		Description = "Огненный носорог. Разгоняется быстрее всех." },

	-- Legendary (Star Egg)
	{ Id = "nebulynx", Name = "Nebulynx", Rarity = "Legendary", Archetype = "quad",
		Body = c(70, 50, 140), Accent = c(255, 120, 230), BaseIncome = 2200, GrowthRate = 1.1,
		Trait = { Kind = "Luck", Value = 0.1, Text = "+10% удача редких яиц" },
		Description = "Рысь, сотканная из туманности." },
	{ Id = "cometail", Name = "Cometail", Rarity = "Legendary", Archetype = "wyrm",
		Body = c(80, 200, 255), Accent = c(255, 255, 255), BaseIncome = 3000, GrowthRate = 1,
		Trait = { Kind = "Income", Value = 0.05, Text = "+5% дохода всей базы" },
		Description = "Змей с хвостом кометы." },
	{ Id = "starwing", Name = "Starwing", Rarity = "Legendary", Archetype = "bird",
		Body = c(255, 220, 90), Accent = c(255, 255, 220), BaseIncome = 4500, GrowthRate = 0.9,
		Trait = { Kind = "Speed", Value = 4, Text = "+4 к скорости" },
		Description = "Звёздная птица. Говорят, приносит удачу." },

	-- Mythic (Prism Egg)
	{ Id = "prismadon", Name = "Prismadon", Rarity = "Mythic", Archetype = "wyrm",
		Body = c(120, 255, 230), Accent = c(255, 120, 255), BaseIncome = 16000, GrowthRate = 1,
		Trait = { Kind = "Incubate", Value = 0.08, Text = "-8% время инкубации" },
		Description = "Кристальный дракон, преломляющий свет." },
	{ Id = "aurorawl", Name = "Aurorawl", Rarity = "Mythic", Archetype = "bird",
		Body = c(60, 220, 160), Accent = c(150, 90, 255), BaseIncome = 24000, GrowthRate = 0.9,
		Trait = { Kind = "Luck", Value = 0.2, Text = "+20% удача редких яиц" },
		Description = "Сова северного сияния." },

	-- Secret (Void Egg)
	{ Id = "nullwyrm", Name = "Nullwyrm", Rarity = "Secret", Archetype = "wyrm",
		Body = c(25, 20, 35), Accent = c(170, 60, 255), BaseIncome = 90000, GrowthRate = 1,
		Trait = { Kind = "Income", Value = 0.1, Text = "+10% дохода всей базы" },
		Description = "Пустотный змей. Его видели лишь ночью." },
	{ Id = "voidmaw", Name = "Voidmaw", Rarity = "Secret", Archetype = "blob",
		Body = c(10, 10, 15), Accent = c(255, 40, 90), BaseIncome = 140000, GrowthRate = 0.9,
		Trait = { Kind = "Luck", Value = 0.3, Text = "+30% удача редких яиц" },
		Description = "Пасть пустоты. Ест звёзды на завтрак." },
}

local byId: { [string]: Creature } = {}
for _, creature in list do
	assert(byId[creature.Id] == nil, "Duplicate creature id " .. creature.Id)
	byId[creature.Id] = creature
end

return {
	List = list,
	ById = byId,
}
