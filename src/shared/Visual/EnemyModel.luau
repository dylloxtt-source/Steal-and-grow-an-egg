--[[
	Модели врагов — те же R6-пропорции, что у башен. Различия: цвета тела,
	снаряжение, оружие, размер. Боссы — увеличенный R6 с короной/крупным оружием.
	Humanoid не создаётся (оптимизация), анимация шага — на клиенте через Motor6D.
]]

local Config = script.Parent.Parent.Config
local Enemies = require(Config.Enemies)
local R6 = require(script.Parent.R6)
local Gear = require(script.Parent.Gear)
local Weapons = require(script.Parent.Weapons)

local EnemyModel = {}

local A = CFrame.Angles

local GEAR: { [string]: (R6.Rig, any) -> () } = {
	hood = function(rig)
		Gear.Hood(rig, Color3.fromRGB(80, 80, 90))
	end,
	headband = function(rig)
		Gear.Headband(rig, Color3.fromRGB(230, 40, 40))
	end,
	plates = function(rig)
		Gear.Plates(rig, Color3.fromRGB(140, 140, 150))
	end,
	cap = function(rig)
		Gear.Cap(rig, Color3.fromRGB(80, 55, 35))
	end,
	knightHelmet = function(rig)
		Gear.KnightHelmet(rig, Color3.fromRGB(175, 180, 190), nil)
	end,
	chestplate = function(rig, look)
		Gear.Chestplate(rig, look.Torso)
	end,
	regenCross = function(rig)
		Gear.Cross(rig, Color3.fromRGB(110, 255, 120))
	end,
	towerShield = function(rig)
		R6.BakePose(rig, { ["Left Shoulder"] = A(0, 0, -0.9) * A(0.5, 0, 0) })
		R6.Grip(rig, "Left Arm", Weapons.TowerShield(), CFrame.new(R6.HandInTorso(rig, "Left Arm").Position + Vector3.new(0.2, 0, -0.3)))
	end,
	visor = function(rig)
		Gear.Visor(rig, Color3.fromRGB(120, 220, 255))
	end,
	medCap = function(rig)
		Gear.MedCap(rig)
	end,
	staff = function(rig)
		R6.BakePose(rig, { ["Right Shoulder"] = A(0, 0, 0.3) })
		R6.Grip(rig, "Right Arm", Weapons.Staff(), CFrame.new(R6.HandInTorso(rig, "Right Arm").Position) * A(math.rad(80), 0, 0))
	end,
	ninjaMask = function(rig)
		Gear.NinjaMask(rig)
	end,
	spikedHelmet = function(rig)
		Gear.SpikedHelmet(rig, Color3.fromRGB(40, 40, 46))
	end,
	cape = function(rig, look)
		Gear.Cape(rig, look.Torso)
	end,
	crown = function(rig)
		Gear.Crown(rig)
	end,
	club = function(rig)
		R6.BakePose(rig, { ["Right Shoulder"] = A(0, 0, 0.4) })
		R6.Grip(rig, "Right Arm", Weapons.Club(), CFrame.new(R6.HandInTorso(rig, "Right Arm").Position) * A(math.rad(50), 0, 0))
	end,
	hammer = function(rig)
		R6.BakePose(rig, { ["Right Shoulder"] = A(0, 0, 0.4) })
		R6.Grip(rig, "Right Arm", Weapons.Hammer(), CFrame.new(R6.HandInTorso(rig, "Right Arm").Position) * A(math.rad(60), 0, 0))
	end,
	greatsword = function(rig)
		R6.BakePose(rig, { ["Right Shoulder"] = A(0, 0, 0.45) })
		R6.Grip(rig, "Right Arm", Weapons.Greatsword(), CFrame.new(R6.HandInTorso(rig, "Right Arm").Position) * A(math.rad(55), 0, 0))
	end,
}

function EnemyModel.Build(enemyId: string): Model
	local enemy = Enemies.ById[enemyId]
	assert(enemy, "Unknown enemy " .. tostring(enemyId))
	local look = enemy.Look
	local rig = R6.Build({
		Humanoid = false,
		Name = enemy.Name,
		Colors = { Head = look.Head, Torso = look.Torso, LeftArm = look.Arms, RightArm = look.Arms, LeftLeg = look.Legs, RightLeg = look.Legs },
	})
	-- Сначала то, что меняет позу (оружие, щит), затем остальное снаряжение,
	-- чтобы приваренные детали не сдвигались при перестановке рук
	local POSE_FIRST = { towerShield = true, staff = true, club = true, hammer = true, greatsword = true }
	for pass = 1, 2 do
		for _, gearId in look.Gear do
			local builder = GEAR[gearId]
			if builder and (POSE_FIRST[gearId] == true) == (pass == 1) then
				builder(rig, look)
			end
		end
	end
	if enemy.Boss then
		local aura = Instance.new("PointLight")
		aura.Color = Color3.fromRGB(255, 60, 60)
		aura.Range = 14
		aura.Brightness = 1.2
		aura.Parent = rig.Parts.Torso
	end
	local model = rig.Model
	if math.abs(enemy.Scale - 1) > 0.01 then
		model:ScaleTo(enemy.Scale)
	end
	model:SetAttribute("EnemyId", enemyId)
	return model
end

return EnemyModel
