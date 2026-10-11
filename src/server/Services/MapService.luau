--[[
	MapService — процедурно строит статичный мир по координатам из Config/Map и Config/Zones:
	шахматная земля, стены с «травяной» кромкой, площадь-безопасная зона с магазинами,
	дорожка с пятью биомами и декором. Всё детерминировано (Random с фиксированным seed).
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Map = require(Shared.Config.Map)
local Zones = require(Shared.Config.Zones)
local Studs = require(Shared.Visual.Studs)
local EggModel = require(Shared.Visual.EggModel)

local MapService = {}

local root: Folder

local GRASS_TOP = Color3.fromRGB(80, 210, 60)
local WOOD = Color3.fromRGB(150, 95, 50)
local WOOD_LIGHT = Color3.fromRGB(235, 175, 60)
local WHITE = Color3.fromRGB(250, 250, 250)

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Шахматная земля с обрезкой краёв. Верх тайлов на Y = 0.
local function checker(parent: Instance, minX: number, maxX: number, minZ: number, maxZ: number,
	tile: number, colors: { Color3 })
	local ix = 0
	local x = minX
	while x < maxX - 0.01 do
		local w = math.min(tile, maxX - x)
		local iz = 0
		local z = minZ
		while z < maxZ - 0.01 do
			local d = math.min(tile, maxZ - z)
			local color = colors[((ix + iz) % #colors) + 1]
			Studs.Block(parent, Vector3.new(w, 2, d), CFrame.new(x + w / 2, -1, z + d / 2), color, { Name = "Ground" })
			z += d
			iz += 1
		end
		x += w
		ix += 1
	end
end

-- Стена из шахматных блоков вдоль оси X или Z с зелёной кромкой сверху
local function wall(parent: Instance, from: Vector3, to: Vector3, thickness: number, colors: { Color3 })
	local delta = to - from
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local dir = delta.Unit
	local alongX = math.abs(dir.X) > math.abs(dir.Z)
	local block = 10
	local rows = math.ceil(Map.WallHeight / block)
	local count = math.ceil(length / block)
	for i = 0, count - 1 do
		local segment = math.min(block, length - i * block)
		local center = from + dir * (i * block + segment / 2)
		for row = 0, rows - 1 do
			local h = math.min(block, Map.WallHeight - row * block)
			local size = if alongX then Vector3.new(segment, h, thickness) else Vector3.new(thickness, h, segment)
			local color = colors[((i + row) % #colors) + 1]
			Studs.Block(parent, size, CFrame.new(center.X, row * block + h / 2, center.Z), color, { Name = "Wall" })
		end
	end
	local capSize = if alongX then Vector3.new(length, 2, thickness + 2) else Vector3.new(thickness + 2, 2, length)
	local mid = from + delta / 2
	Studs.Block(parent, capSize, CFrame.new(mid.X, Map.WallHeight + 1, mid.Z), GRASS_TOP, { Name = "WallTop" })
end

local function surfaceText(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3?, bg: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if bg then 0 else 1
	label.BackgroundColor3 = bg or Color3.new()
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = textColor or WHITE
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(20, 20, 25)
	stroke.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = label
	return label
end

local function setupLighting()
	Lighting.Ambient = Color3.fromRGB(110, 110, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.Brightness = 2.4
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.ClockTime = 14
	if not Lighting:FindFirstChild("StudsColor") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "StudsColor"
		cc.Saturation = 0.18
		cc.Contrast = 0.05
		cc.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.25
		atmosphere.Offset = 0.1
		atmosphere.Color = Color3.fromRGB(200, 225, 255)
		atmosphere.Decay = Color3.fromRGB(120, 160, 220)
		atmosphere.Glare = 0
		atmosphere.Haze = 0.6
		atmosphere.Parent = Lighting
	end
end

------------------------------------------------------------------------
-- Хаб: площадь и район баз
------------------------------------------------------------------------

local function buildFence(parent: Instance, from: Vector3, to: Vector3, color: Color3)
	local delta = to - from
	local length = delta.Magnitude
	local dir = delta.Unit
	local posts = math.max(1, math.floor(length / 6))
	for i = 0, posts do
		local p = from + dir * (length * i / posts)
		Studs.Ground(parent, Vector3.new(1, 3.4, 1), p, color, { Name = "FencePost" })
	end
	local mid = from + delta / 2
	local cf = CFrame.lookAt(mid, mid + dir)
	for _, y in { 1.2, 2.6 } do
		Studs.Block(parent, Vector3.new(0.5, 0.6, length), cf + Vector3.new(0, y, 0), color, { Name = "FenceRail" })
	end
end

local function buildShop(parent: Instance, shop: any)
	local model = Instance.new("Model")
	model.Name = "Shop_" .. shop.Id
	local base = shop.Position
	local look = if math.abs(base.X) < 1 then CFrame.new(base) else CFrame.lookAt(base, Vector3.new(0, 0, base.Z))
	local function at(x: number, y: number, z: number): CFrame
		return look * CFrame.new(x, y, z)
	end

	local counter = Studs.Block(model, Vector3.new(12, 3.2, 3), at(0, 1.6, -3), WOOD, { Name = "Counter" })
	Studs.Block(model, Vector3.new(12.4, 0.6, 3.4), at(0, 3.5, -3), shop.Color, { Name = "CounterTop" })
	Studs.Block(model, Vector3.new(12, 10, 1), at(0, 5, 4), Studs.Darken(WOOD, 0.15), { Name = "Back" })
	for _, x in { -5.8, 5.8 } do
		for _, z in { -4.2, 4 } do
			Studs.Block(model, Vector3.new(0.8, 10, 0.8), at(x, 5, z), WOOD_LIGHT, { Name = "Post" })
		end
	end
	-- Полосатый навес (как у ларьков на референсе)
	local stripes = 7
	for i = 0, stripes - 1 do
		local x = -6.6 + (i + 0.5) * (13.2 / stripes)
		local color = if i % 2 == 0 then shop.Color else WHITE
		local stripe = Studs.Block(model, Vector3.new(13.2 / stripes, 0.6, 10.5), at(x, 10.6, -0.2), color, { Name = "Awning" })
		stripe.CFrame = stripe.CFrame * CFrame.Angles(math.rad(-10), 0, 0)
	end
	local sign = Studs.Block(model, Vector3.new(12, 2.6, 0.6), at(0, 12.9, -4.8), Color3.fromRGB(40, 40, 48), { Name = "Sign" })
	surfaceText(sign, Enum.NormalId.Front, shop.Name, shop.Color)

	-- Светящийся круг перед ларьком
	local pad = Studs.Block(model, Vector3.new(0.4, 9, 9), at(0, 0.21, -8.5) * CFrame.Angles(0, 0, math.rad(90)),
		shop.Color, { Name = "Pad", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, CanCollide = false, Studs = false })
	pad.Transparency = 0.5

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = shop.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ClientAction", "OpenShop")
	prompt:SetAttribute("Tab", shop.Tab)
	prompt.Parent = counter

	model.Parent = parent
end

local function buildBoard(parent: Instance, position: Vector3, title: string, color: Color3, action: string)
	local model = Instance.new("Model")
	model.Name = "Board_" .. action
	local cf = CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
	for _, x in { -6, 6 } do
		Studs.Block(model, Vector3.new(1.2, 9, 1.2), cf * CFrame.new(x, 4.5, 0), WOOD, { Name = "Leg" })
	end
	local board = Studs.Block(model, Vector3.new(14, 6, 1), cf * CFrame.new(0, 8, 0), color, { Name = "Board" })
	surfaceText(board, Enum.NormalId.Front, title, WHITE)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ClientAction", action)
	prompt.Parent = board
	model.Parent = parent
end

local function buildHub()
	local hub = folder("Hub", root)
	local ground = folder("Ground", hub)
	local minX, maxX = Map.BaseArea.Min.X - 8, Map.BaseArea.Max.X + 8
	checker(ground, minX, maxX, Map.Plaza.Min.Z, Map.Plaza.Max.Z, 18,
		{ Color3.fromRGB(110, 220, 70), Color3.fromRGB(96, 204, 60) })
	checker(ground, minX, maxX, Map.BaseArea.Min.Z - 8, Map.BaseArea.Max.Z, 18,
		{ Color3.fromRGB(88, 196, 56), Color3.fromRGB(76, 182, 50) })

	local walls = folder("Walls", hub)
	local wallColors = { Color3.fromRGB(178, 120, 70), Color3.fromRGB(160, 104, 58) }
	local south = Map.BaseArea.Min.Z - 8
	local north = Map.Plaza.Max.Z
	wall(walls, Vector3.new(minX - 3, 0, south), Vector3.new(minX - 3, 0, north + 3), 6, wallColors)
	wall(walls, Vector3.new(maxX + 3, 0, south), Vector3.new(maxX + 3, 0, north + 3), 6, wallColors)
	wall(walls, Vector3.new(minX - 6, 0, south - 3), Vector3.new(maxX + 6, 0, south - 3), 6, wallColors)
	wall(walls, Vector3.new(minX - 6, 0, north + 3), Vector3.new(-Map.Lane.HalfWidth - 6, 0, north + 3), 6, wallColors)
	wall(walls, Vector3.new(Map.Lane.HalfWidth + 6, 0, north + 3), Vector3.new(maxX + 6, 0, north + 3), 6, wallColors)

	-- Площадь
	local plaza = folder("Plaza", hub)
	for _, shop in Map.Shops do
		buildShop(plaza, shop)
	end
	buildBoard(plaza, Map.IndexBoard, "📖 INDEX", Color3.fromRGB(46, 168, 255), "OpenIndex")
	buildBoard(plaza, Map.QuestBoard, "📜 QUESTS", Color3.fromRGB(255, 150, 30), "OpenQuests")

	-- Жёлтый заборчик вдоль площади (как на референсе)
	buildFence(plaza, Vector3.new(minX + 2, 0, Map.Plaza.Min.Z + 2), Vector3.new(-50, 0, Map.Plaza.Min.Z + 2), WOOD_LIGHT)
	buildFence(plaza, Vector3.new(50, 0, Map.Plaza.Min.Z + 2), Vector3.new(maxX - 2, 0, Map.Plaza.Min.Z + 2), WOOD_LIGHT)

	-- Центральная статуя-яйцо — ориентир
	local statueBase = Studs.Ground(plaza, Vector3.new(10, 3, 10), Vector3.new(0, 0, 14), Color3.fromRGB(70, 70, 80), { Name = "StatueBase" })
	Studs.Ground(plaza, Vector3.new(8, 0.6, 8), statueBase.Position + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 194, 26), { Name = "StatueTop" })
	local statue = EggModel.Build("star_egg", 2.8)
	statue:PivotTo(CFrame.new(0, 3.6, 14))
	statue.Parent = plaza

	-- Линия начала дорожки и надпись SAFE ZONE
	Studs.Block(plaza, Vector3.new(Map.Lane.HalfWidth * 2, 0.2, 0.8), CFrame.new(0, 0.1, Map.Lane.ZStart),
		Color3.fromRGB(255, 40, 40), { Name = "SafeLine", Material = Enum.Material.Neon, CanCollide = false, Studs = false })
	local safeSign = Studs.Block(plaza, Vector3.new(34, 0.2, 5), CFrame.new(0, 0.11, Map.Lane.ZStart - 6),
		Color3.new(), { Name = "SafeText", Transparency = 1, CanCollide = false, Studs = false })
	surfaceText(safeSign, Enum.NormalId.Top, "🛡️ SAFE ZONE 🛡️", Color3.fromRGB(255, 255, 255))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(Map.Spawn + Vector3.new(0, 0.5, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(63, 169, 255)
	spawn.TopSurface = Enum.SurfaceType.Studs
	spawn.Parent = plaza
end

------------------------------------------------------------------------
-- Дорожка и биомы
------------------------------------------------------------------------

local function tree(parent: Instance, pos: Vector3, rng: Random, leaves: Color3)
	local h = rng:NextInteger(5, 8)
	Studs.Ground(parent, Vector3.new(1.6, h, 1.6), pos, WOOD, { Name = "Trunk" })
	Studs.Ground(parent, Vector3.new(6, 3, 6), pos + Vector3.new(0, h, 0), leaves, { Name = "Leaves" })
	Studs.Ground(parent, Vector3.new(4, 2, 4), pos + Vector3.new(0, h + 3, 0), Studs.Lighten(leaves, 0.1), { Name = "Leaves" })
end

local function bush(parent: Instance, pos: Vector3, rng: Random, color: Color3)
	local w = rng:NextInteger(4, 7)
	Studs.Ground(parent, Vector3.new(w, 2, w - 1), pos, color, { Name = "Bush" })
	Studs.Ground(parent, Vector3.new(w - 2, 1.5, w - 3), pos + Vector3.new(0.5, 2, 0), Studs.Lighten(color, 0.1), { Name = "Bush" })
end

local function cactus(parent: Instance, pos: Vector3, rng: Random)
	local green = Color3.fromRGB(60, 160, 70)
	local h = rng:NextInteger(5, 9)
	Studs.Ground(parent, Vector3.new(1.6, h, 1.6), pos, green, { Name = "Cactus" })
	Studs.Ground(parent, Vector3.new(2.4, 1, 1), pos + Vector3.new(1.8, h * 0.45, 0), green, { Name = "Cactus" })
	Studs.Ground(parent, Vector3.new(1, 2.4, 1), pos + Vector3.new(2.5, h * 0.45 + 1, 0), green, { Name = "Cactus" })
end

local function pyramid(parent: Instance, pos: Vector3)
	local sand = { Color3.fromRGB(230, 195, 120), Color3.fromRGB(214, 178, 104) }
	for i = 0, 5 do
		local w = 22 - i * 4
		Studs.Ground(parent, Vector3.new(w, 2, w), pos + Vector3.new(0, i * 2, 0), sand[i % 2 + 1], { Name = "Pyramid" })
	end
end

local function pine(parent: Instance, pos: Vector3, rng: Random)
	local dark = Color3.fromRGB(40, 110, 70)
	Studs.Ground(parent, Vector3.new(1.4, 3, 1.4), pos, WOOD, { Name = "Trunk" })
	for i = 0, 2 do
		local w = 7 - i * 2
		Studs.Ground(parent, Vector3.new(w, 2.4, w), pos + Vector3.new(0, 3 + i * 2.4, 0), dark, { Name = "Pine" })
		Studs.Ground(parent, Vector3.new(w - 0.6, 0.6, w - 0.6), pos + Vector3.new(0, 5.4 + i * 2.4, 0), WHITE, { Name = "Snow" })
	end
	if rng:NextNumber() < 0.3 then
		Studs.Ground(parent, Vector3.new(3, 1.2, 2), pos + Vector3.new(3, 0, 1), WHITE, { Name = "SnowPile" })
	end
end

local function iceSpike(parent: Instance, pos: Vector3, rng: Random)
	local h = rng:NextInteger(6, 12)
	local spike = Studs.Ground(parent, Vector3.new(2, h, 2), pos, Color3.fromRGB(150, 210, 255),
		{ Name = "IceSpike", Material = Enum.Material.Glass })
	spike.Transparency = 0.25
	spike.CFrame = spike.CFrame * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), math.rad(rng:NextNumber(0, 90)), math.rad(rng:NextNumber(-12, 12)))
end

local function lavaPool(parent: Instance, pos: Vector3, rng: Random)
	local w = rng:NextInteger(6, 10)
	Studs.Block(parent, Vector3.new(w + 2, 0.4, w + 2), CFrame.new(pos + Vector3.new(0, 0.2, 0)), Color3.fromRGB(40, 32, 34), { Name = "PoolRim" })
	Studs.Block(parent, Vector3.new(w, 0.5, w), CFrame.new(pos + Vector3.new(0, 0.3, 0)), Color3.fromRGB(255, 110, 20),
		{ Name = "Lava", Material = Enum.Material.Neon, Studs = false })
end

local function basalt(parent: Instance, pos: Vector3, rng: Random)
	local h = rng:NextInteger(3, 8)
	Studs.Ground(parent, Vector3.new(3, h, 3), pos, Color3.fromRGB(45, 40, 44), { Name = "Basalt" })
	Studs.Ground(parent, Vector3.new(0.4, h * 0.8, 0.4), pos + Vector3.new(1.6, 0, 0), Color3.fromRGB(255, 90, 20),
		{ Name = "Crack", Material = Enum.Material.Neon, Studs = false })
end

local function crystal(parent: Instance, pos: Vector3, rng: Random)
	local colors = { Color3.fromRGB(255, 120, 230), Color3.fromRGB(120, 220, 255), Color3.fromRGB(190, 120, 255) }
	local color = colors[rng:NextInteger(1, #colors)]
	local h = rng:NextInteger(4, 9)
	local cf = CFrame.new(pos + Vector3.new(0, h / 2 + rng:NextNumber(1, 5), 0))
		* CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), math.rad(rng:NextNumber(0, 90)), math.rad(rng:NextNumber(-20, 20)))
	Studs.Block(parent, Vector3.new(2, h, 2), cf, color, { Name = "Crystal", Material = Enum.Material.Neon })
	Studs.Ground(parent, Vector3.new(3, 1, 3), pos, Color3.fromRGB(60, 45, 110), { Name = "CrystalBase" })
end

local DECOR: { [string]: (Instance, Vector3, Random) -> () } = {
	meadow = function(parent, pos, rng)
		if rng:NextNumber() < 0.45 then
			tree(parent, pos, rng, Color3.fromRGB(60, 170, 50))
		else
			bush(parent, pos, rng, Color3.fromRGB(70, 175, 55))
		end
	end,
	dunes = function(parent, pos, rng)
		if rng:NextNumber() < 0.7 then
			cactus(parent, pos, rng)
		else
			Studs.Ground(parent, Vector3.new(rng:NextInteger(4, 8), rng:NextInteger(1, 3), rng:NextInteger(4, 8)), pos,
				Color3.fromRGB(205, 165, 100), { Name = "Rock" })
		end
	end,
	frost = function(parent, pos, rng)
		if rng:NextNumber() < 0.5 then
			pine(parent, pos, rng)
		else
			iceSpike(parent, pos, rng)
		end
	end,
	magma = function(parent, pos, rng)
		if rng:NextNumber() < 0.4 then
			lavaPool(parent, pos, rng)
		else
			basalt(parent, pos, rng)
		end
	end,
	starfall = function(parent, pos, rng)
		crystal(parent, pos, rng)
	end,
}

local function zoneGate(parent: Instance, zone: any)
	local z = zone.ZStart
	local color = zone.Wall[1]
	local x = Map.Lane.HalfWidth - 3
	for _, side in { -1, 1 } do
		Studs.Ground(parent, Vector3.new(4, 22, 4), Vector3.new(side * x, 0, z), color, { Name = "GatePillar" })
	end
	local beam = Studs.Block(parent, Vector3.new(x * 2 + 4, 4, 2), CFrame.new(0, 24, z), Studs.Darken(color, 0.2), { Name = "GateBeam" })
	local text = string.format("%s  •  👟 %d+", string.upper(zone.Name), zone.RecommendedSpeed)
	surfaceText(beam, Enum.NormalId.Front, text, WHITE)
	surfaceText(beam, Enum.NormalId.Back, "⬇ BASE ⬇", WHITE)
end

local function buildLane()
	local lane = folder("Lane", root)
	local hw = Map.Lane.HalfWidth
	for _, zone in Zones.List do
		local zoneFolder = folder("Zone_" .. zone.Id, lane)
		checker(zoneFolder, -hw - 6, hw + 6, zone.ZStart, zone.ZEnd, 18, zone.Ground)
		wall(zoneFolder, Vector3.new(-hw - 3, 0, zone.ZStart), Vector3.new(-hw - 3, 0, zone.ZEnd), 6, zone.Wall)
		wall(zoneFolder, Vector3.new(hw + 3, 0, zone.ZStart), Vector3.new(hw + 3, 0, zone.ZEnd), 6, zone.Wall)
		if zone.Order > 1 then
			zoneGate(zoneFolder, zone)
		end

		local decor = folder("Decor", zoneFolder)
		local rng = Random.new(zone.Order * 7919)
		local build = DECOR[zone.Id]
		local z = zone.ZStart + 8
		while z < zone.ZEnd - 8 do
			for _, side in { -1, 1 } do
				if rng:NextNumber() < 0.75 then
					local x = side * rng:NextNumber(32, hw - 5)
					build(decor, Vector3.new(x, 0, z + rng:NextNumber(-3, 3)), rng)
				end
			end
			z += rng:NextNumber(12, 20)
		end
		if zone.Id == "dunes" then
			pyramid(decor, Vector3.new(-hw + 12, 0, (zone.ZStart + zone.ZEnd) / 2))
		end
		if zone.Id == "starfall" then
			-- Звёзды в «небе» зоны
			for _ = 1, 40 do
				local p = Vector3.new(rng:NextNumber(-hw, hw), rng:NextNumber(30, 70), rng:NextNumber(zone.ZStart, zone.ZEnd))
				Studs.Block(decor, Vector3.new(0.8, 0.8, 0.8), CFrame.new(p), WHITE,
					{ Name = "Star", Material = Enum.Material.Neon, CanCollide = false, Studs = false, CastShadow = false })
			end
		end
	end

	-- Торцевая стена и портал в конце
	local last = Zones.List[#Zones.List]
	local endZ = last.ZEnd
	wall(lane, Vector3.new(-hw - 6, 0, endZ + 3), Vector3.new(hw + 6, 0, endZ + 3), 6, last.Wall)
	local portal = folder("Portal", lane)
	for _, side in { -1, 1 } do
		Studs.Ground(portal, Vector3.new(4, 20, 4), Vector3.new(side * 10, 0, endZ - 4), Color3.fromRGB(60, 50, 120), { Name = "PortalPillar" })
	end
	Studs.Block(portal, Vector3.new(24, 4, 4), CFrame.new(0, 22, endZ - 4), Color3.fromRGB(60, 50, 120), { Name = "PortalTop" })
	local field = Studs.Block(portal, Vector3.new(16, 20, 0.6), CFrame.new(0, 10, endZ - 4), Color3.fromRGB(170, 60, 255),
		{ Name = "PortalField", Material = Enum.Material.Neon, CanCollide = false, Studs = false })
	field.Transparency = 0.35
end

function MapService:Init(_registry)
	root = Instance.new("Folder")
	root.Name = "Map"
	root.Parent = workspace
end

function MapService:Start()
	setupLighting()
	buildHub()
	buildLane()
end

function MapService:Root(): Folder
	return root
end

return MapService
