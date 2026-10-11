--[[
	ElevatorService — четыре независимых лифта-группы.

	Состояния: Empty → Waiting → Starting → InMatch → (через 3 сек.) Empty.
	• Членство определяется положением персонажа в кабине (зоны не пересекаются),
	  поэтому один игрок физически не может быть в двух лифтах; дополнительно это
	  проверяется сервером.
	• Лидер — первый вошедший; при его выходе лидером становится следующий.
	• Лидер выбирает карту и вместимость (1–4, не меньше текущего числа игроков).
	• Отсчёт Starting запускается, когда группа заполнена, все готовы, истёк таймер
	  ожидания или лидер нажал «Старт». Состав фиксируется в момент запуска матча.
	• Переполненная кабина выталкивает лишнего игрока с сообщением.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Maps = require(Shared.Config.Maps)
local Format = require(Shared.Logic.Format)
local Net = require(Shared.Net)

local ElevatorService = {}
ElevatorService.Elevators = {}

local services
local lobbyEvent: RemoteEvent
local config = Game.Elevator
local scanAccumulator = 0
local broadcastAccumulator = 0
local dirty = true

local function newElevator(index: number)
	return {
		Index = index,
		State = "Empty",
		Members = {} :: { Player },
		Ready = {} :: { [number]: boolean },
		Leader = nil :: Player?,
		MapId = Maps.Default,
		Capacity = config.DefaultCapacity,
		Timer = 0,
	}
end

local function reset(elevator: any)
	elevator.State = "Empty"
	elevator.Members = {}
	elevator.Ready = {}
	elevator.Leader = nil
	elevator.Timer = 0
	elevator.Capacity = config.DefaultCapacity
	dirty = true
end

function ElevatorService:ElevatorOf(player: Player): any?
	for _, elevator in ElevatorService.Elevators do
		if table.find(elevator.Members, player) then
			return elevator
		end
	end
	return nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function pushOut(elevator: any, player: Player)
	local root = rootOf(player)
	local booth = services.LobbyService.Booths[elevator.Index]
	if root and booth and player.Character then
		player.Character:PivotTo(CFrame.new(booth.Exit))
	end
end

local function allReady(elevator: any): boolean
	if #elevator.Members == 0 then
		return false
	end
	for _, member in elevator.Members do
		if not elevator.Ready[member.UserId] then
			return false
		end
	end
	return true
end

local function beginStarting(elevator: any, time: number)
	if elevator.State == "Waiting" then
		elevator.State = "Starting"
		elevator.Timer = time
		dirty = true
	end
end

function ElevatorService:Join(player: Player, elevator: any): (boolean, string?)
	if player:GetAttribute("MatchId") then
		return false, "Ты уже в матче"
	end
	local current = ElevatorService:ElevatorOf(player)
	if current == elevator then
		return true, nil
	end
	if current then
		return false, "Ты уже в другом лифте"
	end
	if elevator.State == "InMatch" then
		return false, "Лифт отправляется — подожди"
	end
	if #elevator.Members >= elevator.Capacity then
		return false, string.format("Лифт заполнен (%d/%d)", #elevator.Members, elevator.Capacity)
	end
	table.insert(elevator.Members, player)
	elevator.Ready[player.UserId] = false
	if not elevator.Leader then
		elevator.Leader = player
	end
	if elevator.State == "Empty" then
		elevator.State = "Waiting"
		elevator.Timer = config.WaitTime
	end
	dirty = true
	return true, nil
end

function ElevatorService:Leave(player: Player, elevator: any?)
	local target = elevator or ElevatorService:ElevatorOf(player)
	if not target then
		return
	end
	local index = table.find(target.Members, player)
	if not index then
		return
	end
	table.remove(target.Members, index)
	target.Ready[player.UserId] = nil
	if target.Leader == player then
		target.Leader = target.Members[1]
	end
	if #target.Members == 0 then
		if target.State ~= "InMatch" then
			reset(target)
		end
	elseif target.State == "Starting" and #target.Members < target.Capacity and not allReady(target) then
		-- Кто-то ушёл во время отсчёта: возвращаемся к ожиданию
		target.State = "Waiting"
		target.Timer = math.max(target.Timer, config.RevertTime)
	end
	dirty = true
end

local function launch(elevator: any)
	local members = table.clone(elevator.Members) -- состав фиксируется здесь
	local valid = {}
	for _, member in members do
		if member.Parent and not member:GetAttribute("MatchId") and #valid < elevator.Capacity then
			table.insert(valid, member)
		end
	end
	if #valid == 0 then
		reset(elevator)
		return
	end
	local match, err = services.MatchService:Create(valid, elevator.MapId)
	if not match then
		elevator.State = "Waiting"
		elevator.Timer = config.RevertTime
		for _, member in valid do
			services.DataService:Notify(member, err or "Не удалось создать матч", "error")
		end
		dirty = true
		return
	end
	elevator.State = "InMatch"
	elevator.Timer = config.InMatchHold
	elevator.Members = {}
	elevator.Ready = {}
	elevator.Leader = nil
	dirty = true
end

local function scan()
	for _, elevator in ElevatorService.Elevators do
		local booth = services.LobbyService.Booths[elevator.Index]
		-- Ушедшие из кабины
		for i = #elevator.Members, 1, -1 do
			local member = elevator.Members[i]
			local root = rootOf(member)
			local inside = false
			if root then
				local offset = root.Position - booth.Center
				inside = math.abs(offset.X) <= booth.Half.X and math.abs(offset.Z) <= booth.Half.Z and offset.Y <= booth.Half.Y * 2
			end
			if not member.Parent or not inside then
				ElevatorService:Leave(member, elevator)
			end
		end
	end
	-- Вошедшие в кабину
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and not player:GetAttribute("MatchId") and services.DataService:GetSession(player) then
			for _, elevator in ElevatorService.Elevators do
				local booth = services.LobbyService.Booths[elevator.Index]
				local offset = root.Position - booth.Center
				if math.abs(offset.X) <= booth.Half.X and math.abs(offset.Z) <= booth.Half.Z and offset.Y <= booth.Half.Y * 2 then
					if not table.find(elevator.Members, player) then
						local ok, message = ElevatorService:Join(player, elevator)
						if not ok then
							pushOut(elevator, player)
							if message then
								services.DataService:Notify(player, message, "error")
							end
						end
					end
				end
			end
		end
	end
end

local function step(dt: number)
	for _, elevator in ElevatorService.Elevators do
		if elevator.State == "Waiting" then
			if #elevator.Members == 0 then
				reset(elevator)
			elseif #elevator.Members >= elevator.Capacity or allReady(elevator) then
				beginStarting(elevator, config.StartTime)
			else
				elevator.Timer -= dt
				if elevator.Timer <= 0 then
					beginStarting(elevator, config.StartTime)
				end
			end
		elseif elevator.State == "Starting" then
			if #elevator.Members == 0 then
				reset(elevator)
			else
				elevator.Timer -= dt
				if elevator.Timer <= 0 then
					launch(elevator)
				end
			end
		elseif elevator.State == "InMatch" then
			elevator.Timer -= dt
			if elevator.Timer <= 0 then
				reset(elevator)
			end
		end
	end
end

function ElevatorService:Snapshot(): { any }
	local list = {}
	for _, elevator in ElevatorService.Elevators do
		local members = {}
		for _, member in elevator.Members do
			table.insert(members, { userId = member.UserId, name = member.DisplayName, ready = elevator.Ready[member.UserId] == true })
		end
		table.insert(list, {
			index = elevator.Index,
			state = elevator.State,
			mapId = elevator.MapId,
			capacity = elevator.Capacity,
			members = members,
			leader = if elevator.Leader then elevator.Leader.UserId else 0,
			timer = math.max(0, elevator.Timer),
		})
	end
	return list
end

local function updateBooths()
	for _, elevator in ElevatorService.Elevators do
		local booth = services.LobbyService.Booths[elevator.Index]
		local color = services.LobbyService.StateColors[elevator.State]
		booth.Strip.Color = color
		booth.FloorGlow.Color = color
		booth.MapLabel.Text = "🗺 " .. Maps.ById[elevator.MapId].Name
		booth.PlayersLabel.Text = string.format("👥 %d / %d", #elevator.Members, elevator.Capacity)
		local status = ({
			Empty = "Свободен — заходи!",
			Waiting = "Ожидание " .. Format.Time(elevator.Timer),
			Starting = "Старт через " .. tostring(math.ceil(elevator.Timer)),
			InMatch = "Матч запущен",
		})[elevator.State]
		booth.StatusLabel.Text = status
		booth.StatusLabel.TextColor3 = color
	end
end

local function broadcast()
	local snapshot = ElevatorService:Snapshot()
	for _, player in Players:GetPlayers() do
		if not player:GetAttribute("MatchId") then
			lobbyEvent:FireClient(player, snapshot)
		end
	end
	updateBooths()
end

function ElevatorService:Init(registry)
	services = registry
	lobbyEvent = Net.Event("LobbyState")
	for i = 1, config.Count do
		ElevatorService.Elevators[i] = newElevator(i)
	end
end

-- Один шаг логики (вызывается каждым Heartbeat; тесты вызывают напрямую)
function ElevatorService:Update(dt: number)
	scanAccumulator += dt
	if scanAccumulator >= 0.2 then
		scanAccumulator = 0
		scan()
	end
	step(dt)
	broadcastAccumulator += dt
	if dirty or broadcastAccumulator >= 0.5 then
		dirty = false
		broadcastAccumulator = 0
		broadcast()
	end
end

function ElevatorService:Start()
	local NetService = services.NetService
	local Check = NetService.Check

	local function leaderElevator(player: Player): (any?, string?)
		local elevator = ElevatorService:ElevatorOf(player)
		if not elevator then
			return nil, "Ты не в лифте"
		end
		if elevator.Leader ~= player then
			return nil, "Это может сделать только лидер группы"
		end
		return elevator, nil
	end

	NetService:Handle("ElevatorSetMap", function(player, _session, payload)
		if not Check.Table(payload) or not Check.String(payload.map, 32) or not Maps.ById[payload.map] then
			return false, "Неверная карта"
		end
		local elevator, err = leaderElevator(player)
		if not elevator then
			return false, err
		end
		if elevator.State ~= "Waiting" then
			return false, "Карту можно менять только во время ожидания"
		end
		elevator.MapId = payload.map
		dirty = true
		return true, nil
	end)

	NetService:Handle("ElevatorSetCapacity", function(player, _session, payload)
		if not Check.Table(payload) or not Check.Int(payload.capacity, config.MinCapacity, config.MaxCapacity) then
			return false, "Размер группы: от 1 до 4"
		end
		local elevator, err = leaderElevator(player)
		if not elevator then
			return false, err
		end
		if elevator.State ~= "Waiting" then
			return false, "Нельзя менять во время отсчёта"
		end
		if payload.capacity < #elevator.Members then
			return false, "В лифте уже больше игроков"
		end
		elevator.Capacity = payload.capacity
		dirty = true
		return true, nil
	end)

	NetService:Handle("ElevatorReady", function(player, _session, payload)
		if not Check.Table(payload) or type(payload.ready) ~= "boolean" then
			return false, "Неверный запрос"
		end
		local elevator = ElevatorService:ElevatorOf(player)
		if not elevator then
			return false, "Ты не в лифте"
		end
		elevator.Ready[player.UserId] = payload.ready
		dirty = true
		return true, nil
	end)

	NetService:Handle("ElevatorLeave", function(player)
		local elevator = ElevatorService:ElevatorOf(player)
		if not elevator then
			return false, "Ты не в лифте"
		end
		ElevatorService:Leave(player, elevator)
		pushOut(elevator, player)
		return true, nil
	end)

	NetService:Handle("ElevatorStart", function(player)
		local elevator, err = leaderElevator(player)
		if not elevator then
			return false, err
		end
		if elevator.State ~= "Waiting" then
			return false, "Отсчёт уже идёт"
		end
		beginStarting(elevator, config.StartTime)
		return true, nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		ElevatorService:Leave(player)
	end)

	RunService.Heartbeat:Connect(function(dt)
		ElevatorService:Update(dt)
	end)
end

return ElevatorService
