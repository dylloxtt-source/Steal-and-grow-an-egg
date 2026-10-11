--[[
	MatchService — жизненный цикл матчей.
	• Create: свободный слот мира → карта → перенос игроков → старт подготовки.
	• Один цикл Heartbeat обновляет все матчи (без циклов на каждую башню/врага).
	• Finish: награды (гемы, опыт, статистика) → экран итогов → возврат в лобби
	  (по кнопке или автоматически) → полная очистка карты, врагов, башен и таймеров.
	• Отключение игрока не ломает матч; если ушли все — матч закрывается.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Maps = require(Shared.Config.Maps)
local Economy = require(Shared.Config.Economy)
local Towers = require(Shared.Config.Towers)
local Profile = require(Shared.Logic.Profile)
local Net = require(Shared.Net)

local Match = require(script.Parent.Parent.Match.Match)

local MatchService = {}
MatchService.Matches = {} :: { [number]: any }

local services
local container: Folder
local slots: { [number]: number } = {} -- slot -> matchId
local nextId = 1
local endedEvent: RemoteEvent

function MatchService:MatchOf(player: Player): any?
	local id = player:GetAttribute("MatchId")
	return if id then MatchService.Matches[id] else nil
end

local function freeSlot(): number?
	for slot = 1, Game.Match.MaxConcurrent do
		if not slots[slot] then
			return slot
		end
	end
	return nil
end

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(cframe)
	end
end

function MatchService:Create(players: { Player }, mapId: string): (any?, string?)
	if not Maps.ById[mapId] then
		return nil, "Unknown map"
	end
	if #players < 1 or #players > Game.Elevator.MaxCapacity then
		return nil, "Invalid party size"
	end
	for _, player in players do
		if player:GetAttribute("MatchId") then
			return nil, player.DisplayName .. " is already in a match"
		end
	end
	local slot = freeSlot()
	if not slot then
		return nil, "All arenas are busy — try again in a minute"
	end
	local id = nextId
	nextId += 1
	local match = Match.new(id, slot, mapId, players, container)
	match.OnFinished = function(m, victory)
		MatchService:OnFinished(m, victory)
	end
	slots[slot] = id
	MatchService.Matches[id] = match
	for _, player in players do
		local session = services.DataService:GetSession(player)
		if session then
			match:ApplyProfile(player, session.Profile)
		end
		player:SetAttribute("MatchId", id)
		player:SetAttribute("MapId", mapId)
		teleport(player, match:SpawnCFrame())
	end
	match:Notify(match.Map.Name .. " - first wave in " .. Game.Match.PrepTime .. " seconds. Place your towers!", "info")
	match:Broadcast()
	return match, nil
end

function MatchService:OnCharacterAdded(player: Player, character: Model)
	local match = MatchService:MatchOf(player)
	if match and not match.Closed then
		-- Ждём, пока движок поставит персонажа на SpawnLocation, иначе перенос перезапишется
		task.spawn(function()
			character:WaitForChild("HumanoidRootPart", 5)
			task.wait()
			if character.Parent and MatchService:MatchOf(player) == match and not match.Closed then
				character:PivotTo(match:SpawnCFrame())
			end
		end)
	end
end

local function rewardsFor(match: any, state: any, victory: boolean): any
	local diff = match.Difficulty
	local wave = match.WavesCleared
	local gems = math.floor((wave * Economy.Gems.PerWave + state.Kills * Economy.Gems.PerKills) * diff)
		+ (if victory then math.floor(Economy.Gems.Victory * diff) else 0)
	local xp = math.floor(wave * Economy.Xp.PerWave * diff) + (if victory then Economy.Xp.Victory else 0)
	return { gems = gems, xp = xp }
end

function MatchService:OnFinished(match: any, victory: boolean)
	match.ResultsAt = os.clock()
	for _, player in table.clone(match.Players) do
		local state = match.PlayerState[player.UserId]
		local session = services.DataService:GetSession(player)
		local rewards = rewardsFor(match, state, victory)
		local levelsGained = 0
		if session then
			local profile = session.Profile
			profile.gems += rewards.gems
			levelsGained = Profile.AddXp(profile, rewards.xp)
			profile.stats.matches += 1
			profile.stats.kills += state.Kills
			profile.stats.wavesCleared += match.WavesCleared
			if victory then
				profile.stats.wins += 1
			else
				profile.stats.losses += 1
			end
			profile.bestWave[match.MapId] = math.max(profile.bestWave[match.MapId] or 0, match.Waves.Wave)
			services.DataService:SendProfile(player)
		end
		local team = {}
		for _, other in match.PlayerState do
			table.insert(team, { name = other.Name, kills = other.Kills, damage = math.floor(other.Damage),
				earned = other.Earned, towers = other.TowersPlaced, connected = other.Connected })
		end
		endedEvent:FireClient(player, {
			victory = victory,
			mapId = match.MapId,
			wave = match.Waves.Wave,
			maxWave = match.Waves.Max,
			wavesCleared = match.WavesCleared,
			baseHp = match.BaseHealth,
			time = match.Time,
			you = { kills = state.Kills, damage = math.floor(state.Damage), earned = state.Earned, towers = state.TowersPlaced },
			team = team,
			rewards = rewards,
			levelsGained = levelsGained,
			returnIn = Game.Match.ResultsTime,
			-- nil = сохранение ещё идёт; итог придёт отдельным сообщением
			saved = if services.DataService.MemoryMode or not session then false else nil,
		})
		if session and not services.DataService.MemoryMode then
			task.spawn(function()
				local saved = services.DataService:SaveAndWait(player)
				if player.Parent then
					endedEvent:FireClient(player, { savedUpdate = true, saved = saved })
				end
			end)
		end
	end
end

function MatchService:ReturnPlayer(match: any, player: Player)
	match:RemovePlayer(player)
	services.LobbyService:SendToLobby(player)
	if #match.Players == 0 then
		MatchService:Close(match)
	end
end

function MatchService:Close(match: any)
	if match.Closed then
		return
	end
	match.Closed = true
	for _, player in table.clone(match.Players) do
		match:RemovePlayer(player)
		services.LobbyService:SendToLobby(player)
	end
	match:Destroy()
	MatchService.Matches[match.Id] = nil
	slots[match.Slot] = nil
end

function MatchService:Update(dt: number)
	for _, match in MatchService.Matches do
		if match.Ended then
			if match.ResultsAt and os.clock() - match.ResultsAt >= Game.Match.ResultsTime then
				MatchService:Close(match)
			elseif not match.ResultsAt and #match.Players == 0 then
				MatchService:Close(match)
			end
		else
			match:Step(dt)
		end
	end
end

function MatchService:Init(registry)
	services = registry
	endedEvent = Net.Event("MatchEnded")
	container = Instance.new("Folder")
	container.Name = "ActiveMatches"
	container.Parent = workspace
end

function MatchService:Start()
	local NetService = services.NetService
	local Check = NetService.Check

	local function current(player: Player): (any?, string?)
		local match = MatchService:MatchOf(player)
		if not match or match.Closed then
			return nil, "You are not in a match"
		end
		return match, nil
	end

	NetService:Handle("PlaceTower", function(player, _session, payload)
		if not Check.Table(payload) or not Check.String(payload.tower, 24) or not Towers.ById[payload.tower]
			or not Check.Number(payload.x, -500, 500) or not Check.Number(payload.z, -500, 500) then
			return false, "Invalid request"
		end
		local match, err = current(player)
		if not match then
			return false, err
		end
		return match.Towers:Place(player, payload.tower, payload.x, payload.z)
	end)

	NetService:Handle("UpgradeTower", function(player, _session, payload)
		local match, err = current(player)
		if not match then
			return false, err
		end
		if not Check.Table(payload) then
			return false, "Invalid request"
		end
		if match.Ended then
			return false, "The match is over"
		end
		return match.Towers:Upgrade(player, payload.uid)
	end)

	NetService:Handle("SellTower", function(player, _session, payload)
		local match, err = current(player)
		if not match then
			return false, err
		end
		if not Check.Table(payload) then
			return false, "Invalid request"
		end
		if match.Ended then
			return false, "The match is over"
		end
		return match.Towers:Sell(player, payload.uid)
	end)

	NetService:Handle("SetPriority", function(player, _session, payload)
		local match, err = current(player)
		if not match then
			return false, err
		end
		if not Check.Table(payload) then
			return false, "Invalid request"
		end
		return match.Towers:SetPriority(player, payload.uid, payload.priority)
	end)

	NetService:Handle("VoteSpeed", function(player)
		local match, err = current(player)
		if not match or match.Ended then
			return false, err or "The match is over"
		end
		return match:Vote(player, "Speed")
	end)

	NetService:Handle("VoteSkip", function(player)
		local match, err = current(player)
		if not match or match.Ended then
			return false, err or "The match is over"
		end
		return match:Vote(player, "Skip")
	end)

	NetService:Handle("ReturnToLobby", function(player)
		local match = MatchService:MatchOf(player)
		if not match then
			return false, "You are not in a match"
		end
		if not match.Ended then
			return false, "The match is still running"
		end
		MatchService:ReturnPlayer(match, player)
		return true, nil
	end)

	NetService:Handle("RequestState", function(player)
		services.DataService:SendProfile(player)
		local match = MatchService:MatchOf(player)
		if match and not match.Closed then
			match:Broadcast()
		end
		return true, nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		local match = MatchService:MatchOf(player)
		if match and not match.Closed then
			match:RemovePlayer(player)
			if #match.Players == 0 then
				MatchService:Close(match)
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		MatchService:Update(dt)
	end)
end

return MatchService
