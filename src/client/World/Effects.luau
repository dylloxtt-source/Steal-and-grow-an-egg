--[[
	Effects — эффекты от сервера: отбрасывание после удара/стража (персонаж
	принадлежит клиенту по сети, поэтому импульс применяем здесь), тряска камеры.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local Sounds = require(script.Parent.Parent.UI.Sounds)

local Effects = {}

local shakeUntil = 0
local shakePower = 0

local function shake(duration: number, power: number)
	shakeUntil = os.clock() + duration
	shakePower = power
end

local function knockback(data: any)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or typeof(data.velocity) ~= "Vector3" then
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	root.AssemblyLinearVelocity = data.velocity
	shake(0.35, 0.6)
	Sounds.Play("hit", 0.7)
	task.delay(math.clamp(tonumber(data.stun) or 1, 0.2, 3), function()
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function Effects.Start()
	Net.Event("Effect").OnClientEvent:Connect(function(kind, data)
		if type(data) ~= "table" then
			return
		end
		if kind == "Knockback" then
			knockback(data)
		elseif kind == "BonkHit" then
			shake(0.15, 0.25)
			Sounds.Play("hit", 1.2)
		end
	end)

	RunService:BindToRenderStep("SGAE_Shake", Enum.RenderPriority.Camera.Value + 1, function()
		if os.clock() < shakeUntil then
			local camera = workspace.CurrentCamera
			if camera then
				local p = shakePower
				camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * p * 4), math.rad((math.random() - 0.5) * p * 4), 0)
			end
		end
	end)
end

return Effects
