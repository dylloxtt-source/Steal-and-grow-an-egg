--[[
	FarmService — грядки на базе: посадка семян, рост по таймеру (идёт и офлайн),
	сбор урожая. Урожай — еда для существ. Грядки нельзя украсть.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Foods = require(Shared.Config.Foods)
local Profile = require(Shared.Logic.Profile)
local Studs = require(Shared.Visual.Studs)

local FarmService = {}

local services
local rng = Random.new()
local LEAF = Color3.fromRGB(70, 180, 60)

local function stageOf(record: any, now: number): number
	-- 1 росток, 2 куст, 3 готово
	local total = record.readyAt - record.plantedAt
	local progress = if total > 0 then (now - record.plantedAt) / total else 1
	if progress >= 1 then
		return 3
	elseif progress >= 0.5 then
		return 2
	end
	return 1
end

local function buildCrop(farm: any, record: any, stage: number)
	local old = farm.Model:FindFirstChild("Crop")
	if old then
		if old:GetAttribute("Stage") == stage and old:GetAttribute("Seed") == record.seed then
			return
		end
		old:Destroy()
	end
	local food = Foods.ById[record.seed]
	local crop = Instance.new("Model")
	crop.Name = "Crop"
	crop:SetAttribute("Stage", stage)
	crop:SetAttribute("Seed", record.seed)
	local base = farm.Soil.Position + Vector3.new(0, farm.Soil.Size.Y / 2, 0)
	if stage == 1 then
		for _, offset in { Vector3.new(-1.3, 0, -1.3), Vector3.new(1.3, 0, 1.3), Vector3.new(1.3, 0, -1.3), Vector3.new(-1.3, 0, 1.3) } do
			Studs.Ground(crop, Vector3.new(0.5, 1, 0.5), base + offset, LEAF, { Name = "Sprout", CanCollide = false })
		end
	else
		Studs.Ground(crop, Vector3.new(4, 2.2, 4), base, LEAF, { Name = "Bush", CanCollide = false })
		Studs.Ground(crop, Vector3.new(2.6, 1, 2.6), base + Vector3.new(0, 2.2, 0), Studs.Lighten(LEAF, 0.15), { Name = "Bush", CanCollide = false })
		if stage == 3 then
			for i = 1, 4 do
				local angle = i * math.pi / 2
				local p = base + Vector3.new(math.cos(angle) * 2.1, 1.4, math.sin(angle) * 2.1)
				Studs.Block(crop, Vector3.new(1, 1, 1), CFrame.new(p), food.Color, { Name = "Fruit", CanCollide = false, Material = Enum.Material.Neon })
			end
		end
	end
	crop.Parent = farm.Model
end

function FarmService:RefreshSlot(session: any, slot: number)
	local plot = session.Plot
	if not plot then
		return
	end
	local farm = plot.Farms[slot]
	if not farm then
		return
	end
	local unlocked = slot <= session.Profile.upgrades.farms
	local record = session.Profile.farm[tostring(slot)]
	local model = farm.Model
	local state
	if not unlocked then
		state = "locked"
	elseif not record then
		state = "empty"
	elseif os.time() >= record.readyAt then
		state = "ready"
	else
		state = "growing"
	end
	model:SetAttribute("State", state)
	model:SetAttribute("Seed", if record then record.seed else nil)
	model:SetAttribute("PlantedAt", if record then record.plantedAt else nil)
	model:SetAttribute("ReadyAt", if record then record.readyAt else nil)

	if record then
		buildCrop(farm, record, stageOf(record, os.time()))
	else
		local crop = model:FindFirstChild("Crop")
		if crop then
			crop:Destroy()
		end
	end

	local prompt = farm.Prompt
	prompt.Enabled = unlocked
	if state == "ready" then
		prompt.ActionText = "Harvest"
		prompt.ObjectText = Foods.ById[record.seed].Name
		prompt:SetAttribute("ClientAction", nil)
	elseif state == "growing" then
		prompt.ActionText = "Growing"
		prompt.ObjectText = Foods.ById[record.seed].Name
		prompt:SetAttribute("ClientAction", "OpenFarm")
	else
		prompt.ActionText = "Plant"
		prompt.ObjectText = "Garden"
		prompt:SetAttribute("ClientAction", "OpenFarm")
	end
	prompt:SetAttribute("Slot", slot)
end

function FarmService:RefreshAll(session: any)
	if not session.Plot then
		return
	end
	for slot = 1, #session.Plot.Farms do
		FarmService:RefreshSlot(session, slot)
	end
end

local function harvest(session: any, slot: number): (boolean, string?)
	local profile = session.Profile
	local key = tostring(slot)
	local record = profile.farm[key]
	if not record then
		return false, "Грядка пуста"
	end
	if os.time() < record.readyAt then
		return false, "Ещё растёт"
	end
	profile.farm[key] = nil
	local food = Foods.ById[record.seed]
	local amount = (food.Seed :: any).Yield
	if rng:NextNumber() < services.CreatureService:GetBonuses(session).Forage then
		amount += 1
	end
	Profile.AddFood(profile, food.Id, amount)
	FarmService:RefreshSlot(session, slot)
	services.QuestService:Progress(session, "Harvest", 1)
	services.DataService:Notify(session.Player, string.format("%s +%d %s", food.Icon, amount, food.Name), "food")
	return true, nil
end

function FarmService:OnPrompt(player: Player, plotIndex: number, slot: number)
	local session = services.DataService:GetSession(player)
	if not session or not session.Plot or session.Plot.Index ~= plotIndex then
		return
	end
	local record = session.Profile.farm[tostring(slot)]
	if record and os.time() >= record.readyAt then
		harvest(session, slot)
		services.DataService:MarkDirty(player)
	end
end

function FarmService:Init(registry)
	services = registry
end

function FarmService:Start()
	local NetService = services.NetService
	local Check = NetService.Check

	NetService:Handle("Plant", function(_player, session, payload)
		if not Check.Table(payload) or not Check.Int(payload.slot, 1, 8) or not Check.String(payload.seed, 32) then
			return false, "Неверный запрос"
		end
		local profile = session.Profile
		local food = Foods.ById[payload.seed]
		if not food or not food.Seed then
			return false, "Это не семя"
		end
		if payload.slot > profile.upgrades.farms then
			return false, "Грядка закрыта"
		end
		local key = tostring(payload.slot)
		if profile.farm[key] then
			return false, "Грядка занята"
		end
		if (profile.seeds[food.Id] or 0) < 1 then
			return false, "Нет семян"
		end
		profile.seeds[food.Id] -= 1
		if profile.seeds[food.Id] <= 0 then
			profile.seeds[food.Id] = nil
		end
		local now = os.time()
		profile.farm[key] = { seed = food.Id, plantedAt = now, readyAt = now + food.Seed.GrowTime }
		FarmService:RefreshSlot(session, payload.slot)
		return true, nil
	end)

	NetService:Handle("Harvest", function(_player, session, payload)
		if not Check.Table(payload) or not Check.Int(payload.slot, 1, 8) then
			return false, "Неверный запрос"
		end
		return harvest(session, payload.slot)
	end)

	services.DataService:OnLoaded(function(_player, session)
		FarmService:RefreshAll(session)
	end)

	task.spawn(function()
		while true do
			task.wait(2)
			for _, session in services.DataService.Sessions do
				if session.Loaded and not session.Released and session.Plot then
					FarmService:RefreshAll(session)
				end
			end
		end
	end)
end

return FarmService
