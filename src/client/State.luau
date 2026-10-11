--[[
	Клиентское состояние: снимки от сервера (лобби, матч, профиль) и обёртка запросов.
	Клиент ничего не решает сам — только показывает и отправляет намерения.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local State = {}

State.Lobby = {} :: { any } -- лифты
State.Match = nil :: any -- снимок матча
State.Profile = nil :: any
State.MemoryMode = false
State.Results = nil :: any

State.LobbyChanged = Instance.new("BindableEvent")
State.MatchChanged = Instance.new("BindableEvent")
State.ProfileChanged = Instance.new("BindableEvent")
State.Fx = Instance.new("BindableEvent")
State.Ended = Instance.new("BindableEvent")
State.Notify = Instance.new("BindableEvent")

local action: RemoteFunction

function State.Init()
	action = Net.ActionFunction()
	Net.Event("LobbyState").OnClientEvent:Connect(function(elevators)
		State.Lobby = elevators
		State.LobbyChanged:Fire(elevators)
	end)
	Net.Event("MatchState").OnClientEvent:Connect(function(snapshot)
		State.Match = snapshot
		State.MatchChanged:Fire(snapshot)
	end)
	Net.Event("MatchFx").OnClientEvent:Connect(function(batch)
		if type(batch) == "table" then
			for _, entry in batch do
				State.Fx:Fire(entry)
			end
		end
	end)
	Net.Event("MatchEnded").OnClientEvent:Connect(function(results)
		if type(results) == "table" and results.savedUpdate then
			if State.Results then
				State.Results.saved = results.saved
			end
		else
			State.Results = results
		end
		State.Ended:Fire(results)
	end)
	Net.Event("Profile").OnClientEvent:Connect(function(view)
		State.Profile = view.profile
		State.MemoryMode = view.memoryMode == true
		State.ProfileChanged:Fire(State.Profile)
	end)
	Net.Event("Notify").OnClientEvent:Connect(function(text, kind)
		State.Notify:Fire(text, kind)
	end)
end

function State.InMatch(): boolean
	return Players.LocalPlayer:GetAttribute("MatchId") ~= nil
end

function State.MyElevator(): any?
	local userId = Players.LocalPlayer.UserId
	for _, elevator in State.Lobby do
		for _, member in elevator.members do
			if member.userId == userId then
				return elevator
			end
		end
	end
	return nil
end

function State.MyTeamEntry(): any?
	local match = State.Match
	if not match then
		return nil
	end
	for _, entry in match.team do
		if entry.userId == Players.LocalPlayer.UserId then
			return entry
		end
	end
	return nil
end

function State.Cash(): number
	local entry = State.MyTeamEntry()
	return entry and entry.cash or 0
end

function State.Action(name: string, payload: any?): (boolean, any?)
	local ok, result = pcall(function()
		return action:InvokeServer(name, payload)
	end)
	if not ok or type(result) ~= "table" then
		State.Notify:Fire("Connection problem — try again", "error")
		return false, nil
	end
	if not result.ok and result.message then
		State.Notify:Fire(result.message, "error")
	end
	return result.ok == true, result.data
end

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
