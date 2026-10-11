--[[
	GuardianService — стражи биомов. Гоняются только за игроками, которые несут яйца,
	поэтому скорость (Speed) — главный показатель прогрессии: без неё дальние
	зоны с редкими яйцами недоступны. Пойманный игрок роняет яйца и отлетает.

	Модель стража сварена с корнем; сервер двигает только корень (дёшево по сети).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Map = require(Shared.Config.Map)
local Zones = require(Shared.Config.Zones)
local Game = require(Shared.Config.Game)
local CreatureModel = require(Shared.Visual.CreatureModel)
local Studs = require(Shared.Visual.Studs)
local Net = require(Shared.Net)

local GuardianService = {}

local services
local rng = Random.new()
local guardians = {}
local effectEvent: RemoteEvent

local function newGuardian(zone: any, index: number, folder: Folder)
	local config = zone.Guardian
	local model = CreatureModel.Build(config.Creature, { Stage = "Adult", Angry = true, ExtraScale = config.Scale })
	model.Name = "Guardian_" .. zone.Id .. "_" .. index
	Studs.SetModelPhysics(model, false, false)
	Studs.WeldModel(model)
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	local home = Vector3.new((index - 1.5) * 30, 0, (zone.ZStart + zone.ZEnd) / 2)
	model:PivotTo(CFrame.new(home))
	model:SetAttribute("Guardian", true)
	model:SetAttribute("Zone", zone.Id)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 9 * config.Scale * 0.6, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 80, 80)
	label.Text = string.format("⚠ GUARDIAN • 👟%d", config.Speed)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label

	model.Parent = folder
	return {
		Zone = zone,
		Config = config,
		Model = model,
		Root = root,
		Position = home,
		Home = home,
		Heading = 0,
		Target = nil :: Player?,
		Wander = home,
		CooldownUntil = 0,
	}
end

local function carrierInZone(guardian: any): Player?
	local zone = guardian.Zone
	local best, bestDistance = nil, guardian.Config.Aggro
	for player, session in services.DataService.Sessions do
		if session.Loaded and session.Carry and #session.Carry > 0 then
			local position = services.CarryService:RootPosition(player)
			if position and not Map.InPlaza(position) and position.Z >= zone.ZStart - 15 and position.Z <= zone.ZEnd + 15 then
				local distance = (Vector3.new(position.X, 0, position.Z) - guardian.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = player, distance
				end
			end
		end
	end
	return best
end

local function catch(guardian: any, player: Player)
	local session = services.DataService:GetSession(player)
	if not session then
		return
	end
	local dropped = services.CarryService:DropAll(session, "guardian")
	if dropped > 0 then
		services.CarryService:Stun(session, Game.Bonk.StunTime)
		local position = services.CarryService:RootPosition(player) or guardian.Position
		local away = (Vector3.new(position.X, 0, position.Z) - guardian.Position)
		local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, -1)
		effectEvent:FireClient(player, "Knockback", { velocity = direction * 70 + Vector3.new(0, 45, 0), stun = Game.Bonk.StunTime })
		services.DataService:Notify(player, "Страж поймал тебя! Нужна скорость побольше 👟", "error")
	end
	guardian.CooldownUntil = os.clock() + 2.5
	guardian.Target = nil
end

local function step(guardian: any, dt: number)
	local clock = os.clock()
	local speed
	local goal
	if clock >= guardian.CooldownUntil then
		guardian.Target = carrierInZone(guardian)
	end
	local target = guardian.Target
	if target then
		local position = services.CarryService:RootPosition(target)
		if position then
			goal = Vector3.new(position.X, 0, position.Z)
			speed = guardian.Config.Speed
			if (goal - guardian.Position).Magnitude <= guardian.Config.Catch then
				catch(guardian, target)
			end
		end
	end
	if not goal then
		-- Патруль вокруг дома
		if (guardian.Wander - guardian.Position).Magnitude < 3 then
			local zone = guardian.Zone
			guardian.Wander = Vector3.new(rng:NextNumber(-30, 30), 0,
				math.clamp(guardian.Home.Z + rng:NextNumber(-60, 60), zone.ZStart + 10, zone.ZEnd - 10))
		end
		goal = guardian.Wander
		speed = 9
	end
	local delta = goal - guardian.Position
	local distance = delta.Magnitude
	if distance > 0.05 then
		local move = math.min(distance, speed * dt)
		local zone = guardian.Zone
		local nextPos = guardian.Position + delta.Unit * move
		-- Страж не покидает свою зону
		nextPos = Vector3.new(
			math.clamp(nextPos.X, -Map.Lane.HalfWidth + 4, Map.Lane.HalfWidth - 4),
			0,
			math.clamp(nextPos.Z, zone.ZStart - 10, zone.ZEnd + 10)
		)
		guardian.Position = nextPos
		guardian.Heading = math.atan2(-delta.X, -delta.Z)
	end
	local bob = math.abs(math.sin(clock * (if target then 14 else 6))) * 0.6
	guardian.Root.CFrame = CFrame.new(guardian.Position + Vector3.new(0, 0.5 * guardian.Config.Scale + bob, 0))
		* CFrame.Angles(0, guardian.Heading, 0)
end

function GuardianService:Init(registry)
	services = registry
	effectEvent = Net.Event("Effect")
end

function GuardianService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = workspace
	for _, zone in Zones.List do
		if zone.Guardian then
			for i = 1, zone.Guardian.Count do
				table.insert(guardians, newGuardian(zone, i, folder))
			end
		end
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 30 then
			return
		end
		local stepDt = accumulator
		accumulator = 0
		if #Players:GetPlayers() == 0 then
			return
		end
		for _, guardian in guardians do
			step(guardian, stepDt)
		end
	end)
end

return GuardianService
