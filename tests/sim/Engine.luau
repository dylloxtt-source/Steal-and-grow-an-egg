--[[
	Мини-эмулятор движка Roblox поверх Lune (@lune/roblox) для интеграционных тестов.

	Настоящие инстансы (Part, Model, TextLabel, ...) берутся из Lune — он проверяет
	имена свойств и типы, поэтому опечатка в коде игры сразу роняет тест.
	Недостающее (события, PivotTo, RemoteFunction, сервисы) эмулируется здесь.
	Сервер и клиент работают в одном процессе с раздельными кешами модулей
	и общаются через те же RemoteEvent/RemoteFunction, что и в игре.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Engine = {}

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

------------------------------------------------------------------------
-- Сигналы
------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local connection = { Connected = true }
	function connection.Disconnect()
		connection.Connected = false
	end
	table.insert(self.handlers, { fn = fn, connection = connection })
	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection.Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	for _, handler in table.clone(self.handlers) do
		if handler.connection.Connected then
			task.spawn(handler.fn, ...)
		end
	end
end

-- Синхронный вызов (обработчики выполняются до возврата, без отдельных потоков)
function Signal:FireSync(...)
	for _, handler in table.clone(self.handlers) do
		if handler.connection.Connected then
			handler.fn(...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

Engine.Signal = Signal

------------------------------------------------------------------------
-- Время
------------------------------------------------------------------------

Engine.TimeOffset = 0
local baseTime = 1_760_000_000

function Engine.Now(): number
	return baseTime + Engine.TimeOffset
end

function Engine.Advance(seconds: number)
	Engine.TimeOffset += seconds
end

------------------------------------------------------------------------
-- События и методы инстансов
------------------------------------------------------------------------

-- Lune не интернирует userdata инстансов (две ссылки на один объект — разные ключи),
-- поэтому стабильный идентификатор храним в атрибуте.
local nextSimId = 0
local function idOf(instance): number
	local id = instance:GetAttribute("__sim")
	if not id then
		nextSimId += 1
		id = nextSimId
		instance:SetAttribute("__sim", id)
	end
	return id
end
Engine.IdOf = idOf

local signals = {}
local function signalOf(instance, name)
	local key = idOf(instance)
	local perInstance = signals[key]
	if not perInstance then
		perInstance = {}
		signals[key] = perInstance
	end
	local signal = perInstance[name]
	if not signal then
		signal = Signal.new()
		perInstance[name] = signal
	end
	return signal
end
Engine.SignalOf = signalOf

local EVENTS = {
	"Touched", "Triggered", "Activated", "MouseEnter", "MouseLeave", "MouseButton1Down", "MouseButton1Up",
	"ChildAdded", "ChildRemoved", "DescendantAdded", "Destroying", "AttributeChanged", "Died",
	"CharacterAdded", "CharacterRemoving", "PlayerAdded", "PlayerRemoving", "OnClientEvent", "OnServerEvent",
	"Event", "Completed",
}
for _, name in EVENTS do
	roblox.implementProperty("Instance", name, function(self)
		return signalOf(self, name)
	end)
end

-- Destroy как в Roblox: уничтоженный инстанс остаётся читаемым (в Lune — нет),
-- Parent = nil, события отключаются. Встроенный Destroy в Lune не переопределить,
-- поэтому загрузчик переписывает «x:Destroy()» на Engine.Destroy(x).
function Engine.Destroy(instance)
	if type(instance) == "table" and type(instance.Destroy) == "function" then
		return instance:Destroy() -- метод Lua-объекта (например, Match:Destroy), а не инстанса
	end
	if typeof(instance) ~= "Instance" then
		return
	end
	local id = instance:GetAttribute("__sim")
	if id and signals[id] and signals[id].Destroying then
		signals[id].Destroying:FireSync()
	end
	for _, child in instance:GetChildren() do
		Engine.Destroy(child)
	end
	instance.Parent = nil
	if id then
		signals[id] = nil
	end
end
function Engine.ClearAllChildren(instance)
	for _, child in instance:GetChildren() do
		Engine.Destroy(child)
	end
end

roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(self, property)
	return signalOf(self, "Changed:" .. property)
end)

-- Атрибуты: нативный SetAttribute в Lune не шлёт сигналов, поэтому загрузчик
-- переписывает «x:SetAttribute(...)» на Engine.SetAttribute (см. transformSource)
roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(self, name)
	return signalOf(self, "Attr:" .. name)
end)
function Engine.SetAttribute(instance, name, value)
	local old = instance:GetAttribute(name)
	instance:SetAttribute(name, value)
	if old ~= value then
		signalOf(instance, "Attr:" .. name):Fire()
		signalOf(instance, "AttributeChanged"):Fire(name)
	end
end

-- Камера: лучи через точку экрана с учётом FieldOfView и соотношения сторон
local function screenRay(camera, x, y)
	local viewport = camera.ViewportSize
	local h = math.tan(math.rad(camera.FieldOfView) / 2)
	local nx = (x / viewport.X) * 2 - 1
	local ny = 1 - (y / viewport.Y) * 2
	local cf = camera.CFrame
	local direction = (cf.RightVector * (nx * h * viewport.X / viewport.Y) + cf.UpVector * (ny * h) + cf.LookVector).Unit
	return roblox.Ray.new(cf.Position, direction)
end
-- Производные свойства вложений (в Lune не вычисляются)
local function attachmentWorld(self)
	local parent = self.Parent
	local base = if parent and parent:IsA("BasePart") then parent.CFrame else CFrame.new()
	return base * self.CFrame
end
function Engine.GetWorldPosition(value)
	if typeof(value) == "Instance" and value:IsA("Attachment") then
		return attachmentWorld(value).Position
	end
	return value.WorldPosition
end
roblox.implementMethod("Camera", "ViewportPointToRay", screenRay)
roblox.implementMethod("Camera", "ScreenPointToRay", screenRay)
Engine.RaycastHook = nil :: any
roblox.implementMethod("Workspace", "Raycast", function(_, origin, direction, params)
	if Engine.RaycastHook then
		return Engine.RaycastHook(origin, direction, params)
	end
	return nil
end)

local specialChildren = {}
Engine.SpecialChildren = specialChildren
roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	local special = specialChildren[idOf(self)]
	if special and special[name] then
		return special[name]
	end
	return self:FindFirstChild(name)
end)

-- В Lune BasePart.Position не связан с CFrame (и не переопределяется), поэтому
-- загрузчик переписывает обращения «x.Position» на эти функции (см. transformSource).
local function isPart(value): boolean
	return typeof(value) == "Instance" and value:IsA("BasePart")
end
function Engine.GetPosition(value)
	if isPart(value) then
		return value.CFrame.Position
	end
	return value.Position
end
function Engine.SetPosition(target, value)
	if isPart(target) then
		local cf = target.CFrame
		target.CFrame = CFrame.new(value) * (cf - cf.Position)
	else
		target.Position = value
	end
end


-- PVInstance
local function pivotOf(model)
	if model:IsA("BasePart") then
		return model.CFrame
	end
	if model.PrimaryPart then
		return model.PrimaryPart.CFrame
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			return d.CFrame
		end
	end
	return CFrame.new()
end
roblox.implementMethod("Model", "GetPivot", pivotOf)
roblox.implementMethod("Model", "PivotTo", function(self, target)
	local delta = target * pivotOf(self):Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end)
roblox.implementMethod("Model", "ScaleTo", function() end)
roblox.implementMethod("Model", "GetBoundingBox", function(self)
	return pivotOf(self), Vector3.new(4, 6, 4)
end)
roblox.implementMethod("Model", "GetExtentsSize", function()
	return Vector3.new(4, 6, 4)
end)
roblox.implementMethod("Humanoid", "ChangeState", function() end)
roblox.implementMethod("Sound", "Play", function() end)
roblox.implementMethod("Sound", "Stop", function() end)
roblox.implementMethod("SoundService", "PlayLocalSound", function() end)
roblox.implementMethod("Workspace", "GetServerTimeNow", function()
	return Engine.Now()
end)

-- Players: возвращаем «канонические» ссылки на игроков, как это делает Roblox
local playerRegistry = {}
local function onlinePlayers()
	local list = {}
	for _, player in playerRegistry do
		if player.Parent ~= nil then
			table.insert(list, player)
		end
	end
	return list
end
roblox.implementMethod("Players", "GetPlayers", function()
	return onlinePlayers()
end)
roblox.implementMethod("Players", "GetPlayerFromCharacter", function(_, character)
	if character == nil then
		return nil
	end
	for _, player in onlinePlayers() do
		if player.Character == character then
			return player
		end
	end
	return nil
end)
roblox.implementMethod("Players", "GetPlayerByUserId", function(_, userId)
	for _, player in onlinePlayers() do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end)
Engine.LocalPlayer = nil
roblox.implementProperty("Players", "LocalPlayer", function()
	return Engine.LocalPlayer
end)
Engine.Kicked = {}
roblox.implementMethod("Player", "Kick", function(self, message)
	Engine.Kicked[self.UserId] = message
end)

-- Remotes: сервер <-> клиент в одном процессе
Engine.RemoteLog = {}
local invokeHandlers = {}
roblox.implementProperty("RemoteFunction", "OnServerInvoke", function(self)
	return invokeHandlers[idOf(self)]
end, function(self, value)
	invokeHandlers[idOf(self)] = value
end)
-- Вызов обработчика сервера от имени произвольного игрока
function Engine.InvokeAs(player, ...)
	local remotes = Engine.ReplicatedStorage:FindFirstChild("Remotes")
	local action = remotes and remotes:FindFirstChild("Action")
	local handler = action and invokeHandlers[idOf(action)]
	assert(handler, "Action remote not found")
	return handler(player, ...)
end
roblox.implementMethod("RemoteFunction", "InvokeServer", function(self, ...)
	local handler = invokeHandlers[idOf(self)]
	assert(handler, "OnServerInvoke не назначен")
	return handler(Engine.LocalPlayer, ...)
end)
roblox.implementMethod("RemoteEvent", "FireClient", function(self, player, ...)
	table.insert(Engine.RemoteLog, { event = self.Name, player = player, args = { ... } })
	if player == Engine.LocalPlayer then
		signalOf(self, "OnClientEvent"):Fire(...)
	end
end)
roblox.implementMethod("RemoteEvent", "FireAllClients", function(self, ...)
	signalOf(self, "OnClientEvent"):Fire(...)
end)
roblox.implementMethod("BindableEvent", "Fire", function(self, ...)
	signalOf(self, "Event"):Fire(...)
end)

------------------------------------------------------------------------
-- Мир и сервисы
------------------------------------------------------------------------

local dataModel = Instance.new("DataModel")
Engine.DataModel = dataModel
Engine.Workspace = dataModel:GetService("Workspace")
Engine.ReplicatedStorage = dataModel:GetService("ReplicatedStorage")
Engine.Players = dataModel:GetService("Players")
local camera = Instance.new("Camera")
camera.ViewportSize = roblox.Vector2.new(1280, 720)
camera.Parent = Engine.Workspace
Engine.Workspace.CurrentCamera = camera

-- CollectionService
local tagged: { [string]: { [any]: boolean } } = {}
local tagAdded: { [string]: any } = {}
local tagRemoved: { [string]: any } = {}
local function tagSignal(map, tag)
	if not map[tag] then
		map[tag] = Signal.new()
	end
	return map[tag]
end
local CollectionService = {
	AddTag = function(_, instance, tag)
		tagged[tag] = tagged[tag] or {}
		if not tagged[tag][instance] then
			tagged[tag][instance] = true
			instance:AddTag(tag)
			tagSignal(tagAdded, tag):Fire(instance)
		end
	end,
	HasTag = function(_, instance, tag)
		return tagged[tag] ~= nil and tagged[tag][instance] == true
	end,
	GetTagged = function(_, tag)
		local list = {}
		for instance in tagged[tag] or {} do
			if instance.Parent then
				table.insert(list, instance)
			end
		end
		return list
	end,
	GetInstanceAddedSignal = function(_, tag)
		return tagSignal(tagAdded, tag)
	end,
	GetInstanceRemovedSignal = function(_, tag)
		return tagSignal(tagRemoved, tag)
	end,
}

-- Хранилище данных в памяти с семантикой UpdateAsync
local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end
Engine.DataStoreData = {}
Engine.DataStoreFails = false
local dataStore = {
	UpdateAsync = function(_, key, transform)
		if Engine.DataStoreFails then
			error("Simulated DataStore outage")
		end
		local result = transform(deepCopy(Engine.DataStoreData[key]))
		if result ~= nil then
			Engine.DataStoreData[key] = deepCopy(result)
		end
		return deepCopy(result)
	end,
}
local DataStoreService = {
	GetDataStore = function()
		return dataStore
	end,
}

Engine.BindToClose = {}
Engine.MouseLocation = roblox.Vector2.new(640, 360)
Engine.KeysDown = {}

-- Сервисы конкретной «стороны» (сервер или клиент)
local function realmServices(isServer: boolean)
	local RunService = {
		Heartbeat = Signal.new(),
		RenderStepped = Signal.new(),
		IsServer = function()
			return isServer
		end,
		IsClient = function()
			return not isServer
		end,
		IsStudio = function()
			return true
		end,
		BindToRenderStep = function() end,
	}
	local realPlayers = dataModel:GetService("Players")
	local playersProxy = setmetatable({}, {
		__index = function(_, key)
			if key == "LocalPlayer" then
				return if isServer then nil else Engine.LocalPlayer
			end
			local value = realPlayers[key]
			if type(value) == "function" then
				return function(_, ...)
					return value(realPlayers, ...)
				end
			end
			return value
		end,
	})
	local stubs = {
		Players = playersProxy,
		RunService = RunService,
		CollectionService = CollectionService,
		DataStoreService = DataStoreService,
		TweenService = {
			Create = function()
				return { Play = function() end, Cancel = function() end, Completed = Signal.new() }
			end,
		},
		ProximityPromptService = { PromptTriggered = Signal.new() },
		UserInputService = {
			InputBegan = Signal.new(), InputChanged = Signal.new(), InputEnded = Signal.new(),
			TouchEnabled = false, KeyboardEnabled = true, MouseEnabled = true,
			GetMouseLocation = function()
				return Engine.MouseLocation
			end,
			IsKeyDown = function(_, key)
				return Engine.KeysDown[key] == true
			end,
		},
		StarterGui = { SetCoreGuiEnabled = function() end },
	}
	local game = setmetatable({
		JobId = "sim-job",
		GetService = function(_, name)
			return stubs[name] or dataModel:GetService(name)
		end,
		BindToClose = function(_, fn)
			table.insert(Engine.BindToClose, fn)
		end,
	}, { __index = function(_, key)
		return dataModel[key]
	end })
	return game, RunService
end

------------------------------------------------------------------------
-- Загрузка модулей (виртуальное дерево из src/)
------------------------------------------------------------------------

local files: { [string]: string } = {}
local dirs: { [string]: boolean } = {}
local function preload(path: string)
	dirs[path] = true
	for _, name in fs.readDir(path) do
		local full = path .. "/" .. name
		if fs.isDir(full) then
			preload(full)
		elseif string.match(name, "%.luau$") then
			files[full] = fs.readFile(full)
		end
	end
end
preload("src")

local nodeCache = {}
local function node(path: string, name: string, parent: any)
	if nodeCache[path] then
		return nodeCache[path]
	end
	local n
	local function child(key)
		local childPath = path .. "/" .. key
		if dirs[childPath] or files[childPath .. ".luau"] then
			return node(childPath, key, n)
		end
		for _, suffix in { ".server.luau", ".client.luau" } do
			if files[childPath .. suffix] then
				return node(childPath, key, n)
			end
		end
		return nil
	end
	n = setmetatable({ __path = path, Name = name, Parent = parent }, {
		__index = function(_, key)
			if key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, childName)
					return child(childName)
				end
			end
			local result = child(key)
			if result == nil then
				error(string.format("%s is not a valid member of %s", tostring(key), path))
			end
			return result
		end,
	})
	nodeCache[path] = n
	return n
end

-- Переписываем x.Position (чтение и запись) и x.AbsoluteSize (чтение) на функции эмулятора
local function transformSource(source: string): string
	local lines = {}
	for line in string.gmatch(source .. "\n", "(.-)\n") do
		local indent, target, op, value = string.match(line, "^(%s*)([%w_][%w_%.]*)%.Position%s*([%+%-%*/]?)=%s*([^=].*)$")
		if indent then
			if op ~= "" then
				line = string.format("%s__setpos(%s, __getpos(%s) %s (%s))", indent, target, target, op, value)
			else
				line = string.format("%s__setpos(%s, %s)", indent, target, value)
			end
		else
			for property, fn in { Position = "__getpos", AbsoluteSize = "__getabs", WorldPosition = "__getworldpos" } do
				line = string.sub((string.gsub(" " .. line .. " ", "([^%w_%.:%)%]\"'])([%a_][%w_]*[%w_%.]-)%." .. property .. "([^%w_])",
					function(before, chain, after)
						if after == "(" then
							return nil -- вызов функции с именем Position(...) — не свойство
						end
						return before .. fn .. "(" .. chain .. ")" .. after
					end)), 2, -2)
			end
		end
		-- Определения методов (function Match:Destroy()) не трогаем — только вызовы
		if not string.match(line, "^%s*function%s") and not string.match(line, "^%s*local%s+function%s") then
			line = string.gsub(line, "([%w_][%w_%.%[%]\"]*):Destroy%(%)", "__destroy(%1)")
			line = string.gsub(line, "([%w_][%w_%.%[%]\"]*):ClearAllChildren%(%)", "__clear(%1)")
			line = string.gsub(line, "([%w_][%w_%.%[%]\"]*):SetAttribute%(", "__setattr(%1, ")
		end
		table.insert(lines, line)
	end
	return table.concat(lines, "\n")
end
function Engine.GetAbsoluteSize(value)
	if typeof(value) == "Instance" then
		return roblox.Vector2.new(900, 600)
	end
	return value.AbsoluteSize
end
Engine.TransformSource = transformSource

Engine.SharedNode = node("src/shared", "Shared", nil)
Engine.ServerNode = node("src/server", "Server", nil)
Engine.ClientNode = node("src/client", "Client", nil)
specialChildren[idOf(Engine.ReplicatedStorage)] = { Shared = Engine.SharedNode }

local RandomStub = {}
RandomStub.__index = RandomStub
function RandomStub.new(seed)
	return setmetatable({ state = math.floor((seed or math.random() * 1e6) % 2147483646) + 1 }, RandomStub)
end
function RandomStub:NextNumber(min, max)
	self.state = (self.state * 48271) % 2147483647
	local r = self.state / 2147483647
	if min and max then
		return min + (max - min) * r
	end
	return r
end
function RandomStub:NextInteger(min, max)
	return math.min(max, math.floor(self:NextNumber(min, max + 1)))
end

local TweenInfoStub = { new = function(...)
	return { ... }
end }

local simOs = setmetatable({
	time = function()
		return math.floor(Engine.Now())
	end,
}, { __index = os })

function Engine.Realm(isServer: boolean)
	local game, RunService = realmServices(isServer)
	local cache = {}
	local realm = { game = game, RunService = RunService, cache = cache }
	local function realmRequire(target)
		if type(target) ~= "table" or not rawget(target, "__path") then
			error("Unsupported require target: " .. tostring(target))
		end
		local path = rawget(target, "__path")
		if cache[path] ~= nil then
			return cache[path]
		end
		local file
		for _, candidate in { path .. ".luau", path .. "/init.luau", path .. "/init.server.luau", path .. "/init.client.luau",
			path .. ".server.luau", path .. ".client.luau" } do
			if files[candidate] then
				file = candidate
				break
			end
		end
		assert(file, "Module not found: " .. path)
		local env = setmetatable({
			script = target,
			require = realmRequire,
			game = game,
			workspace = Engine.Workspace,
			Instance = Instance,
			Enum = roblox.Enum,
			Vector3 = Vector3,
			Vector2 = roblox.Vector2,
			CFrame = CFrame,
			Color3 = roblox.Color3,
			UDim = roblox.UDim,
			UDim2 = roblox.UDim2,
			ColorSequence = roblox.ColorSequence,
			ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
			NumberSequence = roblox.NumberSequence,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
			NumberRange = roblox.NumberRange,
			Rect = roblox.Rect,
			Font = roblox.Font,
			TweenInfo = TweenInfoStub,
			Random = RandomStub,
			task = task,
			os = simOs,
			warn = function(...)
				local parts = {}
				for i = 1, select("#", ...) do
					parts[i] = tostring((select(i, ...)))
				end
				table.insert(Engine.Warnings, table.concat(parts, " "))
			end,
			print = function() end,
		}, { __index = getfenv(0) })
		env.__getpos = Engine.GetPosition
		env.__setpos = Engine.SetPosition
		env.__getabs = Engine.GetAbsoluteSize
		env.__destroy = Engine.Destroy
		env.__clear = Engine.ClearAllChildren
		env.__setattr = Engine.SetAttribute
		env.__getworldpos = Engine.GetWorldPosition
		local chunk = luau.load(transformSource(files[file]), { debugName = file, environment = env })
		local result = chunk()
		cache[path] = if result == nil then true else result
		return result
	end
	realm.require = realmRequire
	return realm
end

Engine.Warnings = {}

------------------------------------------------------------------------
-- Игроки
------------------------------------------------------------------------

local nextUserId = 1000
function Engine.NewPlayer(name: string)
	nextUserId += 1
	local player = Instance.new("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = nextUserId
	local backpack = Instance.new("Backpack")
	backpack.Parent = player
	local gui = Instance.new("PlayerGui")
	gui.Parent = player
	local starterTool = dataModel:GetService("StarterPack"):FindFirstChildOfClass("Tool")
	if starterTool then
		local tool = starterTool:Clone()
		tool:SetAttribute("__sim", nil)
		for _, d in tool:GetDescendants() do
			d:SetAttribute("__sim", nil)
		end
		tool.Parent = backpack
	end
	table.insert(playerRegistry, player)
	return player
end

function Engine.SpawnCharacter(player, position: any)
	local character = Instance.new("Model")
	character.Name = player.Name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(position)
	root.Parent = character
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0))
	head.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Health = 100
	humanoid.Parent = character
	character.PrimaryPart = root
	character.Parent = Engine.Workspace
	player.Character = character
	signalOf(player, "CharacterAdded"):Fire(character)
	return character
end

function Engine.Join(player)
	player.Parent = Engine.Players
	signalOf(Engine.Players, "PlayerAdded"):Fire(player)
end

function Engine.Leave(player)
	signalOf(Engine.Players, "PlayerRemoving"):FireSync(player)
	player.Parent = nil
end

function Engine.MoveTo(player, position: any)
	local character = player.Character
	character:PivotTo(CFrame.new(position))
end

function Engine.Wait(seconds: number)
	task.wait(seconds)
end

return Engine
