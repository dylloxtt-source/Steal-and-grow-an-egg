--[[
	DataService — постоянный прогресс (гемы, уровень, статистика, открытые башни).
	Состояние матча сюда не пишется.

	• UpdateAsync с замком сессии (jobId + время): второй сервер не перезапишет профиль.
	• Автосохранение, сохранение при выходе и в BindToClose, повторы при ошибках.
	• Studio без доступа к API → режим памяти: игрок видит предупреждение
	  «прогресс не сохраняется» (никаких ложных сообщений об успешном сохранении).
	• Живой сервер без DataStore → игрок кикается с просьбой перезайти,
	  чтобы не затереть прогресс пустым профилем.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Profile = require(Shared.Logic.Profile)
local Net = require(Shared.Net)

local STORE_NAME = "R6TD_Players_v1"
local LOCK_TIMEOUT = 600
local LOAD_RETRIES = 5

local DataService = {}
DataService.Sessions = {} :: { [Player]: any }
DataService.MemoryMode = false

local store: any = nil
local loadedCallbacks: { (Player, any) -> () } = {}
local removingCallbacks: { (Player, any) -> () } = {}
local profileEvent: RemoteEvent
local notifyEvent: RemoteEvent

local function keyFor(userId: number): string
	return "p_" .. tostring(userId)
end

local function isApiAccessError(err: any): boolean
	local text = tostring(err)
	return string.find(text, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(text, "API Services", 1, true) ~= nil
		or string.find(text, "403", 1, true) ~= nil
end

function DataService:Init(_registry)
	profileEvent = Net.Event("Profile")
	notifyEvent = Net.Event("Notify")
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore недоступен, режим памяти:", result)
		DataService.MemoryMode = true
	end
end

function DataService:OnLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
end

function DataService:OnRemoving(callback: (Player, any) -> ())
	table.insert(removingCallbacks, callback)
end

function DataService:GetSession(player: Player): any?
	local session = DataService.Sessions[player]
	if session and session.Loaded and not session.Released then
		return session
	end
	return nil
end

function DataService:Notify(player: Player, text: string, kind: string?)
	if player.Parent then
		notifyEvent:FireClient(player, text, kind or "info")
	end
end

function DataService:SendProfile(player: Player)
	local session = DataService:GetSession(player)
	if session then
		profileEvent:FireClient(player, { profile = session.Profile, memoryMode = DataService.MemoryMode })
	end
end

local function loadProfile(player: Player): (boolean, any?)
	if DataService.MemoryMode or not store then
		return true, Profile.Default()
	end
	local key = keyFor(player.UserId)
	for attempt = 1, LOAD_RETRIES do
		local lockedByOther = false
		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(old)
				if type(old) == "table" and type(old.lock) == "table" and old.lock.jobId ~= game.JobId
					and os.time() - (tonumber(old.lock.time) or 0) < LOCK_TIMEOUT and attempt < LOAD_RETRIES then
					lockedByOther = true
					return nil
				end
				local data = Profile.Reconcile(old)
				data.lock = { jobId = game.JobId, time = os.time() }
				return data
			end)
		end)
		if ok and result and not lockedByOther then
			return true, result
		end
		if not ok then
			if RunService:IsStudio() and isApiAccessError(result) then
				warn("[DataService] Studio: включите Game Settings > Security > Enable Studio Access to API Services. Прогресс НЕ сохраняется.")
				DataService.MemoryMode = true
				return true, Profile.Default()
			end
			warn(string.format("[DataService] Ошибка загрузки %s (попытка %d): %s", player.Name, attempt, tostring(result)))
		end
		if not player.Parent then
			return false, nil
		end
		task.wait(if lockedByOther then 3 else 2 ^ attempt)
	end
	return false, nil
end

local function saveSession(session: any, release: boolean): boolean
	if DataService.MemoryMode or not store then
		return false
	end
	while session.Saving do
		task.wait(0.1)
	end
	session.Saving = true
	local profile = session.Profile
	local success = false
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(session.UserId), function(old)
				if type(old) == "table" and type(old.lock) == "table" and old.lock.jobId ~= game.JobId
					and os.time() - (tonumber(old.lock.time) or 0) < LOCK_TIMEOUT then
					return nil -- профиль захвачен другим сервером
				end
				profile.lock = if release then nil else { jobId = game.JobId, time = os.time() }
				return profile
			end)
		end)
		if ok then
			success = true
			break
		end
		warn(string.format("[DataService] Ошибка сохранения %d (попытка %d): %s", session.UserId, attempt, tostring(err)))
		task.wait(attempt)
	end
	session.Saving = false
	return success
end

function DataService:SaveNow(player: Player)
	local session = DataService:GetSession(player)
	if session then
		task.spawn(saveSession, session, false)
	end
end

local function onPlayerAdded(player: Player)
	local session = { Player = player, UserId = player.UserId, Loaded = false }
	DataService.Sessions[player] = session
	local ok, profile = loadProfile(player)
	if not player.Parent then
		if ok and profile then
			session.Profile = profile
			saveSession(session, true)
		end
		DataService.Sessions[player] = nil
		return
	end
	if not ok or not profile then
		player:Kick("Не удалось загрузить прогресс. Пожалуйста, перезайдите через минуту.")
		DataService.Sessions[player] = nil
		return
	end
	session.Profile = profile
	session.Loaded = true
	for _, callback in loadedCallbacks do
		local cbOk, err = pcall(callback, player, session)
		if not cbOk then
			warn("[DataService] OnLoaded:", err)
		end
	end
	player:SetAttribute("Loaded", true)
	DataService:SendProfile(player)
	if DataService.MemoryMode then
		DataService:Notify(player, "Тестовый режим: прогресс не сохраняется (DataStore недоступен)", "warn")
	end
end

local function release(player: Player, session: any)
	if not session.Loaded or session.Released then
		return
	end
	session.Released = true
	for _, callback in removingCallbacks do
		local ok, err = pcall(callback, player, session)
		if not ok then
			warn("[DataService] OnRemoving:", err)
		end
	end
	saveSession(session, true)
end

local function onPlayerRemoving(player: Player)
	local session = DataService.Sessions[player]
	if session then
		release(player, session)
		DataService.Sessions[player] = nil
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	task.spawn(function()
		while true do
			task.wait(Game.AutosaveInterval)
			for _, session in DataService.Sessions do
				if session.Loaded and not session.Released then
					task.spawn(saveSession, session, false)
				end
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player, session in DataService.Sessions do
			pending += 1
			task.spawn(function()
				release(player, session)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return DataService
