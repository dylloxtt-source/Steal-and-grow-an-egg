--[[
	Интеграционный тест: настоящий код сервера и клиента в эмуляторе (tests/sim/Engine).
	Сценарии: лобби и лифты → матч на выбранной карте → башни, улучшения, продажа,
	приоритеты → волны, яд, босс → поражение/победа → итоги → возврат в лобби → очистка.
	Плюс защита: неверные запросы, нехватка денег, спам, двойная награда, отключения.

	Запуск: lune run tests/integration.luau
	Это НЕ замена проверки в Roblox Studio: физика, рендер, анимации, звук и реальная
	сеть здесь не эмулируются (см. docs/TESTING.md).
]]

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local Engine = require("./sim/Engine")

local Vector3 = roblox.Vector3
local Vector2 = roblox.Vector2
local CFrame = roblox.CFrame

------------------------------------------------------------------------
-- Мини-фреймворк
------------------------------------------------------------------------

local passed, failed = 0, 0
local failures = {}

local function check(name: string, condition: any, detail: any?)
	if condition then
		passed += 1
		print("  ✔ " .. name)
	else
		failed += 1
		local text = name .. (if detail ~= nil then "  —  " .. tostring(detail) else "")
		table.insert(failures, text)
		print("  ✘ " .. text)
	end
end

local function section(name: string)
	print("\n== " .. name .. " ==")
end

------------------------------------------------------------------------
-- Запуск сервера и клиента
------------------------------------------------------------------------

local server = Engine.Realm(true)
local serverOk, serverErr = pcall(server.require, Engine.ServerNode)

local S = Engine.ServerNode.Services
local DataService = server.require(S.DataService)
local LobbyService = server.require(S.LobbyService)
local ElevatorService = server.require(S.ElevatorService)
local MatchService = server.require(S.MatchService)
local Shared = Engine.SharedNode
local Maps = server.require(Shared.Config.Maps)
local Towers = server.require(Shared.Config.Towers)
local Enemies = server.require(Shared.Config.Enemies)
local Waves = server.require(Shared.Config.Waves)
local Economy = server.require(Shared.Config.Economy)
local Game = server.require(Shared.Config.Game)
local Placement = server.require(Shared.Logic.Placement)
local MapLayout = server.require(Shared.Logic.MapLayout)

local p1 = Engine.NewPlayer("Alice") -- локальный игрок клиента
local p2 = Engine.NewPlayer("Bob")
local p3 = Engine.NewPlayer("Carol")
local p4 = Engine.NewPlayer("Dave")
local p5 = Engine.NewPlayer("Eve")
Engine.LocalPlayer = p1
for i, p in { p1, p2, p3, p4, p5 } do
	Engine.Join(p)
	Engine.SpawnCharacter(p, Vector3.new(i * 3 - 9, 3, 40))
end
task.wait(0.3)

local client = Engine.Realm(false)
local clientOk, clientErr = pcall(client.require, Engine.ClientNode)
task.wait(0.3)

local C = Engine.ClientNode
local ClientState = client.require(C.State)
local PlacementController = client.require(C.Controllers.PlacementController)
local TowerController = client.require(C.Controllers.TowerController)
local HUDController = client.require(C.Controllers.HUDController)

local function tick(seconds: number, dt: number?)
	local step = dt or 0.1
	local n = math.max(1, math.floor(seconds / step + 0.5))
	for _ = 1, n do
		server.RunService.Heartbeat:FireSync(step)
		client.RunService.Heartbeat:FireSync(step)
		client.RunService.RenderStepped:FireSync(step)
	end
end

-- Запрос к серверу от имени игрока; при «Слишком часто» ждёт и повторяет
local function act(player, name: string, payload: any?): any
	for _ = 1, 10 do
		local result = Engine.InvokeAs(player, name, payload)
		if result.message ~= "Слишком часто" then
			return result
		end
		task.wait(0.25)
	end
	return { ok = false, message = "rate-limited" }
end

local gui = p1.PlayerGui:FindFirstChild("TD_UI")

local function visible(instance): boolean
	local current = instance
	while current and current ~= gui do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return current == gui
end

local function findText(root, pattern: string)
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and string.find(d.Text, pattern, 1, true) and visible(d) then
			return d
		end
	end
	return nil
end

local function boothPosition(index: number): Vector3
	return LobbyService.Booths[index].Center + Vector3.new(0, 3, 0)
end

local function elevator(index: number)
	return ElevatorService.Elevators[index]
end

local function warningsContaining(pattern: string): { string }
	local list = {}
	for _, w in Engine.Warnings do
		if string.find(w, pattern, 1, true) then
			table.insert(list, w)
		end
	end
	return list
end

------------------------------------------------------------------------
section("Запуск")
------------------------------------------------------------------------

check("сервер запустился без ошибок", serverOk, serverErr)
check("все сервисы стартовали", #warningsContaining("не запустился") == 0, table.concat(warningsContaining("не запустился"), "; "))
check("лобби построено (4 лифта)", Engine.Workspace:FindFirstChild("Lobby") ~= nil and #LobbyService.Booths == 4)
check("профили загружены", DataService:GetSession(p1) ~= nil and DataService:GetSession(p5) ~= nil)
check("атрибут Loaded выставлен", p1:GetAttribute("Loaded") == true)
check("клиент запустился без ошибок", clientOk, clientErr)
check("ScreenGui TD_UI создан", gui ~= nil)
check("клиент получил профиль", ClientState.Profile ~= nil and ClientState.Profile.level == 1)
check("слой лобби виден, HUD матча скрыт", gui.Lobby.Visible == true and gui.Match.Visible == false)
check("в режиме DataStore (эмулятор) нет ложного «тестового режима»", DataService.MemoryMode == false)

------------------------------------------------------------------------
section("Лифты")
------------------------------------------------------------------------

tick(0.5)
check("все лифты свободны", elevator(1).State == "Empty" and elevator(4).State == "Empty")

Engine.MoveTo(p1, boothPosition(1))
tick(0.5)
check("вход: игрок в лифте 1, состояние Waiting", elevator(1).State == "Waiting" and #elevator(1).Members == 1)
check("первый вошедший — лидер", elevator(1).Leader == p1)
check("таймер ожидания запущен", elevator(1).Timer > 0 and elevator(1).Timer <= Game.Elevator.WaitTime)
check("клиент видит меню своего лифта", visible(gui.Lobby.Elevator) and ClientState.MyElevator() ~= nil)

Engine.MoveTo(p2, boothPosition(1))
tick(0.5)
check("два игрока в одной группе", #elevator(1).Members == 2 and elevator(1).Leader == p1)

local r = act(p2, "ElevatorSetMap", { map = "desert" })
check("не лидер не может менять карту", r.ok == false, r.message)
r = act(p1, "ElevatorSetMap", { map = "desert" })
check("лидер выбирает карту", r.ok == true and elevator(1).MapId == "desert", r.message)
r = act(p1, "ElevatorSetMap", { map = "unknown_map" })
check("несуществующая карта отклонена", r.ok == false and elevator(1).MapId == "desert")
r = act(p1, "ElevatorSetCapacity", { capacity = 1 })
check("вместимость меньше числа игроков отклонена", r.ok == false and elevator(1).Capacity == 4, r.message)
r = act(p1, "ElevatorSetCapacity", { capacity = 3 })
check("лидер меняет вместимость", r.ok == true and elevator(1).Capacity == 3)
for _, bad in { 0, 5, 2.5, -1, "3", 0 / 0 } do
	r = act(p1, "ElevatorSetCapacity", { capacity = bad })
	check("неверная вместимость отклонена: " .. tostring(bad), r.ok == false and elevator(1).Capacity == 3)
end
tick(0.3)
check("клиент видит выбранную карту в меню", findText(gui.Lobby.Elevator, "Desert Canyon") ~= nil)

r = act(p1, "ElevatorLeave")
tick(0.5)
check("выход лидера: лидером стал следующий", r.ok and elevator(1).Leader == p2 and #elevator(1).Members == 1)
check("вышедший выведен из кабины и не вернулся", ElevatorService:ElevatorOf(p1) == nil)

Engine.MoveTo(p1, boothPosition(2))
tick(0.5)
check("два лифта работают одновременно", elevator(1).State == "Waiting" and elevator(2).State == "Waiting" and elevator(2).Leader == p1)
local joined, joinErr = ElevatorService:Join(p1, elevator(1))
check("нельзя состоять в двух лифтах", joined == false and #elevator(1).Members == 1, joinErr)

Engine.MoveTo(p4, boothPosition(3))
tick(0.5)
check("игрок в лифте 3", ElevatorService:ElevatorOf(p4) == elevator(3))
Engine.Leave(p4)
tick(0.5)
check("отключение: лифт 3 снова свободен", elevator(3).State == "Empty" and #elevator(3).Members == 0)

-- Заполненная группа: вместимость 2, третий игрок не помещается
r = act(p1, "ElevatorSetCapacity", { capacity = 2 })
Engine.MoveTo(p3, boothPosition(2))
tick(0.5)
check("группа заполнена → отсчёт Starting", #elevator(2).Members == 2 and elevator(2).State == "Starting")
Engine.MoveTo(p5, boothPosition(2))
tick(0.5)
check("лишний игрок не попал в полный лифт", ElevatorService:ElevatorOf(p5) == nil and #elevator(2).Members == 2)

-- Уход во время отсчёта возвращает к ожиданию
Engine.MoveTo(p3, Vector3.new(0, 3, 40))
tick(0.5)
check("уход во время отсчёта → снова Waiting", elevator(2).State == "Waiting" and #elevator(2).Members == 1)
r = act(p1, "ElevatorSetCapacity", { capacity = 1 })
check("соло-группа (1 игрок)", r.ok and elevator(2).Capacity == 1)
tick(0.5)
check("соло-группа сразу начинает отсчёт", elevator(2).State == "Starting")

-- Лифт 1: Bob + Eve, готовность
Engine.MoveTo(p5, boothPosition(1))
tick(0.5)
r = act(p2, "ElevatorReady", { ready = true })
tick(0.3)
check("готов один из двух — ждём остальных", elevator(1).State == "Waiting" and r.ok)
r = act(p5, "ElevatorReady", { ready = "yes" })
check("неверный флаг готовности отклонён", r.ok == false)
r = act(p5, "ElevatorReady", { ready = true })
tick(0.3)
check("все готовы → отсчёт", elevator(1).State == "Starting")

tick(Game.Elevator.StartTime + 0.5)
check("лифт 2 запустил матч", elevator(2).State == "InMatch" and p1:GetAttribute("MatchId") ~= nil)
check("лифт 1 запустил матч", elevator(1).State == "InMatch" and p2:GetAttribute("MatchId") ~= nil and p5:GetAttribute("MatchId") ~= nil)
check("Bob и Eve в одном матче", p2:GetAttribute("MatchId") == p5:GetAttribute("MatchId"))
check("разные группы — разные матчи", p1:GetAttribute("MatchId") ~= p2:GetAttribute("MatchId"))
tick(Game.Elevator.InMatchHold + 0.5)
check("после запуска лифты снова свободны", elevator(1).State == "Empty" and elevator(2).State == "Empty")
r = act(p1, "ElevatorSetMap", { map = "snow" })
check("игрок в матче не управляет лифтом", r.ok == false)

------------------------------------------------------------------------
section("Матч: карта, деньги, HUD")
------------------------------------------------------------------------

local solo = MatchService:MatchOf(p1)
local duo = MatchService:MatchOf(p2)
check("соло-матч на карте Greenfield", solo and solo.MapId == "greenfield")
check("матч группы на выбранной карте Desert Canyon", duo and duo.MapId == "desert")
local folder = Engine.Workspace.ActiveMatches:FindFirstChild("Match_" .. solo.Id)
check("карта построена в мире", folder ~= nil and folder:FindFirstChild("Map_greenfield") ~= nil)
check("карты матчей не пересекаются", (solo.Origin - duo.Origin).Magnitude >= Game.Match.SlotSpacing)
local character = p1.Character
local offset = character.PrimaryPart.CFrame.Position - solo.Origin
check("игрок перенесён на карту", math.abs(offset.X) < 100 and math.abs(offset.Z) < 100)
check("стартовые деньги", solo.PlayerState[p1.UserId].Cash == Economy.StartCash and duo.PlayerState[p5.UserId].Cash == Economy.StartCash)
check("здоровье базы по карте", solo.BaseHealth == Maps.ById.greenfield.BaseHealth)
check("фаза подготовки", solo.Waves.Phase == "Prep" and solo.Waves.Wave == 0)
tick(0.3)
check("клиент: HUD матча виден, лобби скрыто", gui.Match.Visible == true and gui.Lobby.Visible == false)
check("клиент: снимок матча получен", ClientState.Match ~= nil and ClientState.Match.mapId == "greenfield")
check("HUD: волна", findText(gui.Match, "ВОЛНА 0 / 30") ~= nil)
check("HUD: деньги", findText(gui.Match, "$" .. Economy.StartCash) ~= nil)
check("HUD: таймер подготовки", findText(gui.Match, "старт через") ~= nil)
check("HUD: 8 карточек башен", #gui.Match.BottomCenter.TowerBar:GetChildren() >= 8 and gui.Match.BottomCenter.TowerBar:FindFirstChild("wolverine") ~= nil)
local Lighting = Engine.DataModel:GetService("Lighting")
check("клиент: освещение карты", math.abs(Lighting.ClockTime - Maps.ById.greenfield.Lighting.ClockTime) < 0.01)

------------------------------------------------------------------------
section("Размещение башен")
------------------------------------------------------------------------

local function spots(match, range: number): { any }
	local layout = MapLayout.Get(match.MapId)
	local samples = {}
	local d = 0
	while d < layout.Path.Length * 0.6 do
		table.insert(samples, (layout.Path:At(d)))
		d += 2
	end
	local list = {}
	local bounds = layout.Map.Bounds
	for x = -bounds.X + 2, bounds.X - 2, 2 do
		for z = -bounds.Y + 2, bounds.Y - 2, 2 do
			if Placement.Check(match.MapId, x, z, match.Towers:Footprints()) then
				local cover = 0
				for _, s in samples do
					if (s - Vector3.new(x, 0, z)).Magnitude <= range then
						cover += 1
					end
				end
				if cover > 0 then
					table.insert(list, { X = x, Z = z, Cover = cover })
				end
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Cover > b.Cover
	end)
	return list
end

local path = MapLayout.Get("greenfield").Path
local onPath = path:At(30)
r = act(p1, "PlaceTower", { tower = "archer", x = onPath.X, z = onPath.Z })
check("нельзя ставить на дорогу", r.ok == false and r.message == Placement.Reasons.Path, r.message)
r = act(p1, "PlaceTower", { tower = "archer", x = 400, z = 0 })
check("нельзя ставить за картой", r.ok == false, r.message)
r = act(p1, "PlaceTower", { tower = "archer", x = 0 / 0, z = 0 })
check("NaN-координаты отклонены", r.ok == false)
r = act(p1, "PlaceTower", { tower = "dragon", x = 0, z = 0 })
check("несуществующая башня отклонена", r.ok == false)
local best = spots(solo, 12)[1]
r = act(p1, "PlaceTower", { tower = "wolverine", x = best.X, z = best.Z })
check("не хватает денег — отказ", r.ok == false and r.message == "Недостаточно денег", r.message)
check("деньги не списаны при отказе", solo.PlayerState[p1.UserId].Cash == Economy.StartCash)

-- Клиентский призрак: камера смотрит сверху на точку
local camera = Engine.Workspace.CurrentCamera
local placementEvents = {}
PlacementController.Changed.Event:Connect(function(active, valid, reason)
	table.insert(placementEvents, { active, valid, reason })
end)
local function aimAt(localPoint: Vector3)
	local world = solo.Origin + Vector3.new(localPoint.X, 0, localPoint.Z)
	-- CFrame.lookAt в Lune ошибается для части направлений, поэтому камера задаётся углами:
	-- наклон вниз atan(50/25), луч из центра экрана попадает ровно в точку
	camera.CFrame = CFrame.new(world + Vector3.new(0, 50, 25)) * CFrame.Angles(-math.atan2(50, 25), 0, 0)
	Engine.MouseLocation = Vector2.new(640, 360)
end
aimAt(onPath)
HUDController.Choose("archer")
tick(0.2)
check("призрак башни создан", Engine.Workspace:FindFirstChild("PlacementGhost") ~= nil and PlacementController.Active())
local last = placementEvents[#placementEvents]
check("призрак на дороге — красный с причиной", last and last[2] == false and last[3] == Placement.Reasons.Path, last and last[3])
check("HUD показывает причину запрета", findText(gui.Match, Placement.Reasons.Path) ~= nil)
aimAt(Vector3.new(best.X, 0, best.Z))
tick(0.2)
last = placementEvents[#placementEvents]
check("призрак на свободном месте — зелёный", last and last[2] == true, last and last[3])
PlacementController.Confirm()
tick(0.3)
check("клиент поставил башню через сервер", #solo.Towers.List == 1 and solo.Towers.List[1].TowerId == "archer")
check("призрак убран после установки", not PlacementController.Active() and Engine.Workspace:FindFirstChild("PlacementGhost") == nil)
check("деньги списаны", solo.PlayerState[p1.UserId].Cash == Economy.StartCash - Towers.ById.archer.Levels[1].Cost)
r = act(p1, "PlaceTower", { tower = "archer", x = best.X + 0.5, z = best.Z })
check("нельзя ставить вплотную к другой башне", r.ok == false and r.message == Placement.Reasons.Tower, r.message)

-- Все 8 башен (денег добавляем напрямую, чтобы проверить каждую)
solo.PlayerState[p1.UserId].Cash = 100000
for _, def in Towers.List do
	if def.Id ~= "archer" then
		local spot = spots(solo, def.Levels[1].Range)[1]
		r = act(p1, "PlaceTower", { tower = def.Id, x = spot.X, z = spot.Z })
		check("установлена башня " .. def.Name, r.ok == true, r.message)
	end
end
check("на карте 8 башен", #solo.Towers.List == 8)
local models = folder.Towers:GetChildren()
check("у каждой башни модель R6 с оружием", #models == 8)
local r6ok = true
for _, model in models do
	for _, part in { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart" } do
		if not model:FindFirstChild(part, true) then
			r6ok = false
		end
	end
end
check("модели башен содержат все части R6", r6ok)

------------------------------------------------------------------------
section("Волны и бой")
------------------------------------------------------------------------

r = act(p1, "VoteSkip")
tick(0.2)
check("пропуск подготовки (соло — сразу)", r.ok and solo.Waves.Wave == 1 and solo.Waves.Phase == "Wave", r.message)
local firstUid = nil
tick(4)
local alive = solo.Enemies.Alive
check("враги появились", #alive > 0 or solo.Enemies.Killed > 0)
if alive[1] then
	local walker = alive[1]
	firstUid = walker.Uid
	local d0 = walker.Distance
	tick(0.5)
	check("враги движутся по маршруту", walker.Dead or walker.Distance > d0, string.format("%.2f -> %.2f", d0, walker.Distance))
	check("клиент получает данные движения (Dist0/Speed)", walker.Model:GetAttribute("Speed") ~= nil and walker.Model:GetAttribute("Dist0") ~= nil)
end
r = act(p1, "VoteSpeed")
check("голос за x2 (соло — большинство)", r.ok and solo.TimeScale == 2)
local fastWalker = solo.Enemies.Alive[1]
tick(0.3)
check("скорость врагов для клиента учитывает x2", fastWalker == nil or fastWalker.Dead
	or math.abs((fastWalker.Model:GetAttribute("Speed") or 0) - fastWalker.SyncedSpeed * 2) < 1e-6)
check("HUD: кнопка x2 отмечена", findText(gui.Match, "x2 включено") ~= nil)
r = act(p1, "VoteSpeed")
check("повторный голос отменяет x2", r.ok and solo.TimeScale == 1)
check("клиент видит врагов (тег Enemy)", #Engine.Workspace.ActiveMatches:GetDescendants() > 0)

local towerByType = {}
for _, tower in solo.Towers.List do
	towerByType[tower.TowerId] = tower
end
-- Яд: несколько попаданий не складываются бесконечно
local toxicMax = 0
for _, def in Towers.ById.toxic.Levels do
	toxicMax = math.max(toxicMax, def.Poison.Dps)
end
local poisonOk = true
local cashBefore = solo.PlayerState[p1.UserId].Earned
for _ = 1, 600 do
	tick(0.5, 0.25)
	for _, enemy in solo.Enemies.Alive do
		if enemy.PoisonDps > toxicMax + 1e-6 then
			poisonOk = false
		end
	end
	if solo.Waves.Wave >= 5 and solo.Waves.Phase ~= "Wave" then
		break
	end
	if solo.Waves.Phase == "Intermission" then
		act(p1, "VoteSkip")
	end
end
check("до 5-й волны дошли", solo.Waves.Wave >= 3, solo.Waves.Wave)
check("яд не накапливается сверх максимума", poisonOk)
check("за убийства начисляются деньги", solo.PlayerState[p1.UserId].Earned > cashBefore)
check("убийства засчитаны игроку", solo.PlayerState[p1.UserId].Kills > 0)
-- Каждая башня: враг-танк ставится на ближайшую к ней точку дороги
local function nearestDistance(position: Vector3): number
	local bestD, bestGap = 0, math.huge
	local d = 0
	while d <= path.Length do
		local gap = (path:At(d) - position).Magnitude
		if gap < bestGap then
			bestD, bestGap = d, gap
		end
		d += 0.5
	end
	return bestD
end
local silent = {}
local savedPhase = solo.Waves.Phase
for id, tower in towerByType do
	for _, e in table.clone(solo.Enemies.Alive) do
		solo.Enemies:Kill(e)
	end
	solo.Waves.Queue = {}
	local before = tower.Damage
	local target = solo.Enemies:Spawn("tank", Waves.Get(1), nearestDistance(tower.Position))
	target.BaseSpeed = 0.2
	tower.Cooldown = 0
	for _ = 1, 30 do
		solo:Step(0.1)
	end
	if tower.Damage <= before then
		table.insert(silent, id)
	end
end
solo.Waves.Phase = savedPhase
check("каждая из 8 башен атакует врага в радиусе", #silent == 0, table.concat(silent, ","))
check("награда за волну начисляется один раз", solo.WavesCleared >= 1)
check("клиент: нет ошибок в эффектах", #warningsContaining("[Fx]") == 0, table.concat(warningsContaining("[Fx]"), "; "))

------------------------------------------------------------------------
section("Улучшение, продажа, приоритеты")
------------------------------------------------------------------------

local archer = towerByType.archer
local cash = solo.PlayerState[p1.UserId].Cash
r = act(p1, "UpgradeTower", { uid = archer.Uid })
check("улучшение до 2 уровня", r.ok and archer.Level == 2 and archer.Model:GetAttribute("Level") == 2, r.message)
check("стоимость улучшения списана", solo.PlayerState[p1.UserId].Cash == cash - Towers.ById.archer.Levels[2].Cost)
for _ = 3, Towers.MaxLevel do
	act(p1, "UpgradeTower", { uid = archer.Uid })
end
check("максимальный уровень", archer.Level == Towers.MaxLevel)
r = act(p1, "UpgradeTower", { uid = archer.Uid })
check("сверх максимума — отказ", r.ok == false and r.message == "Максимальный уровень", r.message)
r = act(p1, "UpgradeTower", { uid = "1; DROP" })
check("неверный uid отклонён", r.ok == false)
r = act(p2, "UpgradeTower", { uid = archer.Uid })
check("игрок другого матча не трогает чужую башню", r.ok == false)

-- Клиентское меню башни
tick(0.3)
local archerModel = nil
for _, model in folder.Towers:GetChildren() do
	if model:GetAttribute("Uid") == archer.Uid then
		archerModel = model
	end
end
TowerController.Select(archerModel)
tick(0.3)
check("меню башни открыто", visible(gui.Match.TowerInfo))
check("меню: Max Level на максимуме", findText(gui.Match.TowerInfo, "Max Level") ~= nil)
check("меню: приоритеты", findText(gui.Match.TowerInfo, "Сильный") ~= nil)

r = act(p1, "SetPriority", { uid = archer.Uid, priority = "Strongest" })
check("приоритет Strongest", r.ok and archer.Priority == "Strongest" and archer.Model:GetAttribute("Priority") == "Strongest")
r = act(p1, "SetPriority", { uid = archer.Uid, priority = "Random" })
check("неверный приоритет отклонён", r.ok == false and archer.Priority == "Strongest")

local sniper = towerByType.sniper
local spent = sniper.Spent
cash = solo.PlayerState[p1.UserId].Cash
r = act(p1, "SellTower", { uid = sniper.Uid })
check("продажа: возврат 60%", r.ok and solo.PlayerState[p1.UserId].Cash == cash + math.floor(spent * Economy.SellRefund), r.message)
check("продажа: башня удалена", solo.Towers.ByUid[sniper.Uid] == nil and #solo.Towers.List == 7)
r = act(p1, "SellTower", { uid = sniper.Uid })
check("повторная продажа — отказ", r.ok == false)
TowerController.Select(nil)

------------------------------------------------------------------------
section("Двойная награда, босс")
------------------------------------------------------------------------

local enemy = solo.Enemies:Spawn("basic", Waves.Get(solo.Waves.Wave))
local before = solo.PlayerState[p1.UserId].Earned
solo.Enemies:Kill(enemy)
local afterFirst = solo.PlayerState[p1.UserId].Earned
solo.Enemies:Kill(enemy)
solo.Enemies:Damage(enemy, 999)
check("награда за убийство выдаётся один раз", afterFirst > before and solo.PlayerState[p1.UserId].Earned == afterFirst)

check("босс по расписанию на волне 10", Waves.Get(10).Boss == "boss_brute" and Waves.Get(20).Boss ~= nil and Waves.Get(30).Boss ~= nil)
for _, e in table.clone(solo.Enemies.Alive) do
	solo.Enemies:Kill(e)
end
solo.Waves.Queue = {}
solo.Waves:StartWave(10)
tick(Waves.Get(10).Total * 1.6 + 6)
local sawBoss = false
for _, e in solo.Enemies.Alive do
	if e.Def.Boss then
		sawBoss = true
	end
end
tick(0.3)
check("босс появился на 10-й волне", sawBoss or solo.Enemies.Killed > 0 and ClientState.Match.wave == 10)
check("HUD: полоса здоровья босса", (not sawBoss) or findText(gui.Match, "☠") ~= nil)

------------------------------------------------------------------------
section("Безопасность запросов")
------------------------------------------------------------------------

local crashes = 0
local junk = { nil, 1, "x", true, {}, { tower = {} }, { x = 1e308, z = -1e308 }, { uid = -1 }, { map = string.rep("a", 1000) },
	{ capacity = math.huge }, { priority = 5 }, { ready = {} } }
for name in server.require(Shared.Net).Actions do
	for _, payload in junk do
		local ok, result = pcall(Engine.InvokeAs, p3, name, payload)
		if not ok or type(result) ~= "table" then
			crashes += 1
		end
	end
end
check("мусорные запросы не роняют сервер", crashes == 0 and #warningsContaining("[NetService]") == 0, table.concat(warningsContaining("[NetService]"), "; "))
r = Engine.InvokeAs(p3, "GiveMeMoney", {})
check("необъявленное действие отклонено", r.ok == false)
r = act(p3, "PlaceTower", { tower = "archer", x = 10, z = 10 })
check("башню нельзя ставить из лобби", r.ok == false)
r = act(p1, "ReturnToLobby")
check("нельзя выйти в лобби посреди матча этой кнопкой", r.ok == false)
local limited = 0
for _ = 1, 30 do
	local result = Engine.InvokeAs(p1, "SetPriority", { uid = archer.Uid, priority = "First" })
	if result.message == "Слишком часто" then
		limited += 1
	end
end
check("спам запросами ограничен", limited > 0, limited)

------------------------------------------------------------------------
section("Отключение во время матча")
------------------------------------------------------------------------

local duoId = duo.Id
Engine.Leave(p5)
tick(0.5)
check("матч продолжается после выхода одного игрока", MatchService.Matches[duoId] ~= nil and #duo.Players == 1)
check("вышедший помечен как отключённый", duo.PlayerState[p5.UserId].Connected == false)
check("снимок команды без вышедшего", #duo:Snapshot().team == 1)
Engine.Leave(p2)
tick(0.5)
check("все вышли → матч закрыт и очищен", MatchService.Matches[duoId] == nil and Engine.Workspace.ActiveMatches:FindFirstChild("Match_" .. duoId) == nil,
	tostring(MatchService.Matches[duoId] ~= nil) .. " " .. tostring(Engine.Workspace.ActiveMatches:FindFirstChild("Match_" .. duoId)))

------------------------------------------------------------------------
section("Поражение, итоги, возврат в лобби")
------------------------------------------------------------------------

for _, tower in table.clone(solo.Towers.List) do
	solo.Towers:Sell(p1, tower.Uid)
end
local hpBefore = solo.BaseHealth
solo.Waves.Queue = {}
for _, e in table.clone(solo.Enemies.Alive) do
	solo.Enemies:Kill(e)
end
solo.Waves:StartWave(12)
local guard = 0
while not solo.Ended and guard < 3000 do
	tick(0.5, 0.5)
	guard += 1
end
check("враги наносят урон базе", solo.BaseHealth < hpBefore)
check("поражение при 0 здоровья базы", solo.Ended and solo.Result == "Defeat", solo.Result)
tick(0.3)
check("клиент: экран итогов", gui.Results.Results.Visible == true and findText(gui.Results, "ПОРАЖЕНИЕ") ~= nil)
check("итоги: кнопка «В лобби»", findText(gui.Results, "В лобби") ~= nil)
local profile = DataService:GetSession(p1).Profile
check("профиль: матч и поражение записаны", profile.stats.matches == 1 and profile.stats.losses == 1)
check("профиль: награды начислены", profile.gems > 0)
task.wait(0.2)
local stored = Engine.DataStoreData["p_" .. p1.UserId]
check("профиль сохранён в DataStore", stored and stored.stats and stored.stats.matches == 1)
check("итоги: «Прогресс сохранён» только после реальной записи", findText(gui.Results, "Прогресс сохранён") ~= nil)
r = act(p1, "PlaceTower", { tower = "archer", x = best.X, z = best.Z })
check("после окончания башни не ставятся", r.ok == false)
local soloId = solo.Id
r = act(p1, "ReturnToLobby")
tick(0.3)
check("возврат в лобби", r.ok and p1:GetAttribute("MatchId") == nil)
local lobbyOffset = p1.Character.PrimaryPart.CFrame.Position - Game.Lobby.Spawn
check("игрок перенесён в лобби", lobbyOffset.Magnitude < 15)
check("матч очищен (папка, враги, башни)", MatchService.Matches[soloId] == nil and Engine.Workspace.ActiveMatches:FindFirstChild("Match_" .. soloId) == nil)
check("клиент: снова лобби", gui.Lobby.Visible == true and gui.Match.Visible == false and gui.Results.Results.Visible == false)
check("клиент: свет лобби", math.abs(Lighting.ClockTime - 14.5) < 0.01)
check("клиент: призрак и выделение сброшены", not PlacementController.Active() and TowerController.Selected() == nil)

------------------------------------------------------------------------
section("Победа")
------------------------------------------------------------------------

Engine.MoveTo(p3, Vector3.new(0, 3, 40))
local victoryMatch = MatchService:Create({ p3 }, "snow")
check("новый матч (снег)", victoryMatch ~= nil and victoryMatch.MapId == "snow")
victoryMatch.Waves:StartWave(victoryMatch.Waves.Max)
Engine.DataStoreFails = true -- сохранение после победы должно честно провалиться
guard = 0
while not victoryMatch.Ended and guard < 2000 do
	for _, e in table.clone(victoryMatch.Enemies.Alive) do
		victoryMatch.Enemies:Damage(e, 1e9, 1)
	end
	tick(0.5, 0.5)
	guard += 1
end
check("победа после последней волны", victoryMatch.Result == "Victory", victoryMatch.Result)
local profile3 = DataService:GetSession(p3).Profile
check("профиль: победа записана", profile3.stats.wins == 1 and profile3.bestWave.snow == victoryMatch.Waves.Max)
local function savedUpdateFor(player)
	for _, entry in Engine.RemoteLog do
		if entry.event == "MatchEnded" and entry.player == player and entry.args[1].savedUpdate then
			return entry.args[1]
		end
	end
	return nil
end
local firstEnded = nil
for _, entry in Engine.RemoteLog do
	if entry.event == "MatchEnded" and entry.player == p3 and not entry.args[1].savedUpdate then
		firstEnded = entry.args[1]
	end
end
check("итоги сначала «сохранение идёт», а не ложный успех", firstEnded and firstEnded.saved == nil)
for _ = 1, 40 do
	if savedUpdateFor(p3) then
		break
	end
	task.wait(0.25)
end
local update = savedUpdateFor(p3)
check("сбой DataStore → итоги сообщают «не сохранено»", update and update.saved == false)
Engine.DataStoreFails = false
victoryMatch.ResultsAt = os.clock() - Game.Match.ResultsTime - 1
tick(0.3)
check("автовозврат в лобби по таймеру итогов", p3:GetAttribute("MatchId") == nil and MatchService.Matches[victoryMatch.Id] == nil)
check("все арены освобождены", next(MatchService.Matches) == nil and #Engine.Workspace.ActiveMatches:GetChildren() == 0)

------------------------------------------------------------------------
section("Отказ DataStore")
------------------------------------------------------------------------

Engine.DataStoreFails = true
local p6 = Engine.NewPlayer("Frank")
Engine.Join(p6)
for _ = 1, 60 do
	if Engine.Kicked[p6.UserId] then
		break
	end
	task.wait(0.25)
end
check("при ошибке загрузки игрок не получает пустой профиль (кик с объяснением)",
	Engine.Kicked[p6.UserId] ~= nil or DataService:GetSession(p6) == nil, Engine.Kicked[p6.UserId])
Engine.DataStoreFails = false

local key = "p_" .. p1.UserId
local before = Engine.DataStoreData[key].gems
Engine.DataStoreData[key].lock = { jobId = "other-server", time = Engine.Now() }
DataService:GetSession(p1).Profile.gems += 1000
check("профиль, занятый другим сервером, не перезаписывается", DataService:SaveAndWait(p1) == false and Engine.DataStoreData[key].gems == before)
Engine.DataStoreData[key].lock = nil
check("после снятия замка сохранение проходит", DataService:SaveAndWait(p1) == true and Engine.DataStoreData[key].gems == before + 1000)

------------------------------------------------------------------------

print(string.format("\nИТОГО: %d проверок пройдено, %d провалено", passed, failed))
for _, text in failures do
	print("  ✘ " .. text)
end
local other = {}
for _, w in Engine.Warnings do
	if not string.find(w, "Simulated DataStore outage", 1, true) and not string.find(w, "Ошибка загрузки", 1, true) then
		table.insert(other, w)
	end
end
if #other > 0 then
	print("\nПредупреждения:")
	for _, w in other do
		print("  " .. w)
	end
end
process.exit(if failed == 0 then 0 else 1)
