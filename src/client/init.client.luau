--[[
	Точка входа клиента: состояние, интерфейс и локальные системы мира.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local State = require(script:WaitForChild("State"))
local UI = script:WaitForChild("UI")
local World = script:WaitForChild("World")

local Router = require(UI.Router)
local HUD = require(UI.HUD)

State.Init()
local screen = Router.Init()

-- Окна (одновременно открыто только одно)
Router.Register("Shop", require(UI.ShopPanel))
Router.Register("Eggs", require(UI.EggsPanel))
Router.Register("Pets", require(UI.PetsPanel))
Router.Register("Feed", require(UI.FeedPanel))
Router.Register("Farm", require(UI.FarmPanel))
Router.Register("Index", require(UI.IndexPanel))
Router.Register("Quests", require(UI.QuestsPanel))
Router.Register("Settings", require(UI.SettingsPanel))

-- Постоянные слои
HUD:Build(screen)
HUD:Start()
require(UI.Notifications):Build(screen)
require(UI.StealAlert):Build(screen)
require(UI.Tutorial):Build(screen)
require(UI.HatchReveal):Build(screen)

require(World.Prompts).Start()
require(World.Billboards).Start()
require(World.Animator).Start()
require(World.Effects).Start()

State.Changed.Event:Connect(function()
	Router.RefreshAll()
end)

-- Список игроков не нужен: HUD показывает всё важное
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

-- Сервер присылает снимок после загрузки; на случай гонки запрашиваем его сами
task.spawn(function()
	local player = Players.LocalPlayer
	while not player:GetAttribute("Loaded") do
		task.wait(0.25)
	end
	State.Fire("RequestState")
end)

print("[Client] Steal and Grow an Egg загружен")
