--[[
	Превью моделей во ViewportFrame (иконки башен, врагов в коллекции).
	Модель строится тем же кодом, что и в игре, поэтому иконка совпадает с башней.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TowerModel = require(Shared.Visual.TowerModel)
local EnemyModel = require(Shared.Visual.EnemyModel)

local Preview = {}

local function frame(model: Model, parent: Instance, size: UDim2, position: UDim2?, focus: string?): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = size
	viewport.Position = position or UDim2.new()
	viewport.Ambient = Color3.fromRGB(160, 160, 170)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-0.6, -1, -0.8)
	for _, d in model:GetDescendants() do
		if d:IsA("PointLight") or d:IsA("ParticleEmitter") or d:IsA("Humanoid") then
			d:Destroy()
		end
	end
	model:PivotTo(CFrame.new(0, 3, 0))
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	local target = if focus == "upper" then Vector3.new(0, 4.2, 0) else Vector3.new(0, 3, 0)
	local distance = if focus == "upper" then 9 else 13
	camera.CFrame = CFrame.lookAt(target + Vector3.new(-0.45, 0.25, -1).Unit * distance, target)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Parent = parent
	return viewport
end

function Preview.Tower(towerId: string, level: number, parent: Instance, size: UDim2, position: UDim2?, focus: string?): ViewportFrame
	return frame(TowerModel.Build(towerId, level), parent, size, position, focus)
end

function Preview.Enemy(enemyId: string, parent: Instance, size: UDim2, position: UDim2?): ViewportFrame
	return frame(EnemyModel.Build(enemyId), parent, size, position, nil)
end

return Preview
