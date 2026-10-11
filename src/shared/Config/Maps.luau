--[[
	Пять карт. Все координаты локальные (центр карты = 0, земля на Y = 0);
	матч размещает карту в своём слоте мира (см. Game.Match.SlotOrigin).

	Waypoints — маршрут врагов (первая точка — портал, последняя — база).
	Bounds    — полуразмеры игрового поля по X и Z.
	NoBuild   — дополнительные запретные прямоугольники (вода, лёд и т.п.).
	Decor     — что генератор (Logic/MapLayout) расставит по карте.
	Lighting  — атмосфера, клиент применяет её, пока игрок в матче.
]]

export type DecorSpec = {
	Kind: string,
	Count: number,
	Radius: number, -- радиус «следа» для запрета размещения (0 — не мешает)
	Zone: string?, -- "edge" — только у краёв, "any" — где угодно
	PathGap: number?,
}

export type Map = {
	Id: string,
	Name: string,
	Description: string,
	Difficulty: number,
	BaseHealth: number,
	Bounds: Vector2,
	PathWidth: number,
	Waypoints: { Vector3 },
	NoBuild: { { Min: Vector2, Max: Vector2 } },
	Seed: number,
	Theme: string,
	Palette: { [string]: Color3 },
	Decor: { DecorSpec },
	Lighting: { [string]: any },
	Camera: { Position: Vector3, LookAt: Vector3 },
	PlayerSpawn: Vector3,
	Accent: Color3,
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function v(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

local list: { Map } = {
	{
		Id = "greenfield", Name = "Greenfield", Description = "A green valley with a stream and a bridge. The best map to start on.",
		Difficulty = 1.0, BaseHealth = 120, Bounds = Vector2.new(84, 62), PathWidth = 8, Seed = 101, Theme = "grass",
		Waypoints = { v(-82, -38), v(-40, -38), v(-40, 22), v(0, 22), v(0, -26), v(40, -26), v(40, 34), v(76, 34) },
		NoBuild = { { Min = Vector2.new(15, -62), Max = Vector2.new(25, 62) } }, -- ручей
		Palette = { Ground = c(106, 176, 76), Ground2 = c(94, 162, 66), Path = c(196, 164, 112), PathEdge = c(150, 120, 80), Accent = c(90, 150, 255) },
		Decor = {
			{ Kind = "tree", Count = 26, Radius = 3, Zone = "edge" },
			{ Kind = "tree", Count = 6, Radius = 3, Zone = "any", PathGap = 6 },
			{ Kind = "rock", Count = 14, Radius = 1.8, Zone = "any" },
			{ Kind = "hill", Count = 5, Radius = 7, Zone = "edge" },
			{ Kind = "bush", Count = 18, Radius = 1.2, Zone = "any" },
			{ Kind = "flowers", Count = 26, Radius = 0, Zone = "any", PathGap = 0.5 },
		},
		Lighting = { ClockTime = 14, Brightness = 2.6, Ambient = c(120, 120, 125), OutdoorAmbient = c(150, 160, 150),
			FogColor = c(190, 220, 255), Haze = 0.6, Density = 0.22, AtmosphereColor = c(200, 225, 255), Saturation = 0.15, Tint = c(255, 255, 250) },
		Camera = { Position = Vector3.new(0, 95, 92), LookAt = Vector3.new(0, 0, 4) },
		PlayerSpawn = Vector3.new(-62, 0, 52),
		Accent = c(106, 176, 76),
	},
	{
		Id = "desert", Name = "Desert Canyon", Description = "A canyon of red rocks, cacti and stone arches.",
		Difficulty = 1.15, BaseHealth = 110, Bounds = Vector2.new(84, 62), PathWidth = 8, Seed = 202, Theme = "desert",
		Waypoints = { v(-82, 46), v(-48, 46), v(-48, -12), v(-14, -12), v(-14, 40), v(24, 40), v(24, -44), v(58, -44), v(58, 10), v(78, 10) },
		NoBuild = {},
		Palette = { Ground = c(226, 190, 128), Ground2 = c(214, 176, 112), Path = c(186, 140, 96), PathEdge = c(150, 100, 70), Accent = c(220, 110, 70) },
		Decor = {
			{ Kind = "redRock", Count = 18, Radius = 5, Zone = "edge" },
			{ Kind = "cactus", Count = 20, Radius = 1.4, Zone = "any" },
			{ Kind = "arch", Count = 3, Radius = 0, Zone = "path" },
			{ Kind = "riverbed", Count = 5, Radius = 0, Zone = "any", PathGap = 1 },
			{ Kind = "bones", Count = 8, Radius = 0, Zone = "any", PathGap = 1 },
			{ Kind = "pebbles", Count = 22, Radius = 0, Zone = "any", PathGap = 0.5 },
		},
		Lighting = { ClockTime = 15.5, Brightness = 3, Ambient = c(150, 120, 95), OutdoorAmbient = c(185, 145, 110),
			FogColor = c(255, 220, 170), Haze = 1.6, Density = 0.3, AtmosphereColor = c(255, 215, 160), Saturation = 0.1, Tint = c(255, 240, 220) },
		Camera = { Position = Vector3.new(0, 98, 92), LookAt = Vector3.new(0, 0, 2) },
		PlayerSpawn = Vector3.new(-66, 0, 20),
		Accent = c(220, 110, 70),
	},
	{
		Id = "snow", Name = "Snow Valley", Description = "A long snowy spiral to an ice fortress, past a frozen stream.",
		Difficulty = 1.3, BaseHealth = 100, Bounds = Vector2.new(84, 62), PathWidth = 8, Seed = 303, Theme = "snow",
		Waypoints = { v(-82, -48), v(56, -48), v(56, 40), v(-52, 40), v(-52, -14), v(28, -14), v(28, 14), v(-8, 14) },
		NoBuild = { { Min = Vector2.new(68, -62), Max = Vector2.new(84, 62) } }, -- замёрзший ручей у края
		Palette = { Ground = c(236, 242, 250), Ground2 = c(220, 230, 244), Path = c(170, 185, 205), PathEdge = c(130, 145, 170), Accent = c(120, 190, 255) },
		Decor = {
			{ Kind = "pine", Count = 28, Radius = 2.6, Zone = "edge" },
			{ Kind = "pine", Count = 6, Radius = 2.6, Zone = "any", PathGap = 6 },
			{ Kind = "snowHill", Count = 6, Radius = 6, Zone = "edge" },
			{ Kind = "icePatch", Count = 7, Radius = 0, Zone = "any", PathGap = 1 },
			{ Kind = "snowRock", Count = 12, Radius = 1.8, Zone = "any" },
		},
		Lighting = { ClockTime = 10.5, Brightness = 2.4, Ambient = c(150, 160, 180), OutdoorAmbient = c(170, 180, 200),
			FogColor = c(230, 240, 255), Haze = 2.2, Density = 0.35, AtmosphereColor = c(225, 235, 255), Saturation = 0.05, Tint = c(235, 245, 255) },
		Camera = { Position = Vector3.new(0, 100, 90), LookAt = Vector3.new(0, 0, 0) },
		PlayerSpawn = Vector3.new(-66, 0, 54),
		Accent = c(120, 190, 255),
	},
	{
		Id = "ruins", Name = "Forgotten Ruins", Description = "Ancient pillars and crumbling walls in an overgrown dusk.",
		Difficulty = 1.35, BaseHealth = 100, Bounds = Vector2.new(84, 64), PathWidth = 8, Seed = 404, Theme = "ruins",
		Waypoints = { v(0, -62), v(0, -36), v(-58, -36), v(-58, 0), v(54, 0), v(54, 34), v(-22, 34), v(-22, 58) },
		NoBuild = {},
		Palette = { Ground = c(84, 118, 70), Ground2 = c(74, 106, 62), Path = c(150, 145, 135), PathEdge = c(110, 105, 98), Accent = c(255, 170, 70) },
		Decor = {
			{ Kind = "column", Count = 16, Radius = 1.8, Zone = "any", PathGap = 3 },
			{ Kind = "brokenWall", Count = 10, Radius = 4, Zone = "edge" },
			{ Kind = "slab", Count = 14, Radius = 0, Zone = "any", PathGap = 1 },
			{ Kind = "overgrowth", Count = 22, Radius = 1.6, Zone = "any" },
			{ Kind = "torch", Count = 10, Radius = 0.8, Zone = "any", PathGap = 1.5 },
			{ Kind = "ruinTree", Count = 12, Radius = 3, Zone = "edge" },
		},
		Lighting = { ClockTime = 18.2, Brightness = 1.6, Ambient = c(85, 80, 95), OutdoorAmbient = c(110, 100, 115),
			FogColor = c(180, 150, 140), Haze = 2.6, Density = 0.42, AtmosphereColor = c(190, 150, 130), Saturation = 0.05, Tint = c(255, 225, 200) },
		Camera = { Position = Vector3.new(0, 100, 92), LookAt = Vector3.new(0, 0, 0) },
		PlayerSpawn = Vector3.new(30, 0, -52),
		Accent = c(255, 170, 70),
	},
	{
		Id = "neon", Name = "Neon City", Description = "A city at night: roads, neon signs and shipping containers. The hardest map.",
		Difficulty = 1.5, BaseHealth = 100, Bounds = Vector2.new(84, 62), PathWidth = 8, Seed = 505, Theme = "neon",
		Waypoints = { v(-82, -30), v(-30, -30), v(-30, 30), v(18, 30), v(18, -42), v(58, -42), v(58, 26), v(78, 26) },
		NoBuild = {},
		Palette = { Ground = c(40, 42, 52), Ground2 = c(34, 36, 46), Path = c(60, 62, 72), PathEdge = c(255, 210, 60), Accent = c(255, 60, 200) },
		Decor = {
			{ Kind = "building", Count = 14, Radius = 7, Zone = "edge" },
			{ Kind = "container", Count = 12, Radius = 3.2, Zone = "any", PathGap = 3 },
			{ Kind = "streetLight", Count = 16, Radius = 0.8, Zone = "path" },
			{ Kind = "neonSign", Count = 8, Radius = 1.5, Zone = "any", PathGap = 3 },
			{ Kind = "crate", Count = 14, Radius = 1.2, Zone = "any" },
		},
		Lighting = { ClockTime = 0.2, Brightness = 1.2, Ambient = c(70, 60, 100), OutdoorAmbient = c(80, 70, 120),
			FogColor = c(60, 40, 90), Haze = 1.4, Density = 0.3, AtmosphereColor = c(120, 70, 170), Saturation = 0.25, Tint = c(235, 225, 255) },
		Camera = { Position = Vector3.new(0, 96, 92), LookAt = Vector3.new(0, 0, 0) },
		PlayerSpawn = Vector3.new(-62, 0, 50),
		Accent = c(255, 60, 200),
	},
}

local byId: { [string]: Map } = {}
for _, map in list do
	assert(byId[map.Id] == nil, "Duplicate map " .. map.Id)
	byId[map.Id] = map
end

return {
	List = list,
	ById = byId,
	Default = "greenfield",
}
