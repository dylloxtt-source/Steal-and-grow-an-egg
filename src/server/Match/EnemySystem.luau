--[[
	EnemySystem — все враги одного матча. Обновляется централизованно из Match:Step
	(никаких циклов на каждого врага).

	Положение врага = пройденная дистанция по маршруту. Клиенты двигают модели сами
	по атрибутам Dist0/Time0/Speed (экстраполяция), сервер переотправляет их при смене
	скорости (оглушение, замедление, ярость, ускорение матча) и раз в SyncInterval.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enemies = require(Shared.Config.Enemies)
local Economy = require(Shared.Config.Economy)
local Game = require(Shared.Config.Game)
local Combat = require(Shared.Logic.Combat)
local EnemyModel = require(Shared.Visual.EnemyModel)

local EnemySystem = {}
EnemySystem.__index = EnemySystem

function EnemySystem.new(match: any)
	return setmetatable({
		Match = match,
		Alive = {} :: { any },
		ByUid = {} :: { [number]: any },
		Removing = {} :: { any },
		NextUid = 1,
		Killed = 0,
		Leaked = 0,
	}, EnemySystem)
end

function EnemySystem:Count(): number
	return #self.Alive
end

local function worldCFrame(match: any, distance: number, scale: number): CFrame
	local position, direction = match.Path:At(distance)
	local world = match.Origin + position + Vector3.new(0, 3 * scale, 0)
	return CFrame.lookAt(world, world + direction)
end

function EnemySystem:Spawn(enemyId: string, wave: any, distance: number?): any?
	local def = Enemies.ById[enemyId]
	if not def then
		warn("[EnemySystem] Неизвестный враг", enemyId)
		return nil
	end
	local match = self.Match
	-- Сложность карты нарастает к 12-й волне: ранние волны не «стена» на трудных картах
	local ramp = math.clamp(wave.Number / 12, 0.35, 1)
	local scale = (1 + (match.Difficulty - 1) * ramp) * match.TeamScale
	local hpMult = if def.Boss then 1 else wave.HealthMult
	local health = math.floor(def.Health * hpMult * scale)
	local shield = math.floor(def.Shield * hpMult * scale)
	local uid = self.NextUid
	self.NextUid += 1
	local enemy = {
		Uid = uid,
		Def = def,
		Wave = wave.Number,
		Distance = distance or 0,
		BaseSpeed = def.Speed * (if def.Boss then 1 else wave.SpeedMult),
		Speed = 0,
		Health = health,
		MaxHealth = health,
		Shield = shield,
		MaxShield = shield,
		Armor = def.Armor + (if def.Armor > 0 then wave.ArmorAdd else 0),
		CcImmune = def.CcImmune == true,
		Stealth = def.Stealth == true,
		PoisonDps = 0, PoisonUntil = 0,
		SlowFactor = 0, SlowUntil = 0,
		StunUntil = 0, StunImmuneUntil = 0,
		LastHit = -math.huge,
		SpawnTime = match.Time,
		Dead = false,
		EnrageMult = 1,
		Abilities = {},
		Position = Vector3.zero,
		Progress = distance or 0,
		SyncTime = -math.huge,
		SyncedSpeed = -1,
		ShownHealth = -1,
	}
	for index, ability in def.Abilities do
		enemy.Abilities[index] = { Def = ability, Next = match.Time + (ability.Interval or 0), Fired = {} }
	end

	local model = EnemyModel.Build(enemyId)
	model.Name = def.Name .. "_" .. uid
	model:PivotTo(worldCFrame(match, enemy.Distance, def.Scale))
	model:SetAttribute("Uid", uid)
	model:SetAttribute("MatchId", match.Id)
	model:SetAttribute("Boss", def.Boss == true)
	model:SetAttribute("Elite", def.Elite == true)
	model:SetAttribute("Stealth", enemy.Stealth)
	model:SetAttribute("Scale", def.Scale)
	model:SetAttribute("MaxHealth", health)
	model:SetAttribute("MaxShield", shield)
	enemy.Model = model
	self:UpdateAttributes(enemy, true)
	model.Parent = match.Folder.Enemies
	CollectionService:AddTag(model, "Enemy")

	table.insert(self.Alive, enemy)
	self.ByUid[uid] = enemy
	if def.Boss then
		match:Fx({ k = "boss", name = def.Name })
		match:Notify("👑 Босс: " .. def.Name .. "!", "boss")
	end
	return enemy
end

-- Атрибуты для клиента: экстраполяция движения и полоски здоровья
function EnemySystem:UpdateAttributes(enemy: any, force: boolean?)
	local model = enemy.Model
	local match = self.Match
	local speed = enemy.Speed
	if force or math.abs(speed - enemy.SyncedSpeed) > 0.01 or match.Time - enemy.SyncTime >= Game.Match.SyncInterval then
		enemy.SyncedSpeed = speed
		enemy.SyncTime = match.Time
		model:SetAttribute("Dist0", enemy.Distance)
		model:SetAttribute("Time0", workspace:GetServerTimeNow())
		model:SetAttribute("Speed", speed * match.TimeScale)
		model:SetAttribute("Stunned", enemy.StunUntil > match.Time)
		model:SetAttribute("Poisoned", enemy.PoisonUntil > match.Time)
	end
	local shown = math.ceil(enemy.Health) + math.ceil(enemy.Shield) * 100000
	if force or shown ~= enemy.ShownHealth then
		enemy.ShownHealth = shown
		model:SetAttribute("Health", math.ceil(enemy.Health))
		model:SetAttribute("Shield", math.ceil(enemy.Shield))
	end
end

-- Урон от башни (или яда). Возвращает нанесённый урон.
function EnemySystem:Damage(enemy: any, amount: number, pierce: number?, tower: any?): number
	if enemy.Dead then
		return 0
	end
	local dealt = Combat.Hit(enemy, amount, pierce, self.Match.Time)
	if tower then
		tower.Damage += dealt
		self.Match:AddDamage(tower.OwnerId, dealt)
	end
	if enemy.Health <= 0 then
		self:Kill(enemy, tower)
	end
	return dealt
end

function EnemySystem:Kill(enemy: any, tower: any?)
	if enemy.Dead then
		return -- награда выдаётся строго один раз
	end
	enemy.Dead = true
	enemy.Health = 0
	self.Killed += 1
	local match = self.Match
	local reward = math.floor(enemy.Def.Reward * (1 + match.Waves.Wave * Economy.KillRewardWaveScale))
	if enemy.Def.Boss then
		reward += Economy.BossBonus
	end
	match:RewardAll(reward)
	match:AddKill(if tower then tower.OwnerId else 0)
	enemy.Model:SetAttribute("Dead", true)
	enemy.Model:SetAttribute("Health", 0)
	match:Fx({ k = "death", e = enemy.Uid, boss = enemy.Def.Boss == true })
	self:Detach(enemy)
	table.insert(self.Removing, { Enemy = enemy, At = match.Time + 0.8 })
end

function EnemySystem:Detach(enemy: any)
	local index = table.find(self.Alive, enemy)
	if index then
		table.remove(self.Alive, index)
	end
end

function EnemySystem:Leak(enemy: any)
	if enemy.Dead then
		return
	end
	enemy.Dead = true
	self.Leaked += 1
	self:Detach(enemy)
	self.Match:DamageBase(enemy.Def.Leak, enemy.Def.Name)
	enemy.Model:SetAttribute("Leaked", true)
	self.ByUid[enemy.Uid] = nil
	enemy.Model:Destroy()
end

local function heal(self: any, healer: any, ability: any)
	local def = ability.Def
	local healed = false
	for _, other in self.Alive do
		if other ~= healer and not other.Dead then
			local delta = other.Position - healer.Position
			if delta.X * delta.X + delta.Z * delta.Z <= def.Radius * def.Radius and other.Health < other.MaxHealth then
				local amount = other.MaxHealth * def.Amount * (if other.Def.Boss then 0.25 else 1)
				Combat.Heal(other, amount)
				healed = true
			end
		end
	end
	if healed then
		self.Match:Fx({ k = "heal", at = self.Match:World(healer.Position), r = def.Radius })
	end
end

local function abilities(self: any, enemy: any, dt: number)
	local match = self.Match
	for _, state in enemy.Abilities do
		local def = state.Def
		if def.Kind == "Regen" then
			if match.Time - enemy.LastHit >= (def.Delay or 1.5) and enemy.Health < enemy.MaxHealth then
				Combat.Heal(enemy, enemy.MaxHealth * def.Amount * dt)
			end
		elseif def.Kind == "Heal" then
			if match.Time >= state.Next then
				state.Next = match.Time + def.Interval
				heal(self, enemy, state)
			end
		elseif def.Kind == "Stomp" then
			if match.Time >= state.Next then
				state.Next = match.Time + def.Interval
				local stunned = match.Towers:StunInRadius(enemy.Position, def.Radius, def.Duration)
				match:Fx({ k = "stomp", at = match:World(enemy.Position), r = def.Radius, n = stunned })
			end
		elseif def.Kind == "Summon" then
			local fraction = enemy.Health / enemy.MaxHealth
			for i, threshold in def.Thresholds do
				if fraction <= threshold and not state.Fired[i] then
					state.Fired[i] = true
					local wave = match.Waves:CurrentConfig()
					for k = 1, def.Count do
						self:Spawn(def.Summon, wave, math.max(0, enemy.Distance - 2 * k))
					end
					match:Fx({ k = "summon", at = match:World(enemy.Position) })
				end
			end
		elseif def.Kind == "Enrage" then
			if not state.Fired[1] and enemy.Health / enemy.MaxHealth <= def.Thresholds[1] then
				state.Fired[1] = true
				enemy.EnrageMult = def.Amount
				match:Fx({ k = "enrage", e = enemy.Uid })
				match:Notify("🔥 " .. enemy.Def.Name .. " в ярости!", "boss")
			end
		end
	end
end

function EnemySystem:Step(dt: number)
	local match = self.Match
	local path = match.Path
	local now = match.Time
	local lifetimeFactor = Game.Match.EnemyLifetimeFactor
	-- Копия: враги могут умирать/дойти до базы в процессе
	for _, enemy in table.clone(self.Alive) do
		if not enemy.Dead then
			enemy.Speed = enemy.BaseSpeed * Combat.SpeedFactor(enemy, now) * enemy.EnrageMult
			enemy.Distance += enemy.Speed * dt
			enemy.Progress = enemy.Distance
			enemy.Position = path:At(enemy.Distance)
			local poison = Combat.TickPoison(enemy, dt, now)
			if poison > 0 and enemy.Health <= 0 then
				self:Kill(enemy, nil)
			elseif not enemy.Dead then
				abilities(self, enemy, dt)
				local maxLifetime = path.Length / math.max(enemy.BaseSpeed, 1) * lifetimeFactor + 30
				if enemy.Distance >= path.Length or now - enemy.SpawnTime > maxLifetime then
					self:Leak(enemy)
				else
					self:UpdateAttributes(enemy)
				end
			end
		end
	end
	for i = #self.Removing, 1, -1 do
		local entry = self.Removing[i]
		if now >= entry.At then
			table.remove(self.Removing, i)
			self.ByUid[entry.Enemy.Uid] = nil
			entry.Enemy.Model:Destroy()
		end
	end
end

-- Принудительная ресинхронизация (смена скорости матча)
function EnemySystem:Resync()
	for _, enemy in self.Alive do
		self:UpdateAttributes(enemy, true)
	end
end

function EnemySystem:Clear()
	for _, enemy in self.Alive do
		enemy.Dead = true
		if enemy.Model then
			enemy.Model:Destroy()
		end
	end
	for _, entry in self.Removing do
		entry.Enemy.Model:Destroy()
	end
	self.Alive = {}
	self.Removing = {}
	self.ByUid = {}
end

return EnemySystem
