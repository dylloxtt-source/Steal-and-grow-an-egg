--[[
	CarryService — яйца, которые игрок несёт над головой.

	item = {
	  Kind   = "lane" | "stolen",
	  EggId  = string,
	  Model  = Model,          -- приварено к голове персонажа
	  Owner  = session?,       -- для украденного: сессия владельца
	  Slot   = number?,        -- для украденного: слот инкубатора владельца
	  EggUid = string?,
	}

	• Каждое яйцо замедляет (Rarity.CarryPenalty), украденное — сильнее.
	• Доставка: как только игрок входит на СВОЮ базу, всё несомое сдаётся.
	• Смерть, удар битой, страж или выход — яйца падают (см. Drop).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Game = require(Shared.Config.Game)
local Map = require(Shared.Config.Map)
local Rarities = require(Shared.Config.Rarities)
local Economy = require(Shared.Logic.Economy)
local Profile = require(Shared.Logic.Profile)
local EggModel = require(Shared.Visual.EggModel)
local Studs = require(Shared.Visual.Studs)

local CarryService = {}

local services

local function getCarry(session: any): { any }
	if not session.Carry then
		session.Carry = {}
	end
	return session.Carry
end

function CarryService:Count(session: any): number
	return #getCarry(session)
end

function CarryService:HasRoom(session: any): boolean
	return #getCarry(session) < session.Profile.upgrades.bag
end

local function humanoidOf(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, root
end

function CarryService:RootPosition(player: Player): Vector3?
	local _, root = humanoidOf(player)
	return root and root.Position
end

function CarryService:IsStunned(session: any): boolean
	return (session.StunnedUntil or 0) > os.clock()
end

function CarryService:WalkSpeed(session: any): number
	local profile = session.Profile
	local bonuses = services.CreatureService:GetBonuses(session)
	local speed = Economy.WalkSpeed(profile.upgrades.speed, bonuses.Speed)
	if profile.settings.slowMode then
		speed = math.min(speed, Game.Movement.SlowModeSpeed)
	end
	return speed
end

function CarryService:RefreshSpeed(player: Player)
	local session = services.DataService:GetSession(player)
	if not session then
		return
	end
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	if CarryService:IsStunned(session) then
		humanoid.WalkSpeed = 0
		return
	end
	local penalty = 0
	for _, item in getCarry(session) do
		local egg = Eggs.ById[item.EggId]
		penalty += Rarities.ById[egg.Rarity].CarryPenalty
		if item.Kind == "stolen" then
			penalty += Game.Movement.StolenExtraPenalty
		end
	end
	humanoid.WalkSpeed = CarryService:WalkSpeed(session) * (1 - math.min(penalty, 0.6))
end

local function refreshHighlight(session: any)
	local character = session.Player.Character
	if not character then
		return
	end
	local hasStolen = false
	for _, item in getCarry(session) do
		if item.Kind == "stolen" then
			hasStolen = true
		end
	end
	local existing = character:FindFirstChild("ThiefHighlight")
	if hasStolen and not existing then
		local highlight = Instance.new("Highlight")
		highlight.Name = "ThiefHighlight"
		highlight.FillColor = Color3.fromRGB(255, 40, 40)
		highlight.FillTransparency = 0.6
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = character
	elseif not hasStolen and existing then
		existing:Destroy()
	end
end

local function attachModels(session: any)
	local character = session.Player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	for i, item in getCarry(session) do
		if item.Model then
			item.Model:Destroy()
			item.Model = nil
		end
		if head then
			local model = EggModel.Build(item.EggId, 0.7)
			model.Name = "CarriedEgg"
			Studs.SetModelPhysics(model, false, false)
			Studs.WeldModel(model)
			model:PivotTo(head.CFrame * CFrame.new(0, 1 + (i - 1) * 2.4, 0))
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = model.PrimaryPart
			weld.Parent = model.PrimaryPart
			model.Parent = character
			item.Model = model
		end
	end
end

function CarryService:Refresh(session: any)
	attachModels(session)
	refreshHighlight(session)
	CarryService:RefreshSpeed(session.Player)
	services.DataService:MarkDirty(session.Player)
end

function CarryService:Add(session: any, item: any): boolean
	if not CarryService:HasRoom(session) then
		return false
	end
	table.insert(getCarry(session), item)
	CarryService:Refresh(session)
	return true
end

-- Убирает конкретный предмет без падения (используется при отмене кражи)
function CarryService:Remove(session: any, item: any)
	local carry = getCarry(session)
	local index = table.find(carry, item)
	if index then
		table.remove(carry, index)
		if item.Model then
			item.Model:Destroy()
			item.Model = nil
		end
		CarryService:Refresh(session)
	end
end

-- Все предметы падают на землю. Возвращает количество выпавших.
function CarryService:DropAll(session: any, reason: string): number
	local carry = getCarry(session)
	if #carry == 0 then
		return 0
	end
	local position = CarryService:RootPosition(session.Player) or Map.Spawn
	session.Carry = {}
	for i, item in carry do
		if item.Model then
			item.Model:Destroy()
			item.Model = nil
		end
		local offset = Vector3.new(math.cos(i * 2.1) * 3, 0, math.sin(i * 2.1) * 3)
		local ground = Vector3.new(position.X, 0, position.Z) + offset
		if item.Kind == "stolen" then
			services.StealService:OnStolenDropped(item, ground, reason)
		elseif reason ~= "leave" then
			services.WorldEggService:SpawnDropped(item.EggId, ground)
		end
	end
	refreshHighlight(session)
	CarryService:RefreshSpeed(session.Player)
	services.DataService:MarkDirty(session.Player)
	return #carry
end

function CarryService:Stun(session: any, duration: number)
	session.StunnedUntil = os.clock() + duration
	CarryService:RefreshSpeed(session.Player)
	task.delay(duration + 0.05, function()
		if session.Player.Parent then
			CarryService:RefreshSpeed(session.Player)
		end
	end)
end

local function deliver(session: any)
	local carry = getCarry(session)
	local profile = session.Profile
	local keep = {}
	local delivered = 0
	for _, item in carry do
		if item.Kind == "stolen" then
			if services.StealService:CompleteSteal(session, item) then
				delivered += 1
			end
			if item.Model then
				item.Model:Destroy()
			end
		elseif #profile.eggs >= Game.Inventory.MaxEggs then
			table.insert(keep, item)
		else
			table.insert(profile.eggs, { uid = Profile.NewUid(profile), id = item.EggId })
			delivered += 1
			if item.Model then
				item.Model:Destroy()
			end
		end
	end
	if delivered == 0 and #keep == #carry then
		if not session.InventoryWarned then
			session.InventoryWarned = true
			services.DataService:Notify(session.Player, "Инвентарь яиц полон!", "error")
		end
		return
	end
	session.InventoryWarned = false
	session.Carry = keep
	services.TutorialService:Reached(session, "deliver")
	services.IncubatorService:AutoFill(session)
	services.DataService:Notify(session.Player, string.format("🏠 Доставлено яиц: %d", delivered), "success")
	CarryService:Refresh(session)
end

function CarryService:Init(registry)
	services = registry
end

function CarryService:Start()
	services.DataService:OnLoaded(function(player, session)
		local function onCharacter(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if not humanoid then
				return
			end
			-- Новый персонаж: старые модели исчезли вместе с прошлым телом
			session.Carry = {}
			CarryService:RefreshSpeed(player)
			humanoid.Died:Connect(function()
				CarryService:DropAll(session, "death")
			end)
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
		player.CharacterRemoving:Connect(function()
			if #getCarry(session) > 0 then
				CarryService:DropAll(session, "death")
			end
		end)
	end)

	services.DataService:OnRemoving(function(_player, session)
		CarryService:DropAll(session, "leave")
	end)

	services.DataService:AddViewContributor(function(session, runtime)
		local carrying = {}
		for _, item in getCarry(session) do
			table.insert(carrying, { eggId = item.EggId, stolen = item.Kind == "stolen" })
		end
		runtime.carrying = carrying
		runtime.walkSpeed = CarryService:WalkSpeed(session)
		runtime.bag = session.Profile.upgrades.bag
	end)

	-- Проверка доставки 5 раз в секунду
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, session in services.DataService.Sessions do
				if session.Loaded and session.Plot and session.Carry and #session.Carry > 0 then
					local position = CarryService:RootPosition(player)
					if position and Map.InPlot(session.Plot.Index, position) then
						deliver(session)
					end
				end
			end
		end
	end)
end

return CarryService
