--[[
	WorldEggService — яйца и еда на дорожке.

	• В каждой зоне держится до MaxEggs яиц; редкость — по весам зоны,
	  ночью Rare+ встречаются в NightLuck раз чаще (Secret — ещё чаще).
	• Подбор — ProximityPrompt на сервере: одно яйцо не может достаться двоим
	  (флаг Taken ставится до любых других действий, без yield).
	• Черта Luck: шанс, что подобранное яйцо улучшится на одну редкость.
	• Еда лежит на земле и подбирается касанием.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Foods = require(Shared.Config.Foods)
local Game = require(Shared.Config.Game)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Config.Zones)
local Profile = require(Shared.Logic.Profile)
local WeightedRandom = require(Shared.Logic.WeightedRandom)
local EggModel = require(Shared.Visual.EggModel)
local Studs = require(Shared.Visual.Studs)

local WorldEggService = {}

local services
local rng = Random.new()
local container: Folder
local zoneState: { [string]: { eggs: { [Model]: boolean }, count: number, nextSpawn: number, foods: number, nextFood: number } } = {}

-- Создаёт яйцо-подбираемый предмет. onTriggered(player, model) вызывается сервером.
function WorldEggService:CreatePickup(eggId: string, position: Vector3, actionText: string,
	onTriggered: (Player, Model) -> ()): (Model, ProximityPrompt)
	local egg = Eggs.ById[eggId]
	local rarity = Rarities.ById[egg.Rarity]
	local model = EggModel.Build(eggId, 1)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	local ring = Studs.Block(model, Vector3.new(0.2, 4, 4), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		rarity.Color, { Name = "Ring", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, CanCollide = false, Studs = false })
	ring.Transparency = 0.35
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model:SetAttribute("EggId", eggId)
	model:SetAttribute("Rarity", egg.Rarity)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = egg.Name
	prompt.HoldDuration = Game.Carry.GrabHold
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		if model:GetAttribute("Taken") or not model.Parent then
			return
		end
		onTriggered(player, model)
	end)

	model.Parent = container
	CollectionService:AddTag(model, "WorldEgg")
	return model, prompt
end

local function luckUpgrade(session: any, eggId: string): string
	local bonuses = services.CreatureService:GetBonuses(session)
	local chance = bonuses.Luck * 0.15
	if chance <= 0 or rng:NextNumber() >= chance then
		return eggId
	end
	local rarity = Rarities.ById[Eggs.ById[eggId].Rarity]
	local nextRarity = Rarities.Ordered[rarity.Order + 1]
	local better = nextRarity and Eggs.ByRarity[nextRarity.Id]
	if not better then
		return eggId
	end
	services.DataService:Notify(session.Player, "🍀 Удача! Яйцо превратилось в " .. better.Name, "success")
	return better.Id
end

-- Общая логика «поднять яйцо с земли»
local function tryGrab(player: Player, model: Model, kind: string): boolean
	local session = services.DataService:GetSession(player)
	if not session then
		return false
	end
	if services.CarryService:IsStunned(session) then
		return false
	end
	if not services.CarryService:HasRoom(session) then
		services.DataService:Notify(player, "🎒 Сумка полна — отнеси яйца на базу", "error")
		return false
	end
	model:SetAttribute("Taken", true)
	local eggId = model:GetAttribute("EggId") :: string
	model:Destroy()
	if kind == "zone" then
		eggId = luckUpgrade(session, eggId)
	end
	services.CarryService:Add(session, { Kind = "lane", EggId = eggId })
	services.QuestService:Progress(session, "LaneEgg", 1)
	services.TutorialService:Reached(session, "grab")
	return true
end

local function pickRarity(zone: any): string?
	local night = services.DayNightService:IsNight()
	local entries = {}
	for rarityId, weight in zone.EggWeights do
		local w = weight
		if night and Rarities.ById[rarityId].Order >= 3 then
			w *= Game.DayNight.NightLuck
			if rarityId == "Secret" then
				w *= Game.DayNight.NightSecretMult
			end
		end
		table.insert(entries, { Item = rarityId, Weight = w })
	end
	table.sort(entries, function(a, b)
		return Rarities.ById[a.Item].Order < Rarities.ById[b.Item].Order
	end)
	return WeightedRandom.Pick(entries, rng)
end

local function spawnZoneEgg(zone: any)
	local state = zoneState[zone.Id]
	local rarityId = pickRarity(zone)
	local egg = rarityId and Eggs.ByRarity[rarityId]
	if not egg then
		return
	end
	local position = Vector3.new(rng:NextNumber(-28, 28), 0.3, rng:NextNumber(zone.ZStart + 12, zone.ZEnd - 12))
	local model
	model = WorldEggService:CreatePickup(egg.Id, position, "Grab", function(player)
		if tryGrab(player, model, "zone") then
			state.eggs[model] = nil
			state.count -= 1
		end
	end)
	model:SetAttribute("Zone", zone.Id)
	state.eggs[model] = true
	state.count += 1
end

function WorldEggService:SpawnDropped(eggId: string, position: Vector3)
	local model
	model = WorldEggService:CreatePickup(eggId, position + Vector3.new(0, 0.3, 0), "Grab", function(player)
		tryGrab(player, model, "drop")
	end)
	model:SetAttribute("Dropped", true)
	task.delay(Game.Carry.LaneEggDespawn, function()
		if model.Parent and not model:GetAttribute("Taken") then
			model:Destroy()
		end
	end)
end

-- Ночью яйца «перезагружаются» (как в оригинале), чтобы ночная удача сработала сразу
function WorldEggService:ResetEggs()
	for _, zone in Zones.List do
		local state = zoneState[zone.Id]
		for model in state.eggs do
			if model.Parent then
				model:Destroy()
			end
		end
		state.eggs = {}
		state.count = 0
		for _ = 1, zone.MaxEggs do
			spawnZoneEgg(zone)
		end
		state.nextSpawn = os.clock() + zone.EggRespawn
	end
end

------------------------------------------------------------------------
-- Еда на земле
------------------------------------------------------------------------

local function pickFood(zone: any): any?
	local night = services.DayNightService:IsNight()
	local entries = {}
	for _, food in Foods.List do
		if food.Pickup and table.find(food.Pickup, zone.Id) then
			local weight = 10
			if food.NightOnly then
				weight = if night then 4 else 0
			elseif food.Catalyst then
				weight = 1.2
			end
			table.insert(entries, { Item = food, Weight = weight })
		end
	end
	return WeightedRandom.Pick(entries, rng)
end

local function spawnFood(zone: any)
	local food = pickFood(zone)
	if not food then
		return
	end
	local state = zoneState[zone.Id]
	local position = Vector3.new(rng:NextNumber(-34, 34), 1, rng:NextNumber(zone.ZStart + 6, zone.ZEnd - 6))
	local part = Studs.Block(container, Vector3.new(1.6, 1.6, 1.6), CFrame.new(position), food.Color,
		{ Name = "Food_" .. food.Id, CanCollide = false })
	part:SetAttribute("FoodId", food.Id)
	CollectionService:AddTag(part, "WorldFood")
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(46, 46)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 80
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = food.Icon
	label.TextScaled = true
	label.Parent = gui
	state.foods += 1

	local taken = false
	part.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local session = player and services.DataService:GetSession(player)
		if not session then
			return
		end
		taken = true
		part:Destroy()
		state.foods -= 1
		local amount = 1
		if rng:NextNumber() < services.CreatureService:GetBonuses(session).Forage then
			amount = 2
		end
		Profile.AddFood(session.Profile, food.Id, amount)
		services.QuestService:Progress(session, "PickupFood", 1)
		services.DataService:Notify(player, string.format("%s +%d %s", food.Icon, amount, food.Name), "food")
		services.DataService:MarkDirty(player)
	end)
end

function WorldEggService:Init(registry)
	services = registry
	container = Instance.new("Folder")
	container.Name = "WorldItems"
	container.Parent = workspace
end

function WorldEggService:Start()
	for _, zone in Zones.List do
		zoneState[zone.Id] = { eggs = {}, count = 0, nextSpawn = 0, foods = 0, nextFood = 0 }
	end
	WorldEggService:ResetEggs()
	for _, zone in Zones.List do
		for _ = 1, zone.MaxFood do
			spawnFood(zone)
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for _, zone in Zones.List do
				local state = zoneState[zone.Id]
				if state.count < zone.MaxEggs and now >= state.nextSpawn then
					spawnZoneEgg(zone)
					state.nextSpawn = now + zone.EggRespawn
				end
				if state.foods < zone.MaxFood and now >= state.nextFood then
					spawnFood(zone)
					state.nextFood = now + 8
				end
			end
		end
	end)
end

return WorldEggService
