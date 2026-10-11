--[[
	Точка входа клиента. Порядок важен: сначала состояние и корневой GUI,
	затем мир (эффекты, враги, башни), затем интерфейсы лобби и матча.
]]

local Players = game:GetService("Players")

local State = require(script.State)
local Root = require(script.UI.Root)
local Notifications = require(script.UI.Notifications)
local Controllers = script.Controllers

State.Init()
local screen = Root.Init()
Notifications.Init(screen)

require(Controllers.Effects).Init()
require(Controllers.EnemyRenderer).Init()
require(Controllers.TowerAnimator).Init()
require(Controllers.FxController).Init()
require(Controllers.PlacementController).Init()
require(Controllers.LightingController).Init()
require(Controllers.LobbyController).Init(screen)
require(Controllers.HUDController).Init(screen)
require(Controllers.ShopController).Init(screen)
require(Controllers.SettingsController).Init(screen)
require(Controllers.ResultsController).Init(screen)
require(script.UI.Kit).InitTooltip(screen)

-- Профиль и (если игрок переподключился в матч) снимок матча
task.spawn(function()
	local player = Players.LocalPlayer
	local waited = 0
	while not player:GetAttribute("Loaded") and waited < 30 do
		waited += task.wait(0.25)
	end
	State.Action("RequestState")
end)
