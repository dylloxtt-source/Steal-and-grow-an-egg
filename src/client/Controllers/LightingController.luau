--[[
	Освещение и атмосфера. Пока игрок в матче, клиент применяет настройки
	его карты (Config/Maps → Lighting), в лобби — дневной свет лобби.
	Изменения Lighting на клиенте видит только этот игрок, поэтому матчи
	на разных картах в одном сервере не мешают друг другу.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maps = require(Shared.Config.Maps)

local LightingController = {}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

LightingController.Lobby = {
	ClockTime = 14.5, Brightness = 2.5, Ambient = c(125, 125, 130), OutdoorAmbient = c(150, 150, 160),
	FogColor = c(200, 220, 255), Haze = 0.5, Density = 0.25, AtmosphereColor = c(205, 225, 255), Saturation = 0.1, Tint = c(255, 255, 255),
}

local atmosphere: Atmosphere
local correction: ColorCorrectionEffect
local bloom: BloomEffect
local current: string? = nil

local function ensure()
	local function get(className: string, name: string): any
		local found = Lighting:FindFirstChild(name)
		if not found then
			found = Instance.new(className)
			found.Name = name
			found.Parent = Lighting
		end
		return found
	end
	atmosphere = get("Atmosphere", "TD_Atmosphere")
	correction = get("ColorCorrectionEffect", "TD_Color")
	bloom = get("BloomEffect", "TD_Bloom")
end

function LightingController.Apply(config: { [string]: any }, neon: boolean?)
	ensure()
	local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Lighting.ClockTime = config.ClockTime
	Lighting.GlobalShadows = true
	TweenService:Create(Lighting, info, {
		Brightness = config.Brightness, Ambient = config.Ambient, OutdoorAmbient = config.OutdoorAmbient,
	}):Play()
	TweenService:Create(atmosphere, info, {
		Density = config.Density, Haze = config.Haze, Color = config.FogColor, Decay = config.AtmosphereColor, Glare = 0, Offset = 0.1,
	}):Play()
	TweenService:Create(correction, info, { Saturation = config.Saturation, TintColor = config.Tint, Contrast = 0.05 }):Play()
	bloom.Intensity = if neon then 0.8 else 0.25
	bloom.Size = 24
	bloom.Threshold = if neon then 1.1 else 1.8
end

local function update()
	local mapId = Players.LocalPlayer:GetAttribute("MapId")
	local key = if Players.LocalPlayer:GetAttribute("MatchId") and mapId then mapId else "lobby"
	if key == current then
		return
	end
	current = key
	local map = Maps.ById[key]
	if map then
		LightingController.Apply(map.Lighting, map.Theme == "neon")
	else
		LightingController.Apply(LightingController.Lobby, false)
	end
end

function LightingController.Init()
	Players.LocalPlayer:GetAttributeChangedSignal("MatchId"):Connect(update)
	Players.LocalPlayer:GetAttributeChangedSignal("MapId"):Connect(update)
	update()
end

return LightingController
