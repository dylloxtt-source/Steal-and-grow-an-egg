--[[
	Выгрузка 3D-моделей башен (уровни 1, 3, 5) и врагов в JSON для tools/preview/models.js.
	Модели строятся тем же кодом, что и в игре (Visual/TowerModel, Visual/EnemyModel).
	Запуск:  lune run tools/preview/models.luau <папка>  &&  node tools/preview/models.js <папка>
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Engine = require("../../tests/sim/Engine")

local Enum = roblox.Enum
local Vector3 = roblox.Vector3

local outDir = process.args[1] or "preview-out"
if not fs.isDir(outDir) then
	fs.writeDir(outDir)
end

local realm = Engine.Realm(true)
local Shared = Engine.SharedNode
local Towers = realm.require(Shared.Config.Towers)
local Enemies = realm.require(Shared.Config.Enemies)
local TowerModel = realm.require(Shared.Visual.TowerModel)
local EnemyModel = realm.require(Shared.Visual.EnemyModel)

local function color(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

local function dumpModel(model, label: string, pivotOverride: any?)
	local pivot = pivotOverride or model:GetPivot()
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "HumanoidRootPart" then
			local local_ = pivot:ToObjectSpace(d.CFrame)
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = local_:GetComponents()
			local shape = "Block"
			if d:IsA("WedgePart") then
				shape = "Wedge"
			elseif d:IsA("CornerWedgePart") then
				shape = "Wedge"
			elseif d:IsA("Part") then
				shape = d.Shape.Name
			end
			local size = d.Size
			local mesh = d:FindFirstChildOfClass("SpecialMesh")
			if mesh and mesh.MeshType == Enum.MeshType.Head then
				shape = "Head"
				size = Vector3.new(1.25, 1.25, 1.25)
			end
			table.insert(parts, {
				n = d.Name, s = shape, size = { size.X, size.Y, size.Z },
				m = { x, y + (if pivotOverride then 0 else 3), z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
				c = color(d.Color), t = d.Transparency, neon = d.Material == Enum.Material.Neon,
			})
		end
	end
	return { label = label, parts = parts }
end

local towers = {}
for _, def in Towers.List do
	for _, level in { 1, 3, 5 } do
		table.insert(towers, dumpModel(TowerModel.Build(def.Id, level), string.format("%s L%d", def.Name, level)))
	end
end
fs.writeFile(outDir .. "/towers.models.json", serde.encode("json", towers))

local enemies = {}
for _, def in Enemies.List do
	table.insert(enemies, dumpModel(EnemyModel.Build(def.Id), def.Name))
end
fs.writeFile(outDir .. "/enemies.models.json", serde.encode("json", enemies))
-- Карты (вид с камеры обзора) и лобби
local Maps = realm.require(Shared.Config.Maps)
local MapBuilder = realm.require(Engine.ServerNode.Match.MapBuilder)
local maps = {}
for _, map in Maps.List do
	local container = roblox.Instance.new("Folder")
	local folder = MapBuilder.Build(map.Id, Vector3.new(0, 0, 0), container)
	local entry = dumpModel(folder, map.Name, roblox.CFrame.new())
	entry.eye = { map.Camera.Position.X, map.Camera.Position.Y, map.Camera.Position.Z }
	entry.target = { map.Camera.LookAt.X, map.Camera.LookAt.Y, map.Camera.LookAt.Z }
	entry.path = {}
	for _, point in map.Waypoints do
		table.insert(entry.path, { point.X, point.Z })
	end
	table.insert(maps, entry)
end
fs.writeFile(outDir .. "/maps.models.json", serde.encode("json", maps))

local server = Engine.Realm(true)
server.require(Engine.ServerNode)
local lobby = dumpModel(Engine.Workspace:FindFirstChild("Lobby"), "Лобби", roblox.CFrame.new())
lobby.eye = { 0, 70, 95 }
lobby.target = { 0, 0, 0 }
fs.writeFile(outDir .. "/lobby.models.json", serde.encode("json", { lobby }))
print("models", #towers, #enemies, #maps)
process.exit(0)
