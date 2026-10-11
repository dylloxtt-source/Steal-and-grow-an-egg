--[[
	Интеграционный тест: сервер и клиент игры на эмуляторе движка (tests/sim/Engine.luau).
	Запуск:  lune run tests/integration.luau
	Проверяет основной цикл, кражу, защиту, ферму, задания, сохранение и сборку UI.
]]

local process = require("@lune/process")
local task = require("@lune/task")
local roblox = require("@lune/roblox")
local Engine = require("./sim/Engine")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local passed, failed = 0, 0
local section = ""
local function ok(cond, message)
	if cond then
		passed += 1
	else
		failed += 1
		print(string.format("  ✗ [%s] %s", section, message))
	end
end
local function eq(a, b, message)
	ok(a == b, string.format("%s (ожидалось %s, получено %s)", message, tostring(b), tostring(a)))
end
local function step(name)
	section = name
	print("• " .. name)
end
local function wait(seconds)
	task.wait(seconds)
end

local function scenario()
------------------------------------------------------------------------
step("Запуск сервера")
local server = Engine.Realm(true)
local bootOk, bootErr = pcall(server.require, Engine.ServerNode)
ok(bootOk, "init.server выполнился: " .. tostring(bootErr))
local S = Engine.ServerNode.Services
local DataService = server.require(S.DataService)
local IncubatorService = server.require(S.IncubatorService)
local CarryService = server.require(S.CarryService)
local PlotService = server.require(S.PlotService)
local Shared = Engine.SharedNode
local Map = server.require(Shared.Config.Map)
local Eggs = server.require(Shared.Config.Eggs)
ok(Engine.Workspace:FindFirstChild("Map") ~= nil, "карта построена")
ok(Engine.Workspace:FindFirstChild("WorldItems") ~= nil, "предметы мира созданы")
local mapParts = 0
for _, d in Engine.Workspace:GetDescendants() do
	if d:IsA("BasePart") then
		mapParts += 1
	end
end
print(string.format("  деталей в мире: %d", mapParts))
ok(mapParts > 1000 and mapParts < 12000, "разумное количество деталей карты")
for _, w in Engine.Warnings do
	print("  warn: " .. w)
end
eq(#Engine.Warnings, 0, "без предупреждений при старте")

------------------------------------------------------------------------
step("Вход игрока и загрузка профиля")
local alice = Engine.NewPlayer("Alice")
Engine.LocalPlayer = alice
Engine.Join(alice)
Engine.SpawnCharacter(alice, Map.Spawn + Vector3.new(0, 3, 0))
wait(0.4)
local aliceSession = DataService:GetSession(alice)
ok(aliceSession ~= nil, "сессия загружена")
ok(aliceSession.Plot ~= nil, "база выдана")
eq(alice:GetAttribute("Loaded"), true, "атрибут Loaded")
local profile = aliceSession.Profile
eq(profile.coins, 100, "стартовые монеты")
eq(#profile.eggs, 1, "стартовое яйцо")
local root = alice.Character.HumanoidRootPart
ok(Map.InPlot(aliceSession.Plot.Index, Engine.GetPosition(root)), "персонаж телепортирован на базу")
eq(alice.Character.Humanoid.WalkSpeed, 16, "базовая скорость")

------------------------------------------------------------------------
step("Клиент: сборка UI")
local client = Engine.Realm(false)
local clientOk, clientErr = pcall(client.require, Engine.ClientNode)
ok(clientOk, "init.client выполнился: " .. tostring(clientErr))
wait(0.6)
local State = client.require(Engine.ClientNode.State)
ok(State.Profile() ~= nil, "клиент получил снимок профиля")
local gui = alice.PlayerGui:FindFirstChild("SGAE_UI")
ok(gui ~= nil, "ScreenGui создан")

local function act(name, payload)
	local success = State.Action(name, payload)
	wait(0.2) -- снимок состояния уходит с задержкой 0.12
	return success
end

------------------------------------------------------------------------
step("Инкубация и вылупление")
local starterUid = profile.eggs[1].uid
ok(act("Incubate", { uid = starterUid }), "яйцо помещено в инкубатор")
ok(profile.incubators["1"] ~= nil, "запись инкубатора")
eq(profile.tutorial, 2, "обучение: шаг 2")
ok(not act("Incubate", { uid = starterUid }), "повторная инкубация того же яйца отклонена")
ok(not act("Hatch", { slot = 1 }), "рано вылуплять")
local incModel = aliceSession.Plot.Incubators[1].Model
eq(incModel:GetAttribute("State"), "incubating", "атрибут State = incubating")
ok(incModel:FindFirstChild("Egg") ~= nil, "модель яйца в инкубаторе")
Engine.Advance(31)
local coinsBefore = profile.coins
ok(act("Hatch", { slot = 1 }), "вылупление")
ok(not act("Hatch", { slot = 1 }), "повторное вылупление отклонено")
local creatureCount = 0
local creatureUid
for uid in profile.creatures do
	creatureCount += 1
	creatureUid = uid
end
eq(creatureCount, 1, "ровно одно существо")
ok(profile.coins > coinsBefore, "награда за открытие в индексе")
local hatchedEvents = 0
for _, entry in Engine.RemoteLog do
	if entry.event == "Hatched" and entry.player == alice then
		hatchedEvents += 1
	end
end
eq(hatchedEvents, 1, "одно событие Hatched")
ok(aliceSession.Plot.Pen:FindFirstChild(creatureUid) ~= nil, "модель существа в загоне")

------------------------------------------------------------------------
step("Кормление")
local creature = profile.creatures[creatureUid]
local pellets = profile.food.pellet
ok(act("Feed", { uid = creatureUid, food = "pellet" }), "покормили")
eq(profile.food.pellet, pellets - 1, "гранула потрачена")
ok(creature.fullness > 60, "сытость выросла")
creature.fullness = 99
ok(not act("Feed", { uid = creatureUid, food = "pellet" }), "сытого не кормим")
eq(profile.food.pellet, pellets - 1, "еда не списана при отказе")
ok(not act("Feed", { uid = creatureUid, food = "starfruit" }), "нельзя скормить отсутствующую еду")

------------------------------------------------------------------------
step("Яйцо с дорожки и доставка")
Engine.MoveTo(alice, Vector3.new(0, 3, 100))
local worldEgg
for _, model in Engine.Workspace.WorldItems:GetChildren() do
	if model:IsA("Model") and model:GetAttribute("Zone") == "meadow" then
		worldEgg = model
		break
	end
end
ok(worldEgg ~= nil, "на лугу есть яйца")
local prompt = worldEgg:FindFirstChild("Root"):FindFirstChildOfClass("ProximityPrompt")
prompt.Triggered:FireSync(alice)
eq(CarryService:Count(aliceSession), 1, "яйцо в руках")
eq(worldEgg.Parent, nil, "яйцо убрано с земли (второй игрок не сможет его взять)")
ok(alice.Character:FindFirstChild("CarriedEgg") ~= nil, "модель яйца над головой")
ok(alice.Character.Humanoid.WalkSpeed < 16, "переноска замедляет")
local other
for _, model in Engine.Workspace.WorldItems:GetChildren() do
	if model:IsA("Model") and model:GetAttribute("EggId") and model ~= worldEgg and model.Parent then
		other = model
		break
	end
end
other.Root:FindFirstChildOfClass("ProximityPrompt").Triggered:FireSync(alice)
eq(CarryService:Count(aliceSession), 1, "сумка на 1 яйцо")
Engine.MoveTo(alice, Map.PlotWorld(aliceSession.Plot.Index, Map.PlotLayout.Delivery) + Vector3.new(0, 3, 0))
wait(0.5)
eq(CarryService:Count(aliceSession), 0, "яйцо сдано на базе")
ok(profile.incubators["1"] ~= nil, "доставленное яйцо автоматически в инкубаторе")
eq(profile.tutorial, 4, "обучение: шаги grab и deliver пройдены")

------------------------------------------------------------------------
step("Еда на дорожке")
local food
for _, part in Engine.Workspace.WorldItems:GetChildren() do
	if part:IsA("BasePart") and part:GetAttribute("FoodId") then
		food = part
		break
	end
end
ok(food ~= nil, "на дорожке лежит еда")
local foodId = food:GetAttribute("FoodId")
local had = profile.food[foodId] or 0
food.Touched:FireSync(root)
ok((profile.food[foodId] or 0) > had, "еда подобрана касанием")
eq(food.Parent, nil, "еда исчезла с земли")

------------------------------------------------------------------------
step("Доход и касса")
for _ = 1, 3 do
	Engine.Advance(1)
	wait(1.05)
end
ok(profile.vault > 0, "доход копится в кассе: " .. tostring(profile.vault))
local coins = profile.coins
aliceSession.Plot.Vault.Touched:FireSync(root)
ok(profile.coins > coins, "касса собрана")
ok(profile.vault < 1, "касса пуста")

------------------------------------------------------------------------
step("Магазин, улучшения, настройки, продажа")
profile.coins = 10000
ok(act("Buy", { category = "egg", id = "meadow_egg", amount = 1 }), "купили яйцо")
eq(profile.coins, 9900, "списано 100")
ok(not act("Buy", { category = "egg", id = "void_egg" }), "Void Egg не продаётся")
ok(not act("Buy", { category = "egg", id = "meadow_egg", amount = 50 }), "количество ограничено")
ok(not act("Buy", { category = "food", id = 123 }), "неверный тип ID")
ok(act("Buy", { category = "seed", id = "berry", amount = 5 }), "купили семена")
ok(act("Upgrade", { id = "speed" }), "улучшили скорость")
eq(alice.Character.Humanoid.WalkSpeed, 17, "скорость 17")
ok(act("SetSetting", { key = "slowMode", value = true }), "Slow Mode")
eq(alice.Character.Humanoid.WalkSpeed, 16, "медленный режим")
act("SetSetting", { key = "slowMode", value = false })
ok(not act("SetSetting", { key = "coins", value = true }), "чужие настройки нельзя")
ok(act("Upgrade", { id = "incubators" }), "третий инкубатор")
eq(profile.upgrades.incubators, 3, "уровень инкубаторов")
local before = profile.coins
profile.coins = 0
ok(not act("Upgrade", { id = "pens" }), "без денег не улучшить")
profile.coins = before
ok(not act("NoSuchAction", {}), "неизвестное действие")
local limited = 0
for _ = 1, 15 do
	if State.Action("Buy", { category = "food", id = "pellet", amount = 1 }) == false then
		limited += 1
	end
end
ok(limited > 0, "лимит частоты срабатывает")

------------------------------------------------------------------------
step("Ферма")
ok(act("Plant", { slot = 1, seed = "berry" }), "посадили")
ok(not act("Plant", { slot = 1, seed = "berry" }), "грядка занята")
ok(not act("Plant", { slot = 5, seed = "berry" }), "закрытая грядка")
ok(not act("Plant", { slot = 2, seed = "pellet" }), "гранулы не сажаются")
Engine.Advance(61)
local berries = profile.food.berry or 0
aliceSession.Plot.Farms[1].Prompt.Triggered:FireSync(alice)
ok((profile.food.berry or 0) >= berries + 3, "урожай собран")
eq(profile.farm["1"], nil, "грядка освободилась")

------------------------------------------------------------------------
step("Кража: второй игрок")
local bob = Engine.NewPlayer("Bob")
Engine.Join(bob)
Engine.SpawnCharacter(bob, Map.Spawn + Vector3.new(0, 3, 0))
wait(0.4)
local bobSession = DataService:GetSession(bob)
ok(bobSession ~= nil and bobSession.Plot ~= nil and bobSession.Plot ~= aliceSession.Plot, "у Боба своя база")
local StealService = server.require(S.StealService)
-- Вор должен стоять у инкубаторов Алисы (у подсказки дальность 10 студов)
local function atAlice(player)
	Engine.MoveTo(player, Map.PlotWorld(aliceSession.Plot.Index, Map.PlotLayout.Incubators[1]) + Vector3.new(4, 3, 0))
end
atAlice(bob)
-- Алиса — новичок
local stealPrompt = aliceSession.Plot.Incubators[1].StealPrompt
ok(StealService:IsNewbie(aliceSession), "Алиса под защитой новичка")
stealPrompt.Triggered:FireSync(bob)
eq(CarryService:Count(bobSession), 0, "у новичка украсть нельзя")
profile.stats.playTime = 5000
IncubatorService:RefreshAll(aliceSession)
ok(stealPrompt.Enabled, "кнопка кражи активна после защиты")
eq(stealPrompt:GetAttribute("NotOwner"), alice.UserId, "кнопку кражи не видит владелец")
local record = profile.incubators["1"]
local stolenEggId = record.id
stealPrompt.Triggered:FireSync(bob)
eq(CarryService:Count(bobSession), 1, "Боб несёт яйцо")
eq(record.transit, bob.UserId, "яйцо в пути, но ещё в профиле Алисы")
ok(not act("Hatch", { slot = 1 }), "владелец не может открыть яйцо в пути")
ok(bob.Character:FindFirstChild("ThiefHighlight") ~= nil, "вор подсвечен")
local alerts = 0
for _, entry in Engine.RemoteLog do
	if entry.event == "StealAlert" and entry.player == alice and entry.args[1].active then
		alerts += 1
	end
end
ok(alerts >= 1, "Алиса получила тревогу")
stealPrompt.Triggered:FireSync(bob)
eq(CarryService:Count(bobSession), 1, "одно яйцо не украсть дважды")
local aliceCoins = profile.coins
local bobEggsTotal = #bobSession.Profile.eggs
for _ in bobSession.Profile.incubators do
	bobEggsTotal += 1
end
Engine.MoveTo(bob, Map.PlotWorld(bobSession.Plot.Index, Map.PlotLayout.Delivery) + Vector3.new(0, 3, 0))
wait(0.5)
eq(profile.incubators["1"], nil, "яйцо ушло от Алисы")
local bobGot = 0
for _, egg in bobSession.Profile.eggs do
	if egg.id == stolenEggId then
		bobGot += 1
	end
end
local function totalEggs(prof)
	local n = #prof.eggs
	for _ in prof.incubators do
		n += 1
	end
	return n
end
eq(totalEggs(bobSession.Profile), bobEggsTotal + 1, "Боб получил яйцо")
ok(profile.coins > aliceCoins, "Алиса получила страховку")
eq(bobSession.Profile.stats.stolen, 1, "статистика краж")
local _ = bobGot

------------------------------------------------------------------------
step("Защита: перезарядка жертвы, замок базы")
-- В инкубаторах Алисы есть ещё яйца (купленное и доставленное)
local slotWithEgg
for slot = 1, profile.upgrades.incubators do
	local r = profile.incubators[tostring(slot)]
	if r and not r.transit then
		slotWithEgg = slot
		break
	end
end
if not slotWithEgg then
	act("Buy", { category = "egg", id = "meadow_egg" })
	for slot = 1, profile.upgrades.incubators do
		if profile.incubators[tostring(slot)] then
			slotWithEgg = slot
		end
	end
end
ok(slotWithEgg ~= nil, "есть яйцо для следующей попытки")
local prompt2 = aliceSession.Plot.Incubators[slotWithEgg].StealPrompt
atAlice(bob)
prompt2.Triggered:FireSync(bob)
eq(CarryService:Count(bobSession), 0, "жертву нельзя обокрасть повторно сразу")
Engine.Advance(61)
aliceSession.Plot.LockPrompt.Triggered:FireSync(alice)
ok(StealService:IsLocked(aliceSession), "база заперта")
IncubatorService:RefreshAll(aliceSession)
ok(not prompt2.Enabled, "кнопка кражи выключена под замком")
prompt2.Triggered:FireSync(bob)
eq(CarryService:Count(bobSession), 0, "под замком украсть нельзя")
aliceSession.LockedUntil = 0
IncubatorService:RefreshAll(aliceSession)

------------------------------------------------------------------------
step("Удар битой выбивает украденное яйцо; владелец забирает его")
atAlice(bob)
prompt2.Triggered:FireSync(bob)
eq(CarryService:Count(bobSession), 1, "Боб снова несёт яйцо")
local stealPos = Vector3.new(0, 3, -130)
Engine.MoveTo(alice, stealPos)
Engine.MoveTo(bob, stealPos + Vector3.new(0, 0, -4))
local tool = alice.Backpack:FindFirstChildOfClass("Tool")
ok(tool ~= nil, "у Алисы есть бита")
tool.Activated:FireSync()
eq(CarryService:Count(bobSession), 0, "яйцо выбито")
local recordAfter = profile.incubators[tostring(slotWithEgg)]
eq(recordAfter.transit, -1, "яйцо лежит на земле")
local drop
for _, model in Engine.Workspace.WorldItems:GetChildren() do
	if model:GetAttribute("StolenFrom") == alice.UserId then
		drop = model
	end
end
ok(drop ~= nil, "выпавшее яйцо в мире")
drop.Root:FindFirstChildOfClass("ProximityPrompt").Triggered:FireSync(alice)
eq(recordAfter.transit, nil, "яйцо вернулось в инкубатор")
eq(drop.Parent, nil, "модель убрана")

------------------------------------------------------------------------
step("Вор выходит из игры посреди кражи")
Engine.Advance(5)
wait(1.3) -- кулдаун удара/оглушения по os.clock
atAlice(bob)
prompt2.Triggered:FireSync(bob)
eq(CarryService:Count(bobSession), 1, "Боб украл снова")
local bobId = bob.UserId
Engine.Leave(bob)
wait(0.2)
eq(profile.incubators[tostring(slotWithEgg)].transit, nil, "яйцо вернулось владельцу")
local saved = Engine.DataStoreData["u_" .. bobId]
ok(saved ~= nil, "профиль Боба сохранён")
ok(saved and saved.lock == nil, "замок сессии снят при выходе")
ok(saved and saved.stats.stolen == 1, "сохранена статистика")

------------------------------------------------------------------------
step("Повторный вход восстанавливает прогресс")
local bob2 = Engine.NewPlayer("Bob")
bob2.UserId = bobId
Engine.Join(bob2)
Engine.SpawnCharacter(bob2, Map.Spawn + Vector3.new(0, 3, 0))
wait(0.4)
local bob2Session = DataService:GetSession(bob2)
ok(bob2Session ~= nil, "Боб загрузился снова")
eq(bob2Session.Profile.stats.stolen, 1, "данные восстановлены")

------------------------------------------------------------------------
step("Страж ловит игрока с яйцом")
local GuardianFolder = Engine.Workspace:FindFirstChild("Guardians")
ok(GuardianFolder ~= nil and #GuardianFolder:GetChildren() > 0, "стражи созданы")
local guardian = GuardianFolder:FindFirstChild("Guardian_dunes_1")
local gpos = Engine.GetPosition(guardian.Root)
Engine.MoveTo(bob2, Vector3.new(gpos.X, 3, gpos.Z))
CarryService:Add(bob2Session, { Kind = "lane", EggId = "dune_egg" })
eq(CarryService:Count(bob2Session), 1, "несёт яйцо в дюнах")
for _ = 1, 5 do
	server.RunService.Heartbeat:FireSync(1 / 20)
end
eq(CarryService:Count(bob2Session), 0, "страж выбил яйцо")

------------------------------------------------------------------------
step("Задания и обучение")
local QuestService = server.require(S.QuestService)
local list = profile.quests.list
eq(#list, 3, "три задания на день")
local Quests = server.require(Shared.Config.Quests)
local first = list[1]
local quest = Quests.ById[first.id]
QuestService:Progress(aliceSession, quest.Stat, quest.Target)
ok(act("ClaimQuest", { id = first.id }), "награда получена")
ok(not act("ClaimQuest", { id = first.id }), "повторно не выдаётся")

------------------------------------------------------------------------
step("Клиент: окна открываются и обновляются без ошибок")
local Router = client.require(Engine.ClientNode.UI.Router)
for _, name in { "Shop", "Eggs", "Pets", "Feed", "Farm", "Index", "Quests", "Settings" } do
	local okOpen, err = pcall(function()
		Router.Open(name, if name == "Feed" then creatureUid elseif name == "Farm" then 1 else nil)
		local module = Router.Get(name)
		if module.Refresh then
			module:Refresh()
		end
	end)
	ok(okOpen, "окно " .. name .. ": " .. tostring(err))
end
local Shop = client.require(Engine.ClientNode.UI.ShopPanel)
for _, tab in { "Eggs", "Food", "Seeds", "Upgrades", "Sell" } do
	local okTab, err = pcall(function()
		Router.Open("Shop", tab)
		Shop:Refresh()
	end)
	ok(okTab, "вкладка " .. tab .. ": " .. tostring(err))
end
Router.Close()
-- Клиентские циклы (подписи, анимации, HUD)
local clientErrors = 0
for _ = 1, 6 do
	local okTick, err = pcall(function()
		client.RunService.Heartbeat:FireSync(0.3)
		client.RunService.RenderStepped:FireSync(1 / 60)
	end)
	if not okTick then
		clientErrors += 1
		print("  client tick error: " .. tostring(err))
	end
end
eq(clientErrors, 0, "клиентские циклы без ошибок")
local billboards = alice.PlayerGui:FindFirstChild("WorldBillboards")
ok(billboards ~= nil and #billboards:GetChildren() > 10, "подписи над объектами созданы")

------------------------------------------------------------------------
step("Владелец выходит, пока у него крадут")
bob2Session.Profile.stats.playTime = 5000
local aliceSlot
for slot = 1, profile.upgrades.incubators do
	local r = profile.incubators[tostring(slot)]
	if r and not r.transit then
		aliceSlot = slot
	end
end
Engine.Advance(120)
wait(1.3)
atAlice(bob2)
aliceSession.Plot.Incubators[aliceSlot].StealPrompt.Triggered:FireSync(bob2)
wait(0.3)
eq(CarryService:Count(bob2Session), 1, "Боб несёт яйцо Алисы")
local aliceId = alice.UserId
Engine.Leave(alice)
wait(0.2)
eq(CarryService:Count(bob2Session), 0, "кража отменена")
local aliceSaved = Engine.DataStoreData["u_" .. aliceId]
ok(aliceSaved.incubators[tostring(aliceSlot)] ~= nil, "яйцо осталось в сохранении Алисы")
eq(aliceSaved.incubators[tostring(aliceSlot)].transit, nil, "без метки transit")
eq(Engine.Kicked[aliceId], nil, "никого не кикнули")

------------------------------------------------------------------------
step("Офлайн-прогресс при повторном входе")
local savedCreature
for _, c in aliceSaved.creatures do
	if c.placed then
		savedCreature = c
	end
end
ok(savedCreature ~= nil, "у Алисы сохранено существо в загоне")
Engine.Advance(2 * 3600)
local alice2 = Engine.NewPlayer("Alice")
alice2.UserId = aliceId
Engine.Join(alice2)
Engine.SpawnCharacter(alice2, Map.Spawn + Vector3.new(0, 3, 0))
wait(0.4)
local alice2Session = DataService:GetSession(alice2)
ok(alice2Session ~= nil, "Алиса вернулась")
ok(alice2Session.Profile.vault > aliceSaved.vault, "офлайн-доход начислен в кассу")
local creatureNow = alice2Session.Profile.creatures[savedCreature.uid]
ok(creatureNow.growth >= savedCreature.growth, "рост учтён офлайн")
ok(creatureNow.fullness < savedCreature.fullness or savedCreature.fullness == 0, "голод учтён офлайн")
local readyCount = 0
for _, r in alice2Session.Profile.incubators do
	if IncubatorService:IsReady(r) then
		readyCount += 1
	end
end
ok(readyCount > 0, "таймеры инкубаторов шли офлайн")

------------------------------------------------------------------------
step("Продажа существа")
local sellCoins = alice2Session.Profile.coins
local sold = Engine.InvokeAs(alice2, "Sell", { uid = savedCreature.uid })
ok(sold.ok, "продали существо")
eq(alice2Session.Profile.creatures[savedCreature.uid], nil, "существо удалено")
ok(alice2Session.Profile.coins > sellCoins, "монеты за продажу")
ok(not Engine.InvokeAs(alice2, "Sell", { uid = savedCreature.uid }).ok, "повторная продажа невозможна")
eq(alice2Session.Plot.Pen:FindFirstChild(savedCreature.uid), nil, "модель убрана из загона")

------------------------------------------------------------------------
step("Ночь перезагружает яйца")
local WorldEggService = server.require(S.WorldEggService)
WorldEggService:ResetEggs()
local zoneEggs = 0
for _, model in Engine.Workspace.WorldItems:GetChildren() do
	if model:IsA("Model") and model:GetAttribute("Zone") then
		zoneEggs += 1
	end
end
local Zones = server.require(Shared.Config.Zones)
local expected = 0
for _, zone in Zones.List do
	expected += zone.MaxEggs
end
eq(zoneEggs, expected, "все зоны заполнены яйцами")

------------------------------------------------------------------------
step("Выключение сервера сохраняет всех")
bob2Session.Profile.coins = 777
for _, fn in Engine.BindToClose do
	fn()
end
eq(Engine.DataStoreData["u_" .. bobId].coins, 777, "BindToClose сохранил профиль")

end

local scenarioOk, scenarioErr = pcall(scenario)
if not scenarioOk then
	failed += 1
	print(string.format("  ✗ [%s] сценарий упал: %s", section, tostring(scenarioErr)))
end

------------------------------------------------------------------------
for _, w in Engine.Warnings do
	print("  warn: " .. w)
end
print(string.format("\nИнтеграция: пройдено %d, провалено %d", passed, failed))
process.exit(if failed == 0 then 0 else 1)
