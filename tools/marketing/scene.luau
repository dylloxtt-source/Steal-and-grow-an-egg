--[[
	Сцена для обложки: карта Greenfield, башни и враги — те же модели, что в игре.
	Выгружает детали в JSON для tools/marketing/thumbnail.js.
	Запуск:  lune run tools/marketing/scene.luau <папка>  &&  node tools/marketing/thumbnail.js <папка>
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

local function color(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

local parts = {}
local function addPart(d, scaleAround: any?, scale: number?)
	if not d:IsA("BasePart") or d.Transparency >= 0.95 or d.Name == "HumanoidRootPart" or d.Name == "Boundary" then
		return
	end
	local cf = d.CFrame
	local size = d.Size
	if scaleAround and scale then
		local offset = cf.Position - scaleAround
		cf = (cf - cf.Position) + (scaleAround + offset * scale)
		size = size * scale
	end
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local shape = "Block"
	if d:IsA("WedgePart") or d:IsA("CornerWedgePart") then
		shape = "Wedge"
	elseif d:IsA("Part") then
		shape = d.Shape.Name
	end
	local mesh = d:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Head then
		shape = "Head"
		size = Vector3.new(1.25, 1.25, 1.25) * (scale or 1)
	end
	table.insert(parts, {
		s = shape, size = { size.X, size.Y, size.Z }, m = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
		c = color(d.Color), t = d.Transparency, neon = d.Material == Enum.Material.Neon,
		studs = d.TopSurface == Enum.SurfaceType.Studs, flat = (cf.Position.Y + size.Y / 2) < 0.6,
	})
end

-- Карта
local container = roblox.Instance.new("Folder")
local map = MapBuilder.Build("greenfield", Vector3.new(0, 0, 0), container)
for _, d in map:GetDescendants() do
	-- Декор у самой камеры загораживает кадр — пропускаем (земля и дорога остаются)
	local nearCamera = d:IsA("BasePart") and d.CFrame.Position.Z > 38 and d.CFrame.Position.Y + d.Size.Y / 2 > 0.6
	if not nearCamera then
		addPart(d)
	end
end
local path = MapLayout.Get("greenfield").Path

-- Башни вдоль дороги (z = 22 — горизонтальный участок перед камерой)
local towers = {
	{ "swordsman", 5, Vector3.new(-30, 0, 29) },
	{ "wolverine", 5, Vector3.new(-18, 0, 29.5) },
	{ "lumberjack", 5, Vector3.new(-7, 0, 29) },
	{ "archer", 5, Vector3.new(-25, 0, 13) },
	{ "minigunner", 4, Vector3.new(-12, 0, 13.5) },
	{ "sniper", 5, Vector3.new(8, 0, 30) },
	{ "toxic", 4, Vector3.new(8, 0, 12) },
	{ "pistol", 5, Vector3.new(-42, 0, 32) },
}
local shots = {}
for _, entry in towers do
	local model = TowerModel.Build(entry[1], entry[2])
	local base = entry[3] + Vector3.new(0, 3, 0)
	local target = Vector3.new(entry[3].X + (if entry[3].Z > 22 then 3 else -3), 3, 22)
	if entry[1] == "toxic" then
		target = Vector3.new(0, 4, 14)
	end
	model:PivotTo(lookAt(base, target))
	for _, d in model:GetDescendants() do
		addPart(d)
	end
	local muzzle = nil
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "Muzzle" and d.Parent and d.Parent:IsA("BasePart") then
			local p = (d.Parent.CFrame * d.CFrame).Position
			muzzle = { p.X, p.Y, p.Z }
		end
	end
	table.insert(shots, { tower = entry[1], from = muzzle or { base.X, base.Y + 1, base.Z }, to = { target.X, target.Y, target.Z } })
end

-- Враги на дороге и босс на повороте
local enemies = {}
local function placeEnemy(enemyId: string, distance: number, hp: number)
	local def = Enemies.ById[enemyId]
	local model = EnemyModel.Build(enemyId)
	local position, direction = path:At(distance)
	local scale = def.Scale
	local root = position + Vector3.new(0, 3 * scale, 0)
	model:PivotTo(lookAt(root, root + direction))
	local pivot = model:GetPivot().Position
	for _, d in model:GetDescendants() do
		addPart(d, pivot, scale)
	end
	table.insert(enemies, { name = def.Name, boss = def.Boss == true, elite = def.Elite == true, hp = hp,
		at = { root.X, root.Y + 2.4 * scale, root.Z } })
end
local function distanceAt(x: number, z: number): number
	local best, bestGap = 0, math.huge
	local d = 0
	while d <= path.Length do
		local gap = (path:At(d) - Vector3.new(x, 0, z)).Magnitude
		if gap < bestGap then
			best, bestGap = d, gap
		end
		d += 0.5
	end
	return best
end
placeEnemy("basic", distanceAt(-36, 22), 0.35)
placeEnemy("runner", distanceAt(-29, 22), 0.8)
placeEnemy("armored", distanceAt(-21, 22), 0.55)
placeEnemy("shielded", distanceAt(-13, 22), 0.9)
placeEnemy("elite", distanceAt(-6, 22), 0.6)
placeEnemy("boss_brute", distanceAt(0, 14), 0.7)

fs.writeFile(outDir .. "/scene.json", serde.encode("json", { parts = parts, shots = shots, enemies = enemies }))
print("parts", #parts)
process.exit(0)
