--[[
	TowerAnimator — анимации башен (процедурные, через Motor6D.Transform):
	• Idle — дыхание и лёгкое покачивание.
	• Поворот к цели (только по горизонтали, плавно) — оружие поворачивается вместе с телом.
	• Атаки — у каждого вида свой ключевой цикл: удар мечом, натяжение лука, отдача,
	  замах топором, серия ударов когтями. Оглушение от босса — покачивание головой.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Config.Towers)
local TowerModel = require(Shared.Visual.TowerModel)

local TowerAnimator = {}

local towers: { [Model]: any } = {}
local byKey: { [string]: any } = {}

local A = CFrame.Angles

local function motor(model: Model, name: string): Motor6D?
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == name then
			return d
		end
	end
	return nil
end

local function keyOf(model: Instance): string
	return tostring(model:GetAttribute("MatchId")) .. ":" .. tostring(model:GetAttribute("Uid"))
end

local function track(model: Instance)
	if not model:IsA("Model") or towers[model] or not model.PrimaryPart then
		return
	end
	local def = Towers.ById[(model:GetAttribute("TowerId") :: string?) or ""]
	if not def then
		return
	end
	local state = {
		Model = model,
		Root = model.PrimaryPart,
		Def = def,
		Kind = def.Attack,
		Base = model.PrimaryPart.CFrame,
		Yaw = select(2, model.PrimaryPart.CFrame:ToEulerAnglesYXZ()),
		Joints = {
			RightShoulder = motor(model, "Right Shoulder"),
			LeftShoulder = motor(model, "Left Shoulder"),
			RootJoint = motor(model, "RootJoint"),
			Neck = motor(model, "Neck"),
			RightHip = motor(model, "Right Hip"),
			LeftHip = motor(model, "Left Hip"),
		},
		Muzzles = TowerModel.Muzzles(model),
		AttackStart = -math.huge,
		AttackLength = 0.3,
		Combo = 1,
		Phase = math.random() * 10,
	}
	towers[model] = state
	byKey[keyOf(model)] = state
end

local function untrack(model: Instance)
	if towers[model :: Model] then
		towers[model :: Model] = nil
		local key = keyOf(model)
		if byKey[key] and byKey[key].Model == model then
			byKey[key] = nil
		end
	end
end

function TowerAnimator.Get(matchId: number, uid: number): any?
	return byKey[tostring(matchId) .. ":" .. tostring(uid)]
end

-- Мировая точка вылета снаряда (дуло; для двух пистолетов — чередуются)
function TowerAnimator.Muzzle(state: any, index: number?): Vector3
	local muzzles = state.Muzzles
	if #muzzles > 0 then
		local muzzle = muzzles[((index or 0) % #muzzles) + 1]
		if muzzle.Parent then
			return muzzle.WorldPosition
		end
	end
	return state.Root.Position + Vector3.new(0, 1, 0)
end

local LENGTH = { melee = 0.32, arrow = 0.45, hitscan = 0.12, minigun = 0.08, sniper = 0.5, toxic = 0.3, axe = 0.55, claws = 0.36 }

function TowerAnimator.Attack(state: any, combo: number?)
	state.AttackStart = os.clock()
	state.AttackLength = LENGTH[state.Kind] or 0.3
	state.Combo = combo or 1
end

-- Поза атаки в момент t ∈ [0, 1]
local function attackPose(state: any, t: number): { [string]: CFrame }
	local kind = state.Kind
	local s = math.sin(t * math.pi)
	if kind == "melee" then
		local swing = if t < 0.35 then t / 0.35 * 1.4 else 1.4 - (t - 0.35) / 0.65 * 2.2
		return { RightShoulder = A(0, 0, swing) * A(-s * 0.5, 0, 0), RootJoint = A(0, 0, s * 0.35) }
	elseif kind == "axe" then
		local lift = if t < 0.45 then t / 0.45 * 2.4 else 2.4 - (t - 0.45) / 0.55 * 3.1
		return { RightShoulder = A(0, 0, lift), LeftShoulder = A(0, 0, -lift * 0.6), RootJoint = A(s * 0.25, 0, 0) }
	elseif kind == "arrow" then
		local pull = if t < 0.7 then t / 0.7 else 1 - (t - 0.7) / 0.3
		return { RightShoulder = A(-pull * 0.35, 0, 0) * A(0, 0, -pull * 0.25) }
	elseif kind == "sniper" then
		return { RightShoulder = A(0, 0, s * 0.35), LeftShoulder = A(0, 0, -s * 0.25), RootJoint = A(-s * 0.08, 0, 0), Neck = A(s * 0.15, 0, 0) }
	elseif kind == "hitscan" or kind == "minigun" or kind == "toxic" then
		local kick = (1 - t) * (if kind == "minigun" then 0.08 else 0.25)
		return { RightShoulder = A(0, 0, kick), LeftShoulder = A(0, 0, -kick * 0.6) }
	elseif kind == "claws" then
		-- Серия: руки поочерёдно бьют вперёд
		local hits = math.max(1, state.Combo)
		local phase = (t * hits) % 1
		local index = math.floor(t * hits)
		local jab = math.sin(phase * math.pi) * 1.3
		if index % 2 == 0 then
			return { RightShoulder = A(0, 0, jab) * A(0.3, 0, 0), RootJoint = A(0, 0, 0.15) }
		end
		return { LeftShoulder = A(0, 0, -jab) * A(0.3, 0, 0), RootJoint = A(0, 0, -0.15) }
	end
	return {}
end

local function targetPosition(state: any): Vector3?
	local uid = state.Model:GetAttribute("TargetUid")
	if not uid or uid == 0 then
		return nil
	end
	local EnemyRenderer = require(script.Parent.EnemyRenderer)
	return EnemyRenderer.Position(state.Model:GetAttribute("MatchId"), uid)
end

local function update(state: any, now: number, dt: number)
	local joints = state.Joints
	-- Поворот к цели
	local target = targetPosition(state)
	local root = state.Root
	if target then
		local delta = target - root.Position
		if delta.X * delta.X + delta.Z * delta.Z > 0.01 then
			local desired = math.atan2(-delta.X, -delta.Z)
			local diff = (desired - state.Yaw + math.pi) % (2 * math.pi) - math.pi
			state.Yaw += diff * math.min(1, dt * 14)
		end
	end
	root.CFrame = CFrame.new(root.Position) * A(0, state.Yaw, 0)

	-- Поза: дыхание + атака + оглушение
	local breathe = math.sin((now + state.Phase) * 2) * 0.03
	local pose = { RightShoulder = CFrame.new(), LeftShoulder = CFrame.new(), RootJoint = A(breathe, 0, 0), Neck = CFrame.new() }
	local elapsed = os.clock() - state.AttackStart
	if elapsed < state.AttackLength then
		for name, cf in attackPose(state, elapsed / state.AttackLength) do
			pose[name] = (pose[name] or CFrame.new()) * cf
		end
	end
	local stunnedAt = state.Model:GetAttribute("StunnedAt")
	local stunnedFor = state.Model:GetAttribute("StunnedFor")
	if stunnedAt and stunnedFor and workspace:GetServerTimeNow() - stunnedAt < stunnedFor then
		pose.Neck = A(0, 0, math.sin(now * 10) * 0.4)
		pose.RightShoulder = A(0, 0, -0.4)
	end
	for name, cf in pose do
		local joint = joints[name]
		if joint then
			joint.Transform = cf
		end
	end
end

function TowerAnimator.Init()
	for _, model in CollectionService:GetTagged("Tower") do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal("Tower"):Connect(function(model)
		task.defer(track, model)
	end)
	CollectionService:GetInstanceRemovedSignal("Tower"):Connect(untrack)
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		for model, state in towers do
			if not model.Parent then
				untrack(model)
			else
				update(state, now, dt)
			end
		end
	end)
end

return TowerAnimator
