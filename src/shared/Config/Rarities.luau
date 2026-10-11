--[[
	Редкости. Порядок (Order) используется для сортировки, удачи и визуала.
	Все множители редкости живут здесь, чтобы баланс правился в одном месте.
]]

export type Rarity = {
	Id: string,
	Name: string,
	Order: number,
	Color: Color3,
	DarkColor: Color3,
	GrowthScale: number, -- множитель порогов роста
	Appetite: number, -- множитель скорости голода
	CarryPenalty: number, -- доля потери скорости при переноске яйца
	StealHold: number, -- секунды удержания кнопки для кражи из инкубатора
}

local Rarities: { [string]: Rarity } = {
	Common = {
		Id = "Common", Name = "Common", Order = 1,
		Color = Color3.fromRGB(205, 205, 205), DarkColor = Color3.fromRGB(110, 110, 120),
		GrowthScale = 1, Appetite = 1, CarryPenalty = 0.05, StealHold = 1.5,
	},
	Uncommon = {
		Id = "Uncommon", Name = "Uncommon", Order = 2,
		Color = Color3.fromRGB(92, 227, 92), DarkColor = Color3.fromRGB(30, 120, 40),
		GrowthScale = 1.4, Appetite = 1.1, CarryPenalty = 0.08, StealHold = 2,
	},
	Rare = {
		Id = "Rare", Name = "Rare", Order = 3,
		Color = Color3.fromRGB(63, 169, 255), DarkColor = Color3.fromRGB(20, 70, 160),
		GrowthScale = 2, Appetite = 1.2, CarryPenalty = 0.12, StealHold = 2.5,
	},
	Epic = {
		Id = "Epic", Name = "Epic", Order = 4,
		Color = Color3.fromRGB(179, 87, 255), DarkColor = Color3.fromRGB(80, 25, 150),
		GrowthScale = 2.8, Appetite = 1.3, CarryPenalty = 0.16, StealHold = 3,
	},
	Legendary = {
		Id = "Legendary", Name = "Legendary", Order = 5,
		Color = Color3.fromRGB(255, 194, 26), DarkColor = Color3.fromRGB(170, 100, 0),
		GrowthScale = 4, Appetite = 1.4, CarryPenalty = 0.2, StealHold = 3.5,
	},
	Mythic = {
		Id = "Mythic", Name = "Mythic", Order = 6,
		Color = Color3.fromRGB(255, 79, 154), DarkColor = Color3.fromRGB(150, 20, 80),
		GrowthScale = 5.5, Appetite = 1.5, CarryPenalty = 0.25, StealHold = 4,
	},
	Secret = {
		Id = "Secret", Name = "Secret", Order = 7,
		Color = Color3.fromRGB(40, 40, 48), DarkColor = Color3.fromRGB(0, 0, 0),
		GrowthScale = 7.5, Appetite = 1.6, CarryPenalty = 0.3, StealHold = 4.5,
	},
}

local ordered: { Rarity } = {}
for _, rarity in Rarities do
	table.insert(ordered, rarity)
end
table.sort(ordered, function(a, b)
	return a.Order < b.Order
end)

return {
	ById = Rarities,
	Ordered = ordered,
	-- Цвета для радужного градиента редкости Secret в UI
	SecretGradient = {
		Color3.fromRGB(255, 80, 80),
		Color3.fromRGB(255, 210, 60),
		Color3.fromRGB(80, 230, 120),
		Color3.fromRGB(70, 160, 255),
		Color3.fromRGB(190, 90, 255),
	},
}
