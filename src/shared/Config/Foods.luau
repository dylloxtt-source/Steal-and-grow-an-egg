--[[
	Еда, семена и усилители.

	Fullness — сколько сытости восстанавливает (из 100).
	Growth   — сколько очков роста даёт сразу.
	BuyPrice — цена в магазине (nil = не продаётся).
	Seed     — параметры семени для фермы (nil = не выращивается).
	Pickup   — зоны дорожки, где еда лежит на земле.
	Catalyst — нужна для перехода Adult -> Ascended.
	IgnoresFullness — можно скормить даже сытому существу (усилители).
]]

export type Seed = { Price: number, GrowTime: number, Yield: number }

export type Food = {
	Id: string,
	Name: string,
	Icon: string,
	Color: Color3,
	Fullness: number,
	Growth: number,
	BuyPrice: number?,
	Seed: Seed?,
	Pickup: { string }?,
	NightOnly: boolean?,
	Catalyst: boolean?,
	IgnoresFullness: boolean?,
	Description: string,
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { Food } = {
	{ Id = "pellet", Name = "Grain Pellet", Icon = "🌾", Color = c(220, 190, 120),
		Fullness = 20, Growth = 15, BuyPrice = 15,
		Description = "Дешёвый базовый корм." },
	{ Id = "berry", Name = "Meadow Berry", Icon = "🫐", Color = c(110, 90, 230),
		Fullness = 30, Growth = 30, BuyPrice = 60,
		Seed = { Price = 40, GrowTime = 60, Yield = 3 }, Pickup = { "meadow" },
		Description = "Ягода с луга. Растёт быстро." },
	{ Id = "dune_fig", Name = "Dune Fig", Icon = "🍐", Color = c(200, 160, 80),
		Fullness = 35, Growth = 70, BuyPrice = 600,
		Seed = { Price = 400, GrowTime = 120, Yield = 3 }, Pickup = { "dunes" },
		Description = "Сладкий инжир из дюн." },
	{ Id = "frost_apple", Name = "Frost Apple", Icon = "🍏", Color = c(150, 220, 255),
		Fullness = 40, Growth = 180, BuyPrice = 4500,
		Seed = { Price = 3000, GrowTime = 240, Yield = 3 }, Pickup = { "frost" },
		Description = "Хрустящее ледяное яблоко." },
	{ Id = "ember_pepper", Name = "Ember Pepper", Icon = "🌶️", Color = c(255, 80, 30),
		Fullness = 45, Growth = 500, BuyPrice = 35000,
		Seed = { Price = 25000, GrowTime = 420, Yield = 3 }, Pickup = { "magma" },
		Description = "Острейший перец. Существа растут как на дрожжах." },
	{ Id = "starfruit", Name = "Starfruit", Icon = "⭐", Color = c(255, 225, 80),
		Fullness = 60, Growth = 800, BuyPrice = nil,
		Seed = { Price = 400000, GrowTime = 900, Yield = 1 }, Pickup = { "starfall" },
		Catalyst = true,
		Description = "Нужен, чтобы взрослое существо стало Ascended." },
	{ Id = "moon_melon", Name = "Moon Melon", Icon = "🍈", Color = c(200, 230, 255),
		Fullness = 100, Growth = 1200, BuyPrice = nil,
		Pickup = { "meadow", "dunes", "frost", "magma", "starfall" }, NightOnly = true,
		Description = "Появляется только ночью. Полностью насыщает." },
	{ Id = "growth_tonic", Name = "Growth Tonic", Icon = "🧪", Color = c(120, 255, 140),
		Fullness = 0, Growth = 1500, BuyPrice = 25000, IgnoresFullness = true,
		Description = "Ускоритель роста. Можно давать даже сытым." },
}

local byId: { [string]: Food } = {}
for _, food in list do
	assert(byId[food.Id] == nil, "Duplicate food id " .. food.Id)
	byId[food.Id] = food
end

return {
	List = list,
	ById = byId,
}
