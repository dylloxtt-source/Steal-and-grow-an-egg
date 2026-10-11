--[[
	Prompts — локальная фильтрация подсказок и клиентские действия.
	• OwnerOnly = userId — подсказку видит только владелец.
	• NotOwner  = userId — видят все, кроме владельца (кнопка «Steal»).
	• ClientAction — подсказка открывает окно на клиенте (сервер её игнорирует,
	  а там, где нужно, сам решает по своему обработчику).
	Сервер всё равно проверяет каждое действие — фильтр нужен только для удобства.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Router = require(script.Parent.Parent.UI.Router)

local Prompts = {}

local userId = Players.LocalPlayer.UserId
local applying: { [ProximityPrompt]: boolean } = {}
local serverEnabled: { [ProximityPrompt]: boolean } = {} -- значение, которое прислал сервер

local function allowed(prompt: ProximityPrompt): boolean
	local ownerOnly = prompt:GetAttribute("OwnerOnly")
	if ownerOnly ~= nil and ownerOnly ~= userId then
		return false
	end
	local notOwner = prompt:GetAttribute("NotOwner")
	if notOwner ~= nil and notOwner == userId then
		return false
	end
	return true
end

-- Локально выставляет Enabled = (значение сервера) И (подсказка разрешена этому игроку)
local function apply(prompt: ProximityPrompt)
	local desired = serverEnabled[prompt] == true and allowed(prompt)
	if prompt.Enabled ~= desired then
		applying[prompt] = true
		prompt.Enabled = desired
		applying[prompt] = nil
	end
end

local function watch(prompt: ProximityPrompt)
	if serverEnabled[prompt] ~= nil then
		return
	end
	serverEnabled[prompt] = prompt.Enabled
	apply(prompt)
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if applying[prompt] then
			return
		end
		-- Изменение пришло с сервера
		serverEnabled[prompt] = prompt.Enabled
		apply(prompt)
	end)
	prompt.AttributeChanged:Connect(function()
		apply(prompt)
	end)
	prompt.Destroying:Connect(function()
		serverEnabled[prompt] = nil
	end)
end

local function onTriggered(prompt: ProximityPrompt)
	local action = prompt:GetAttribute("ClientAction")
	if action == "OpenShop" then
		Router.Open("Shop", prompt:GetAttribute("Tab"))
	elseif action == "OpenIndex" then
		Router.Open("Index")
	elseif action == "OpenQuests" then
		Router.Open("Quests")
	elseif action == "OpenEggs" then
		Router.Open("Eggs")
	elseif action == "OpenFeed" then
		Router.Open("Feed", prompt:GetAttribute("Uid"))
	elseif action == "OpenFarm" then
		Router.Open("Farm", prompt:GetAttribute("Slot"))
	end
end

function Prompts.Start()
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			watch(descendant)
		end
	end
	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			watch(descendant)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(onTriggered)
	-- Стиль подсказок по умолчанию оставляем стандартным: он адаптирован под мобильные
end

return Prompts
