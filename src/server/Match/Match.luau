--[[
	Match — один матч: карта в своём слоте мира, игроки, деньги, база, системы
	врагов/башен/волн, отложенные события и пачки визуальных эффектов.

	Время матча (Time) идёт только через Step(dt) с учётом ускорения (TimeScale),
	поэтому вся логика детерминирована и одинаково работает в игре и в тестах.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maps = require(Shared.Config.Maps)
local Game = require(Shared.Config.Game)
local Economy = require(Shared.Config.Economy)
local MapLayout = require(Shared.Logic.MapLayout)
local Net = require(Shared.Net)

local MapBuilder = require(script.Parent.MapBuilder)
local EnemySystem = require(script.Parent.EnemySystem)
local TowerSystem = require(script.Parent.TowerSystem)
local WaveSystem = require(script.Parent.WaveSystem)

local Match = {}
Match.__index = Match

local stateEvent: RemoteEvent
local fxEvent: RemoteEvent
local notifyEvent: RemoteEvent

function Match.new(id: number, slot: number, mapId: string, players: { Player }, container: Instance)
	stateEvent = stateEvent or Net.Event("MatchState")
	fxEvent = fxEvent or Net.Event("MatchFx")
	notifyEvent = notifyEvent or Net.Event("Notify")
	local map = Maps.ById[mapId]
	local origin = Game.Match.SlotOrigin + Vector3.new((slot - 1) * Game.Match.SlotSpacing, 0, 0)
	local folder = Instance.new("Folder")
	folder.Name = "Match_" .. id
	folder:SetAttribute("MatchId", id)
	folder:SetAttribute("MapId", mapId)
	folder:SetAttribute("Origin", origin)
	for _, name in { "Enemies", "Towers" } do
		local sub = Instance.new("Folder")
		sub.Name = name
		sub.Parent = folder
	end
	folder.Parent = container
	MapBuilder.Build(mapId, origin, folder)

	local self = setmetatable({
		Id = id,
		Slot = slot,
		MapId = mapId,
		Map = map,
		Origin = origin,
		Folder = folder,
		Path = MapLayout.Get(mapId).Path,
		Difficulty = map.Difficulty,
		TeamScale = 1 + Game.Match.TeamHpScale * (#players - 1),
		Players = {} :: { Player },
		PlayerState = {} :: { [number]: any },
		BaseHealth = map.BaseHealth,
		BaseMaxHealth = map.BaseHealth,
		Time = 0,
		TimeScale = 1,
		Accumulator = 0,
		StateAccumulator = 0,
		FxQueue = {} :: { any },
		Scheduled = {} :: { { At: number, Fn: () -> () } },
		Votes = { Speed = {}, Skip = {} },
		Ended = false,
		Result = nil :: string?,
		WavesCleared = 0,
		Dirty = true,
		OnFinished = nil :: ((any, boolean) -> ())?,
	}, Match)
	self.Enemies = EnemySystem.new(self)
	self.Towers = TowerSystem.new(self)
	self.Waves = WaveSystem.new(self)
	for _, player in players do
		self:AddPlayer(player)
	end
	return self
end

function Match:AddPlayer(player: Player)
	table.insert(self.Players, player)
	self.PlayerState[player.UserId] = {
		UserId = player.UserId,
		Name = player.DisplayName,
		Cash = Economy.StartCash,
		Kills = 0,
		Damage = 0,
		Earned = 0,
		TowersPlaced = 0,
		Connected = true,
		Loadout = nil :: { string }?, -- башни, которые игрок взял в матч (nil — без ограничений)
		AutoSkip = false,
	}
end

-- Набор башен и настройки из профиля (MatchService вызывает при создании матча)
function Match:ApplyProfile(player: Player, profile: any)
	local state = self.PlayerState[player.UserId]
	if state and profile then
		state.Loadout = table.clone(profile.loadout)
		state.AutoSkip = profile.settings.autoSkip == true
		self:MarkDirty()
	end
end

function Match:SetAutoSkip(player: Player, enabled: boolean)
	local state = self.PlayerState[player.UserId]
	if state then
		state.AutoSkip = enabled
		self:MarkDirty()
	end
end

-- Авто-скип: если каждый игрок либо проголосовал за пропуск, либо включил авто-скип,
-- ожидание заканчивается само. В подготовке авто-скип ждёт, пока игрок поставит
-- первую башню; в перерыве — 1.5 сек., чтобы было видно, что волна пройдена.
local AUTO_SKIP_DELAY = 1.5
function Match:CheckAutoSkip()
	local waves = self.Waves
	local phase = waves.Phase
	if phase ~= "Prep" and phase ~= "Intermission" or #self.Players == 0 then
		return
	end
	local total = if phase == "Prep" then Game.Match.PrepTime else Game.Match.Intermission
	if total - waves.Timer < AUTO_SKIP_DELAY then
		return
	end
	local anyAuto = false
	for _, player in self.Players do
		local state = self.PlayerState[player.UserId]
		local auto = state and state.AutoSkip and (phase == "Intermission" or state.TowersPlaced > 0)
		if auto then
			anyAuto = true
		elseif not self.Votes.Skip[player.UserId] then
			return
		end
	end
	if anyAuto and waves:Skip() then
		self:MarkDirty()
	end
end

function Match:RemovePlayer(player: Player)
	local index = table.find(self.Players, player)
	if index then
		table.remove(self.Players, index)
	end
	local state = self.PlayerState[player.UserId]
	if state then
		state.Connected = false
	end
	self.Votes.Speed[player.UserId] = nil
	self.Votes.Skip[player.UserId] = nil
	self:RecountSpeed()
	self:MarkDirty()
end

function Match:World(localPosition: Vector3): Vector3
	return self.Origin + localPosition
end

function Match:SpawnCFrame(): CFrame
	local position = self.Origin + self.Map.PlayerSpawn + Vector3.new(math.random(-4, 4), 4, math.random(-4, 4))
	return CFrame.lookAt(position, self.Origin + Vector3.new(0, 4, 0))
end

function Match:Fx(entry: any)
	table.insert(self.FxQueue, entry)
end

function Match:Notify(text: string, kind: string?)
	for _, player in self.Players do
		notifyEvent:FireClient(player, text, kind or "info")
	end
end

function Match:MarkDirty()
	self.Dirty = true
end

function Match:Schedule(delay: number, fn: () -> ())
	table.insert(self.Scheduled, { At = self.Time + delay, Fn = fn })
end

function Match:RewardAll(amount: number)
	for _, state in self.PlayerState do
		if state.Connected then
			state.Cash += amount
			state.Earned += amount
		end
	end
	self.Dirty = true
end

function Match:AddKill(userId: number)
	local state = self.PlayerState[userId]
	if state then
		state.Kills += 1
	end
end

function Match:AddDamage(userId: number, amount: number)
	local state = self.PlayerState[userId]
	if state then
		state.Damage += amount
	end
end

function Match:DamageBase(amount: number, source: string)
	if self.Ended then
		return
	end
	self.BaseHealth = math.max(0, self.BaseHealth - amount)
	self:Fx({ k = "leak", n = amount })
	self:MarkDirty()
	if self.BaseHealth <= 0 then
		self:Notify("💥 The base was destroyed (" .. source .. ")", "error")
		self:Finish(false)
	end
end

function Match:ClearVotes(kind: string)
	self.Votes[kind] = {}
end

function Match:RecountSpeed()
	local votes = 0
	for _ in self.Votes.Speed do
		votes += 1
	end
	local scale = if #self.Players > 0 and votes * 2 > #self.Players then 2 else 1
	if scale ~= self.TimeScale then
		self.TimeScale = scale
		self.Enemies:Resync()
		self:Notify(if scale == 2 then "⏩ Speed x2 enabled" else "▶ Normal speed", "info")
	end
end

function Match:Vote(player: Player, kind: string): (boolean, string?)
	local votes = self.Votes[kind]
	if votes[player.UserId] then
		votes[player.UserId] = nil
	else
		votes[player.UserId] = true
	end
	if kind == "Speed" then
		self:RecountSpeed()
	elseif kind == "Skip" then
		local count = 0
		for _ in votes do
			count += 1
		end
		if count >= #self.Players and not self.Waves:Skip() then
			votes[player.UserId] = nil
			return false, "Nothing to skip right now"
		end
	end
	self:MarkDirty()
	return true, nil
end

function Match:Finish(victory: boolean)
	if self.Ended then
		return
	end
	self.Ended = true
	self.Result = if victory then "Victory" else "Defeat"
	self.Waves.Phase = self.Result
	self:Fx({ k = if victory then "victory" else "defeat" })
	self:Flush()
	self:Broadcast()
	if self.OnFinished then
		self.OnFinished(self, victory)
	end
end

function Match:Snapshot(): any
	local team = {}
	for _, state in self.PlayerState do
		if state.Connected then
			table.insert(team, {
				userId = state.UserId, name = state.Name, cash = state.Cash, kills = state.Kills,
				towers = self.Towers:CountFor(state.UserId), autoSkip = state.AutoSkip, loadout = state.Loadout,
			})
		end
	end
	local bosses = {}
	for _, enemy in self.Enemies.Alive do
		if enemy.Def.Boss then
			table.insert(bosses, { uid = enemy.Uid, name = enemy.Def.Name, hp = math.ceil(enemy.Health), maxHp = enemy.MaxHealth,
				shield = math.ceil(enemy.Shield), maxShield = enemy.MaxShield })
		end
	end
	local speedBy, skipBy = {}, {}
	for userId in self.Votes.Speed do
		table.insert(speedBy, userId)
	end
	for userId in self.Votes.Skip do
		table.insert(skipBy, userId)
	end
	return {
		id = self.Id,
		mapId = self.MapId,
		origin = self.Origin,
		wave = self.Waves.Wave,
		maxWave = self.Waves.Max,
		phase = self.Waves.Phase,
		timer = self.Waves:TimerValue(),
		baseHp = self.BaseHealth,
		baseMaxHp = self.BaseMaxHealth,
		enemies = self.Enemies:Count() + #self.Waves.Queue,
		waveTotal = if self.Waves.Config then self.Waves.Config.Total else 0,
		timeScale = self.TimeScale,
		speedVotes = #speedBy,
		skipVotes = #skipBy,
		speedBy = speedBy,
		skipBy = skipBy,
		players = #self.Players,
		team = team,
		bosses = bosses,
		towerLimit = Economy.TowerLimit,
	}
end

function Match:Broadcast()
	local snapshot = self:Snapshot()
	for _, player in self.Players do
		stateEvent:FireClient(player, snapshot)
	end
	self.Dirty = false
end

function Match:Flush()
	if #self.FxQueue == 0 then
		return
	end
	local batch = self.FxQueue
	self.FxQueue = {}
	for _, player in self.Players do
		fxEvent:FireClient(player, batch)
	end
end

-- Один фиксированный шаг симуляции
function Match:Tick(dt: number)
	self.Time += dt
	for i = #self.Scheduled, 1, -1 do
		local entry = self.Scheduled[i]
		if self.Time >= entry.At then
			table.remove(self.Scheduled, i)
			local ok, err = pcall(entry.Fn)
			if not ok then
				warn("[Match] scheduled:", err)
			end
		end
	end
	if self.Ended then
		return
	end
	self:CheckAutoSkip()
	self.Waves:Step(dt)
	if self.Ended then
		return
	end
	self.Enemies:Step(dt)
	if self.Ended then
		return
	end
	self.Towers:Step(dt)
end

-- Реальное время → фиксированные шаги с учётом ускорения
function Match:Step(realDt: number)
	if self.Ended then
		return
	end
	local step = 1 / Game.Match.TickRate
	self.Accumulator += math.min(realDt, 0.5)
	while self.Accumulator >= step and not self.Ended do
		self.Accumulator -= step
		self:Tick(step * self.TimeScale)
	end
	self:Flush()
	self.StateAccumulator += realDt
	-- Снимок: не чаще 10 раз в секунду при изменениях и не реже StateRate
	if (self.Dirty and self.StateAccumulator >= 0.1) or self.StateAccumulator >= 1 / Game.Match.StateRate then
		self.StateAccumulator = 0
		self:Broadcast()
	end
end

function Match:Destroy()
	self.Ended = true
	self.Enemies:Clear()
	self.Towers:Clear()
	self.Scheduled = {}
	self.FxQueue = {}
	if self.Folder then
		self.Folder:Destroy()
		self.Folder = nil
	end
end

return Match
