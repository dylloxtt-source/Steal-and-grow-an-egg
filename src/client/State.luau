--[[
	Клиентское состояние: последний снимок профиля от сервера + обёртка для действий.
	UI только читает State.View и отправляет запросы; все расчёты значимых
	величин делает сервер.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local State = {}

State.View = nil :: any
State.Changed = Instance.new("BindableEvent")
State.Notify = Instance.new("BindableEvent") -- (text, kind) — локальные уведомления

local actionFunction: RemoteFunction

function State.Init()
	actionFunction = Net.ActionFunction()
	Net.Event("State").OnClientEvent:Connect(function(view)
		State.View = view
		State.Changed:Fire(view)
	end)
end

function State.Profile(): any
	return State.View and State.View.profile
end

function State.Runtime(): any
	return State.View and State.View.runtime or {}
end

-- Отправляет действие на сервер. Ошибку показывает уведомлением.
function State.Action(name: string, payload: any?): (boolean, any?)
	local ok, result = pcall(function()
		return actionFunction:InvokeServer(name, payload)
	end)
	if not ok or type(result) ~= "table" then
		State.Notify:Fire("Нет связи с сервером", "error")
		return false, nil
	end
	if not result.ok and result.message then
		State.Notify:Fire(result.message, "error")
	end
	return result.ok == true, result.data
end

-- Асинхронный вариант для кнопок (не блокирует UI)
function State.Fire(name: string, payload: any?, onDone: ((boolean, any?) -> ())?)
	task.spawn(function()
		local ok, data = State.Action(name, payload)
		if onDone then
			onDone(ok, data)
		end
	end)
end

function State.Now(): number
	return workspace:GetServerTimeNow()
end

return State
