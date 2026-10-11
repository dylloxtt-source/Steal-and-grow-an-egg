--[[
	Точка входа сервера. Сервисы инициализируются (Init) и запускаются (Start)
	в фиксированном порядке; каждый получает общий реестр services.
]]

local Services = script:WaitForChild("Services")

local ORDER = {
	"DataService",
	"NetService",
	"MapService",
	"PlotService",
	"DayNightService",
	"TutorialService",
	"QuestService",
	"CreatureService",
	"IncubatorService",
	"FarmService",
	"CarryService",
	"StealService",
	"WorldEggService",
	"GuardianService",
	"CombatService",
	"ShopService",
}

local registry = {}
for _, name in ORDER do
	registry[name] = require(Services:WaitForChild(name))
end

for _, name in ORDER do
	registry[name]:Init(registry)
end

-- DataService стартует последним: к моменту загрузки первого игрока все
-- сервисы уже подписались на OnLoaded/OnRemoving.
local function start(name: string)
	local ok, err = pcall(function()
		registry[name]:Start()
	end)
	if not ok then
		warn(string.format("[Server] %s failed to start: %s", name, tostring(err)))
	end
end

for _, name in ORDER do
	if name ~= "DataService" then
		start(name)
	end
end
start("DataService")

print("[Server] Steal and Grow an Egg запущен")
