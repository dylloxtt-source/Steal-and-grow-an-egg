-- Чистая логика: случайный выбор, форматирование, рост, экономика, профиль
return function(t)
	local WeightedRandom = t.load("Logic.WeightedRandom")
	local Format = t.load("Logic.Format")
	local Growth = t.load("Logic.Growth")
	local Economy = t.load("Logic.Economy")
	local Profile = t.load("Logic.Profile")
	local Game = t.load("Config.Game")
	local Foods = t.load("Config.Foods")

	-- WeightedRandom
	local entries = { { Item = "a", Weight = 1 }, { Item = "b", Weight = 3 }, { Item = "c", Weight = 0 } }
	t.eq(WeightedRandom.Pick(entries, nil, 0), "a", "roll 0 -> первый")
	t.eq(WeightedRandom.Pick(entries, nil, 0.24), "a", "roll 0.24 -> a")
	t.eq(WeightedRandom.Pick(entries, nil, 0.26), "b", "roll 0.26 -> b")
	t.eq(WeightedRandom.Pick(entries, nil, 0.9999999), "b", "нулевой вес никогда не выпадает")
	t.eq(WeightedRandom.Pick({}, nil, 0.5), nil, "пустой список")
	local rng = t.Random.new(42)
	local counts = { a = 0, b = 0, c = 0 }
	for _ = 1, 20000 do
		local item = WeightedRandom.Pick(entries, rng)
		counts[item] += 1
	end
	t.near(counts.b / 20000, 0.75, 0.02, "распределение соответствует весам")
	t.eq(counts.c, 0, "c не выпадает")

	-- Format
	t.eq(Format.Number(1300000), "1.3M", "1.3M")
	t.eq(Format.Money(481800000), "$481.8M", "$481.8M")
	t.eq(Format.Number(999), "999", "999")
	t.eq(Format.Number(1000), "1K", "1K")
	t.eq(Format.Number(2.5), "2.5", "дробь")
	t.eq(Format.Number(150000), "150K", "150K")
	t.eq(Format.Number(999999), "999.9K", "999.9K без округления вверх")
	t.eq(Format.Time(282), "4m 42s", "4m 42s")
	t.eq(Format.Time(5), "5s", "5s")
	t.eq(Format.Time(3700), "1h 1m", "1h 1m")
	t.eq(Format.Percent(0.39), "39%", "39%")
	t.eq(Format.Percent(0.065), "6.5%", "6.5%")
	t.eq(Format.Percent(0.005), "0.5%", "0.5%")

	-- Growth
	local function creature(species: string)
		return { uid = "u1", species = species, size = 1, sizeId = "Normal", mutation = "None", growth = 0,
			fullness = 100, ascended = false, placed = true, lastTick = 1000 }
	end
	local c = creature("pebblepup")
	local juvenile, adult = Growth.Thresholds("pebblepup")
	t.eq(juvenile, Game.Growth.Juvenile, "порог Juvenile для Common")
	t.eq(Growth.Stage(c), "Baby", "новорождённый — Baby")
	local elapsed, fedTime, stageUp = Growth.Simulate(c, 1090)
	t.eq(elapsed, 90, "учтено 90 сек")
	t.eq(fedTime, 90, "всё время сыт")
	t.near(c.growth, 90 * 1.2, 1e-6, "рост с GrowthRate 1.2")
	t.ok(not stageUp, "ещё не Juvenile")
	Growth.Simulate(c, 1200)
	t.eq(Growth.Stage(c), "Juvenile", "стал Juvenile")

	-- Голодание: сытость кончается, рост останавливается
	local hungry = creature("mossbun")
	hungry.fullness = 10
	local decay = Growth.DecayPerSecond("mossbun")
	local e2, fed2 = Growth.Simulate(hungry, 1000 + 10000)
	t.eq(e2, 10000, "длинный интервал")
	t.near(fed2, 10 / decay, 1e-6, "рос только пока был сыт")
	t.eq(hungry.fullness, 0, "сытость не уходит в минус")
	local earned = Growth.EarnedOver(hungry, e2, fed2, 0)
	local rate = Growth.IncomePerSecond(hungry, 0)
	t.near(earned, rate * (fed2 + (e2 - fed2) * Game.Growth.HungryIncomeMult), 1e-6, "голодный приносит половину")

	-- Офлайн-лимит
	local offline = creature("pebblepup")
	local e3 = Growth.Simulate(offline, 1000 + 100 * 3600, Game.Offline.MaxSeconds)
	t.eq(e3, Game.Offline.MaxSeconds, "офлайн ограничен MaxSeconds")

	-- Хранилище: время не идёт
	local stored = creature("pebblepup")
	stored.placed = false
	stored.fullness = 50
	Growth.Simulate(stored, 5000)
	t.eq(stored.fullness, 50, "в хранилище не голодает")
	t.eq(stored.growth, 0, "в хранилище не растёт")
	t.eq(stored.lastTick, 5000, "lastTick обновлён")

	-- Рост не превышает Adult без Starfruit
	local big = creature("pebblepup")
	Growth.Simulate(big, 1000 + 100000)
	t.eq(big.growth <= adult, true, "рост ограничен порогом Adult")

	-- Кормление
	local feed = creature("pebblepup")
	local result = Growth.ApplyFood(feed, Foods.ById.pellet)
	t.ok(not result.ok, "сытого нельзя кормить обычной едой")
	feed.fullness = 10
	result = Growth.ApplyFood(feed, Foods.ById.pellet)
	t.ok(result.ok, "голодного можно кормить")
	t.eq(feed.fullness, 30, "сытость +20")
	t.eq(feed.growth, 15, "рост +15")
	local tonic = Growth.ApplyFood(feed, Foods.ById.growth_tonic)
	t.ok(tonic.ok, "тоник даётся даже сытому")
	local adultC = creature("pebblepup")
	adultC.growth = adult
	t.eq(Growth.Stage(adultC), "Adult", "Adult")
	t.ok(not Growth.ApplyFood(adultC, Foods.ById.growth_tonic).ok, "тоник бесполезен на Adult")
	local asc = Growth.ApplyFood(adultC, Foods.ById.starfruit)
	t.ok(asc.ok and asc.stageUp, "Starfruit делает Ascended")
	t.eq(Growth.Stage(adultC), "Ascended", "стадия Ascended")
	t.ok(Growth.IncomePerSecond(adultC, 0) > Growth.IncomePerSecond(creature("pebblepup"), 0) * 10, "Ascended приносит намного больше")
	t.ok(Growth.SellValue(adultC) > Growth.SellValue(creature("pebblepup")), "взрослый дороже при продаже")

	-- Economy
	t.eq(Economy.HatchDuration("meadow_egg", 0, 0), 30, "базовое время")
	t.eq(Economy.HatchDuration("frost_egg", 5, 0.3), math.floor(240 * 0.6 * 0.7), "улучшения ускоряют")
	t.eq(Economy.HatchDuration("meadow_egg", 5, 0.3) >= 5, true, "минимум 5 сек")
	t.eq(Economy.SkipCost("meadow_egg", 0, 30), 0, "готовое не стоит ничего")
	t.ok(Economy.SkipCost("star_egg", 1500, 1500) > Economy.SkipCost("star_egg", 10, 1500), "дороже, когда больше осталось")
	t.eq(Economy.WalkSpeed(1000, 0), Game.Movement.MaxWalkSpeed, "скорость ограничена")
	t.eq(Economy.UpgradeCost("bag", 3), nil, "нет цены на максимуме")

	local profile = Profile.Default()
	local bonuses = Economy.Bonuses(profile, Growth.Stage)
	t.eq(bonuses.Income, 0, "без индекса бонуса нет")
	profile.index.pebblepup = true
	profile.index.mossbun = true
	local dh = creature("dunehopper")
	profile.creatures[dh.uid] = dh
	bonuses = Economy.Bonuses(profile, Growth.Stage)
	t.near(bonuses.Income, 2 * Game.Index.IncomeBonusPerSpecies, 1e-9, "бонус индекса")
	t.eq(bonuses.Speed, 0, "черта не работает у Baby")
	dh.growth = 1e9
	bonuses = Economy.Bonuses(profile, Growth.Stage)
	t.eq(bonuses.Speed, 1, "черта Speed у Adult")

	-- Profile
	local fresh = Profile.Reconcile(nil)
	t.eq(fresh.coins, Game.StartCoins, "пустое сохранение -> профиль по умолчанию")
	t.eq(#fresh.eggs, 1, "стартовое яйцо")
	local dirty = {
		version = 1, coins = -50, eggs = { { uid = "u5", id = "meadow_egg" }, { uid = "u6", id = "deleted_egg" } },
		creatures = { x = { species = "nope" } }, food = { pellet = 3, ghost = 2 }, upgrades = { pens = 999 },
		farm = { ["1"] = { seed = "pellet" } },
	}
	local fixed = Profile.Reconcile(dirty)
	t.eq(fixed.coins, 0, "отрицательные монеты исправлены")
	t.eq(#fixed.eggs, 1, "неизвестные яйца удалены")
	t.eq(fixed.creatures.x, nil, "неизвестные существа удалены")
	t.eq(fixed.food.ghost, nil, "неизвестная еда удалена")
	t.eq(fixed.upgrades.pens, 12, "уровень ограничен максимумом")
	t.eq(fixed.upgrades.bag, 1, "недостающие улучшения добавлены")
	t.eq(fixed.farm["1"], nil, "грядка с не-семенем удалена")
	t.ok(fixed.settings ~= nil and fixed.stats ~= nil, "недостающие разделы добавлены")
	local again = Profile.Reconcile(fixed)
	t.eq(again.coins, fixed.coins, "сверка идемпотентна")
	t.ok(Profile.TakeFood(fixed, "pellet", 3), "забрать еду")
	t.eq(fixed.food.pellet, nil, "пустой стек удаляется")
	t.ok(not Profile.TakeFood(fixed, "pellet", 1), "нельзя забрать отсутствующее")
	local uidA, uidB = Profile.NewUid(fixed), Profile.NewUid(fixed)
	t.ok(uidA ~= uidB, "uid уникальны")
end
