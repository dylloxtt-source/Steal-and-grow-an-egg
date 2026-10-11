--[[
	PlotService — шесть баз игроков. Геометрия строится один раз при старте,
	при входе игрок получает свободную базу, при выходе база очищается.

	Динамика (яйца, существа, урожай) рисуется профильными сервисами, а
	PlotService даёт им ссылки на слоты и общие атрибуты для клиента:
	  Incubator (тег) — Slot, OwnerId, State, EggId, StartedAt, Duration
	  FarmPlot  (тег) — Slot, OwnerId, State, Seed, PlantedAt, ReadyAt
	  Plot model      — OwnerId, OwnerName, Vault, LockedUntil, LockCooldownUntil, ProtectedUntil
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Map = require(Shared.Config.Map)
local Studs = require(Shared.Visual.Studs)

local PlotService = {}

local services
local plots = {}
local WOOD = Color3.fromRGB(150, 95, 50)
local SOIL = Color3.fromRGB(110, 70, 40)
local LOCKED = Color3.fromRGB(120, 120, 128)

local function makePrompt(parent: Instance, action: string, object: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function fenceLine(parent: Instance, from: Vector3, to: Vector3, height: number)
	local delta = to - from
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local dir = delta.Unit
	local posts = math.max(1, math.floor(length / 6))
	for i = 0, posts do
		Studs.Ground(parent, Vector3.new(1, height, 1), from + dir * (length * i / posts), WOOD, { Name = "Post" })
	end
	local mid = from + delta / 2
	local cf = CFrame.lookAt(mid, mid + dir)
	for _, y in { height * 0.35, height * 0.8 } do
		Studs.Block(parent, Vector3.new(0.5, 0.6, length), cf + Vector3.new(0, y, 0), Color3.fromRGB(170, 70, 50), { Name = "Rail" })
	end
end

local function surfaceLabel(part: BasePart, face: Enum.NormalId, text: string): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Parent = label
	return label
end

local function buildPlot(index: number)
	local center = Map.PlotCenters[index]
	local color = Map.PlotColors[index]
	local layout = Map.PlotLayout
	local half = Map.PlotSize / 2
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerId", 0)

	local function world(v: Vector3): Vector3
		return center + v
	end

	-- Цветная рамка базы
	for _, edge in {
		{ Vector3.new(0, 0, -half), Vector3.new(Map.PlotSize, 0.3, 1.5) },
		{ Vector3.new(0, 0, half), Vector3.new(Map.PlotSize, 0.3, 1.5) },
		{ Vector3.new(-half, 0, 0), Vector3.new(1.5, 0.3, Map.PlotSize) },
		{ Vector3.new(half, 0, 0), Vector3.new(1.5, 0.3, Map.PlotSize) },
	} do
		Studs.Ground(model, edge[2], world(edge[1]), color, { Name = "Border", Material = Enum.Material.Neon, Studs = false })
	end

	-- Забор с проходом по центру передней стороны
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = model
	local gap = layout.EntranceHalfWidth
	local inset = half - 1.5
	fenceLine(fence, world(Vector3.new(-inset, 0, -inset)), world(Vector3.new(inset, 0, -inset)), 3.4)
	fenceLine(fence, world(Vector3.new(-inset, 0, -inset)), world(Vector3.new(-inset, 0, inset)), 3.4)
	fenceLine(fence, world(Vector3.new(inset, 0, -inset)), world(Vector3.new(inset, 0, inset)), 3.4)
	fenceLine(fence, world(Vector3.new(-inset, 0, inset)), world(Vector3.new(-gap, 0, inset)), 3.4)
	fenceLine(fence, world(Vector3.new(gap, 0, inset)), world(Vector3.new(inset, 0, inset)), 3.4)

	-- Табличка с именем владельца
	local signCf = CFrame.new(world(layout.Sign))
	for _, x in { -7, 7 } do
		Studs.Block(model, Vector3.new(1, 10, 1), signCf * CFrame.new(x, 5, 0), WOOD, { Name = "SignLeg" })
	end
	local board = Studs.Block(model, Vector3.new(16, 4, 0.8), signCf * CFrame.new(0, 9, 0), color, { Name = "SignBoard" })
	local signLabel = surfaceLabel(board, Enum.NormalId.Back, "FREE BASE")

	-- Загон
	local penMin, penMax = layout.PenMin, layout.PenMax
	local penSize = penMax - penMin
	local penCenter = (penMin + penMax) / 2
	Studs.Block(model, Vector3.new(penSize.X, 0.2, penSize.Z), CFrame.new(world(penCenter) + Vector3.new(0, 0.1, 0)),
		Color3.fromRGB(130, 225, 90), { Name = "PenFloor" })
	local penFence = Instance.new("Folder")
	penFence.Name = "PenFence"
	penFence.Parent = model
	local corners = {
		world(Vector3.new(penMin.X, 0, penMin.Z)), world(Vector3.new(penMax.X, 0, penMin.Z)),
		world(Vector3.new(penMax.X, 0, penMax.Z)), world(Vector3.new(penMin.X, 0, penMax.Z)),
	}
	for i = 1, 4 do
		fenceLine(penFence, corners[i], corners[i % 4 + 1], 2.2)
	end
	local trough = Studs.Ground(model, Vector3.new(6, 1.4, 2), world(Vector3.new(penMax.X - 5, 0, penMax.Z - 3)), WOOD, { Name = "Trough" })
	Studs.Block(model, Vector3.new(5.4, 0.3, 1.4), trough.CFrame + Vector3.new(0, 0.6, 0), Color3.fromRGB(230, 200, 110), { Name = "Feed" })
	local pen = Instance.new("Folder")
	pen.Name = "Creatures"
	pen.Parent = model

	-- Инкубаторы
	local incubators = {}
	for slot, localPos in layout.Incubators do
		local inc = Instance.new("Model")
		inc.Name = "Incubator" .. slot
		local base = world(localPos)
		local cf = CFrame.lookAt(base, base + Vector3.new(1, 0, 0))
		local basePart = Studs.Block(inc, Vector3.new(6, 1.2, 6), cf + Vector3.new(0, 0.6, 0), Color3.fromRGB(60, 60, 70), { Name = "Base" })
		local top = Studs.Block(inc, Vector3.new(5, 0.6, 5), cf + Vector3.new(0, 1.5, 0), color, { Name = "Top" })
		local dome = Studs.Block(inc, Vector3.new(4.4, 4.4, 4.4), cf + Vector3.new(0, 4, 0), Color3.fromRGB(200, 240, 255),
			{ Name = "Dome", Material = Enum.Material.Glass, CanCollide = false, Studs = false })
		dome.Transparency = 0.65
		local anchor = Studs.Block(inc, Vector3.new(1, 1, 1), cf + Vector3.new(0, 1.8, 0), Color3.new(),
			{ Name = "EggAnchor", Transparency = 1, CanCollide = false, Studs = false, CanQuery = false })
		inc.PrimaryPart = basePart
		inc:SetAttribute("Slot", slot)
		inc:SetAttribute("PlotIndex", index)
		inc:SetAttribute("OwnerId", 0)
		inc:SetAttribute("State", "locked")
		local ownerPrompt = makePrompt(top, "Incubate", "Incubator", 0)
		ownerPrompt.Name = "OwnerPrompt"
		ownerPrompt.Enabled = false
		local stealPrompt = makePrompt(top, "Steal", "Egg", 2)
		stealPrompt.Name = "StealPrompt"
		stealPrompt.KeyboardKeyCode = Enum.KeyCode.F
		stealPrompt.UIOffset = Vector2.new(0, 60)
		stealPrompt.Enabled = false
		inc.Parent = model
		CollectionService:AddTag(inc, "Incubator")
		incubators[slot] = { Model = inc, Top = top, Anchor = anchor, OwnerPrompt = ownerPrompt, StealPrompt = stealPrompt }

		ownerPrompt.Triggered:Connect(function(player)
			services.IncubatorService:OnOwnerPrompt(player, index, slot)
		end)
		stealPrompt.Triggered:Connect(function(player)
			services.StealService:OnStealPrompt(player, index, slot)
		end)
	end

	-- Грядки
	local farms = {}
	for slot, localPos in layout.Farms do
		local farm = Instance.new("Model")
		farm.Name = "Farm" .. slot
		local pos = world(localPos)
		local frame = Studs.Ground(farm, Vector3.new(7, 0.8, 7), pos, WOOD, { Name = "Frame" })
		local soil = Studs.Ground(farm, Vector3.new(6, 0.5, 6), pos + Vector3.new(0, 0.5, 0), SOIL, { Name = "Soil" })
		farm.PrimaryPart = frame
		farm:SetAttribute("Slot", slot)
		farm:SetAttribute("PlotIndex", index)
		farm:SetAttribute("OwnerId", 0)
		farm:SetAttribute("State", "locked")
		local prompt = makePrompt(soil, "Plant", "Garden", 0)
		prompt.Name = "OwnerPrompt"
		prompt.Enabled = false
		farm.Parent = model
		CollectionService:AddTag(farm, "FarmPlot")
		farms[slot] = { Model = farm, Soil = soil, Prompt = prompt }
		prompt.Triggered:Connect(function(player)
			services.FarmService:OnPrompt(player, index, slot)
		end)
	end

	-- Касса (копилка дохода)
	local vault = Studs.Ground(model, Vector3.new(7, 0.6, 7), world(layout.Vault), Color3.fromRGB(255, 194, 26), { Name = "VaultPad" })
	vault.Material = Enum.Material.Neon
	CollectionService:AddTag(vault, "Vault")
	vault:SetAttribute("PlotIndex", index)
	vault.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local plot = plots[index]
		if player and plot.Owner == player then
			services.CreatureService:CollectVault(player)
		end
	end)

	-- Кнопка замка базы
	local lockBase = Studs.Ground(model, Vector3.new(5, 1, 5), world(layout.Lock), Color3.fromRGB(60, 60, 70), { Name = "LockBase" })
	local lockButton = Studs.Ground(model, Vector3.new(3.6, 0.6, 3.6), world(layout.Lock) + Vector3.new(0, 1, 0), Color3.fromRGB(230, 50, 50), { Name = "LockButton" })
	CollectionService:AddTag(lockButton, "LockPad")
	lockButton:SetAttribute("PlotIndex", index)
	local lockPrompt = makePrompt(lockButton, "Lock Base", "🔒", 0)
	lockPrompt.Name = "OwnerPrompt"
	lockPrompt.Enabled = false
	lockPrompt.Triggered:Connect(function(player)
		services.StealService:LockBase(player)
	end)
	local _ = lockBase

	-- Силовое поле замка (визуал)
	local barrier = {}
	for _, edge in {
		{ Vector3.new(0, 0, -half), Vector3.new(Map.PlotSize, 14, 0.4) },
		{ Vector3.new(0, 0, half), Vector3.new(Map.PlotSize, 14, 0.4) },
		{ Vector3.new(-half, 0, 0), Vector3.new(0.4, 14, Map.PlotSize) },
		{ Vector3.new(half, 0, 0), Vector3.new(0.4, 14, Map.PlotSize) },
	} do
		local part = Studs.Ground(model, edge[2], world(edge[1]), color,
			{ Name = "Barrier", Material = Enum.Material.ForceField, CanCollide = false, Studs = false, CastShadow = false, CanQuery = false })
		part.Transparency = 1
		table.insert(barrier, part)
	end

	model.Parent = workspace:WaitForChild("Map")
	plots[index] = {
		Index = index,
		Model = model,
		Color = color,
		Owner = nil :: Player?,
		Incubators = incubators,
		Farms = farms,
		Pen = pen,
		PenMin = world(penMin) + Vector3.new(2, 0, 2),
		PenMax = world(penMax) - Vector3.new(2, 0, 2),
		Vault = vault,
		LockPrompt = lockPrompt,
		Barrier = barrier,
		SignLabel = signLabel,
	}
end

local function setOwnerAttributes(plot: any, userId: number)
	plot.Model:SetAttribute("OwnerId", userId)
	for _, inc in plot.Incubators do
		inc.Model:SetAttribute("OwnerId", userId)
		inc.OwnerPrompt:SetAttribute("OwnerOnly", userId)
		inc.StealPrompt:SetAttribute("NotOwner", userId)
	end
	for _, farm in plot.Farms do
		farm.Model:SetAttribute("OwnerId", userId)
		farm.Prompt:SetAttribute("OwnerOnly", userId)
	end
	plot.LockPrompt:SetAttribute("OwnerOnly", userId)
	plot.Vault:SetAttribute("OwnerId", userId)
end

function PlotService:GetPlot(index: number): any
	return plots[index]
end

function PlotService:GetPlotOf(player: Player): any?
	local session = services.DataService:GetSession(player)
	return session and session.Plot
end

function PlotService:PlotAt(position: Vector3): any?
	for index, plot in plots do
		if Map.InPlot(index, position) then
			return plot
		end
	end
	return nil
end

-- Видимость слотов в зависимости от улучшений
function PlotService:RefreshSlots(session: any)
	local plot = session.Plot
	if not plot then
		return
	end
	local upgrades = session.Profile.upgrades
	for slot, inc in plot.Incubators do
		local unlocked = slot <= upgrades.incubators
		inc.Top.Color = if unlocked then plot.Color else LOCKED
		inc.OwnerPrompt.Enabled = unlocked
		if not unlocked then
			inc.Model:SetAttribute("State", "locked")
			inc.StealPrompt.Enabled = false
		end
	end
	for slot, farm in plot.Farms do
		local unlocked = slot <= upgrades.farms
		farm.Soil.Color = if unlocked then SOIL else LOCKED
		farm.Prompt.Enabled = unlocked
		if not unlocked then
			farm.Model:SetAttribute("State", "locked")
		end
	end
	plot.LockPrompt.Enabled = true
end

function PlotService:SetBarrier(plot: any, active: boolean)
	for _, part in plot.Barrier do
		part.Transparency = if active then 0.55 else 1
	end
end

function PlotService:EntranceCFrame(plot: any): CFrame
	local pos = Map.PlotWorld(plot.Index, Map.PlotLayout.Delivery) + Vector3.new(0, 4, 0)
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
end

local function teleportHome(player: Player, character: Model)
	local session = services.DataService:GetSession(player)
	if not session or not session.Plot then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if root then
		task.wait(0.1)
		character:PivotTo(PlotService:EntranceCFrame(session.Plot))
	end
end

function PlotService:Init(registry)
	services = registry
end

function PlotService:Start()
	for index = 1, #Map.PlotCenters do
		buildPlot(index)
	end

	services.DataService:OnLoaded(function(player, session)
		local free
		for _, plot in plots do
			if plot.Owner == nil then
				free = plot
				break
			end
		end
		if not free then
			player:Kick("Сервер заполнен: все базы заняты. Зайдите на другой сервер.")
			return
		end
		free.Owner = player
		session.Plot = free
		setOwnerAttributes(free, player.UserId)
		free.Model:SetAttribute("OwnerName", player.DisplayName)
		free.SignLabel.Text = player.DisplayName .. "'s Base"
		PlotService:RefreshSlots(session)

		player.CharacterAdded:Connect(function(character)
			teleportHome(player, character)
		end)
		if player.Character then
			task.spawn(teleportHome, player, player.Character)
		end
	end)

	services.DataService:AddViewContributor(function(session, runtime)
		runtime.plotIndex = if session.Plot then session.Plot.Index else nil
	end)

	services.DataService:OnRemoving(function(_player, session)
		local plot = session.Plot
		if not plot then
			return
		end
		session.Plot = nil
		plot.Owner = nil
		setOwnerAttributes(plot, 0)
		plot.Model:SetAttribute("OwnerName", "")
		plot.Model:SetAttribute("Vault", 0)
		plot.Model:SetAttribute("LockedUntil", 0)
		plot.SignLabel.Text = "FREE BASE"
		PlotService:SetBarrier(plot, false)
		plot.Pen:ClearAllChildren()
		for _, inc in plot.Incubators do
			inc.Model:SetAttribute("State", "locked")
			inc.Model:SetAttribute("EggId", nil)
			inc.OwnerPrompt.Enabled = false
			inc.StealPrompt.Enabled = false
			local egg = inc.Model:FindFirstChild("Egg")
			if egg then
				egg:Destroy()
			end
		end
		for _, farm in plot.Farms do
			farm.Model:SetAttribute("State", "locked")
			farm.Prompt.Enabled = false
			local crop = farm.Model:FindFirstChild("Crop")
			if crop then
				crop:Destroy()
			end
		end
		plot.LockPrompt.Enabled = false
	end)
end

return PlotService
