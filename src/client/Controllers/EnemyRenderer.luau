--[[
	EnemyRenderer — движение и анимация врагов на клиенте.
	Сервер присылает только Dist0/Time0/Speed; положение на маршруте клиент считает
	сам каждый кадр (плавно и без сетевой нагрузки). Анимации — процедурные через
	Motor6D.Transform (шаг, оглушение, смерть), без внешних ID анимаций.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapLayout = require(Shared.Logic.MapLayout)

local Kit = require(script.Parent.Parent.UI.Kit)

local C = Kit.Theme.Colors

local EnemyRenderer = {}

local enemies: { [Model]: any } = {}
local byUid: { [string]: any } = {}

local A = CFrame.Angles

local function motor(model: Model, name: string): Motor6D?
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == name then
			return d
		end
	end
	return nil
end

local function hpBar(model: Model, boss: boolean): any
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local gui = Kit.Create("BillboardGui", {
		Name = "HpBar",
		Size = if boss then UDim2.fromOffset(150, 18) else UDim2.fromOffset(56, 8),
		StudsOffsetWorldSpace = Vector3.new(0, 1.6 * ((model:GetAttribute("Scale") :: number?) or 1), 0),
		AlwaysOnTop = false,
		MaxDistance = 140,
		LightInfluence = 0,
		Adornee = head,
		Parent = head,
	})
	local back = Kit.Create("Frame", { BackgroundColor3 = C.Background, BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Parent = gui })
	Kit.Corner(back, 4)
	local fill = Kit.Create("Frame", { BackgroundColor3 = if boss then C.Red else C.Green, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Parent = back })
	Kit.Corner(fill, 4)
	local shield = Kit.Create("Frame", { BackgroundColor3 = C.Accent, Size = UDim2.new(0, 0, 0.35, 0), Position = UDim2.fromScale(0, 0.65),
		BorderSizePixel = 0, Parent = back })
	local icon = Kit.Text({ Text = "", Size = UDim2.fromOffset(40, 20), Position = UDim2.new(0.5, 0, 0, -22), AnchorPoint = Vector2.new(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center, TextSize = 14, Parent = gui })
	return { Gui = gui, Fill = fill, Shield = shield, Icon = icon }
end

local function track(model: Instance)
	if not model:IsA("Model") or enemies[model] then
		return
	end
	local matchFolder = model.Parent and model.Parent.Parent
	local mapId = matchFolder and matchFolder:GetAttribute("MapId")
	local origin = matchFolder and matchFolder:GetAttribute("Origin")
	local root = model.PrimaryPart
	if not mapId or typeof(origin) ~= "Vector3" or not root then
		return
	end
	local state = {
		Model = model,
		Root = root,
		Path = MapLayout.Get(mapId).Path,
		Origin = origin,
		Scale = model:GetAttribute("Scale") or 1,
		Joints = {
			RightShoulder = motor(model, "Right Shoulder"),
			LeftShoulder = motor(model, "Left Shoulder"),
			RightHip = motor(model, "Right Hip"),
			LeftHip = motor(model, "Left Hip"),
			RootJoint = motor(model, "RootJoint"),
			Neck = motor(model, "Neck"),
		},
		Phase = math.random() * 10,
		DeathStart = nil :: number?,
		Bar = hpBar(model, model:GetAttribute("Boss") == true),
		Position = root.Position,
		Stealth = model:GetAttribute("Stealth") == true,
	}
	if state.Stealth then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0.55
			end
		end
	end
	enemies[model] = state
	byUid[tostring(model:GetAttribute("MatchId")) .. ":" .. tostring(model:GetAttribute("Uid"))] = state
end

local function untrack(model: Instance)
	local state = enemies[model :: Model]
	if state then
		enemies[model :: Model] = nil
		byUid[tostring(model:GetAttribute("MatchId")) .. ":" .. tostring(model:GetAttribute("Uid"))] = nil
	end
end

-- Текущая мировая позиция врага (для снарядов и эффектов)
function EnemyRenderer.Position(matchId: number, uid: number): Vector3?
	local state = byUid[tostring(matchId) .. ":" .. tostring(uid)]
	return state and state.Position
end

function EnemyRenderer.Count(): number
	local n = 0
	for _ in enemies do
		n += 1
	end
	return n
end

local function animate(state: any, now: number, dt: number)
	local model = state.Model
	local joints = state.Joints
	local dead = model:GetAttribute("Dead") == true
	if dead then
		state.DeathStart = state.DeathStart or now
		local t = math.min(1, (now - state.DeathStart) / 0.5)
		if joints.RootJoint then
			joints.RootJoint.Transform = A(-t * math.pi / 2, 0, 0)
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.LocalTransparencyModifier = math.max(if state.Stealth then 0.55 else 0, t * 0.9)
			end
		end
		if state.Bar then
			state.Bar.Gui.Enabled = false
		end
		return
	end

	-- Положение на маршруте
	local dist0 = model:GetAttribute("Dist0") or 0
	local time0 = model:GetAttribute("Time0") or now
	local speed = model:GetAttribute("Speed") or 0
	local distance = math.clamp(dist0 + speed * (now - time0), 0, state.Path.Length)
	local position, direction = state.Path:At(distance)
	local world = state.Origin + position + Vector3.new(0, 3 * state.Scale, 0)
	state.Position = world
	local look = CFrame.lookAt(world, world + direction)
	local rotated = state.Root.CFrame:Lerp(look, math.min(1, dt * 12))
	state.Root.CFrame = rotated - rotated.Position + world

	-- Шаг
	local stunned = model:GetAttribute("Stunned") == true
	local swing = if stunned or speed <= 0.01 then 0 else math.sin((now + state.Phase) * (4 + speed * 0.6)) * 0.7
	if joints.RightHip then
		joints.RightHip.Transform = A(0, 0, swing)
	end
	if joints.LeftHip then
		joints.LeftHip.Transform = A(0, 0, swing)
	end
	if joints.RightShoulder then
		joints.RightShoulder.Transform = A(0, 0, -swing * 0.6)
	end
	if joints.LeftShoulder then
		joints.LeftShoulder.Transform = A(0, 0, -swing * 0.6)
	end
	if joints.Neck then
		joints.Neck.Transform = if stunned then A(0, 0, math.sin(now * 12) * 0.35) else CFrame.new()
	end

	-- Полоска здоровья
	local bar = state.Bar
	if bar then
		local hp = model:GetAttribute("Health") or 0
		local maxHp = math.max(1, model:GetAttribute("MaxHealth") or 1)
		local shield = model:GetAttribute("Shield") or 0
		local maxShield = model:GetAttribute("MaxShield") or 0
		bar.Fill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
		bar.Fill.BackgroundColor3 = if model:GetAttribute("Boss") then C.Red elseif hp / maxHp < 0.35 then C.Orange else C.Green
		bar.Shield.Size = UDim2.new(if maxShield > 0 then math.clamp(shield / maxShield, 0, 1) else 0, 0, 0.35, 0)
		bar.Icon.Text = (if stunned then "💫" else "") .. (if model:GetAttribute("Poisoned") then "☣" else "")
	end
end

function EnemyRenderer.Init()
	for _, model in CollectionService:GetTagged("Enemy") do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(function(model)
		task.defer(track, model)
	end)
	CollectionService:GetInstanceRemovedSignal("Enemy"):Connect(untrack)
	RunService.RenderStepped:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		for model, state in enemies do
			if not model.Parent then
				enemies[model] = nil
			else
				animate(state, now, dt)
			end
		end
	end)
end

return EnemyRenderer
