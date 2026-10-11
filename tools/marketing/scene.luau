--[[
	Сцена для обложки и иконки: карта Snow Valley, башни и враги — те же модели, что в игре.
	Враги «в шаге», босс замахивается мечом (детали конечностей поворачиваются вокруг суставов R6
	вместе со всем, что к ним приварено). Выгружает детали и источники света в JSON
	для tools/marketing/render.js.
	Запуск:  lune run tools/marketing/scene.luau <папка>
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Engine = require("../../tests/sim/Engine")

local Enum = roblox.Enum
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local lookAt = Engine.LookAt

local outDir = process.args[1] or "marketing-out"
if not fs.isDir(outDir) then
	fs.writeDir(outDir)
end

local realm = Engine.Realm(true)
local Shared = Engine.SharedNode
local TowerModel = realm.require(Shared.Visual.TowerModel)
local EnemyModel = realm.require(Shared.Visual.EnemyModel)
local Enemies = realm.require(Shared.Config.Enemies)
local MapBuilder = realm.require(Engine.ServerNode.Match.MapBuilder)
local MapLayout = realm.require(Shared.Logic.MapLayout)

local MAP = "snow"

local function color(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

local parts = {}
local lights = {}

local function addPart(d, cf, size, tag: string?)
	if not d:IsA("BasePart") or d.Transparency >= 0.95 or d.Name == "HumanoidRootPart" or d.Name == "Boundary" then
		return
	end
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local shape = "Block"
	if d:IsA("WedgePart") then
		shape = "Wedge"
	elseif d:IsA("CornerWedgePart") then
		shape = "CornerWedge"
	elseif d:IsA("Part") then
		shape = d.Shape.Name
	end
	local face = false
	local mesh = d:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Head then
		shape = "Head"
		face = d:FindFirstChild("face") ~= nil
	end
	table.insert(parts, {
		s = shape, size = { size.X, size.Y, size.Z }, m = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
		c = color(d.Color), t = d.Transparency, mat = d.Material.Name, refl = d.Reflectance,
		studs = d.TopSurface == Enum.SurfaceType.Studs, face = face, name = d.Name, tag = tag,
	})
end

local function addLights(model: Instance, scaleAround: Vector3?, scale: number?)
	for _, d in model:GetDescendants() do
		if d:IsA("PointLight") and d.Parent and d.Parent:IsA("BasePart") then
			local p = d.Parent.CFrame.Position
			if scaleAround and scale then
				p = scaleAround + (p - scaleAround) * scale
			end
			table.insert(lights, { p = { p.X, p.Y, p.Z }, c = color(d.Color), range = d.Range * (scale or 1), b = d.Brightness })
		end
	end
end

-- Карта
local container = roblox.Instance.new("Folder")
local map = MapBuilder.Build(MAP, Vector3.new(0, 0, 0), container)
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		addPart(d, d.CFrame, d.Size, "map")
	end
end
addLights(map)
local path = MapLayout.Get(MAP).Path

--[[
	Поза без физики: каждая деталь модели относится к части тела R6, к которой она приварена
	(через WeldConstraint/Motor6D оружия). Поворот конечности = поворот вокруг её сустава
	(C0 в торсе) на угол вокруг оси Z сустава — как Motor6D.Transform в игре.
]]
local LIMBS = { ["Head"] = "Neck", ["Left Arm"] = "Left Shoulder", ["Right Arm"] = "Right Shoulder",
	["Left Leg"] = "Left Hip", ["Right Leg"] = "Right Hip" }
local CORE = { Torso = true, HumanoidRootPart = true }

-- В Lune один и тот же инстанс может приходить разными обёртками, поэтому ключи — номера-атрибуты
local function idOf(part: Instance): number
	return part:GetAttribute("_mk") :: number
end

local function limbOf(model: Model): { [number]: string }
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			d:SetAttribute("_mk", n)
		end
	end
	local edges: { [number]: { Instance } } = {}
	local function link(a, b)
		local ia, ib = idOf(a), idOf(b)
		if ia and ib then
			edges[ia] = edges[ia] or {}
			edges[ib] = edges[ib] or {}
			table.insert(edges[ia], b)
			table.insert(edges[ib], a)
		end
	end
	for _, d in model:GetDescendants() do
		if (d:IsA("WeldConstraint") or d:IsA("Motor6D") or d:IsA("Weld")) and d.Part0 and d.Part1 then
			local core0 = CORE[d.Part0.Name] or LIMBS[d.Part0.Name]
			local core1 = CORE[d.Part1.Name] or LIMBS[d.Part1.Name]
			if not (core0 and core1 and d.Part0.Parent == model and d.Part1.Parent == model) then
				link(d.Part0, d.Part1)
			end
		end
	end
	local owner: { [number]: string } = {}
	for limbName in LIMBS do
		local limb = model:FindFirstChild(limbName)
		if limb then
			owner[idOf(limb)] = limbName
			local queue = { limb }
			while #queue > 0 do
				local node = table.remove(queue)
				for _, other in edges[idOf(node)] or {} do
					local isBody = other.Parent == model and (CORE[other.Name] or LIMBS[other.Name])
					if not owner[idOf(other)] and not isBody then
						owner[idOf(other)] = limbName
						table.insert(queue, other)
					end
				end
			end
		end
	end
	return owner
end

-- pose: { [limbName] = CFrame в системе сустава }; scale — масштаб вокруг опоры модели (боссы)
local function emitModel(model: Model, pose: { [string]: CFrame }?, scale: number?, tag: string)
	local pivot = model:GetPivot().Position
	local owner = limbOf(model)
	local torso = model:FindFirstChild("Torso") :: BasePart
	local jointWorld = {}
	if pose and torso then
		for limbName, jointName in LIMBS do
			local motor = torso:FindFirstChild(jointName)
			if motor and pose[limbName] then
				jointWorld[limbName] = torso.CFrame * motor.C0
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf = d.CFrame
			local limbName = owner[idOf(d)]
			if limbName and jointWorld[limbName] then
				local j = jointWorld[limbName]
				cf = j * pose[limbName] * j:Inverse() * cf
			end
			local size = d.Size
			if scale then
				cf = (cf - cf.Position) + (pivot + (cf.Position - pivot) * scale)
				size = size * scale
			end
			addPart(d, cf, size, tag)
		end
	end
	addLights(model, pivot, scale)
end

local function distanceAt(x: number, z: number): number
	local best, bestGap = 0, math.huge
	local d = 0
	while d <= path.Length do
		local gap = (path:At(d) - Vector3.new(x, 0, z)).Magnitude
		if gap < bestGap then
			best, bestGap = d, gap
		end
		d += 0.25
	end
	return best
end

local A = CFrame.Angles
local function walk(phase: number, amount: number?): { [string]: CFrame }
	local a = (amount or 0.65) * math.sin(phase)
	return { ["Left Leg"] = A(0, 0, a), ["Right Leg"] = A(0, 0, a), ["Left Arm"] = A(0, 0, -a * 0.7),
		["Right Arm"] = A(0, 0, -a * 0.7) }
end

-- Враги идут по прямому участку дороги к камере (z = -48, движение по +X).
-- В эмуляторе нет Model:ScaleTo, поэтому крупные враги масштабируются при выгрузке вокруг опоры.
local enemies = {}
local function placeScaled(enemyId: string, x: number, side: number, phase: number, extraPose)
	local def = Enemies.ById[enemyId]
	local model = EnemyModel.Build(enemyId)
	local position, direction = path:At(distanceAt(x, -48))
	local root = position + Vector3.new(0, 3, side)
	model:PivotTo(lookAt(root, root + direction))
	local pose = walk(phase, 0.45)
	for k, v in extraPose or {} do
		pose[k] = v
	end
	-- опора модели — HumanoidRootPart (центр торса, 3 стада над землёй): после масштаба поднимаем
	local scale = def.Scale
	model:PivotTo(model:GetPivot() + Vector3.new(0, 3 * scale - 3, 0))
	emitModel(model, pose, scale, "enemy:" .. enemyId)
	table.insert(enemies, { id = enemyId, name = def.Name, boss = def.Boss == true,
		at = { root.X, 3 * scale + 2.6 * scale, root.Z } })
end
-- Финальный босс замахивается двуручным мечом, рыцарь и элита — по бокам
placeScaled("boss_warlord", 14, 0, 0.3, { ["Right Arm"] = A(0, 0, 1.05), ["Left Arm"] = A(0, 0, -0.6) })
placeScaled("boss_juggernaut", -30, 1.5, 1.2)
placeScaled("elite", 24, -3.4, 1.0)
placeScaled("armored", 27, 3.4, 2.4)
placeScaled("runner", 33, 2.6, 3.6)
placeScaled("shielded", 30, -3.0, 0.4)
placeScaled("basic", 19, -3.8, 2.0)
placeScaled("tank", 8, 4.0, 0.8)
placeScaled("armored", 3, -3.2, 0.2)
placeScaled("basic", -4, 1.0, 2.9)
placeScaled("basic", -14, -2.0, 1.4)

-- Башни: на переднем плане по бокам дороги и вдоль неё
local towers = {}
local function placeTower(towerId: string, level: number, x: number, z: number, aimAt: Vector3, pose, stage: string?)
	local model = TowerModel.Build(towerId, level)
	local base = Vector3.new(x, 3, z)
	local aim = Vector3.new(aimAt.X, 3, aimAt.Z)
	model:PivotTo(lookAt(base, aim))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Pedestal" then
			d.Transparency = 1
		end
	end
	emitModel(model, pose, nil, "tower:" .. towerId)
	local muzzles = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "Muzzle" and d.Parent and d.Parent:IsA("BasePart") then
			local p = (d.Parent.CFrame * d.CFrame).Position
			table.insert(muzzles, { p.X, p.Y, p.Z })
		end
	end
	table.insert(towers, { id = towerId, level = level, at = { x, 3, z }, aim = { aimAt.X, aimAt.Y, aimAt.Z }, muzzles = muzzles,
		stage = stage })
end

placeTower("minigunner", 5, 45.5, -43.2, Vector3.new(34, 3, -47.5))
placeTower("sniper", 5, 47, -53.9, Vector3.new(16, 3, -49))
placeTower("wolverine", 5, 29.5, -54, Vector3.new(24, 3, -51.4), { ["Right Leg"] = A(0, 0, 0.35), ["Left Leg"] = A(0, 0, -0.25) })
placeTower("swordsman", 5, 37, -42, Vector3.new(33, 3, -45.4))
placeTower("toxic", 5, 21, -40.5, Vector3.new(14, 3, -44))
placeTower("archer", 5, 16, -57, Vector3.new(8, 3, -50))
placeTower("lumberjack", 5, 7, -39, Vector3.new(3, 3, -44))
placeTower("pistol", 5, 40, -58.5, Vector3.new(24, 3, -51))
-- Отдельная постановка для иконки — за спиной камеры обложки (в кадр обложки не попадает)
placeTower("wolverine", 5, 66, -27, Vector3.new(58, 3, -29.5), {
	["Right Arm"] = A(0, 0, 1.15), ["Left Arm"] = A(0, 0, -0.95), ["Right Leg"] = A(0, 0, 0.3), ["Left Leg"] = A(0, 0, -0.2),
}, "icon")

fs.writeFile(outDir .. "/scene.json", serde.encode("json", { parts = parts, lights = lights, towers = towers, enemies = enemies,
	path = { -82, -48, 56, -48 } }))
print("parts", #parts, "lights", #lights)
process.exit(0)
