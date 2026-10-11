--[[
	Предпросмотр интерфейса: запускает сервер и клиент в эмуляторе (tests/sim/Engine),
	проводит игрока через лобби, лифт, матч и итоги и выгружает дерево GUI в JSON.
	Затем tools/preview/render.js рисует JSON в браузере.

	Запуск:  lune run tools/preview/dump.luau <папка-вывода>
	         node tools/preview/render.js <папка-вывода>
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local Engine = require("../../tests/sim/Engine")

local Vector3 = roblox.Vector3
local Vector2 = roblox.Vector2
local outDir = process.args[1] or "preview-out"
if not fs.isDir(outDir) then
	fs.writeDir(outDir)
end

local server = Engine.Realm(true)
server.require(Engine.ServerNode)
local S = Engine.ServerNode.Services
local DataService = server.require(S.DataService)
local LobbyService = server.require(S.LobbyService)
local MatchService = server.require(S.MatchService)
local Waves = server.require(Engine.SharedNode.Config.Waves)
local MapLayout = server.require(Engine.SharedNode.Logic.MapLayout)
local Placement = server.require(Engine.SharedNode.Logic.Placement)

local player = Engine.NewPlayer("Alice")
local friend = Engine.NewPlayer("Bob_TheBuilder")
Engine.LocalPlayer = player
Engine.Join(player)
Engine.Join(friend)
Engine.SpawnCharacter(player, Vector3.new(0, 3, 40))
Engine.SpawnCharacter(friend, Vector3.new(3, 3, 40))
task.wait(0.3)
local profile = DataService:GetSession(player).Profile
profile.gems = 1340
profile.level = 7
profile.xp = 420
profile.stats.wins = 12
DataService:SendProfile(player)

local client = Engine.Realm(false)
client.require(Engine.ClientNode)
task.wait(0.3)
local C = Engine.ClientNode.Controllers
local LobbyController = client.require(C.LobbyController)
local PlacementController = client.require(C.PlacementController)
local TowerController = client.require(C.TowerController)
local HUDController = client.require(C.HUDController)
local Notifications = client.require(Engine.ClientNode.UI.Notifications)
local input = client.game:GetService("UserInputService")
local camera = Engine.Workspace.CurrentCamera

local function tick(seconds: number)
	for _ = 1, math.max(1, math.floor(seconds / 0.1)) do
		server.RunService.Heartbeat:FireSync(0.1)
		client.RunService.Heartbeat:FireSync(0.1)
		client.RunService.RenderStepped:FireSync(0.1)
	end
end

------------------------------------------------------------------------
-- Выгрузка дерева
------------------------------------------------------------------------

local function get(instance, property)
	local ok, value = pcall(function()
		return instance[property]
	end)
	return if ok then value else nil
end

local function udim2(value)
	if not value then
		return nil
	end
	return { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
end

local function color(value)
	if not value then
		return nil
	end
	return { math.floor(value.R * 255 + 0.5), math.floor(value.G * 255 + 0.5), math.floor(value.B * 255 + 0.5) }
end

local function enumName(value)
	return if value then value.Name else nil
end

local WEIGHTS = { Medium = 500, SemiBold = 600, Bold = 700, ExtraBold = 800, Regular = 400, Heavy = 900 }
local R6 = { HumanoidRootPart = true, Head = true, Torso = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true,
	["Right Leg"] = true, Pedestal = true }

local function dump(instance)
	local class = instance.ClassName
	local node = { c = class, n = instance.Name, children = {}, mods = {} }
	if instance:IsA("GuiObject") then
		node.size = udim2(get(instance, "Size"))
		node.pos = udim2(get(instance, "Position"))
		local anchor = get(instance, "AnchorPoint")
		node.anchor = if anchor then { anchor.X, anchor.Y } else { 0, 0 }
		node.vis = get(instance, "Visible")
		node.bg = color(get(instance, "BackgroundColor3"))
		node.bgt = get(instance, "BackgroundTransparency")
		node.z = get(instance, "ZIndex")
		node.rot = get(instance, "Rotation")
		node.lo = get(instance, "LayoutOrder")
		node.clip = get(instance, "ClipsDescendants")
		node.autosize = enumName(get(instance, "AutomaticSize"))
		if instance:IsA("TextLabel") or instance:IsA("TextButton") then
			node.text = get(instance, "Text")
			node.tc = color(get(instance, "TextColor3"))
			node.tsize = get(instance, "TextSize")
			node.wrap = get(instance, "TextWrapped")
			node.xa = enumName(get(instance, "TextXAlignment"))
			node.ya = enumName(get(instance, "TextYAlignment"))
			node.tt = get(instance, "TextTransparency")
			node.trunc = enumName(get(instance, "TextTruncate")) == "AtEnd"
			local face = get(instance, "FontFace")
			node.fw = if face then WEIGHTS[face.Weight.Name] or 600 else 600
		end
		if class == "ViewportFrame" then
			local model = instance:FindFirstChildOfClass("Model")
			if model then
				local function partColor(name)
					local p = model:FindFirstChild(name)
					return if p then color(p.Color) else nil
				end
				local accent = nil
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") and not R6[d.Name] and d.Transparency < 1 and not accent then
						accent = color(d.Color)
					end
				end
				node.viewport = { head = partColor("Head"), torso = partColor("Torso"), arm = partColor("Right Arm"), leg = partColor("Left Leg"),
					accent = accent }
			end
		end
		if node.vis == false then
			return node
		end
	end
	for _, child in instance:GetChildren() do
		local cc = child.ClassName
		if cc == "UIListLayout" then
			node.mods.list = {
				dir = enumName(get(child, "FillDirection")),
				pad = { get(child, "Padding").Scale, get(child, "Padding").Offset },
				ha = enumName(get(child, "HorizontalAlignment")),
			}
		elseif cc == "UIGridLayout" then
			node.mods.grid = { cell = udim2(get(child, "CellSize")), pad = udim2(get(child, "CellPadding")) }
		elseif cc == "UIPadding" then
			node.mods.pad = {
				get(child, "PaddingLeft").Offset, get(child, "PaddingRight").Offset,
				get(child, "PaddingTop").Offset, get(child, "PaddingBottom").Offset,
			}
		elseif cc == "UICorner" then
			local r = get(child, "CornerRadius")
			node.mods.corner = { r.Scale, r.Offset }
		elseif cc == "UIStroke" then
			if get(child, "Enabled") ~= false then
				node.mods.strokes = node.mods.strokes or {}
				table.insert(node.mods.strokes, {
					t = get(child, "Thickness"), c = color(get(child, "Color")),
					border = enumName(get(child, "ApplyStrokeMode")) == "Border", tr = get(child, "Transparency"),
				})
			end
		elseif cc == "UIGradient" then
			local seq = get(child, "Color")
			local kps = seq and seq.Keypoints
			if kps then
				node.mods.gradient = { a = color(kps[1].Value), b = color(kps[#kps].Value), rot = get(child, "Rotation") }
			end
		elseif cc == "UIScale" then
			if child.Name == "FitScale" then
				node.mods.scale = get(child, "Scale")
			end
		elseif child:IsA("GuiObject") or child:IsA("LayerCollector") then
			table.insert(node.children, dump(child))
		end
	end
	return node
end

local function setScreen(width: number, height: number)
	-- Узкий экран считаем телефоном (сенсор без мыши)
	input.TouchEnabled = width < 1000
	input.MouseEnabled = width >= 1000
	camera.ViewportSize = Vector2.new(width, height)
	Engine.SignalOf(camera, "Changed:ViewportSize"):FireSync()
end

local function scene(name: string, width: number?, height: number?)
	local w, h = width or 1280, height or 720
	setScreen(w, h)
	tick(0.3)
	local tree = dump(player.PlayerGui)
	fs.writeFile(string.format("%s/%s@%dx%d.json", outDir, name, w, h), serde.encode("json", tree))
	print("scene", name, w, h)
end

------------------------------------------------------------------------
-- Сцены
------------------------------------------------------------------------

tick(0.5)
Notifications.Show("Добро пожаловать! Зайди в лифт, чтобы начать матч", "info")
scene("lobby")

Engine.MoveTo(player, LobbyService.Booths[1].Center + Vector3.new(0, 3, 0))
Engine.MoveTo(friend, LobbyService.Booths[1].Center + Vector3.new(1, 3, 0))
tick(0.5)
Engine.InvokeAs(player, "ElevatorSetMap", { map = "neon" })
Engine.InvokeAs(friend, "ElevatorReady", { ready = true })
scene("lobby_elevator")
scene("lobby_elevator", 844, 390)

LobbyController.ToggleCollection()
scene("lobby_collection")
LobbyController.ToggleCollection()

-- Матч на двоих
Engine.MoveTo(player, Vector3.new(0, 3, 40))
Engine.MoveTo(friend, Vector3.new(3, 3, 40))
tick(0.5)
local match = MatchService:Create({ player, friend }, "greenfield")
tick(0.5)
-- Несколько башен игроков
local layout = MapLayout.Get("greenfield")
local placed = 0
for x = -60, 60, 7 do
	for z = -50, 50, 7 do
		if placed < 6 and Placement.Check("greenfield", x, z, match.Towers:Footprints()) and layout.Path:DistanceTo(Vector3.new(x, 0, z)) < 9 then
			local towerIds = { "archer", "swordsman", "toxic", "pistol", "sniper", "lumberjack" }
			match.PlayerState[player.UserId].Cash = 5000
			match.Towers:Place(if placed % 3 == 2 then friend else player, towerIds[placed + 1], x, z)
			placed += 1
		end
	end
end
match.PlayerState[player.UserId].Cash = 1250
match.PlayerState[friend.UserId].Cash = 640
scene("match_prep")

-- Волна с боссом и выбранная башня
match.Waves:StartWave(10)
tick(30)
local boss = nil
for _, e in match.Enemies.Alive do
	if e.Def.Boss then
		boss = e
	end
end
if boss then
	boss.Health = math.floor(boss.MaxHealth * 0.62)
end
match.BaseHealth = 84
match:MarkDirty()
tick(0.3)
local towerModel = nil
for _, model in Engine.Workspace.ActiveMatches:GetDescendants() do
	if model:IsA("Model") and model:GetAttribute("TowerId") == "archer" and model:GetAttribute("OwnerId") == player.UserId then
		towerModel = model
	end
end
TowerController.Select(towerModel)
scene("match_tower")
scene("match_tower", 844, 390)
TowerController.Select(nil)

-- Размещение с причиной запрета (телефон: кнопки «Поставить/Отмена»)
setScreen(844, 390)
local onRoad = layout.Path:At(60)
local world = match.Origin + onRoad
camera.CFrame = roblox.CFrame.new(world + Vector3.new(0, 50, 25)) * roblox.CFrame.Angles(-math.atan2(50, 25), 0, 0)
Engine.MouseLocation = Vector2.new(422, 195)
HUDController.Choose("minigunner")
scene("match_place", 844, 390)
PlacementController.Stop()

-- Итоги
match.Waves.Queue = {}
for _, e in table.clone(match.Enemies.Alive) do
	match.Enemies:Kill(e)
end
match.WavesCleared = 30
match.Waves.Wave = 30
match:Finish(true)
tick(0.3)
scene("results")
scene("results", 844, 390)

process.exit(0)
