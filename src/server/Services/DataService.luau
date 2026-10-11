--[[
	DataService — загрузка/сохранение профилей и сессии игроков.

	• DataStore + UpdateAsync с «замком сессии» (jobId + время), чтобы два сервера
	  не писали один профиль одновременно (защита от дюпа при быстром перезаходе).
	• Автосохранение раз в Game.AutosaveInterval, сохранение при выходе и BindToClose.
	• Если DataStore недоступен в Studio (выключен доступ к API) — режим памяти:
	  игра работает, но прогресс не сохраняется (игрок получает предупреждение).
	• Если DataStore недоступен на живом сервере — игрок кикается с просьбой
	  перезайти, чтобы не перезаписать его прогресс пустым профилем.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Profile = require(Shared.Logic.Profile)
local Net = require(Shared.Net)

local STORE_NAME = "SGAE_Players_v1"
local LOCK_TIMEOUT = 600
local LOAD_RETRIES = 5

local DataService = {}
DataService.Sessions = {} :: { [Player]: any }
DataService.MemoryMode = false

local store: DataStore? = nil
local loadedCallbacks: { (Player, any) -> () } = {}
local removingCallbacks: { (Player, any) -> () } = {}
local viewContributors: { (any, any) -> () } = {}
local stateEvent: RemoteEvent
local notifyEvent: RemoteEvent

local function keyFor(userId: number): string
	return "u_" .. tostring(userId)
end

local function isApiAccessError(err: any): boolean
	local text = tostring(err)
	return string.find(text, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(text, "API Services", 1, true) ~= nil
		or string.find(text, "403", 1, true) ~= nil
end

function DataService:Init(_registry)
	stateEvent = Net.Event("State")
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

-- Сервисы добавляют в снимок для клиента свои поля (runtime-состояние)
function DataService:AddViewContributor(callback: (any, any) -> ())
	table.insert(viewContributors, callback)
end

function DataService:GetSession(player: Player): any?
	local session = DataService.Sessions[player]
	if session and session.Loaded then
		return session
	end
	return nil
end

function DataService:Notify(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind or "info")
end

-- Отложенная (склеенная) отправка состояния клиенту
function DataService:MarkDirty(player: Player)
	local session = DataService.Sessions[player]
	if not session or not session.Loaded or session.SyncQueued then
		return
	end
	session.SyncQueued = true
	task.delay(0.12, function()
		session.SyncQueued = false
		if DataService.Sessions[player] == session and player.Parent then
			local view = { profile = session.Profile, runtime = {} }
			for _, contributor in viewContributors do
				local ok, err = pcall(contributor, session, view.runtime)
				if not ok then
					warn("[DataService] view contributor error:", err)
				end
			end
			view.runtime.serverTime = os.time()
			stateEvent:FireClient(player, view)
		end
	end)
end

local function loadProfile(player: Player): (boolean, any?)
	if DataService.MemoryMode or not store then
		return true, Profile.Default()
	end
	local key = keyFor(player.UserId)
	for attempt = 1, LOAD_RETRIES do
		local lockedByOther = false
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(key, function(old)
				local data = old
				if type(data) == "table" and type(data.lock) == "table" then
					local lock = data.lock
					if lock.jobId ~= game.JobId and os.time() - (tonumber(lock.time) or 0) < LOCK_TIMEOUT
						and attempt < LOAD_RETRIES then
						lockedByOther = true
						return nil -- отменяем запись, подождём освобождения
					end
				end
				data = Profile.Reconcile(data)
				data.lock = { jobId = game.JobId, time = os.time() }
				return data
			end)
		end)
		if ok and not lockedByOther and result then
			return true, result
		end
		if not ok then
			if RunService:IsStudio() and isApiAccessError(result) then
				warn("[DataService] Нет доступа к API в Studio — включите Game Settings > Security > "
					.. "Enable Studio Access to API Services. Прогресс не сохраняется.")
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
		return true
	end
	if session.Saving then
		-- Не запускаем параллельные записи одного профиля
		while session.Saving do
			task.wait(0.1)
		end
		if not release then
			return true
		end
	end
	session.Saving = true
	local profile = session.Profile
	profile.lastOnline = os.time()
	local key = keyFor(session.UserId)
	local success = false
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(old)
				if type(old) == "table" and type(old.lock) == "table" and old.lock.jobId ~= game.JobId
					and os.time() - (tonumber(old.lock.time) or 0) < LOCK_TIMEOUT then
					-- Профиль захвачен другим сервером — не перетираем
					return nil
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
	local session = DataService.Sessions[player]
	if session and session.Loaded then
		task.spawn(saveSession, session, false)
	end
end

local function onPlayerAdded(player: Player)
	local session = {
		Player = player,
		UserId = player.UserId,
		Loaded = false,
		JoinTime = os.clock(),
	}
	DataService.Sessions[player] = session

	local ok, profile = loadProfile(player)
	if not player.Parent then
		if ok and profile and not DataService.MemoryMode then
			session.Profile = profile
			saveSession(session, true)
		end
		DataService.Sessions[player] = nil
		return
	end
	if not ok or not profile then
		player:Kick("Не удалось загрузить сохранение. Пожалуйста, перезайдите через минуту.")
		DataService.Sessions[player] = nil
		return
	end

	session.Profile = profile
	session.Loaded = true
	for _, callback in loadedCallbacks do
		local cbOk, err = pcall(callback, player, session)
		if not cbOk then
			warn("[DataService] OnLoaded error:", err)
		end
	end
	player:SetAttribute("Loaded", true)
	DataService:MarkDirty(player)
	if DataService.MemoryMode then
		DataService:Notify(player, "Studio: сохранения выключены (нет доступа к API)", "warn")
	end
end

local function onPlayerRemoving(player: Player)
	local session = DataService.Sessions[player]
	if not session then
		return
	end
	if session.Loaded and not session.Released then
		session.Released = true
		for _, callback in removingCallbacks do
			local ok, err = pcall(callback, player, session)
			if not ok then
				warn("[DataService] OnRemoving error:", err)
			end
		end
		session.Profile.stats.playTime += os.clock() - session.JoinTime
		session.JoinTime = os.clock()
		saveSession(session, true)
	end
	DataService.Sessions[player] = nil
end

-- Игровое время с учётом текущей сессии (для защиты новичков)
function DataService:PlayTime(session: any): number
	return session.Profile.stats.playTime + (os.clock() - session.JoinTime)
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
				if session.Loaded then
					session.Profile.stats.playTime += os.clock() - session.JoinTime
					session.JoinTime = os.clock()
					task.spawn(saveSession, session, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, session in DataService.Sessions do
			if session.Loaded and not session.Released then
				session.Released = true
				pending += 1
				task.spawn(function()
					for _, callback in removingCallbacks do
						pcall(callback, player, session)
					end
					saveSession(session, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return DataService
