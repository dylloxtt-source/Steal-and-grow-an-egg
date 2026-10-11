--[[
	Система координат карты (в студах). Y = 0 — верх земли.

	        +Z (дорожка с биомами, Z 40..1140, ширина 90)
	                  |
	  [  Площадь / SAFE ZONE: X -132..132, Z -40..40  ]
	  [ База1 ][ База2 ][ База3 ]   ряд A, центр Z = -82
	  [ База4 ][ База5 ][ База6 ]   ряд B, центр Z = -170
	        -Z

	Все базы смотрят входом на +Z (к площади). Локальные координаты базы:
	x — вправо, z — к входу. Размер базы 72x72, вход по центру передней стороны.
]]

local Map = {}

Map.GroundY = 0
Map.WallHeight = 28
Map.TileSize = 18

Map.Plaza = {
	Min = Vector3.new(-132, 0, -40),
	Max = Vector3.new(132, 0, 40),
}

Map.Lane = {
	HalfWidth = 45,
	ZStart = 40,
	ZEnd = 1140,
}

Map.BaseArea = {
	Min = Vector3.new(-132, 0, -226),
	Max = Vector3.new(132, 0, -40),
}

Map.Spawn = Vector3.new(0, 0, -12)

Map.PlotSize = 72
Map.PlotCenters = {
	Vector3.new(-88, 0, -82),
	Vector3.new(0, 0, -82),
	Vector3.new(88, 0, -82),
	Vector3.new(-88, 0, -170),
	Vector3.new(0, 0, -170),
	Vector3.new(88, 0, -170),
}

Map.PlotColors = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(170, 90, 255),
	Color3.fromRGB(60, 210, 120),
	Color3.fromRGB(255, 140, 40),
}

-- Локальная раскладка базы
Map.PlotLayout = {
	EntranceHalfWidth = 9,
	Incubators = {
		Vector3.new(-29, 0, -25),
		Vector3.new(-29, 0, -15),
		Vector3.new(-29, 0, -5),
		Vector3.new(-29, 0, 5),
		Vector3.new(-29, 0, 15),
		Vector3.new(-29, 0, 25),
	},
	PenMin = Vector3.new(-21, 0, -31),
	PenMax = Vector3.new(15, 0, 16),
	Farms = {
		Vector3.new(23, 0, -27),
		Vector3.new(31, 0, -27),
		Vector3.new(23, 0, -19),
		Vector3.new(31, 0, -19),
		Vector3.new(23, 0, -11),
		Vector3.new(31, 0, -11),
		Vector3.new(23, 0, -3),
		Vector3.new(31, 0, -3),
	},
	Vault = Vector3.new(26, 0, 12),
	Lock = Vector3.new(26, 0, 26),
	Sign = Vector3.new(0, 0, -34),
	Delivery = Vector3.new(0, 0, 26),
}

Map.Shops = {
	{ Id = "eggs", Name = "EGG SHOP", Tab = "Eggs", Position = Vector3.new(-96, 0, 6), Color = Color3.fromRGB(255, 194, 26) },
	{ Id = "food", Name = "FOOD & SEEDS", Tab = "Food", Position = Vector3.new(-52, 0, 18), Color = Color3.fromRGB(92, 227, 92) },
	{ Id = "sell", Name = "SELL", Tab = "Sell", Position = Vector3.new(52, 0, 18), Color = Color3.fromRGB(230, 50, 50) },
	{ Id = "upgrades", Name = "UPGRADES", Tab = "Upgrades", Position = Vector3.new(96, 0, 6), Color = Color3.fromRGB(63, 169, 255) },
}

Map.IndexBoard = Vector3.new(-30, 0, -28)
Map.QuestBoard = Vector3.new(30, 0, -28)

function Map.InPlaza(position: Vector3): boolean
	return position.X >= Map.Plaza.Min.X and position.X <= Map.Plaza.Max.X
		and position.Z >= Map.Plaza.Min.Z and position.Z <= Map.Plaza.Max.Z
end

function Map.InLane(position: Vector3): boolean
	return math.abs(position.X) <= Map.Lane.HalfWidth
		and position.Z >= Map.Lane.ZStart and position.Z <= Map.Lane.ZEnd
end

function Map.PlotWorld(plotIndex: number, localPosition: Vector3): Vector3
	return Map.PlotCenters[plotIndex] + localPosition
end

function Map.InPlot(plotIndex: number, position: Vector3, margin: number?): boolean
	local center = Map.PlotCenters[plotIndex]
	local half = Map.PlotSize / 2 + (margin or 0)
	return math.abs(position.X - center.X) <= half and math.abs(position.Z - center.Z) <= half
end

return Map
