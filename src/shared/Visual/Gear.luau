--[[
	Снаряжение для R6: шлемы, капюшоны, жилеты, плащи и т.п.
	Детали ставятся относительно частей тела в текущей позе и привариваются.
]]

local Parts = require(script.Parent.Parts)
local R6 = require(script.Parent.R6)

local Gear = {}

local function put(rig: R6.Rig, partName: string, size: Vector3, offset: CFrame, color: Color3, options: Parts.Options?, kind: string?): BasePart
	local base = rig.Parts[partName]
	local piece
	if kind == "Wedge" then
		piece = Parts.Wedge(nil, size, base.CFrame * offset, color, options)
	elseif kind == "Ball" then
		piece = Parts.Ball(nil, size.X, base.CFrame * offset, color, options)
	elseif kind == "CylinderY" then
		piece = Parts.Cylinder(nil, size.Y, size.X, base.CFrame * offset, color, "Y", options)
	elseif kind == "CylinderZ" then
		piece = Parts.Cylinder(nil, size.Z, size.X, base.CFrame * offset, color, "Z", options)
	else
		piece = Parts.Block(nil, size, base.CFrame * offset, color, options)
	end
	piece.Name = (options and options.Name) or "Gear"
	R6.Attach(rig, partName, piece)
	return piece
end
Gear.Put = put

local GOLD = Color3.fromRGB(255, 200, 60)
local DARK = Color3.fromRGB(40, 40, 46)
local METAL = Enum.Material.Metal

------------------------------------------------------------------------
-- Голова
------------------------------------------------------------------------

function Gear.KnightHelmet(rig: R6.Rig, color: Color3, plume: Color3?)
	put(rig, "Head", Vector3.new(1.4, 0.75, 1.38), CFrame.new(0, 0.3, 0.02), color, { Name = "Helmet", Material = METAL })
	put(rig, "Head", Vector3.new(1.42, 0.5, 0.25), CFrame.new(0, -0.05, -0.6), color, { Name = "Faceguard", Material = METAL })
	put(rig, "Head", Vector3.new(1.0, 0.1, 0.05), CFrame.new(0, 0.05, -0.74), DARK, { Name = "Visor" })
	if plume then
		put(rig, "Head", Vector3.new(0.25, 0.6, 1.1), CFrame.new(0, 0.95, 0.1), plume, { Name = "Plume" })
	end
end

function Gear.Hood(rig: R6.Rig, color: Color3)
	put(rig, "Head", Vector3.new(1.4, 1.25, 1.3), CFrame.new(0, 0.12, 0.1), color, { Name = "Hood" })
	put(rig, "Head", Vector3.new(1.0, 0.6, 0.7), CFrame.new(0, 0.55, 0.7) * CFrame.Angles(math.rad(-25), 0, 0), color, { Name = "HoodTip" }, "Wedge")
	put(rig, "Head", Vector3.new(1.42, 1.0, 0.08), CFrame.new(0, -0.05, -0.62), DARK, { Name = "HoodShade", Transparency = 1 })
end

function Gear.Cap(rig: R6.Rig, color: Color3)
	put(rig, "Head", Vector3.new(1.32, 0.4, 1.32), CFrame.new(0, 0.55, 0), color, { Name = "Cap" })
	put(rig, "Head", Vector3.new(1.0, 0.08, 0.6), CFrame.new(0, 0.38, -0.85), color, { Name = "Brim" })
end

function Gear.Beanie(rig: R6.Rig, color: Color3)
	put(rig, "Head", Vector3.new(1.34, 0.55, 1.34), CFrame.new(0, 0.5, 0), color, { Name = "Beanie" })
	put(rig, "Head", Vector3.new(1.38, 0.18, 1.38), CFrame.new(0, 0.28, 0), Parts.Darken(color, 0.25), { Name = "BeanieFold" })
end

function Gear.Headband(rig: R6.Rig, color: Color3)
	put(rig, "Head", Vector3.new(1.32, 0.2, 1.32), CFrame.new(0, 0.32, 0), color, { Name = "Headband" })
end

function Gear.Sunglasses(rig: R6.Rig)
	put(rig, "Head", Vector3.new(1.05, 0.2, 0.1), CFrame.new(0, 0.15, -0.64), DARK, { Name = "Glasses", Reflectance = 0.3 })
end

function Gear.ArmyHelmet(rig: R6.Rig, color: Color3)
	put(rig, "Head", Vector3.new(1.45, 0.6, 1.45), CFrame.new(0, 0.42, 0), color, { Name = "Helmet" })
	put(rig, "Head", Vector3.new(1.6, 0.1, 1.6), CFrame.new(0, 0.15, 0), Parts.Darken(color, 0.2), { Name = "HelmetRim" })
end

function Gear.Goggles(rig: R6.Rig, lens: Color3)
	put(rig, "Head", Vector3.new(1.34, 0.18, 1.34), CFrame.new(0, 0.2, 0), DARK, { Name = "Strap" })
	for _, x in { -0.25, 0.25 } do
		put(rig, "Head", Vector3.new(0.3, 0.26, 0.12), CFrame.new(x, 0.2, -0.66), lens, { Name = "Lens", Material = Enum.Material.Neon })
	end
end

function Gear.GasMask(rig: R6.Rig, filter: Color3)
	put(rig, "Head", Vector3.new(0.9, 0.55, 0.3), CFrame.new(0, -0.15, -0.6), DARK, { Name = "Mask" })
	for _, x in { -0.42, 0.42 } do
		put(rig, "Head", Vector3.new(0.35, 0.35, 0.35), CFrame.new(x, -0.25, -0.7), filter, { Name = "Filter", Material = Enum.Material.Neon }, "Ball")
	end
	for _, x in { -0.22, 0.22 } do
		put(rig, "Head", Vector3.new(0.26, 0.22, 0.08), CFrame.new(x, 0.18, -0.64), Color3.fromRGB(150, 230, 255), { Name = "Eye", Material = Enum.Material.Glass, Transparency = 0.2 })
	end
end

function Gear.Beard(rig: R6.Rig, color: Color3)
	put(rig, "Head", Vector3.new(1.0, 0.45, 0.25), CFrame.new(0, -0.38, -0.55), color, { Name = "Beard" })
end

function Gear.Visor(rig: R6.Rig, color: Color3)
	put(rig, "Head", Vector3.new(1.2, 0.2, 0.1), CFrame.new(0, 0.15, -0.64), color, { Name = "Visor", Material = Enum.Material.Neon })
end

function Gear.MedCap(rig: R6.Rig)
	put(rig, "Head", Vector3.new(1.3, 0.45, 1.3), CFrame.new(0, 0.55, 0), Color3.fromRGB(245, 245, 245), { Name = "MedCap" })
	put(rig, "Head", Vector3.new(0.4, 0.12, 0.05), CFrame.new(0, 0.6, -0.67), Color3.fromRGB(230, 40, 40), { Name = "CrossH" })
	put(rig, "Head", Vector3.new(0.12, 0.38, 0.05), CFrame.new(0, 0.6, -0.67), Color3.fromRGB(230, 40, 40), { Name = "CrossV" })
end

function Gear.NinjaMask(rig: R6.Rig)
	put(rig, "Head", Vector3.new(1.33, 0.55, 1.33), CFrame.new(0, -0.18, 0), Color3.fromRGB(20, 20, 26), { Name = "Mask" })
	put(rig, "Head", Vector3.new(0.9, 0.1, 0.06), CFrame.new(0, 0.15, -0.65), Color3.fromRGB(255, 40, 60), { Name = "Eyes", Material = Enum.Material.Neon })
end

function Gear.SpikedHelmet(rig: R6.Rig, color: Color3)
	put(rig, "Head", Vector3.new(1.42, 0.7, 1.42), CFrame.new(0, 0.32, 0), color, { Name = "Helmet", Material = METAL })
	for i = -1, 1 do
		put(rig, "Head", Vector3.new(0.18, 0.55, 0.3), CFrame.new(i * 0.45, 0.95, 0), Color3.fromRGB(200, 200, 210), { Name = "Spike", Material = METAL }, "Wedge")
	end
	put(rig, "Head", Vector3.new(0.9, 0.1, 0.06), CFrame.new(0, 0.1, -0.73), Color3.fromRGB(255, 60, 40), { Name = "Eyes", Material = Enum.Material.Neon })
end

function Gear.Crown(rig: R6.Rig)
	put(rig, "Head", Vector3.new(1.3, 0.3, 1.3), CFrame.new(0, 0.85, 0), GOLD, { Name = "Crown", Material = METAL, Reflectance = 0.2 })
	for _, offset in { Vector3.new(-0.5, 0, -0.5), Vector3.new(0.5, 0, -0.5), Vector3.new(-0.5, 0, 0.5), Vector3.new(0.5, 0, 0.5), Vector3.new(0, 0, -0.6) } do
		put(rig, "Head", Vector3.new(0.2, 0.4, 0.2), CFrame.new(offset.X, 1.15, offset.Z), GOLD, { Name = "CrownSpike", Material = METAL })
	end
	put(rig, "Head", Vector3.new(0.25, 0.25, 0.1), CFrame.new(0, 0.85, -0.68), Color3.fromRGB(255, 40, 80), { Name = "Gem", Material = Enum.Material.Neon })
end

------------------------------------------------------------------------
-- Тело
------------------------------------------------------------------------

function Gear.Belt(rig: R6.Rig, color: Color3, buckle: Color3?)
	put(rig, "Torso", Vector3.new(2.06, 0.28, 1.06), CFrame.new(0, -0.82, 0), color, { Name = "Belt" })
	put(rig, "Torso", Vector3.new(0.4, 0.3, 0.08), CFrame.new(0, -0.82, -0.56), buckle or GOLD, { Name = "Buckle", Material = METAL })
end

function Gear.Vest(rig: R6.Rig, color: Color3)
	put(rig, "Torso", Vector3.new(2.12, 1.7, 1.14), CFrame.new(0, 0.1, 0), color, { Name = "Vest" })
	for _, x in { -0.5, 0.5 } do
		put(rig, "Torso", Vector3.new(0.5, 0.4, 0.15), CFrame.new(x, -0.3, -0.6), Parts.Darken(color, 0.2), { Name = "Pouch" })
	end
end

function Gear.Chestplate(rig: R6.Rig, color: Color3)
	put(rig, "Torso", Vector3.new(2.12, 1.8, 1.16), CFrame.new(0, 0.05, 0), color, { Name = "Chestplate", Material = METAL, Reflectance = 0.1 })
	for _, arm in { "Left Arm", "Right Arm" } do
		put(rig, arm, Vector3.new(1.15, 0.5, 1.15), CFrame.new(0, 0.75, 0), color, { Name = "Pauldron", Material = METAL })
	end
end

function Gear.Plates(rig: R6.Rig, color: Color3)
	put(rig, "Torso", Vector3.new(1.6, 1.0, 0.15), CFrame.new(0, 0.3, -0.58), color, { Name = "Plate", Material = METAL })
	for _, leg in { "Left Leg", "Right Leg" } do
		put(rig, leg, Vector3.new(1.1, 0.6, 1.1), CFrame.new(0, 0.1, 0), color, { Name = "KneePlate", Material = METAL })
	end
end

function Gear.AmmoBelt(rig: R6.Rig)
	put(rig, "Torso", Vector3.new(0.3, 2.5, 0.1), CFrame.new(0, 0.05, -0.6) * CFrame.Angles(0, 0, math.rad(40)), GOLD, { Name = "AmmoBelt", Material = METAL })
end

function Gear.Cape(rig: R6.Rig, color: Color3)
	put(rig, "Torso", Vector3.new(1.9, 2.6, 0.12), CFrame.new(0, -0.35, 0.6) * CFrame.Angles(math.rad(8), 0, 0), color, { Name = "Cape" })
end

function Gear.ShoulderPads(rig: R6.Rig, color: Color3)
	for _, arm in { "Left Arm", "Right Arm" } do
		put(rig, arm, Vector3.new(1.15, 0.45, 1.15), CFrame.new(0, 0.78, 0), color, { Name = "Pad" })
	end
end

function Gear.Plaid(rig: R6.Rig, base: Color3, stripe: Color3)
	put(rig, "Torso", Vector3.new(2.06, 2.02, 1.06), CFrame.new(), base, { Name = "Shirt" })
	for i = -1, 1 do
		put(rig, "Torso", Vector3.new(2.08, 0.14, 1.08), CFrame.new(0, i * 0.6, 0), stripe, { Name = "StripeH" })
		put(rig, "Torso", Vector3.new(0.14, 2.04, 1.08), CFrame.new(i * 0.6, 0, 0), stripe, { Name = "StripeV" })
	end
	for _, arm in { "Left Arm", "Right Arm" } do
		put(rig, arm, Vector3.new(1.04, 1.0, 1.04), CFrame.new(0, 0.5, 0), base, { Name = "Sleeve" })
	end
end

function Gear.Cross(rig: R6.Rig, color: Color3)
	put(rig, "Torso", Vector3.new(0.9, 0.25, 0.06), CFrame.new(0, 0.25, -0.53), color, { Name = "CrossH", Material = Enum.Material.Neon })
	put(rig, "Torso", Vector3.new(0.25, 0.9, 0.06), CFrame.new(0, 0.25, -0.53), color, { Name = "CrossV", Material = Enum.Material.Neon })
end

function Gear.Back(rig: R6.Rig, model: Model, offset: CFrame)
	local torso = rig.Parts.Torso
	model:PivotTo(torso.CFrame * offset)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model.Parent = rig.Model
end

return Gear
