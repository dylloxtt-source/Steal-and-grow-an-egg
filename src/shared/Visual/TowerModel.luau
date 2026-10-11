--[[
	Модели башен. Каждая башня — R6 Dummy (Visual/R6) в позе держания оружия
	+ оружие на Motor6D к руке + снаряжение. Росомаха — только тело и когти.

	Атрибуты модели: TowerId, Level, Tier. Части оружия с Attachment "Muzzle"
	используются клиентом для вспышек и трассеров.
]]

local Config = script.Parent.Parent.Config
local Towers = require(Config.Towers)
local R6 = require(script.Parent.R6)
local Gear = require(script.Parent.Gear)
local Weapons = require(script.Parent.Weapons)

local TowerModel = {}

local A = CFrame.Angles
local rad = math.rad

local function at(rig: R6.Rig, arm: string, offset: Vector3?): Vector3
	return R6.HandInTorso(rig, arm).Position + (offset or Vector3.zero)
end

-- Позы держания (запекаются в C0) и сборка снаряжения
local BUILD: { [string]: (R6.Rig, number) -> () } = {
	swordsman = function(rig, tier)
		R6.BakePose(rig, { ["Right Shoulder"] = A(0, 0, 0.35), ["Left Shoulder"] = A(0, 0, -0.12) })
		R6.Grip(rig, "Right Arm", Weapons.Sword(tier), CFrame.new(at(rig, "Right Arm", Vector3.new(0, 0.15, 0))) * A(rad(35), 0, 0))
		local steel = if tier >= 3 then Color3.fromRGB(255, 205, 80) elseif tier == 2 then Color3.fromRGB(200, 210, 225) else Color3.fromRGB(150, 155, 165)
		Gear.KnightHelmet(rig, steel, if tier >= 2 then Color3.fromRGB(220, 40, 40) else nil)
		Gear.Belt(rig, Color3.fromRGB(90, 60, 35))
		if tier >= 3 then
			Gear.Cape(rig, Color3.fromRGB(200, 30, 40))
		end
	end,

	archer = function(rig, tier)
		R6.BakePose(rig, {
			["Left Shoulder"] = A(0, 0, -1.5) * A(0.15, 0, 0),
			["Right Shoulder"] = A(0, 0, 1.35) * A(0.75, 0, 0),
			["Neck"] = A(0, 0, -0.1),
		})
		R6.Grip(rig, "Left Arm", Weapons.Bow(tier), CFrame.new(at(rig, "Left Arm", Vector3.new(0, 0, -0.1))))
		Gear.Back(rig, Weapons.Quiver(tier), CFrame.new(0.45, 0.3, 0.7) * A(0, 0, rad(-20)))
		Gear.Hood(rig, if tier >= 3 then Color3.fromRGB(30, 90, 40) else Color3.fromRGB(60, 130, 60))
		Gear.Belt(rig, Color3.fromRGB(110, 70, 40))
		if tier >= 3 then
			Gear.Cape(rig, Color3.fromRGB(40, 110, 50))
		end
	end,

	pistol = function(rig, tier)
		local pose = { ["Right Shoulder"] = A(0, 0, 1.55) * A(0.1, 0, 0) }
		if tier >= 3 then
			pose["Left Shoulder"] = A(0, 0, -1.55) * A(0.1, 0, 0)
		end
		R6.BakePose(rig, pose)
		R6.Grip(rig, "Right Arm", Weapons.Pistol(tier), CFrame.new(at(rig, "Right Arm", Vector3.new(0, 0.1, -0.1))))
		if tier >= 3 then
			local second = Weapons.Pistol(tier)
			second.Name = "PistolLeft"
			R6.Grip(rig, "Left Arm", second, CFrame.new(at(rig, "Left Arm", Vector3.new(0, 0.1, -0.1))))
		end
		Gear.Cap(rig, Color3.fromRGB(30, 40, 80))
		Gear.Sunglasses(rig)
		Gear.Belt(rig, Color3.fromRGB(30, 30, 35), Color3.fromRGB(200, 200, 210))
	end,

	minigunner = function(rig, tier)
		R6.BakePose(rig, {
			["Right Shoulder"] = A(0, 0, 1.35) * A(0.15, 0, 0),
			["Left Shoulder"] = A(0, 0, -1.4) * A(0.75, 0, 0),
		})
		R6.Grip(rig, "Right Arm", Weapons.MachineGun(tier), CFrame.new(at(rig, "Right Arm", Vector3.new(-0.3, 0.2, 0))))
		local olive = if tier >= 3 then Color3.fromRGB(70, 80, 50) else Color3.fromRGB(95, 110, 70)
		Gear.ArmyHelmet(rig, olive)
		Gear.Vest(rig, Color3.fromRGB(60, 70, 45))
		Gear.AmmoBelt(rig)
		if tier >= 2 then
			Gear.ShoulderPads(rig, olive)
		end
	end,

	sniper = function(rig, tier)
		R6.BakePose(rig, {
			["Right Shoulder"] = A(0, 0, 1.45) * A(0.35, 0, 0),
			["Left Shoulder"] = A(0, 0, -1.5) * A(0.8, 0, 0),
			["Neck"] = A(0.15, 0, -0.15),
		})
		R6.Grip(rig, "Right Arm", Weapons.Sniper(tier), CFrame.new(at(rig, "Right Arm", Vector3.new(-0.2, 0.3, 0.2))))
		Gear.Beanie(rig, Color3.fromRGB(50, 60, 45))
		Gear.Goggles(rig, if tier >= 2 then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(120, 200, 255))
		Gear.Vest(rig, if tier >= 3 then Color3.fromRGB(45, 50, 40) else Color3.fromRGB(85, 95, 65))
	end,

	toxic = function(rig, tier)
		R6.BakePose(rig, {
			["Right Shoulder"] = A(0, 0, 1.4) * A(0.1, 0, 0),
			["Left Shoulder"] = A(0, 0, -1.2) * A(0.6, 0, 0),
		})
		R6.Grip(rig, "Right Arm", Weapons.ToxicGun(tier), CFrame.new(at(rig, "Right Arm", Vector3.new(-0.1, 0.15, 0))))
		Gear.Back(rig, Weapons.ToxicTank(tier), CFrame.new(0, 0.1, 0.85))
		Gear.GasMask(rig, Color3.fromRGB(110, 255, 80))
		Gear.ShoulderPads(rig, Color3.fromRGB(70, 160, 60))
		Gear.Belt(rig, Color3.fromRGB(50, 60, 50), Color3.fromRGB(110, 255, 80))
	end,

	lumberjack = function(rig, tier)
		R6.BakePose(rig, { ["Right Shoulder"] = A(0, 0, 0.5), ["Left Shoulder"] = A(0, 0, -0.25) * A(0.3, 0, 0) })
		R6.Grip(rig, "Right Arm", Weapons.Axe(tier), CFrame.new(at(rig, "Right Arm", Vector3.new(0, 0.2, 0))) * A(rad(70), 0, 0))
		Gear.Plaid(rig, Color3.fromRGB(190, 40, 40), Color3.fromRGB(40, 25, 25))
		Gear.Beanie(rig, Color3.fromRGB(200, 60, 40))
		Gear.Beard(rig, Color3.fromRGB(110, 70, 40))
		if tier >= 2 then
			Gear.Belt(rig, Color3.fromRGB(70, 45, 25))
		end
	end,

	-- Только R6-тело и когти: без одежды, брони, масок и аксессуаров
	wolverine = function(rig, tier)
		R6.BakePose(rig, {
			["Right Shoulder"] = A(0, 0, 0.7) * A(0.2, 0, 0),
			["Left Shoulder"] = A(0, 0, -0.7) * A(0.2, 0, 0),
		})
		local right = Weapons.Claws(tier)
		right.Name = "ClawsRight"
		R6.Grip(rig, "Right Arm", right, CFrame.new(at(rig, "Right Arm", Vector3.new(0, 0.1, -0.15))) * A(rad(-15), 0, 0))
		local left = Weapons.Claws(tier)
		left.Name = "ClawsLeft"
		R6.Grip(rig, "Left Arm", left, CFrame.new(at(rig, "Left Arm", Vector3.new(0, 0.1, -0.15))) * A(rad(-15), 0, 0))
	end,
}

function TowerModel.Build(towerId: string, level: number): Model
	local tower = Towers.ById[towerId]
	assert(tower, "Unknown tower " .. tostring(towerId))
	local stats = tower.Levels[math.clamp(level, 1, #tower.Levels)]
	local rig = R6.Build({ Humanoid = true, Name = tower.Name, Colors = R6.ReferenceColors })
	BUILD[towerId](rig, stats.Tier)
	local model = rig.Model
	model:SetAttribute("TowerId", towerId)
	model:SetAttribute("Level", level)
	model:SetAttribute("Tier", stats.Tier)
	-- Подставка под башней (цвет — акцент башни), не мешает читаемости
	local base = Instance.new("Part")
	base.Name = "Pedestal"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.3, 3.2, 3.2)
	base.CFrame = CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2)
	base.Color = tower.Accent
	base.Material = Enum.Material.SmoothPlastic
	base.Anchored = false
	base.CanCollide = false
	base.CanTouch = false
	base.Massless = true
	base.TopSurface = Enum.SurfaceType.Smooth
	base.BottomSurface = Enum.SurfaceType.Smooth
	R6.Attach(rig, "HumanoidRootPart", base)
	return model
end

-- Все точки вылета снарядов модели
function TowerModel.Muzzles(model: Model): { Attachment }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "Muzzle" then
			table.insert(list, d)
		end
	end
	return list
end

return TowerModel
