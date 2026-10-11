--[[
	Размещение башен: прозрачный призрак, зелёный/красный цвет, радиус атаки,
	причина запрета. Проверка — та же функция Logic/Placement, что на сервере,
	поэтому подсказка совпадает с решением сервера (а сервер всё равно проверяет сам).

	ПК: мышь двигает призрак, ЛКМ — поставить (Shift — поставить ещё), ПКМ/Q/Esc — отмена.
	Телефон: тап/перетаскивание по полю двигает призрак, кнопки «Поставить» / «Отмена».
	Точка на поле — пересечение луча камеры с плоскостью земли (без физики).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Config.Towers)
local Placement = require(Shared.Logic.Placement)
local TowerModel = require(Shared.Visual.TowerModel)

local State = require(script.Parent.Parent.State)
local Sound = require(script.Parent.Sound)

local PlacementController = {}

PlacementController.Changed = Instance.new("BindableEvent") -- (active, valid, reason)

local current: any = nil
local touchPoint: Vector2? = nil

local GREEN = Color3.fromRGB(80, 230, 120)
local RED = Color3.fromRGB(255, 80, 90)

local function matchFolder(): Instance?
	local id = Players.LocalPlayer:GetAttribute("MatchId")
	local active = workspace:FindFirstChild("ActiveMatches")
	return id and active and active:FindFirstChild("Match_" .. id)
end

function PlacementController.Footprints(folder: Instance, origin: Vector3): { { X: number, Z: number } }
	local list = {}
	local towersFolder = folder:FindFirstChild("Towers")
	if towersFolder then
		for _, model in towersFolder:GetChildren() do
			if model:IsA("Model") and model.PrimaryPart then
				local p = model.PrimaryPart.Position - origin
				table.insert(list, { X = p.X, Z = p.Z })
			end
		end
	end
	return list
end

function PlacementController.MyTowerCount(folder: Instance): number
	local count = 0
	local towersFolder = folder:FindFirstChild("Towers")
	if towersFolder then
		for _, model in towersFolder:GetChildren() do
			if model:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then
				count += 1
			end
		end
	end
	return count
end

function PlacementController.Active(): boolean
	return current ~= nil
end

function PlacementController.TowerId(): string?
	return current and current.TowerId
end

function PlacementController.Stop()
	if current then
		current.Ghost:Destroy()
		current.Ring:Destroy()
		current = nil
		PlacementController.Changed:Fire(false, false, nil)
	end
end

function PlacementController.Start(towerId: string)
	local folder = matchFolder()
	if not folder or not Towers.ById[towerId] then
		return
	end
	PlacementController.Stop()
	local def = Towers.ById[towerId]
	local ghost = TowerModel.Build(towerId, 1)
	ghost.Name = "PlacementGhost"
	for _, d in ghost:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanCollide = false
			d.CastShadow = false
			if d.Transparency < 1 then
				d.Transparency = 0.35
			end
		elseif d:IsA("Decal") then
			d.Transparency = 0.35
		end
	end
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = ghost
	ghost.Parent = workspace
	local ring = Instance.new("Part")
	ring.Name = "PlacementRange"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.78
	local range = def.Levels[1].Range
	ring.Size = Vector3.new(0.15, range * 2, range * 2)
	ring.Parent = workspace
	current = {
		TowerId = towerId,
		Def = def,
		Ghost = ghost,
		Highlight = highlight,
		Ring = ring,
		Folder = folder,
		Valid = false,
		Reason = nil :: string?,
		X = 0,
		Z = 0,
	}
	touchPoint = nil
	Sound.Play("Click")
end

-- Луч камеры: касание — экранные координаты (ScreenPointToRay учитывает отступ
-- верхней панели), мышь — координаты вьюпорта, иначе — центр экрана
local function cameraRay(): Ray
	local camera = workspace.CurrentCamera
	if touchPoint then
		return camera:ScreenPointToRay(touchPoint.X, touchPoint.Y)
	end
	if UserInputService.MouseEnabled then
		local mouse = UserInputService:GetMouseLocation()
		return camera:ViewportPointToRay(mouse.X, mouse.Y)
	end
	local center = camera.ViewportSize / 2
	return camera:ViewportPointToRay(center.X, center.Y)
end

local function update()
	if not current then
		return
	end
	local folder = current.Folder
	if not folder.Parent then
		PlacementController.Stop()
		return
	end
	local origin = folder:GetAttribute("Origin") :: Vector3
	local mapId = folder:GetAttribute("MapId") :: string
	local camera = workspace.CurrentCamera
	local ray = cameraRay()
	if math.abs(ray.Direction.Y) < 1e-3 then
		return
	end
	local t = (origin.Y - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return
	end
	local hit = ray.Origin + ray.Direction * t
	local x = math.floor((hit.X - origin.X) * 2 + 0.5) / 2
	local z = math.floor((hit.Z - origin.Z) * 2 + 0.5) / 2
	current.X, current.Z = x, z
	local ok, reason = Placement.Check(mapId, x, z, PlacementController.Footprints(folder, origin))
	local cost = current.Def.Levels[1].Cost
	if ok and State.Cash() < cost then
		ok, reason = false, "Недостаточно денег"
	end
	local match = State.Match
	if ok and match and PlacementController.MyTowerCount(folder) >= (match.towerLimit or 15) then
		ok, reason = false, "Достигнут лимит башен"
	end
	local changed = ok ~= current.Valid or reason ~= current.Reason
	current.Valid, current.Reason = ok, reason
	local world = origin + Vector3.new(x, 3, z)
	local look = Vector3.new(camera.CFrame.Position.X, world.Y, camera.CFrame.Position.Z)
	current.Ghost:PivotTo(if (look - world).Magnitude > 0.1 then CFrame.lookAt(world, look) else CFrame.new(world))
	current.Highlight.FillColor = if ok then GREEN else RED
	current.Highlight.OutlineColor = if ok then GREEN else RED
	current.Ring.Color = if ok then GREEN else RED
	current.Ring.CFrame = CFrame.new(origin + Vector3.new(x, 0.25, z)) * CFrame.Angles(0, 0, math.pi / 2)
	if changed then
		PlacementController.Changed:Fire(true, ok, reason)
	end
end

function PlacementController.Confirm()
	if not current then
		return
	end
	update()
	if not current.Valid then
		Sound.Play("Error")
		return
	end
	local towerId, x, z = current.TowerId, current.X, current.Z
	local keep = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
	State.Fire("PlaceTower", { tower = towerId, x = x, z = z }, function(ok)
		if ok and not keep then
			PlacementController.Stop()
		end
	end)
end

function PlacementController.Init()
	RunService.RenderStepped:Connect(update)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not current then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton2 then
			PlacementController.Stop()
			return
		end
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			PlacementController.Confirm()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			touchPoint = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if current and not processed and input.UserInputType == Enum.UserInputType.Touch then
			touchPoint = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("MatchId"):Connect(PlacementController.Stop)
end

return PlacementController
