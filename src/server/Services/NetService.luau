--[[
	NetService — единая точка входа для запросов клиента.
	• Только объявленные в Net.Actions действия, лимит частоты на каждое (token bucket).
	• Обработчики не уступают управление — проверка и изменение атомарны.
	• Ошибка в обработчике не роняет сервер и не утекает клиенту.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local NetService = {}

type Handler = (Player, any, any) -> (boolean, string?, any?)

local services
local handlers: { [string]: Handler } = {}
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

function NetService:Init(registry)
	services = registry
	-- Все удалённые объекты создаются сразу: клиент ждёт их через WaitForChild
	-- при запуске, даже если ни одного матча ещё не было
	for _, name in Net.Events do
		Net.Event(name)
	end
	Net.ActionFunction()
end

function NetService:Handle(name: string, handler: Handler)
	assert(Net.Actions[name], "Action is not declared in Net.Actions: " .. name)
	assert(handlers[name] == nil, "Duplicate handler: " .. name)
	handlers[name] = handler
end

local function allow(player: Player, action: string): boolean
	local limit = Net.Actions[action]
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local now = os.clock()
	local bucket = perPlayer[action]
	if not bucket then
		bucket = { tokens = limit, last = now }
		perPlayer[action] = bucket
	end
	bucket.tokens = math.min(limit, bucket.tokens + (now - bucket.last) * limit)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

NetService.Check = {}

function NetService.Check.Table(value: any): boolean
	return type(value) == "table"
end

function NetService.Check.String(value: any, maxLength: number?): boolean
	return type(value) == "string" and #value > 0 and #value <= (maxLength or 48)
end

function NetService.Check.Int(value: any, min: number, max: number): boolean
	return type(value) == "number" and value == value and value == math.floor(value) and value >= min and value <= max
end

function NetService.Check.Number(value: any, min: number, max: number): boolean
	return type(value) == "number" and value == value and value >= min and value <= max
end

function NetService:Start()
	local action = Net.ActionFunction()
	action.OnServerInvoke = function(player: Player, name: any, payload: any)
		if type(name) ~= "string" or not handlers[name] then
			return { ok = false, message = "Неизвестное действие" }
		end
		if not allow(player, name) then
			return { ok = false, message = "Слишком часто" }
		end
		local session = services.DataService:GetSession(player)
		if not session then
			return { ok = false, message = "Загрузка..." }
		end
		local ok, success, message, data = pcall(handlers[name], player, session, payload)
		if not ok then
			warn(string.format("[NetService] %s от %s: %s", name, player.Name, tostring(success)))
			return { ok = false, message = "Ошибка сервера" }
		end
		return { ok = success == true, message = message, data = data }
	end
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return NetService
