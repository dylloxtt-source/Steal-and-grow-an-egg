--[[
	R6-риг: основа ВСЕХ башен и врагов.

	Интеграция с вашим Dummy: положите модель в ReplicatedStorage.Assets.R6Dummy
	(стандартная R6-структура: HumanoidRootPart, Torso, Head, Left/Right Arm, Left/Right Leg,
	Motor6D RootJoint/Neck/Left Shoulder/Right Shoulder/Left Hip/Right Hip). Тогда все
	башни и враги строятся из её клона: сохраняются пропорции, меши, лицо и Humanoid.
	Если модели нет — собирается процедурный риг с классическими R6-размерами и суставами
	(те же C0/C1, что у стандартного персонажа Roblox).

	Ориентация: модель смотрит по -Z (LookVector), ноги стоят на Y = 0, HumanoidRootPart на Y = 3.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local R6 = {}

-- Классический облик из референса (жёлтая кожа, синий торс, зелёные ноги)
R6.Skin = Color3.fromRGB(245, 205, 48)
R6.ReferenceColors = {
	Head = R6.Skin,
	Torso = Color3.fromRGB(13, 105, 172),
	LeftArm = R6.Skin,
	RightArm = R6.Skin,
	LeftLeg = Color3.fromRGB(164, 189, 71),
	RightLeg = Color3.fromRGB(164, 189, 71),
}

R6.PartNames = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local COLOR_KEYS = {
	Head = "Head", Torso = "Torso", ["Left Arm"] = "LeftArm", ["Right Arm"] = "RightArm",
	["Left Leg"] = "LeftLeg", ["Right Leg"] = "RightLeg",
}

-- Стандартные суставы R6
R6.Joints = {
	RootJoint = { Parent = "HumanoidRootPart", Part0 = "HumanoidRootPart", Part1 = "Torso",
		C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0), C1 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0) },
	Neck = { Parent = "Torso", Part0 = "Torso", Part1 = "Head",
		C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0), C1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0) },
	["Right Shoulder"] = { Parent = "Torso", Part0 = "Torso", Part1 = "Right Arm",
		C0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), C1 = CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	["Left Shoulder"] = { Parent = "Torso", Part0 = "Torso", Part1 = "Left Arm",
		C0 = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), C1 = CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	["Right Hip"] = { Parent = "Torso", Part0 = "Torso", Part1 = "Right Leg",
		C0 = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), C1 = CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	["Left Hip"] = { Parent = "Torso", Part0 = "Torso", Part1 = "Left Leg",
		C0 = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), C1 = CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
}
R6.JointOrder = { "RootJoint", "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" }

local SIZES = {
	HumanoidRootPart = Vector3.new(2, 2, 1),
	Torso = Vector3.new(2, 2, 1),
	Head = Vector3.new(2, 1, 1),
	["Left Arm"] = Vector3.new(1, 2, 1),
	["Right Arm"] = Vector3.new(1, 2, 1),
	["Left Leg"] = Vector3.new(1, 2, 1),
	["Right Leg"] = Vector3.new(1, 2, 1),
}

export type Rig = {
	Model: Model,
	Root: BasePart,
	Parts: { [string]: BasePart },
	Joints: { [string]: Motor6D },
}

local function part(name: string, model: Model): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = SIZES[name]
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = model
	return p
end

local function proceduralRig(withHumanoid: boolean): Model
	local model = Instance.new("Model")
	model.Name = "R6"
	local root = part("HumanoidRootPart", model)
	root.Transparency = 1
	root.Anchored = true
	for _, name in R6.PartNames do
		part(name, model)
	end
	local head = model:FindFirstChild("Head") :: Part
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	for _, jointName in R6.JointOrder do
		local def = R6.Joints[jointName]
		local motor = Instance.new("Motor6D")
		motor.Name = jointName
		motor.Part0 = model:FindFirstChild(def.Part0) :: BasePart
		motor.Part1 = model:FindFirstChild(def.Part1) :: BasePart
		motor.C0 = def.C0
		motor.C1 = def.C1
		motor.Parent = model:FindFirstChild(def.Parent)
	end
	if withHumanoid then
		local humanoid = Instance.new("Humanoid")
		humanoid.RigType = Enum.HumanoidRigType.R6
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.Parent = model
	end
	model.PrimaryPart = root
	return model
end

-- Ваш Dummy, если он есть и имеет корректную структуру
local function userDummy(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local dummy = assets and assets:FindFirstChild("R6Dummy")
	if not dummy or not dummy:IsA("Model") then
		return nil
	end
	for _, name in { "HumanoidRootPart", "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		if not dummy:FindFirstChild(name) then
			warn("[R6] Assets.R6Dummy is not a valid R6 rig (missing " .. name .. "), using the built-in rig")
			return nil
		end
	end
	return dummy
end

local function findJoint(model: Model, name: string): Motor6D?
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == name then
			return d
		end
	end
	return nil
end

export type BuildOptions = {
	Colors: { [string]: Color3 }?,
	Humanoid: boolean?,
	Name: string?,
}

-- Строит R6-модель и раскладывает части по суставам (до сварки снаряжения)
function R6.Build(options: BuildOptions?): Rig
	local opts = options or {}
	local template = userDummy()
	local model
	if template then
		model = template:Clone()
		for _, d in model:GetDescendants() do
			-- Скрипты из ассета не запускаем; одежда, аксессуары и BodyColors убираются:
			-- облик башен задаёт игра (чистое R6-тело + оружие), а BodyColors перекрасил бы части
			if d:IsA("LuaSourceContainer") or d:IsA("Accoutrement") or d:IsA("Clothing") or d:IsA("ShirtGraphic")
				or d:IsA("BodyColors") or d:IsA("CharacterMesh") then
				d:Destroy()
			end
		end
		if not opts.Humanoid then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:Destroy()
			end
		end
	else
		model = proceduralRig(opts.Humanoid ~= false)
	end
	model.Name = opts.Name or "R6"

	local parts = {}
	for _, name in { "HumanoidRootPart", "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		local p = model:FindFirstChild(name) :: BasePart
		p.Anchored = name == "HumanoidRootPart"
		p.CanCollide = false
		p.CanTouch = false
		p.Massless = true
		parts[name] = p
	end
	local colors = opts.Colors or R6.ReferenceColors
	for name, key in COLOR_KEYS do
		if colors[key] then
			parts[name].Color = colors[key]
		end
	end
	-- Убираем одежду-шаблон, если она есть у ассета: цвет задаёт облик
	for _, d in model:GetChildren() do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end

	local joints = {}
	for _, jointName in R6.JointOrder do
		local motor = findJoint(model, jointName)
		if motor then
			joints[jointName] = motor
			motor:SetAttribute("BaseC0", motor.C0)
		end
	end
	model.PrimaryPart = parts.HumanoidRootPart
	parts.HumanoidRootPart.CFrame = CFrame.new(0, 3, 0)
	R6.Solve(parts, joints)
	return { Model = model, Root = parts.HumanoidRootPart, Parts = parts, Joints = joints }
end

-- Расставляет части по текущим C0/C1 (нужно до сварки снаряжения)
function R6.Solve(parts: { [string]: BasePart }, joints: { [string]: Motor6D })
	for _, jointName in R6.JointOrder do
		local motor = joints[jointName]
		if motor and motor.Part0 and motor.Part1 then
			motor.Part1.CFrame = motor.Part0.CFrame * motor.C0 * motor.C1:Inverse()
		end
	end
end

-- «Запекает» позу в C0 (поза держания оружия видна всем без анимации)
function R6.BakePose(rig: Rig, pose: { [string]: CFrame })
	for jointName, transform in pose do
		local motor = rig.Joints[jointName]
		if motor then
			local base = motor:GetAttribute("BaseC0") or motor.C0
			motor.C0 = base * transform
			motor:SetAttribute("PoseC0", motor.C0)
		end
	end
	R6.Solve(rig.Parts, rig.Joints)
end

-- Приваривает деталь к части тела с сохранением текущего положения
function R6.Attach(rig: Rig, partName: string, piece: BasePart)
	local target = rig.Parts[partName]
	piece.Anchored = false
	piece.CanCollide = false
	piece.CanTouch = false
	piece.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = target
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = rig.Model
end

--[[
	Прикрепляет оружие к руке через Motor6D. weapon — модель, у которой PrimaryPart (Handle)
	стоит в точке хвата, «вперёд» — -Z, «вверх» — +Y. desired — где должно оказаться
	оружие относительно торса в текущей (запечённой) позе. C0 вычисляется из позы,
	поэтому оружие корректно следует за рукой во всех анимациях.
]]
function R6.Grip(rig: Rig, armName: string, weapon: Model, desired: CFrame): Motor6D
	local arm = rig.Parts[armName]
	local torso = rig.Parts.Torso
	local handle = weapon.PrimaryPart :: BasePart
	for _, d in weapon:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	local armInTorso = torso.CFrame:Inverse() * arm.CFrame
	local motor = Instance.new("Motor6D")
	motor.Name = "Grip_" .. weapon.Name
	motor.Part0 = arm
	motor.Part1 = handle
	motor.C0 = armInTorso:Inverse() * desired
	motor.C1 = CFrame.new()
	motor.Parent = arm
	weapon:PivotTo(torso.CFrame * desired)
	weapon.Parent = rig.Model
	return motor
end

-- Позиция кисти (низ руки) относительно торса в текущей позе
function R6.HandInTorso(rig: Rig, armName: string): CFrame
	local torso = rig.Parts.Torso
	local arm = rig.Parts[armName]
	return torso.CFrame:Inverse() * arm.CFrame * CFrame.new(0, -1, 0)
end

-- Сварка всех деталей модели-оружия с её PrimaryPart
function R6.WeldModel(model: Model)
	local root = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
end

return R6
