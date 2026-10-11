--[[
	Сетевой контракт. Сервер создаёт папку Remotes, клиент её ждёт.

	Action (RemoteFunction, клиент -> сервер): Action:InvokeServer(name, payload)
	  возвращает { ok = boolean, message = string?, data = any? }.
	  Все действия проверяются на сервере (см. server/Services/NetService).

	События сервер -> клиент:
	  State      (profileView)            — полный снимок профиля для UI
	  Notify     (text, kind)             — всплывающее уведомление
	  Hatched    (result)                 — показ вылупления
	  StealAlert (info)                   — у вас крадут / вор пойман
	  Effect     (kind, data)             — визуальные эффекты (оглушение и т.п.)
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.FolderName = "Remotes"
Net.Function = "Action"
Net.Events = { "State", "Notify", "Hatched", "StealAlert", "Effect" }

-- Имена действий, допустимых с клиента, и лимит вызовов в секунду
Net.Actions = {
	Incubate = 4,
	Hatch = 4,
	HatchAll = 1,
	SkipHatch = 2,
	Buy = 6,
	Upgrade = 4,
	Feed = 6,
	Place = 4,
	Store = 4,
	Sell = 4,
	Plant = 4,
	Harvest = 4,
	ClaimQuest = 2,
	SetSetting = 3,
	Tutorial = 2,
	RequestState = 1,
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
