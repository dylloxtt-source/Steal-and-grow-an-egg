--[[
	Animator — локальная анимация: существа бродят по загону и подпрыгивают,
	яйца на дорожке парят и вращаются, готовые яйца в инкубаторах покачиваются.
	Всё считается только на клиенте и только рядом с камерой — сервер не нагружается.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Animator = {}

local RANGE = 140
local creatures: { [Model]: any } = {}
local eggs: { [Model]: any } = {}

local function cameraPosition(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

local function addCreature(model: Instance)
	if not model:IsA("Model") or creatures[model] then
		return
	end
	local pivot = model:GetPivot()
	creatures[model] = {
		Position = Vector3.new(pivot.Position.X, pivot.Position.Y, pivot.Position.Z),
		Heading = select(2, pivot:ToEulerAnglesYXZ()),
		Target = nil :: Vector3?,
		WaitUntil = os.clock() + math.random() * 3,
		Phase = math.random() * 10,
		Speed = 3 + math.random() * 2,
	}
end

local function addEgg(model: Instance)
	if not model:IsA("Model") or eggs[model] then
		return
	end
	eggs[model] = { Base = model:GetPivot(), Phase = math.random() * 10 }
end

local function stepCreature(model: Model, state: any, dt: number, t: number)
	local penMin = model:GetAttribute("PenMin")
	local penMax = model:GetAttribute("PenMax")
	if typeof(penMin) ~= "Vector3" or typeof(penMax) ~= "Vector3" then
		return
	end
	local moving = false
	if state.Target then
		local delta = Vector3.new(state.Target.X - state.Position.X, 0, state.Target.Z - state.Position.Z)
		local distance = delta.Magnitude
		if distance < 0.4 then
			state.Target = nil
			state.WaitUntil = t + 1.5 + math.random() * 4
		else
			local step = math.min(distance, state.Speed * dt)
			state.Position += delta.Unit * step
			local desired = math.atan2(-delta.X, -delta.Z)
			local diff = (desired - state.Heading + math.pi) % (2 * math.pi) - math.pi
			state.Heading += diff * math.min(1, dt * 6)
			moving = true
		end
	elseif t >= state.WaitUntil then
		state.Target = Vector3.new(
			penMin.X + math.random() * (penMax.X - penMin.X),
			state.Position.Y,
			penMin.Z + math.random() * (penMax.Z - penMin.Z)
		)
	end
	local hop = if moving then math.abs(math.sin((t + state.Phase) * 9)) * 0.6 else math.sin((t + state.Phase) * 2) * 0.08 + 0.08
	model:PivotTo(CFrame.new(state.Position + Vector3.new(0, hop, 0)) * CFrame.Angles(0, state.Heading, 0))
end

function Animator.Start()
	for _, model in CollectionService:GetTagged("PenCreature") do
		addCreature(model)
	end
	CollectionService:GetInstanceAddedSignal("PenCreature"):Connect(function(model)
		task.wait()
		addCreature(model)
	end)
	CollectionService:GetInstanceRemovedSignal("PenCreature"):Connect(function(model)
		creatures[model :: Model] = nil
	end)
	for _, model in CollectionService:GetTagged("WorldEgg") do
		addEgg(model)
	end
	CollectionService:GetInstanceAddedSignal("WorldEgg"):Connect(function(model)
		task.wait()
		addEgg(model)
	end)
	CollectionService:GetInstanceRemovedSignal("WorldEgg"):Connect(function(model)
		eggs[model :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local camera = cameraPosition()
		for model, state in creatures do
			if not model.Parent then
				creatures[model] = nil
			elseif (state.Position - camera).Magnitude < RANGE then
				stepCreature(model, state, dt, t)
			end
		end
		for model, state in eggs do
			if not model.Parent then
				eggs[model] = nil
			elseif (state.Base.Position - camera).Magnitude < RANGE * 0.6 then
				local bob = math.sin((t + state.Phase) * 2.5) * 0.35 + 0.35
				model:PivotTo(state.Base * CFrame.new(0, bob, 0) * CFrame.Angles(0, (t + state.Phase) * 1.2, 0))
			end
		end
		-- Готовые яйца в инкубаторах покачиваются
		for _, incubator in CollectionService:GetTagged("Incubator") do
			if incubator:GetAttribute("State") == "ready" then
				local egg = incubator:FindFirstChild("Egg") :: Model?
				local anchor = incubator:FindFirstChild("EggAnchor") :: BasePart?
				if egg and anchor and (anchor.Position - camera).Magnitude < 80 then
					local wobble = math.sin(t * 12) * math.rad(10)
					egg:PivotTo((anchor.CFrame - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, wobble))
				end
			end
		end
	end)
end

return Animator
