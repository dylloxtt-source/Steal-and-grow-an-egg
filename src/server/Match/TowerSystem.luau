--[[
	TowerSystem — башни матча: установка, улучшение, продажа, приоритет, атаки.
	Все проверки на сервере: владелец, деньги, лимит, допустимость места
	(Logic/Placement — та же функция, что подсвечивает призрак на клиенте).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Config.Towers)
local Economy = require(Shared.Config.Economy)
local Placement = require(Shared.Logic.Placement)
local TowerModel = require(Shared.Visual.TowerModel)
local Attacks = require(script.Parent.Attacks)

local TowerSystem = {}
TowerSystem.__index = TowerSystem

function TowerSystem.new(match: any)
	return setmetatable({
		Match = match,
		List = {} :: { any },
		ByUid = {} :: { [number]: any },
		NextUid = 1,
	}, TowerSystem)
end

function TowerSystem:CountFor(userId: number): number
	local count = 0
	for _, tower in self.List do
		if tower.OwnerId == userId then
			count += 1
		end
	end
	return count
end

function TowerSystem:Footprints(): { { X: number, Z: number } }
	local list = {}
	for _, tower in self.List do
		table.insert(list, { X = tower.Position.X, Z = tower.Position.Z })
	end
	return list
end

local function facing(match: any, position: Vector3): CFrame
	-- Смотрим на ближайшую точку маршрута
	local path = match.Path
	local best, bestDistance = path.Points[1], math.huge
	local d = 0
	while d <= path.Length do
		local p = path:At(d)
		local distance = (p - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = p, distance
		end
		d += 4
	end
	local world = match.Origin + position + Vector3.new(0, 3, 0)
	local target = match.Origin + Vector3.new(best.X, 3, best.Z)
	if (target - world).Magnitude < 0.1 then
		return CFrame.new(world)
	end
	return CFrame.lookAt(world, target)
end

function TowerSystem:BuildModel(tower: any, cframe: CFrame)
	if tower.Model then
		tower.Model:Destroy()
	end
	local model = TowerModel.Build(tower.TowerId, tower.Level)
	model.Name = tower.Def.Name .. "_" .. tower.Uid
	model:PivotTo(cframe)
	model:SetAttribute("Uid", tower.Uid)
	model:SetAttribute("OwnerId", tower.OwnerId)
	model:SetAttribute("Priority", tower.Priority)
	model:SetAttribute("MatchId", self.Match.Id)
	model:SetAttribute("Spent", tower.Spent)
	model:SetAttribute("Range", tower.Stats.Range)
	model:SetAttribute("Detect", tower.Stats.Detect == true)
	model.Parent = self.Match.Folder.Towers
	CollectionService:AddTag(model, "Tower")
	tower.Model = model
end

function TowerSystem:Place(player: Player, towerId: string, x: number, z: number): (boolean, string?, any?)
	local match = self.Match
	local def = Towers.ById[towerId]
	if not def then
		return false, "Неизвестная башня"
	end
	if match.Ended then
		return false, "Матч окончен"
	end
	local state = match.PlayerState[player.UserId]
	if not state then
		return false, "Ты не в этом матче"
	end
	if self:CountFor(player.UserId) >= Economy.TowerLimit then
		return false, string.format("Лимит башен: %d", Economy.TowerLimit)
	end
	local cost = def.Levels[1].Cost
	if state.Cash < cost then
		return false, "Недостаточно денег"
	end
	local ok, reason = Placement.Check(match.MapId, x, z, self:Footprints())
	if not ok then
		return false, reason
	end
	state.Cash -= cost
	state.TowersPlaced += 1
	local uid = self.NextUid
	self.NextUid += 1
	local tower = {
		Uid = uid,
		TowerId = towerId,
		Def = def,
		Level = 1,
		Stats = def.Levels[1],
		OwnerId = player.UserId,
		OwnerName = player.DisplayName,
		Position = Vector3.new(x, 0, z),
		Priority = "First",
		Cooldown = 0.3,
		Spent = cost,
		StunnedUntil = 0,
		Spin = 0,
		Shots = 0,
		Attacks = 0,
		Damage = 0,
		TargetUid = 0,
	}
	self:BuildModel(tower, facing(match, tower.Position))
	table.insert(self.List, tower)
	self.ByUid[uid] = tower
	match:Fx({ k = "place", t = uid })
	match:MarkDirty()
	return true, nil, { uid = uid }
end

local function owned(self: any, player: Player, uid: any): (any?, string?)
	if type(uid) ~= "number" then
		return nil, "Неверная башня"
	end
	local tower = self.ByUid[uid]
	if not tower then
		return nil, "Башня не найдена"
	end
	if tower.OwnerId ~= player.UserId then
		return nil, "Это не твоя башня"
	end
	return tower, nil
end

function TowerSystem:Upgrade(player: Player, uid: any): (boolean, string?)
	local tower, err = owned(self, player, uid)
	if not tower then
		return false, err
	end
	if tower.Level >= #tower.Def.Levels then
		return false, "Максимальный уровень"
	end
	local state = self.Match.PlayerState[player.UserId]
	local nextStats = tower.Def.Levels[tower.Level + 1]
	if not state or state.Cash < nextStats.Cost then
		return false, "Недостаточно денег"
	end
	state.Cash -= nextStats.Cost
	tower.Level += 1
	tower.Stats = nextStats
	tower.Spent += nextStats.Cost
	self:BuildModel(tower, tower.Model:GetPivot())
	self.Match:Fx({ k = "upgrade", t = tower.Uid, l = tower.Level })
	self.Match:MarkDirty()
	return true, nil
end

function TowerSystem:Remove(tower: any)
	local index = table.find(self.List, tower)
	if index then
		table.remove(self.List, index)
	end
	self.ByUid[tower.Uid] = nil
	if tower.Model then
		tower.Model:Destroy()
		tower.Model = nil
	end
end

function TowerSystem:Sell(player: Player, uid: any): (boolean, string?, any?)
	local tower, err = owned(self, player, uid)
	if not tower then
		return false, err
	end
	local refund = math.floor(tower.Spent * Economy.SellRefund)
	local state = self.Match.PlayerState[player.UserId]
	if state then
		state.Cash += refund
	end
	self.Match:Fx({ k = "sell", at = self.Match:World(tower.Position) })
	self:Remove(tower)
	self.Match:MarkDirty()
	return true, nil, { refund = refund }
end

function TowerSystem:SetPriority(player: Player, uid: any, priority: any): (boolean, string?)
	local tower, err = owned(self, player, uid)
	if not tower then
		return false, err
	end
	if type(priority) ~= "string" or not table.find(Towers.Priorities, priority) then
		return false, "Неверный приоритет"
	end
	tower.Priority = priority
	tower.Model:SetAttribute("Priority", priority)
	return true, nil
end

-- Оглушение башен топотом босса
function TowerSystem:StunInRadius(position: Vector3, radius: number, duration: number): number
	local count = 0
	local now = self.Match.Time
	for _, tower in self.List do
		local delta = tower.Position - position
		if delta.X * delta.X + delta.Z * delta.Z <= radius * radius then
			tower.StunnedUntil = math.max(tower.StunnedUntil, now + duration)
			tower.Model:SetAttribute("StunnedFor", duration)
			tower.Model:SetAttribute("StunnedAt", workspace:GetServerTimeNow())
			count += 1
		end
	end
	return count
end

function TowerSystem:Step(dt: number)
	local match = self.Match
	local now = match.Time
	for _, tower in self.List do
		if tower.StunnedUntil <= now then
			tower.Cooldown -= dt
			-- Несколько атак за шаг, если перезарядка короче шага (пулемёт, ускорение x2)
			local attempts = 0
			while tower.Cooldown <= 0 and attempts < 4 do
				attempts += 1
				local attacked = Attacks[tower.Def.Attack](tower, match)
				if attacked then
					tower.Cooldown += tower.Stats.Cooldown / (1 + (tower.Spin or 0))
				else
					tower.Cooldown = 0.1 -- нет цели: проверим снова чуть позже
					tower.TargetUid = 0
					break
				end
			end
			if tower.Cooldown < -0.2 then
				tower.Cooldown = 0
			end
			if tower.Model and tower.Model:GetAttribute("TargetUid") ~= tower.TargetUid then
				tower.Model:SetAttribute("TargetUid", tower.TargetUid)
			end
		end
	end
end

function TowerSystem:Clear()
	for _, tower in self.List do
		if tower.Model then
			tower.Model:Destroy()
		end
	end
	self.List = {}
	self.ByUid = {}
end

return TowerSystem
