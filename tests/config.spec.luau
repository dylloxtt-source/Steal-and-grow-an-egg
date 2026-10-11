-- Целостность конфигов: ссылки между таблицами, нормализация шансов, рост цен
return function(t)
	local Eggs = t.load("Config.Eggs")
	local Creatures = t.load("Config.Creatures")
	local Rarities = t.load("Config.Rarities")
	local Zones = t.load("Config.Zones")
	local Foods = t.load("Config.Foods")
	local Upgrades = t.load("Config.Upgrades")
	local WeightedRandom = t.load("Logic.WeightedRandom")

	local inEgg = {}
	for _, egg in Eggs.List do
		t.ok(Rarities.ById[egg.Rarity] ~= nil, egg.Id .. ": неизвестная редкость")
		t.ok(egg.HatchTime > 0, egg.Id .. ": время вылупления > 0")
		t.ok(egg.Value > 0, egg.Id .. ": ценность > 0")
		local entries = {}
		for _, entry in egg.Creatures do
			t.ok(Creatures.ById[entry.Creature] ~= nil, egg.Id .. ": существо " .. entry.Creature .. " не найдено")
			t.ok(entry.Weight > 0, egg.Id .. ": вес > 0")
			inEgg[entry.Creature] = true
			table.insert(entries, { Item = entry.Creature, Weight = entry.Weight })
		end
		local sum = 0
		for _, chance in WeightedRandom.Chances(entries) do
			sum += chance
		end
		t.near(sum, 1, 1e-9, egg.Id .. ": шансы нормализованы")
	end
	for _, creature in Creatures.List do
		t.ok(inEgg[creature.Id], creature.Id .. ": выпадает хотя бы из одного яйца")
		t.ok(Rarities.ById[creature.Rarity] ~= nil, creature.Id .. ": редкость")
		t.ok(creature.BaseIncome > 0, creature.Id .. ": доход > 0")
		if creature.Trait then
			local kinds = { Speed = true, Luck = true, Incubate = true, Income = true, Lock = true, Forage = true }
			t.ok(kinds[creature.Trait.Kind], creature.Id .. ": известный тип черты")
		end
	end
	for _, rarity in Rarities.Ordered do
		t.ok(Eggs.ByRarity[rarity.Id] ~= nil, "есть яйцо редкости " .. rarity.Id)
	end
	-- Цены яиц растут с редкостью
	local lastPrice = 0
	for _, rarity in Rarities.Ordered do
		local egg = Eggs.ByRarity[rarity.Id]
		if egg.Price then
			t.ok(egg.Price > lastPrice, egg.Id .. ": цена выше предыдущей редкости")
			lastPrice = egg.Price
		end
	end

	-- Зоны идут подряд и ссылаются на существующие редкости
	local z = Zones.List[1].ZStart
	for _, zone in Zones.List do
		t.eq(zone.ZStart, z, zone.Id .. ": зона начинается там, где кончилась предыдущая")
		z = zone.ZEnd
		for rarityId in zone.EggWeights do
			t.ok(Eggs.ByRarity[rarityId] ~= nil, zone.Id .. ": яйцо редкости " .. rarityId)
		end
		if zone.Guardian then
			t.ok(Creatures.ById[zone.Guardian.Creature] ~= nil, zone.Id .. ": модель стража")
		end
	end
	t.eq(Zones.AtZ(100).Id, "meadow", "AtZ(100) = луг")
	t.eq(Zones.AtZ(1000).Id, "starfall", "AtZ(1000) = звездопад")
	t.eq(Zones.AtZ(-10), nil, "AtZ на площади = nil")

	for _, food in Foods.List do
		if food.Pickup then
			for _, zoneId in food.Pickup do
				t.ok(Zones.ById[zoneId] ~= nil, food.Id .. ": зона " .. zoneId)
			end
		end
		if food.Seed then
			t.ok(food.Seed.Price > 0 and food.Seed.GrowTime > 0 and food.Seed.Yield > 0, food.Id .. ": параметры семени")
		end
	end

	for _, upgrade in Upgrades.List do
		local last = 0
		for level = upgrade.Start, upgrade.Max - 1 do
			local cost = upgrade.Cost(level)
			t.ok(cost < math.huge and cost > last, string.format("%s: цена уровня %d конечна и растёт", upgrade.Id, level))
			last = cost
		end
	end
end
