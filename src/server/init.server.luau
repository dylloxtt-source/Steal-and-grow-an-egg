--[[
	Точка входа сервера. Сервисы инициализируются и запускаются в фиксированном
	порядке; DataService стартует последним, чтобы все подписки были готовы.
]]

local Services = script:WaitForChild("Services")

local ORDER = { "DataService", "NetService", "LobbyService", "MatchService", "ElevatorService" }

local registry = {}
for _, name in ORDER do
	registry[name] = require(Services:WaitForChild(name))
end
for _, name in ORDER do
	registry[name]:Init(registry)
end

local function start(name: string)
	local ok, err = pcall(function()
		registry[name]:Start()
	end)
	if not ok then
		warn(string.format("[Server] %s не запустился: %s", name, tostring(err)))
	end
end

for _, name in ORDER do
	if name ~= "DataService" then
		start(name)
	end
end
start("DataService")

print("[Server] R6 Tower Defense запущен")
