--[[
	LobbyService — строит лобби (площадь, 4 лифта, табло, зал коллекции башен,
	место под будущий магазин) и возвращает игроков в лобби.
	Лифты: ElevatorService использует Booths[index] (зона, табличка, точка выхода).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Towers = require(Shared.Config.Towers)
local Parts = require(Shared.Visual.Parts)
local TowerModel = require(Shared.Visual.TowerModel)

local LobbyService = {}
LobbyService.Booths = {}

local services
local folder: Folder
local rng = Random.new(77)

local A = CFrame.Angles
local rad = math.rad

local ELEVATOR_X = { -39, -13, 13, 39 }
local ELEVATOR_Z = -24
local STATE_COLORS = {
	Empty = Color3.fromRGB(80, 220, 120),
	Waiting = Color3.fromRGB(255, 210, 60),
	Starting = Color3.fromRGB(255, 140, 40),
	InMatch = Color3.fromRGB(255, 70, 70),
}
LobbyService.StateColors = STATE_COLORS

local function block(size: Vector3, cf: CFrame, color: Color3, opts: any?): BasePart
	return Parts.Block(folder, size, cf, color, opts)
end

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3?, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = position
	l.Size = size
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", if bold then Enum.FontWeight.ExtraBold else Enum.FontWeight.SemiBold)
	l.Parent = parent
	return l
end

local function surface(part: BasePart, face: Enum.NormalId, ppu: number?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu or 30
	gui.LightInfluence = 0
	gui.Parent = part
	return gui
end

local function tree(position: Vector3)
	local h = rng:NextNumber(3, 5)
	Parts.Cylinder(folder, h, 0.9, CFrame.new(position + Vector3.new(0, h / 2, 0)), Color3.fromRGB(115, 80, 50), "Y")
	local green = Color3.fromRGB(80, 160, 70):Lerp(Color3.fromRGB(120, 185, 80), rng:NextNumber())
	block(Vector3.new(4.4, 3.6, 4.4), CFrame.new(position + Vector3.new(0, h + 1.6, 0)) * A(0, rad(20), 0), green)
	block(Vector3.new(3.4, 3.4, 3.4), CFrame.new(position + Vector3.new(0, h + 3, 0)) * A(rad(45), rad(45), 0), Parts.Lighten(green, 0.08))
end

local function lamp(position: Vector3)
	Parts.Cylinder(folder, 6, 0.4, CFrame.new(position + Vector3.new(0, 3, 0)), Color3.fromRGB(60, 62, 72), "Y")
	local bulb = Parts.Neon(folder, Vector3.new(1, 1, 1), CFrame.new(position + Vector3.new(0, 6.3, 0)) * A(0, rad(45), 0), Color3.fromRGB(255, 240, 200))
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 1
	light.Color = Color3.fromRGB(255, 235, 200)
	light.Parent = bulb
end

local function bench(position: Vector3, rotation: number)
	local cf = CFrame.new(position) * A(0, rad(rotation), 0)
	local wood = Color3.fromRGB(160, 110, 70)
	block(Vector3.new(4, 0.3, 1.2), cf * CFrame.new(0, 1.2, 0), wood)
	block(Vector3.new(4, 1, 0.25), cf * CFrame.new(0, 1.85, 0.5), wood)
	for _, x in { -1.6, 1.6 } do
		block(Vector3.new(0.3, 1.2, 1), cf * CFrame.new(x, 0.6, 0), Color3.fromRGB(60, 60, 70))
	end
end

local function buildGround()
	local light, dark = Color3.fromRGB(120, 190, 95), Color3.fromRGB(108, 178, 85)
	for ix = -6, 5 do
		for iz = -5, 5 do
			local part = block(Vector3.new(14, 2, 14), CFrame.new(ix * 14 + 7, -1, iz * 14 + 7), if (ix + iz) % 2 == 0 then light else dark,
				{ Material = Enum.Material.Grass, CastShadow = false, CanCollide = true })
			part.Name = "Ground"
		end
	end
	local stone = Color3.fromRGB(205, 200, 190)
	-- Центральная площадь и дорожки к лифтам
	Parts.Cylinder(folder, 0.3, 46, CFrame.new(0, 0.1, 22), stone, "Y", { CanCollide = true, CastShadow = false, Material = Enum.Material.Slate })
	block(Vector3.new(96, 0.3, 10), CFrame.new(0, 0.12, -6), stone, { CanCollide = true, CastShadow = false, Material = Enum.Material.Slate })
	for _, x in ELEVATOR_X do
		block(Vector3.new(8, 0.32, 14), CFrame.new(x, 0.13, -12), Parts.Lighten(stone, 0.05), { CanCollide = true, CastShadow = false, Material = Enum.Material.Slate })
		-- Неоновые стрелки к лифту
		for i = 0, 2 do
			local arrow = Parts.Neon(folder, Vector3.new(2.2, 0.1, 0.5), CFrame.new(x, 0.32, -3 - i * 3) * A(0, rad(35), 0), Color3.fromRGB(90, 200, 255))
			arrow.Name = "Arrow"
			Parts.Neon(folder, Vector3.new(2.2, 0.1, 0.5), CFrame.new(x + 0.0, 0.32, -3 - i * 3) * A(0, rad(-35), 0), Color3.fromRGB(90, 200, 255))
		end
	end
	-- Фонтан
	Parts.Cylinder(folder, 1.2, 12, CFrame.new(0, 0.6, 22), Color3.fromRGB(170, 170, 180), "Y", { CanCollide = true, Material = Enum.Material.Slate })
	Parts.Cylinder(folder, 0.2, 10.5, CFrame.new(0, 1.15, 22), Color3.fromRGB(100, 170, 240), "Y", { Material = Enum.Material.Glass, Transparency = 0.3 })
	Parts.Cylinder(folder, 3, 1.4, CFrame.new(0, 2, 22), Color3.fromRGB(170, 170, 180), "Y", { CanCollide = true })
	local spray = Parts.Neon(folder, Vector3.new(1, 1.6, 1), CFrame.new(0, 4.2, 22), Color3.fromRGB(150, 210, 255))
	spray.Transparency = 0.4
	-- Ограда по периметру
	for _, entry in {
		{ Vector3.new(170, 3, 2), CFrame.new(0, 1.5, 78) }, { Vector3.new(170, 3, 2), CFrame.new(0, 1.5, -72) },
		{ Vector3.new(2, 3, 150), CFrame.new(-84, 1.5, 3) }, { Vector3.new(2, 3, 150), CFrame.new(84, 1.5, 3) },
	} do
		block(entry[1], entry[2], Color3.fromRGB(150, 110, 75), { CanCollide = true })
	end
end

local function buildBooth(index: number)
	local x = ELEVATOR_X[index]
	local center = Vector3.new(x, 0, ELEVATOR_Z)
	local metal = Color3.fromRGB(70, 76, 92)
	local model = Instance.new("Model")
	model.Name = "Elevator" .. index
	local function piece(size: Vector3, cf: CFrame, color: Color3, opts: any?): BasePart
		local p = Parts.Block(model, size, cf, color, opts)
		return p
	end
	piece(Vector3.new(11, 0.5, 11), CFrame.new(center + Vector3.new(0, 0.25, 0)), Color3.fromRGB(45, 48, 60), { CanCollide = true, Material = Enum.Material.DiamondPlate })
	piece(Vector3.new(11, 12, 1), CFrame.new(center + Vector3.new(0, 6, -5.5)), metal, { CanCollide = true, Material = Enum.Material.Metal })
	for _, side in { -1, 1 } do
		piece(Vector3.new(1, 12, 11), CFrame.new(center + Vector3.new(side * 5.5, 6, 0)), metal, { CanCollide = true, Material = Enum.Material.Metal })
		piece(Vector3.new(0.2, 9, 8), CFrame.new(center + Vector3.new(side * 4.95, 5.5, 0)), Color3.fromRGB(150, 200, 240),
			{ Material = Enum.Material.Glass, Transparency = 0.6 })
	end
	piece(Vector3.new(12, 1, 12), CFrame.new(center + Vector3.new(0, 12.5, 0)), Parts.Darken(metal, 0.2), { CanCollide = true })
	local strip = piece(Vector3.new(11.4, 0.4, 0.4), CFrame.new(center + Vector3.new(0, 11.7, 5.6)), STATE_COLORS.Empty, { Material = Enum.Material.Neon })
	strip.Name = "StateStrip"
	local floorGlow = piece(Vector3.new(9, 0.06, 9), CFrame.new(center + Vector3.new(0, 0.53, 0)), STATE_COLORS.Empty, { Material = Enum.Material.Neon, Transparency = 0.5, CastShadow = false })
	floorGlow.Name = "FloorGlow"
	-- Табло над входом
	local board = piece(Vector3.new(11, 5, 0.4), CFrame.new(center + Vector3.new(0, 15.5, 5.2)), Color3.fromRGB(25, 27, 36), { CanCollide = false })
	board.Name = "Board"
	local gui = surface(board, Enum.NormalId.Back, 40)
	local title = label(gui, "ELEVATOR " .. index, UDim2.fromScale(0.03, 0.04), UDim2.fromScale(0.94, 0.26), Color3.fromRGB(120, 210, 255), true)
	local mapLabel = label(gui, "", UDim2.fromScale(0.03, 0.32), UDim2.fromScale(0.94, 0.22))
	local playersLabel = label(gui, "", UDim2.fromScale(0.03, 0.55), UDim2.fromScale(0.94, 0.2))
	local statusLabel = label(gui, "", UDim2.fromScale(0.03, 0.76), UDim2.fromScale(0.94, 0.2), STATE_COLORS.Empty, true)
	model.Parent = folder
	LobbyService.Booths[index] = {
		Index = index,
		Model = model,
		Center = center,
		Half = Vector3.new(4.6, 7, 4.6),
		Exit = center + Vector3.new(0, 3, 10),
		Strip = strip,
		FloorGlow = floorGlow,
		Title = title,
		MapLabel = mapLabel,
		PlayersLabel = playersLabel,
		StatusLabel = statusLabel,
	}
end

local function buildInfoBoard()
	local cf = CFrame.new(-56, 0, 34) * A(0, rad(50), 0)
	for _, x in { -5, 5 } do
		block(Vector3.new(0.8, 9, 0.8), cf * CFrame.new(x, 4.5, 0), Color3.fromRGB(70, 60, 50), { CanCollide = true })
	end
	local board = block(Vector3.new(12, 7, 0.5), cf * CFrame.new(0, 7, 0), Color3.fromRGB(28, 30, 40), { CanCollide = true })
	local gui = surface(board, Enum.NormalId.Back, 36)
	label(gui, "HOW TO PLAY", UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.9, 0.16), Color3.fromRGB(255, 200, 70), true)
	local body = label(gui, "1. Step into any of the 4 elevators\n2. The leader picks a map and party size (1–4)\n3. Press Ready or wait for the timer\n4. Place towers (keys 1–5), upgrade and sell\n5. Survive 30 waves and earn gems\n6. Spend gems on new towers in the Tower Shop",
		UDim2.fromScale(0.05, 0.22), UDim2.fromScale(0.9, 0.74))
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
end

local function buildCollection()
	local cf = CFrame.new(56, 0, 30) * A(0, rad(-50), 0)
	local wall = Color3.fromRGB(235, 230, 220)
	block(Vector3.new(18, 0.6, 12), cf * CFrame.new(0, 0.3, 0), Color3.fromRGB(180, 175, 165), { CanCollide = true })
	block(Vector3.new(18, 9, 1), cf * CFrame.new(0, 4.5, -5.5), wall, { CanCollide = true })
	for _, x in { -8.5, 8.5 } do
		block(Vector3.new(1, 9, 12), cf * CFrame.new(x, 4.5, 0), wall, { CanCollide = true })
	end
	Parts.Wedge(folder, Vector3.new(19, 3, 7), cf * CFrame.new(0, 10.5, 2.5), Color3.fromRGB(60, 120, 220))
	Parts.Wedge(folder, Vector3.new(19, 3, 7), cf * CFrame.new(0, 10.5, -3.5) * A(0, math.pi, 0), Color3.fromRGB(60, 120, 220))
	local sign = block(Vector3.new(14, 2.4, 0.4), cf * CFrame.new(0, 8, 6.3), Color3.fromRGB(28, 30, 40))
	local gui = surface(sign, Enum.NormalId.Back, 36)
	label(gui, "TOWER SHOP", UDim2.fromScale(0.03, 0.1), UDim2.fromScale(0.94, 0.8), Color3.fromRGB(120, 210, 255), true)
	local counter = block(Vector3.new(6, 3, 1.5), cf * CFrame.new(0, 1.5, 2), Color3.fromRGB(70, 76, 92), { CanCollide = true })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Tower Shop"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ClientAction", "OpenShop")
	prompt.Parent = counter
	-- Витрина: все восемь башен на постаментах
	for i, tower in Towers.List do
		local angle = rad(-150 + (i - 1) * (300 / (#Towers.List - 1)))
		local position = Vector3.new(math.cos(angle) * 18, 0.6, 22 + math.sin(angle) * 18)
		Parts.Cylinder(folder, 0.6, 3.6, CFrame.new(position + Vector3.new(0, -0.3, 0)), tower.Accent, "Y", { CanCollide = true })
		local statue = TowerModel.Build(tower.Id, 1)
		statue:PivotTo(CFrame.lookAt(position + Vector3.new(0, 3, 0), Vector3.new(0, 3, 22)))
		statue.Parent = folder
		local humanoid = statue:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayName = tower.Name
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
			humanoid.NameDisplayDistance = 40
		end
	end
end

local function buildShopPlaceholder()
	local cf = CFrame.new(-56, 0, 4) * A(0, rad(70), 0)
	block(Vector3.new(10, 4, 4), cf * CFrame.new(0, 2, 0), Color3.fromRGB(160, 110, 70), { CanCollide = true })
	for i = 0, 5 do
		block(Vector3.new(10 / 6, 0.4, 6), cf * CFrame.new(-5 + (i + 0.5) * 10 / 6, 7, 0.5) * A(rad(-12), 0, 0),
			if i % 2 == 0 then Color3.fromRGB(240, 80, 90) else Color3.fromRGB(250, 250, 250))
	end
	for _, x in { -4.6, 4.6 } do
		block(Vector3.new(0.5, 7, 0.5), cf * CFrame.new(x, 3.5, 2.5), Color3.fromRGB(90, 70, 50), { CanCollide = true })
	end
	local sign = block(Vector3.new(9, 1.8, 0.3), cf * CFrame.new(0, 8.5, 2.8), Color3.fromRGB(28, 30, 40))
	local gui = surface(sign, Enum.NormalId.Back, 36)
	label(gui, "LOADOUT", UDim2.fromScale(0.03, 0.1), UDim2.fromScale(0.94, 0.8), Color3.fromRGB(255, 200, 70), true)
	local counter = block(Vector3.new(8, 3, 1.5), cf * CFrame.new(0, 1.5, 2.6), Color3.fromRGB(70, 76, 92), { CanCollide = true })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Edit"
	prompt.ObjectText = "Tower Loadout"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ClientAction", "OpenLoadout")
	prompt.Parent = counter
end

local function buildDecor()
	for _ = 1, 22 do
		local x = rng:NextNumber(-80, 80)
		local z = rng:NextNumber(-68, 74)
		local nearElevators = z < -6 and z > -36 and math.abs(x) < 52
		local nearPlaza = (Vector3.new(x, 0, z) - Vector3.new(0, 0, 22)).Magnitude < 30
		local nearPath = math.abs(z + 6) < 8 and math.abs(x) < 50
		local nearBuildings = (Vector3.new(x, 0, z) - Vector3.new(56, 0, 30)).Magnitude < 16
			or (Vector3.new(x, 0, z) - Vector3.new(-56, 0, 34)).Magnitude < 12
			or (Vector3.new(x, 0, z) - Vector3.new(-56, 0, 4)).Magnitude < 12
		if not (nearElevators or nearPlaza or nearPath or nearBuildings) then
			tree(Vector3.new(x, 0, z))
		end
	end
	for _, position in { Vector3.new(-26, 0, 6), Vector3.new(26, 0, 6), Vector3.new(-26, 0, 38), Vector3.new(26, 0, 38), Vector3.new(-50, 0, -6), Vector3.new(50, 0, -6) } do
		lamp(position)
	end
	for _, entry in { { Vector3.new(-14, 0, 44), 0 }, { Vector3.new(14, 0, 44), 0 }, { Vector3.new(-24, 0, 22), 90 }, { Vector3.new(24, 0, 22), -90 } } do
		bench(entry[1], entry[2])
	end
end

function LobbyService:Init(registry)
	services = registry
	folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = workspace
end

function LobbyService:SpawnCFrame(): CFrame
	local offset = Vector3.new(rng:NextNumber(-6, 6), 3, rng:NextNumber(-4, 4))
	local position = Game.Lobby.Spawn + offset
	return CFrame.lookAt(position, Vector3.new(0, 3, -24))
end

function LobbyService:SendToLobby(player: Player)
	player:SetAttribute("MatchId", nil)
	player:SetAttribute("MapId", nil)
	local character = player.Character
	if character then
		character:PivotTo(LobbyService:SpawnCFrame())
	end
end

function LobbyService:Start()
	buildGround()
	for i = 1, Game.Elevator.Count do
		buildBooth(i)
	end
	buildInfoBoard()
	buildCollection()
	buildShopPlaceholder()
	buildDecor()

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(Game.Lobby.Spawn + Vector3.new(0, 0.5, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(90, 200, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	-- Персонаж, появившийся во время матча, переносится на карту матча
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.wait()
			if player:GetAttribute("MatchId") then
				services.MatchService:OnCharacterAdded(player, character)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return LobbyService
