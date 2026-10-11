--[[
	CombatService — бита «Bonk Bat». Удар выбивает яйца из рук и отбрасывает.
	• На площади (SAFE ZONE) бить нельзя и там нельзя получить удар.
	• Кулдаун и дальность проверяются на сервере (Tool.Activated приходит и на сервер).
	• Отбрасывание применяет клиент цели (его персонаж принадлежит ему по сети),
	  оглушение (WalkSpeed = 0) — сервер.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Map = require(Shared.Config.Map)
local Studs = require(Shared.Visual.Studs)
local Net = require(Shared.Net)

local CombatService = {}

local services
local effectEvent: RemoteEvent

local function buildTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Bonk Bat"
	tool.ToolTip = "Выбивает яйца из рук"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, -1.4, 0)
	local handle = Studs.Block(tool, Vector3.new(0.6, 4.2, 0.6), CFrame.new(), Color3.fromRGB(170, 95, 45),
		{ Name = "Handle", Anchored = false, CanCollide = false })
	local tip = Studs.Block(tool, Vector3.new(0.9, 1.4, 0.9), CFrame.new(0, 1.6, 0), Color3.fromRGB(230, 60, 60),
		{ Name = "Tip", Anchored = false, CanCollide = false })
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = tip
	weld.Parent = tip
	tip.CFrame = handle.CFrame * CFrame.new(0, 1.6, 0)
	local swing = Instance.new("Sound")
	swing.Name = "Swing"
	swing.SoundId = "rbxasset://sounds/swoosh.wav"
	swing.Volume = 0.6
	swing.Parent = handle
	return tool
end

local function findTarget(attacker: Player, root: BasePart): (Player?, BasePart?)
	local best, bestRoot, bestDistance = nil, nil, Game.Bonk.Range
	local look = root.CFrame.LookVector
	for _, player in Players:GetPlayers() do
		if player ~= attacker and player.Character then
			local otherRoot = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if otherRoot and humanoid and humanoid.Health > 0 and not Map.InPlaza(otherRoot.Position) then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				local facing = if distance > 0.1 then look:Dot(offset.Unit) else 1
				if distance < bestDistance and (facing > 0.2 or distance < 4) then
					best, bestRoot, bestDistance = player, otherRoot, distance
				end
			end
		end
	end
	return best, bestRoot
end

local function onActivated(player: Player, tool: Tool)
	local session = services.DataService:GetSession(player)
	if not session then
		return
	end
	local clock = os.clock()
	if (session.BonkReadyAt or 0) > clock or services.CarryService:IsStunned(session) then
		return
	end
	session.BonkReadyAt = clock + Game.Bonk.Cooldown

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local handle = tool:FindFirstChild("Handle")
	local swing = handle and handle:FindFirstChild("Swing") :: Sound?
	if swing then
		swing:Play()
	end
	tool.Grip = CFrame.new(0, -1.4, 0) * CFrame.Angles(math.rad(-80), 0, 0)
	task.delay(0.18, function()
		tool.Grip = CFrame.new(0, -1.4, 0)
	end)

	if Map.InPlaza(root.Position) then
		return
	end
	local target, targetRoot = findTarget(player, root)
	if not target or not targetRoot then
		return
	end
	local targetSession = services.DataService:GetSession(target)
	if not targetSession or services.CarryService:IsStunned(targetSession) then
		return
	end

	local dropped = services.CarryService:DropAll(targetSession, "bonk")
	services.CarryService:Stun(targetSession, Game.Bonk.StunTime)
	local away = targetRoot.Position - root.Position
	local direction = Vector3.new(away.X, 0, away.Z)
	direction = if direction.Magnitude > 0.1 then direction.Unit else root.CFrame.LookVector
	effectEvent:FireClient(target, "Knockback", {
		velocity = direction * Game.Bonk.Knockback + Vector3.new(0, 30, 0),
		stun = Game.Bonk.StunTime,
	})
	effectEvent:FireClient(player, "BonkHit", { dropped = dropped })
	if dropped > 0 then
		services.QuestService:Progress(session, "BonkDrop", 1)
		services.DataService:Notify(target, "💥 " .. player.DisplayName .. " выбил у тебя яйцо!", "error")
	end
end

function CombatService:Init(registry)
	services = registry
	effectEvent = Net.Event("Effect")
end

function CombatService:Start()
	local template = buildTool()
	template.Parent = StarterPack

	local function hookBackpack(player: Player)
		local function hook(tool: Instance)
			if tool:IsA("Tool") and tool.Name == template.Name and not tool:GetAttribute("Hooked") then
				tool:SetAttribute("Hooked", true)
				tool.Activated:Connect(function()
					onActivated(player, tool)
				end)
			end
		end
		local function watch(container: Instance)
			for _, child in container:GetChildren() do
				hook(child)
			end
			container.ChildAdded:Connect(hook)
		end
		local backpack = player:WaitForChild("Backpack", 10)
		if backpack then
			watch(backpack)
		end
		player.CharacterAdded:Connect(function(character)
			watch(character)
			local newBackpack = player:WaitForChild("Backpack", 10)
			if newBackpack and newBackpack ~= backpack then
				backpack = newBackpack
				watch(newBackpack)
			end
		end)
		if player.Character then
			watch(player.Character)
		end
	end

	Players.PlayerAdded:Connect(hookBackpack)
	for _, player in Players:GetPlayers() do
		task.spawn(hookBackpack, player)
	end
end

return CombatService
