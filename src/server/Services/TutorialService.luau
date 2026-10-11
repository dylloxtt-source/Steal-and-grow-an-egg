--[[
	TutorialService — пошаговое обучение. Шаг хранится в profile.tutorial
	(индекс в Config/Tutorial.Steps; больше длины списка — обучение пройдено).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tutorial = require(Shared.Config.Tutorial)
local Format = require(Shared.Logic.Format)

local TutorialService = {}

local services

function TutorialService:Reached(session: any, key: string)
	local profile = session.Profile
	local step = Tutorial.Steps[profile.tutorial]
	if not step or step.Key ~= key then
		return
	end
	profile.tutorial += 1
	if profile.tutorial > #Tutorial.Steps then
		profile.coins += Tutorial.Reward
		services.DataService:Notify(session.Player, "🎓 Обучение пройдено! +" .. Format.Money(Tutorial.Reward), "success")
	end
	services.DataService:MarkDirty(session.Player)
end

function TutorialService:Init(registry)
	services = registry
end

function TutorialService:Start()
	services.NetService:Handle("Tutorial", function(_player, session, payload)
		if type(payload) == "table" and payload.skip == true then
			session.Profile.tutorial = #Tutorial.Steps + 1
			return true, nil
		end
		return false, "Неверный запрос"
	end)
end

return TutorialService
