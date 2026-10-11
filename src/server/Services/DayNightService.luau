--[[
	DayNightService — цикл дня и ночи. Ночью редкие яйца встречаются чаще,
	появляются Moon Melon, растут шансы мутаций; в начале ночи яйца на дорожке
	перезагружаются. Клиент читает атрибуты IsNight / PhaseEndsAt у ReplicatedStorage.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)

local DayNightService = {}

local services
local isNight = false

function DayNightService:IsNight(): boolean
	return isNight
end

local function applyLighting(night: boolean)
	local info = TweenInfo.new(6, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		ClockTime = if night then 0.5 else 14,
		Ambient = if night then Color3.fromRGB(70, 60, 110) else Color3.fromRGB(110, 110, 120),
		OutdoorAmbient = if night then Color3.fromRGB(90, 80, 140) else Color3.fromRGB(150, 150, 160),
		Brightness = if night then 1.2 else 2.4,
	}):Play()
end

local function setPhase(night: boolean)
	isNight = night
	local duration = if night then Game.DayNight.NightSeconds else Game.DayNight.DaySeconds
	ReplicatedStorage:SetAttribute("IsNight", night)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + duration)
	applyLighting(night)
	if night then
		services.WorldEggService:ResetEggs()
		for player in services.DataService.Sessions do
			services.DataService:Notify(player, "🌙 Ночь! Редкие яйца ×2, появились Moon Melon", "night")
		end
	end
	return duration
end

function DayNightService:Init(registry)
	services = registry
end

function DayNightService:Start()
	task.spawn(function()
		local night = false
		while true do
			local duration = setPhase(night)
			task.wait(duration)
			night = not night
		end
	end)
end

return DayNightService
