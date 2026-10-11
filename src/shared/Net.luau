--[[
	Сетевой контракт. Сервер создаёт ReplicatedStorage.Remotes, клиент ждёт.

	Action (RemoteFunction, клиент → сервер): Action:InvokeServer(name, payload)
	  → { ok, message, data }. Лимиты частоты — ниже (вызовов в секунду).

	События сервер → клиент:
	  LobbyState  (elevators)      — состояние всех лифтов
	  MatchState  (snapshot)       — снимок матча для его участников
	  MatchFx     (list)           — пачка визуальных событий за тик
	  MatchEnded  (results)        — итоги матча
	  Profile     (profileView)    — постоянный прогресс
	  Notify      (text, kind)     — уведомление
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.FolderName = "Remotes"
Net.Function = "Action"
Net.Events = { "LobbyState", "MatchState", "MatchFx", "MatchEnded", "Profile", "Notify" }

Net.Actions = {
	ElevatorSetMap = 4,
	ElevatorSetCapacity = 4,
	ElevatorReady = 4,
	ElevatorLeave = 2,
	ElevatorStart = 2,
	PlaceTower = 6,
	UpgradeTower = 6,
	SellTower = 4,
	SetPriority = 6,
	VoteSpeed = 2,
	VoteSkip = 2,
	ReturnToLobby = 1,
	RequestState = 2,
	BuyTower = 3,
	EquipTower = 6,
	UnequipTower = 6,
	SetSetting = 6,
}

local folder: Folder? = nil

function Net.Folder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(Net.FolderName)
		if existing then
			folder = existing :: Folder
		else
			local created = Instance.new("Folder")
			created.Name = Net.FolderName
			created.Parent = ReplicatedStorage
			folder = created
		end
	else
		folder = ReplicatedStorage:WaitForChild(Net.FolderName) :: Folder
	end
	return (folder :: any) :: Folder
end

function Net.Event(name: string): RemoteEvent
	local root = Net.Folder()
	if RunService:IsServer() then
		local existing = root:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = root
		return event
	end
	return root:WaitForChild(name) :: RemoteEvent
end

function Net.ActionFunction(): RemoteFunction
	local root = Net.Folder()
	if RunService:IsServer() then
		local existing = root:FindFirstChild(Net.Function)
		if existing then
			return existing :: RemoteFunction
		end
		local fn = Instance.new("RemoteFunction")
		fn.Name = Net.Function
		fn.Parent = root
		return fn
	end
	return root:WaitForChild(Net.Function) :: RemoteFunction
end

return Net
