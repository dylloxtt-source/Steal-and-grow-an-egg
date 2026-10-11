--[[
	Превью моделей во ViewportFrame (яйца и существа) для карточек UI.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EggModel = require(Shared.Visual.EggModel)
local CreatureModel = require(Shared.Visual.CreatureModel)

local Preview = {}

local function frame(model: Model, parent: Instance, size: UDim2, position: UDim2?, silhouette: boolean?): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = size
	viewport.Position = position or UDim2.new()
	viewport.Ambient = Color3.fromRGB(170, 170, 180)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -1.5, -1)

	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif silhouette and d:IsA("BasePart") then
			d.Color = Color3.fromRGB(20, 20, 26)
			d.Material = Enum.Material.SmoothPlastic
			d.Reflectance = 0
		end
	end
	local cf, extents = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() - cf.Position)
	model.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local radius = extents.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	local direction = Vector3.new(0.6, 0.35, -1).Unit
	camera.CFrame = CFrame.lookAt(direction * distance, Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Parent = parent
	return viewport
end

function Preview.Egg(eggId: string, parent: Instance, size: UDim2, position: UDim2?): ViewportFrame
	return frame(EggModel.Build(eggId, 1), parent, size, position)
end

function Preview.Creature(speciesId: string, options: any?, parent: Instance, size: UDim2, position: UDim2?, silhouette: boolean?): ViewportFrame
	local opts = options or {}
	local model = CreatureModel.Build(speciesId, {
		Stage = opts.Stage or "Adult",
		Mutation = opts.Mutation,
		Size = 1,
	})
	return frame(model, parent, size, position, silhouette)
end

return Preview
