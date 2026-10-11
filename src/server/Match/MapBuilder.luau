--[[
	Строит карту матча из Config/Maps и Logic/MapLayout в точке origin.
	Визуальная иерархия: дорога (контрастная, с бортиками) → места для башен (ровная
	земля) → база и портал (крупные, яркие) → декор (у краёв, приглушённый).
	Весь декор — low-poly из примитивов, без внешних ассетов и скриптов.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maps = require(Shared.Config.Maps)
local MapLayout = require(Shared.Logic.MapLayout)
local Parts = require(Shared.Visual.Parts)

local MapBuilder = {}

local A = CFrame.Angles
local rad = math.rad

type Ctx = { Folder: Folder, Origin: CFrame, Map: any, Rng: Random }

local function block(ctx: Ctx, size: Vector3, cf: CFrame, color: Color3, opts: any?): BasePart
	return Parts.Block(ctx.Folder, size, ctx.Origin * cf, color, opts)
end

local function wedge(ctx: Ctx, size: Vector3, cf: CFrame, color: Color3, opts: any?): BasePart
	return Parts.Wedge(ctx.Folder, size, ctx.Origin * cf, color, opts)
end

local function cyl(ctx: Ctx, length: number, d: number, cf: CFrame, color: Color3, axis: string?, opts: any?): BasePart
	return Parts.Cylinder(ctx.Folder, length, d, ctx.Origin * cf, color, axis, opts)
end

local function ball(ctx: Ctx, d: number, cf: CFrame, color: Color3, opts: any?): BasePart
	return Parts.Ball(ctx.Folder, d, ctx.Origin * cf, color, opts)
end

local function neon(ctx: Ctx, size: Vector3, cf: CFrame, color: Color3): BasePart
	return Parts.Neon(ctx.Folder, size, ctx.Origin * cf, color)
end

local function light(part: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
end

-- Low-poly «кристалл» листвы: два повёрнутых блока
local function canopy(ctx: Ctx, cf: CFrame, size: number, color: Color3)
	block(ctx, Vector3.new(size, size * 0.8, size), cf * A(0, rad(20), 0), color)
	block(ctx, Vector3.new(size * 0.8, size * 0.9, size * 0.8), cf * CFrame.new(0, size * 0.35, 0) * A(rad(45), rad(45), 0), Parts.Lighten(color, 0.08))
end

------------------------------------------------------------------------
-- Декор
------------------------------------------------------------------------

local PROPS: { [string]: (Ctx, any, CFrame, number) -> () } = {}

PROPS.tree = function(ctx, _item, cf, s)
	local h = 3 + ctx.Rng:NextNumber(0, 2)
	cyl(ctx, h * s, 0.9 * s, cf * CFrame.new(0, h * s / 2, 0), Color3.fromRGB(115, 80, 50), "Y")
	local green = Color3.fromRGB(70, 150, 60):Lerp(Color3.fromRGB(110, 175, 70), ctx.Rng:NextNumber())
	canopy(ctx, cf * CFrame.new(0, h * s + 1.6 * s, 0), 4.2 * s, green)
end

PROPS.rock = function(ctx, _item, cf, s)
	local grey = Color3.fromRGB(130, 135, 140)
	block(ctx, Vector3.new(2.6, 1.6, 2.2) * s, cf * CFrame.new(0, 0.6 * s, 0) * A(rad(10), 0, rad(8)), grey, { Material = Enum.Material.Slate })
	block(ctx, Vector3.new(1.4, 1.0, 1.4) * s, cf * CFrame.new(0.9 * s, 0.4 * s, 0.6 * s) * A(0, rad(35), rad(-12)), Parts.Lighten(grey, 0.1), { Material = Enum.Material.Slate })
end

PROPS.hill = function(ctx, _item, cf, s)
	local green = ctx.Map.Palette.Ground2
	cyl(ctx, 2.5 * s, 14 * s, cf * CFrame.new(0, 0.8 * s, 0), Parts.Darken(green, 0.05), "Y", { Material = Enum.Material.Grass })
	cyl(ctx, 2 * s, 9 * s, cf * CFrame.new(0.8 * s, 2.4 * s, 0.4 * s), Parts.Lighten(green, 0.06), "Y", { Material = Enum.Material.Grass })
end

PROPS.bush = function(ctx, _item, cf, s)
	local green = Color3.fromRGB(70, 140, 55)
	ball(ctx, 2 * s, cf * CFrame.new(0, 0.6 * s, 0), green)
	ball(ctx, 1.4 * s, cf * CFrame.new(0.8 * s, 0.5 * s, 0.3 * s), Parts.Lighten(green, 0.1))
end

PROPS.flowers = function(ctx, _item, cf, s)
	local colors = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 80), Color3.fromRGB(180, 120, 255), Color3.fromRGB(255, 255, 255) }
	for i = 1, 4 do
		local offset = Vector3.new(ctx.Rng:NextNumber(-1, 1), 0, ctx.Rng:NextNumber(-1, 1)) * s
		block(ctx, Vector3.new(0.1, 0.5, 0.1), cf * CFrame.new(offset + Vector3.new(0, 0.25, 0)), Color3.fromRGB(70, 140, 50), { CastShadow = false })
		block(ctx, Vector3.new(0.35, 0.2, 0.35), cf * CFrame.new(offset + Vector3.new(0, 0.55, 0)) * A(0, rad(45), 0), colors[(i % #colors) + 1], { CastShadow = false })
	end
end

PROPS.stream = function(ctx, item, _cf, _s)
	local p = item.Position
	block(ctx, Vector3.new(9, 0.12, ctx.Map.Bounds.Y * 2 + 12), CFrame.new(p.X, 0.04, p.Z), Color3.fromRGB(70, 130, 210), { CastShadow = false })
	block(ctx, Vector3.new(8, 0.06, ctx.Map.Bounds.Y * 2 + 12), CFrame.new(p.X, 0.12, p.Z), Color3.fromRGB(130, 190, 245),
		{ Material = Enum.Material.Glass, Transparency = 0.45, CastShadow = false })
	for _, x in { -5.5, 5.5 } do
		block(ctx, Vector3.new(1.2, 0.5, ctx.Map.Bounds.Y * 2 + 12), CFrame.new(p.X + x, 0.2, p.Z), Color3.fromRGB(120, 120, 125), { Material = Enum.Material.Slate })
	end
end

PROPS.bridge = function(ctx, item, _cf, _s)
	local p = item.Position
	local wood = Color3.fromRGB(150, 105, 65)
	for i = -6, 6 do
		block(ctx, Vector3.new(1.1, 0.35, 9.5), CFrame.new(p.X + i * 1.15, 0.3, p.Z), if i % 2 == 0 then wood else Parts.Darken(wood, 0.1))
	end
	for _, z in { -4.9, 4.9 } do
		block(ctx, Vector3.new(15, 0.3, 0.3), CFrame.new(p.X, 1.6, p.Z + z), Parts.Darken(wood, 0.2))
		for _, x in { -7, -2.3, 2.3, 7 } do
			block(ctx, Vector3.new(0.4, 1.6, 0.4), CFrame.new(p.X + x, 0.9, p.Z + z), Parts.Darken(wood, 0.25))
		end
	end
end

PROPS.redRock = function(ctx, _item, cf, s)
	local red = Color3.fromRGB(190, 95, 60):Lerp(Color3.fromRGB(160, 70, 45), ctx.Rng:NextNumber())
	local h = (5 + ctx.Rng:NextNumber(0, 5)) * s
	block(ctx, Vector3.new(6, h, 5) * Vector3.new(s, 1, s), cf * CFrame.new(0, h / 2, 0) * A(0, rad(15), rad(4)), red, { Material = Enum.Material.Sandstone })
	block(ctx, Vector3.new(4.5, h * 0.35, 4) * Vector3.new(s, 1, s), cf * CFrame.new(0.5 * s, h + h * 0.15, 0) * A(0, rad(-20), 0), Parts.Lighten(red, 0.1), { Material = Enum.Material.Sandstone })
	block(ctx, Vector3.new(7, 0.6, 6) * Vector3.new(s, 1, s), cf * CFrame.new(0, h * 0.55, 0) * A(0, rad(40), 0), Parts.Darken(red, 0.15), { Material = Enum.Material.Sandstone })
end

PROPS.cactus = function(ctx, _item, cf, s)
	local green = Color3.fromRGB(80, 150, 70)
	local h = (3 + ctx.Rng:NextNumber(0, 2.5)) * s
	block(ctx, Vector3.new(0.9, h, 0.9) * Vector3.new(s, 1, s), cf * CFrame.new(0, h / 2, 0), green)
	block(ctx, Vector3.new(1.4, 0.6, 0.6) * s, cf * CFrame.new(0.9 * s, h * 0.5, 0), green)
	block(ctx, Vector3.new(0.6, 1.4, 0.6) * s, cf * CFrame.new(1.3 * s, h * 0.5 + 0.9 * s, 0), Parts.Lighten(green, 0.08))
	block(ctx, Vector3.new(0.3, 0.3, 0.3) * s, cf * CFrame.new(0, h + 0.1, 0), Color3.fromRGB(255, 120, 170))
end

PROPS.arch = function(ctx, _item, cf, s)
	local stone = Color3.fromRGB(200, 140, 95)
	local half = ctx.Map.PathWidth / 2 + 1.5
	for _, x in { -half, half } do
		block(ctx, Vector3.new(2, 9, 2.2), cf * CFrame.new(x, 4.5, 0), stone, { Material = Enum.Material.Sandstone })
	end
	block(ctx, Vector3.new(half * 2 + 3, 1.8, 2.6), cf * CFrame.new(0, 9.6, 0), Parts.Darken(stone, 0.08), { Material = Enum.Material.Sandstone })
	wedge(ctx, Vector3.new(2.6, 1.6, 2), cf * CFrame.new(-half + 1.5, 8, 0) * A(0, rad(90), 0), stone, { Material = Enum.Material.Sandstone })
	wedge(ctx, Vector3.new(2.6, 1.6, 2), cf * CFrame.new(half - 1.5, 8, 0) * A(0, rad(-90), 0), stone, { Material = Enum.Material.Sandstone })
	local _ = s
end

PROPS.riverbed = function(ctx, _item, cf, s)
	block(ctx, Vector3.new(3, 0.08, 14) * Vector3.new(s, 1, s), cf * CFrame.new(0, 0.04, 0), Color3.fromRGB(190, 150, 100), { CastShadow = false })
	block(ctx, Vector3.new(1.5, 0.1, 10) * Vector3.new(s, 1, s), cf * CFrame.new(0.4, 0.06, 1) * A(0, rad(8), 0), Color3.fromRGB(170, 130, 85), { CastShadow = false })
end

PROPS.bones = function(ctx, _item, cf, s)
	local bone = Color3.fromRGB(240, 235, 220)
	block(ctx, Vector3.new(1.8, 0.25, 0.25) * s, cf * CFrame.new(0, 0.12, 0), bone)
	block(ctx, Vector3.new(0.6, 0.6, 0.6) * s, cf * CFrame.new(1.1 * s, 0.3, 0), bone)
end

PROPS.pebbles = function(ctx, _item, cf, s)
	for i = 1, 3 do
		block(ctx, Vector3.new(0.5, 0.3, 0.4) * s, cf * CFrame.new(i * 0.6 - 1.2, 0.15, ctx.Rng:NextNumber(-0.5, 0.5)) * A(0, rad(i * 30), 0),
			Color3.fromRGB(170, 140, 110), { CastShadow = false })
	end
end

PROPS.pine = function(ctx, _item, cf, s)
	local dark = Color3.fromRGB(40, 95, 70)
	cyl(ctx, 2 * s, 0.8 * s, cf * CFrame.new(0, s, 0), Color3.fromRGB(100, 70, 50), "Y")
	for i = 0, 2 do
		local w = (4.2 - i * 1.1) * s
		local y = (2 + i * 1.7) * s
		block(ctx, Vector3.new(w, 1.8 * s, w), cf * CFrame.new(0, y, 0) * A(0, rad(i * 25), 0), dark)
		block(ctx, Vector3.new(w * 0.85, 0.35 * s, w * 0.85), cf * CFrame.new(0, y + 0.95 * s, 0) * A(0, rad(i * 25 + 10), 0), Color3.fromRGB(245, 250, 255))
	end
end

PROPS.snowHill = function(ctx, _item, cf, s)
	cyl(ctx, 2.2 * s, 12 * s, cf * CFrame.new(0, 0.6 * s, 0), Color3.fromRGB(245, 248, 255), "Y", { Material = Enum.Material.Snow })
	cyl(ctx, 2 * s, 7 * s, cf * CFrame.new(1 * s, 2 * s, 0), Color3.fromRGB(250, 252, 255), "Y", { Material = Enum.Material.Snow })
end

PROPS.icePatch = function(ctx, _item, cf, s)
	block(ctx, Vector3.new(6, 0.08, 4) * Vector3.new(s, 1, s), cf * CFrame.new(0, 0.05, 0), Color3.fromRGB(170, 215, 255),
		{ Material = Enum.Material.Ice, Transparency = 0.2, CastShadow = false })
end

PROPS.snowRock = function(ctx, item, cf, s)
	PROPS.rock(ctx, item, cf, s)
	block(ctx, Vector3.new(2.2, 0.4, 1.9) * s, cf * CFrame.new(0, 1.45 * s, 0) * A(rad(10), 0, rad(8)), Color3.fromRGB(250, 252, 255))
end

PROPS.frozenStream = function(ctx, item, _cf, _s)
	local p = item.Position
	block(ctx, Vector3.new(14, 0.12, ctx.Map.Bounds.Y * 2 + 12), CFrame.new(p.X, 0.05, p.Z), Color3.fromRGB(160, 210, 250),
		{ Material = Enum.Material.Ice, Transparency = 0.1 })
end

PROPS.fortWall = function(ctx, item, _cf, _s)
	local p = item.Position
	local stone = Color3.fromRGB(150, 160, 175)
	local along = if item.Rotation == 0 then Vector3.new(15, 4, 1.6) else Vector3.new(1.6, 4, 15)
	block(ctx, along, CFrame.new(p.X, 2, p.Z), stone, { Material = Enum.Material.Slate })
	for k = -2, 2 do
		local offset = if item.Rotation == 0 then Vector3.new(k * 3.2, 4.5, 0) else Vector3.new(0, 4.5, k * 3.2)
		block(ctx, Vector3.new(1.6, 1, 1.6), CFrame.new(p + offset), Parts.Lighten(stone, 0.1), { Material = Enum.Material.Slate })
	end
	block(ctx, along + Vector3.new(0.2, -3.7, 0.2), CFrame.new(p.X, 4.1, p.Z), Color3.fromRGB(250, 252, 255))
end

PROPS.column = function(ctx, _item, cf, s)
	local stone = Color3.fromRGB(170, 165, 150)
	local broken = ctx.Rng:NextNumber() < 0.45
	local h = if broken then (2 + ctx.Rng:NextNumber(0, 3)) * s else 8 * s
	block(ctx, Vector3.new(2.6, 0.6, 2.6) * Vector3.new(s, 1, s), cf * CFrame.new(0, 0.3, 0), Parts.Darken(stone, 0.1), { Material = Enum.Material.Slate })
	cyl(ctx, h, 1.7 * s, cf * CFrame.new(0, 0.6 + h / 2, 0) * A(if broken then rad(6) else 0, 0, 0), stone, "Y", { Material = Enum.Material.Slate })
	if not broken then
		block(ctx, Vector3.new(2.6, 0.6, 2.6) * Vector3.new(s, 1, s), cf * CFrame.new(0, 0.9 + h, 0), Parts.Darken(stone, 0.05), { Material = Enum.Material.Slate })
	else
		block(ctx, Vector3.new(1.4, 1.4, 3) * s, cf * CFrame.new(2 * s, 0.6, 1 * s) * A(rad(80), rad(30), 0), stone, { Material = Enum.Material.Slate })
	end
	block(ctx, Vector3.new(0.4, h * 0.6, 0.15), cf * CFrame.new(0.86 * s, 0.6 + h * 0.4, 0), Color3.fromRGB(70, 120, 50), { CastShadow = false })
end

PROPS.brokenWall = function(ctx, _item, cf, s)
	local stone = Color3.fromRGB(150, 145, 135)
	for i = -2, 2 do
		local h = (2 + ((i + 3) * 1.37) % 3.5) * s
		block(ctx, Vector3.new(1.8 * s, h, 1.4), cf * CFrame.new(i * 1.8 * s, h / 2, 0), if i % 2 == 0 then stone else Parts.Darken(stone, 0.08), { Material = Enum.Material.Slate })
	end
	block(ctx, Vector3.new(2, 1, 1.6) * s, cf * CFrame.new(1 * s, 0.5, 2 * s) * A(0, rad(30), rad(10)), Parts.Darken(stone, 0.12), { Material = Enum.Material.Slate })
	block(ctx, Vector3.new(6 * s, 0.25, 1.5), cf * CFrame.new(0, 2.3 * s, 0.1), Color3.fromRGB(70, 120, 50), { CastShadow = false })
end

PROPS.slab = function(ctx, _item, cf, s)
	block(ctx, Vector3.new(4, 0.25, 4) * Vector3.new(s, 1, s), cf * CFrame.new(0, 0.12, 0), Color3.fromRGB(140, 135, 125), { Material = Enum.Material.Slate, CastShadow = false })
end

PROPS.overgrowth = function(ctx, _item, cf, s)
	local green = Color3.fromRGB(60, 110, 50)
	ball(ctx, 2.4 * s, cf * CFrame.new(0, 0.7 * s, 0), green)
	block(ctx, Vector3.new(0.3, 1.5, 0.3) * s, cf * CFrame.new(0.7 * s, 1.4 * s, 0.2) * A(0, 0, rad(20)), Parts.Lighten(green, 0.1))
end

PROPS.torch = function(ctx, _item, cf, s)
	cyl(ctx, 3 * s, 0.4, cf * CFrame.new(0, 1.5 * s, 0), Color3.fromRGB(80, 60, 45), "Y")
	local flame = neon(ctx, Vector3.new(0.6, 0.8, 0.6) * s, cf * CFrame.new(0, 3.3 * s, 0) * A(0, rad(45), 0), Color3.fromRGB(255, 160, 60))
	light(flame, Color3.fromRGB(255, 160, 80), 14, 1.4)
end

PROPS.ruinTree = function(ctx, item, cf, s)
	local h = 5 * s
	cyl(ctx, h, 1.1 * s, cf * CFrame.new(0, h / 2, 0), Color3.fromRGB(90, 70, 55), "Y")
	canopy(ctx, cf * CFrame.new(0, h + 1.5 * s, 0), 4.6 * s, Color3.fromRGB(60, 95, 55))
	local _ = item
end

PROPS.building = function(ctx, _item, cf, s)
	local colors = { Color3.fromRGB(60, 62, 80), Color3.fromRGB(70, 60, 90), Color3.fromRGB(50, 70, 85) }
	local neonColors = { Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 230, 255), Color3.fromRGB(255, 200, 60) }
	local h = (8 + ctx.Rng:NextNumber(0, 10)) * s
	local w = 10 * s
	local body = colors[ctx.Rng:NextInteger(1, #colors)]
	local glow = neonColors[ctx.Rng:NextInteger(1, #neonColors)]
	block(ctx, Vector3.new(w, h, w), cf * CFrame.new(0, h / 2, 0), body, { Material = Enum.Material.Concrete })
	block(ctx, Vector3.new(w + 0.4, 0.6, w + 0.4), cf * CFrame.new(0, h + 0.3, 0), Parts.Darken(body, 0.2))
	for row = 1, math.floor(h / 3) do
		neon(ctx, Vector3.new(w + 0.1, 0.3, w + 0.1), cf * CFrame.new(0, row * 3 - 0.5, 0), if row % 2 == 0 then glow else Parts.Darken(glow, 0.6))
	end
	block(ctx, Vector3.new(2, 1.2, 2) * s, cf * CFrame.new(1.5 * s, h + 1.2, 1 * s), Color3.fromRGB(150, 150, 160))
end

PROPS.container = function(ctx, _item, cf, s)
	local colors = { Color3.fromRGB(200, 70, 50), Color3.fromRGB(50, 120, 200), Color3.fromRGB(220, 170, 50), Color3.fromRGB(60, 160, 100) }
	local color = colors[ctx.Rng:NextInteger(1, #colors)]
	block(ctx, Vector3.new(6, 2.6, 2.6) * s, cf * CFrame.new(0, 1.3 * s, 0), color, { Material = Enum.Material.DiamondPlate })
	for i = -2, 2 do
		block(ctx, Vector3.new(0.15, 2.4, 2.7) * s, cf * CFrame.new(i * 1.2 * s, 1.3 * s, 0), Parts.Darken(color, 0.2))
	end
end

PROPS.streetLight = function(ctx, _item, cf, s)
	cyl(ctx, 6 * s, 0.35, cf * CFrame.new(0, 3 * s, 0), Color3.fromRGB(60, 60, 70), "Y")
	block(ctx, Vector3.new(0.3, 0.3, 2) * s, cf * CFrame.new(0, 6 * s, -0.8 * s), Color3.fromRGB(60, 60, 70))
	local lamp = neon(ctx, Vector3.new(0.8, 0.3, 0.8) * s, cf * CFrame.new(0, 5.8 * s, -1.6 * s), Color3.fromRGB(255, 240, 200))
	light(lamp, Color3.fromRGB(255, 230, 190), 16, 1.2)
end

PROPS.neonSign = function(ctx, _item, cf, s)
	local colors = { Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 230, 255), Color3.fromRGB(150, 255, 90) }
	local color = colors[ctx.Rng:NextInteger(1, #colors)]
	for _, x in { -1.6, 1.6 } do
		block(ctx, Vector3.new(0.3, 4, 0.3) * s, cf * CFrame.new(x * s, 2 * s, 0), Color3.fromRGB(50, 50, 60))
	end
	local board = block(ctx, Vector3.new(4.2, 2, 0.3) * s, cf * CFrame.new(0, 4.5 * s, 0), Color3.fromRGB(25, 25, 35))
	neon(ctx, Vector3.new(3.6, 0.25, 0.35) * s, cf * CFrame.new(0, 5.1 * s, 0), color)
	neon(ctx, Vector3.new(2.4, 0.25, 0.35) * s, cf * CFrame.new(-0.5 * s, 4.4 * s, 0), color)
	light(board, color, 12, 1)
end

PROPS.crate = function(ctx, _item, cf, s)
	block(ctx, Vector3.new(1.8, 1.8, 1.8) * s, cf * CFrame.new(0, 0.9 * s, 0), Color3.fromRGB(150, 110, 70), { Material = Enum.Material.WoodPlanks })
end

PROPS.roadMarks = function(ctx, _item, _cf, _s)
	local layout = MapLayout.Get(ctx.Map.Id)
	local path = layout.Path
	local d = 2
	while d < path.Length - 2 do
		local p, dir = path:At(d)
		block(ctx, Vector3.new(0.35, 0.06, 1.8), CFrame.lookAt(p + Vector3.new(0, 0.2, 0), p + Vector3.new(0, 0.2, 0) + dir), Color3.fromRGB(240, 240, 240), { CastShadow = false })
		d += 5
	end
end

PROPS.portal = function(ctx, item, _cf, _s)
	local p = item.Position
	local _, dir = MapLayout.Get(ctx.Map.Id).Path:At(1)
	local cf = CFrame.lookAt(p, p + dir)
	local frame = Color3.fromRGB(60, 50, 80)
	for _, x in { -5, 5 } do
		block(ctx, Vector3.new(1.6, 9, 1.6), cf * CFrame.new(x, 4.5, 0), frame, { Material = Enum.Material.Slate })
	end
	block(ctx, Vector3.new(11.6, 1.6, 1.8), cf * CFrame.new(0, 9.5, 0), frame, { Material = Enum.Material.Slate })
	local field = neon(ctx, Vector3.new(8.4, 8.2, 0.3), cf * CFrame.new(0, 4.6, 0.4), Color3.fromRGB(200, 60, 255))
	field.Transparency = 0.35
	field.Name = "PortalField"
	light(field, Color3.fromRGB(200, 80, 255), 18, 2)
end

-- База: крупная, контрастная, с «сердцем», к которому крепится полоса HP
local BASES: { [string]: (Ctx, CFrame) -> () } = {
	castle = function(ctx, cf)
		local stone = Color3.fromRGB(170, 170, 180)
		block(ctx, Vector3.new(12, 1, 12), cf * CFrame.new(0, 0.5, 0), Parts.Darken(stone, 0.2), { Material = Enum.Material.Slate })
		block(ctx, Vector3.new(8, 7, 8), cf * CFrame.new(0, 4.5, 0), stone, { Material = Enum.Material.Slate })
		for _, x in { -3, -1, 1, 3 } do
			for _, z in { -4, 4 } do
				block(ctx, Vector3.new(1.2, 1.2, 1), cf * CFrame.new(x, 8.6, z), stone, { Material = Enum.Material.Slate })
			end
		end
		for _, corner in { Vector3.new(-5, 0, -5), Vector3.new(5, 0, -5), Vector3.new(-5, 0, 5), Vector3.new(5, 0, 5) } do
			cyl(ctx, 9, 3, cf * CFrame.new(corner.X, 4.5, corner.Z), Parts.Lighten(stone, 0.05), "Y", { Material = Enum.Material.Slate })
			wedge(ctx, Vector3.new(3.2, 2.5, 1.6), cf * CFrame.new(corner.X, 10.2, corner.Z + 0.8), Color3.fromRGB(60, 90, 200))
			wedge(ctx, Vector3.new(3.2, 2.5, 1.6), cf * CFrame.new(corner.X, 10.2, corner.Z - 0.8) * A(0, math.pi, 0), Color3.fromRGB(60, 90, 200))
		end
		block(ctx, Vector3.new(3, 4, 0.4), cf * CFrame.new(0, 3, -4.1), Color3.fromRGB(90, 60, 40))
	end,
	fortress = function(ctx, cf)
		local ice = Color3.fromRGB(190, 220, 245)
		block(ctx, Vector3.new(10, 1, 10), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(150, 160, 175), { Material = Enum.Material.Slate })
		block(ctx, Vector3.new(6.5, 6, 6.5), cf * CFrame.new(0, 4, 0), ice, { Material = Enum.Material.Ice })
		wedge(ctx, Vector3.new(6.5, 3, 3.25), cf * CFrame.new(0, 8.5, 1.62), Color3.fromRGB(245, 250, 255))
		wedge(ctx, Vector3.new(6.5, 3, 3.25), cf * CFrame.new(0, 8.5, -1.62) * A(0, math.pi, 0), Color3.fromRGB(245, 250, 255))
	end,
	bunker = function(ctx, cf)
		block(ctx, Vector3.new(12, 1, 12), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(40, 40, 50), { Material = Enum.Material.DiamondPlate })
		block(ctx, Vector3.new(8, 4, 8), cf * CFrame.new(0, 3, 0), Color3.fromRGB(70, 75, 90), { Material = Enum.Material.Metal })
		local dome = ball(ctx, 11, cf * CFrame.new(0, 3, 0), Color3.fromRGB(80, 220, 255), { Material = Enum.Material.ForceField, Transparency = 0.2 })
		dome.CastShadow = false
		neon(ctx, Vector3.new(8.2, 0.3, 8.2), cf * CFrame.new(0, 5.1, 0), Color3.fromRGB(80, 220, 255))
	end,
	temple = function(ctx, cf)
		local stone = Color3.fromRGB(175, 165, 140)
		for i = 0, 3 do
			local w = 12 - i * 2.5
			block(ctx, Vector3.new(w, 1.6, w), cf * CFrame.new(0, 0.8 + i * 1.6, 0), if i % 2 == 0 then stone else Parts.Darken(stone, 0.08), { Material = Enum.Material.Slate })
		end
		local flame = neon(ctx, Vector3.new(1.4, 2, 1.4), cf * CFrame.new(0, 7.6, 0) * A(0, rad(45), 0), Color3.fromRGB(255, 170, 60))
		light(flame, Color3.fromRGB(255, 170, 80), 24, 2)
	end,
}

local BASE_STYLE = { grass = "castle", desert = "castle", snow = "fortress", ruins = "temple", neon = "bunker" }

PROPS.base = function(ctx, item, _cf, _s)
	local p = item.Position
	local _, dir = MapLayout.Get(ctx.Map.Id).Path:At(math.huge)
	local cf = CFrame.lookAt(p, p - dir) -- вход базы смотрит навстречу врагам
	BASES[BASE_STYLE[ctx.Map.Theme] or "castle"](ctx, cf)
	local heart = Parts.Block(ctx.Folder, Vector3.new(1, 1, 1), ctx.Origin * cf * CFrame.new(0, 12, 0), Color3.new(), { Name = "BaseAnchor", Transparency = 1 })
	heart.CanQuery = false
end

------------------------------------------------------------------------
-- Земля, края, дорога
------------------------------------------------------------------------

local function ground(ctx: Ctx)
	local map = ctx.Map
	local bx, bz = map.Bounds.X, map.Bounds.Y
	local tile = 12
	local material = ({ grass = Enum.Material.Grass, desert = Enum.Material.Sand, snow = Enum.Material.Snow,
		ruins = Enum.Material.Grass, neon = Enum.Material.Asphalt })[map.Theme] or Enum.Material.SmoothPlastic
	local x = -bx - 6
	local ix = 0
	while x < bx + 6 do
		local z = -bz - 6
		local iz = 0
		while z < bz + 6 do
			local w = math.min(tile, bx + 6 - x)
			local d = math.min(tile, bz + 6 - z)
			local color = if (ix + iz) % 2 == 0 then map.Palette.Ground else map.Palette.Ground2
			-- Земля твёрдая: по ней ходит персонаж игрока (декор и дорога — без коллизии)
			local part = block(ctx, Vector3.new(w, 2, d), CFrame.new(x + w / 2, -1, z + d / 2), color,
				{ Material = material, CastShadow = false, CanCollide = true })
			part.Name = "Ground"
			z += d
			iz += 1
		end
		x += tile
		ix += 1
	end
	-- Низкий борт вокруг поля
	local edge = Parts.Darken(map.Palette.Ground2, 0.35)
	local sizes = {
		{ Vector3.new(bx * 2 + 16, 3, 4), CFrame.new(0, 1.5, bz + 8) },
		{ Vector3.new(bx * 2 + 16, 3, 4), CFrame.new(0, 1.5, -bz - 8) },
		{ Vector3.new(4, 3, bz * 2 + 12), CFrame.new(bx + 8, 1.5, 0) },
		{ Vector3.new(4, 3, bz * 2 + 12), CFrame.new(-bx - 8, 1.5, 0) },
	}
	for _, entry in sizes do
		block(ctx, entry[1], entry[2], edge, { Material = if map.Theme == "neon" then Enum.Material.Concrete else Enum.Material.Slate, CanCollide = true })
	end
	-- Невидимые стены по краю поля: персонаж не упадёт с карты в пустоту
	local walls = {
		{ Vector3.new(bx * 2 + 20, 40, 2), CFrame.new(0, 20, bz + 9) },
		{ Vector3.new(bx * 2 + 20, 40, 2), CFrame.new(0, 20, -bz - 9) },
		{ Vector3.new(2, 40, bz * 2 + 20), CFrame.new(bx + 9, 20, 0) },
		{ Vector3.new(2, 40, bz * 2 + 20), CFrame.new(-bx - 9, 20, 0) },
	}
	for _, entry in walls do
		local wall = block(ctx, entry[1], entry[2], edge, { Transparency = 1, CanCollide = true, CastShadow = false })
		wall.Name = "Boundary"
		wall.CanQuery = false
	end
end

local function road(ctx: Ctx)
	local map = ctx.Map
	local points = map.Waypoints
	local width = map.PathWidth
	local material = ({ grass = Enum.Material.Ground, desert = Enum.Material.Sandstone, snow = Enum.Material.Ice,
		ruins = Enum.Material.Cobblestone, neon = Enum.Material.Asphalt })[map.Theme] or Enum.Material.SmoothPlastic
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local mid = (a + b) / 2
		local length = (b - a).Magnitude
		local cf = CFrame.lookAt(mid, b)
		local surface = block(ctx, Vector3.new(width, 0.3, length + width), cf * CFrame.new(0, 0.05, 0), map.Palette.Path, { Material = material, CastShadow = false })
		surface.Name = "Road"
		for _, side in { -1, 1 } do
			local edgePart = block(ctx, Vector3.new(0.6, 0.35, length + width * 0.4), cf * CFrame.new(side * (width / 2 + 0.3), 0.12, 0), map.Palette.PathEdge,
				{ Material = if map.Theme == "neon" then Enum.Material.Neon else Enum.Material.Slate, CastShadow = false })
			edgePart.Name = "RoadEdge"
		end
	end
end

-- Строит карту в папке parent. Возвращает Folder карты.
function MapBuilder.Build(mapId: string, origin: Vector3, parent: Instance): Folder
	local map = Maps.ById[mapId]
	local folder = Instance.new("Folder")
	folder.Name = "Map_" .. mapId
	local ctx: Ctx = { Folder = folder, Origin = CFrame.new(origin), Map = map, Rng = Random.new(map.Seed * 31) }
	ground(ctx)
	road(ctx)
	local layout = MapLayout.Get(mapId)
	for _, item in layout.Items do
		local builder = PROPS[item.Kind]
		if builder then
			local cf = CFrame.new(item.Position) * A(0, rad(item.Rotation), 0)
			builder(ctx, item, cf, item.Scale)
		end
	end
	folder.Parent = parent
	return folder
end

return MapBuilder
