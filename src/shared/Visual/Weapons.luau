--[[
	Оружие башен и врагов. Каждый билдер возвращает Model:
	  PrimaryPart = Handle в точке хвата, «вперёд» = -Z, «вверх» = +Y.
	  Attachment "Muzzle" (если есть) — откуда вылетают пули/стрелы/яд.
	tier 1..3 — визуальный уровень (улучшения меняют материал, размеры, свечение).
]]

local Parts = require(script.Parent.Parts)

local Weapons = {}

local IRON = Color3.fromRGB(165, 170, 180)
local STEEL = Color3.fromRGB(205, 215, 230)
local GOLD = Color3.fromRGB(255, 200, 60)
local WOOD = Color3.fromRGB(120, 78, 45)
local DARK = Color3.fromRGB(45, 45, 52)
local GUNMETAL = Color3.fromRGB(70, 74, 84)

local function new(name: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	local handle = Parts.Block(model, Vector3.new(0.2, 0.2, 0.2), CFrame.new(), DARK, { Name = "Handle", Transparency = 1 })
	model.PrimaryPart = handle
	return model, handle
end

local function muzzle(handle: BasePart, offset: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Muzzle"
	attachment.Position = offset
	attachment.Parent = handle
end

local function finish(model: Model): Model
	local root = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
	return model
end

function Weapons.Sword(tier: number): Model
	local model = new("Sword")
	local bladeColor = if tier >= 3 then Color3.fromRGB(120, 200, 255) elseif tier == 2 then STEEL else IRON
	local length = 2.6 + tier * 0.35
	Parts.Block(model, Vector3.new(0.28, 0.28, 0.9), CFrame.new(0, 0, 0.2), WOOD, { Name = "Grip" })
	Parts.Block(model, Vector3.new(0.34, 0.34, 0.25), CFrame.new(0, 0, 0.7), if tier >= 2 then GOLD else IRON, { Name = "Pommel" })
	Parts.Block(model, Vector3.new(1.3 + tier * 0.15, 0.22, 0.26), CFrame.new(0, 0, -0.35), if tier >= 2 then GOLD else IRON, { Name = "Guard" })
	local blade = Parts.Block(model, Vector3.new(0.12, 0.38 + tier * 0.04, length), CFrame.new(0, 0, -0.45 - length / 2), bladeColor,
		{ Name = "Blade", Material = if tier >= 3 then Enum.Material.Neon else Enum.Material.Metal, Reflectance = 0.15 })
	Parts.Wedge(model, Vector3.new(0.12, 0.38 + tier * 0.04, 0.5), CFrame.new(0, 0, -0.7 - length) * CFrame.Angles(0, math.pi, 0),
		bladeColor, { Name = "Tip", Material = blade.Material })
	if tier >= 3 then
		local light = Instance.new("PointLight")
		light.Color = bladeColor
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = blade
	end
	return finish(model)
end

function Weapons.Bow(tier: number): Model
	local model, handle = new("Bow")
	local wood = if tier >= 3 then Color3.fromRGB(70, 40, 25) elseif tier == 2 then Color3.fromRGB(150, 95, 50) else WOOD
	local trim = if tier >= 2 then GOLD else wood
	Parts.Block(model, Vector3.new(0.22, 0.6, 0.22), CFrame.new(), trim, { Name = "Riser" })
	-- Плечи лука: ломаная к игроку (+Z), концы соединены тетивой
	local points = { Vector3.new(0, 0.3, 0), Vector3.new(0, 0.9, 0.06), Vector3.new(0, 1.4, 0.2), Vector3.new(0, 1.75, 0.42) }
	for _, side in { 1, -1 } do
		for i = 1, #points - 1 do
			local a = Vector3.new(0, points[i].Y * side, points[i].Z)
			local b = Vector3.new(0, points[i + 1].Y * side, points[i + 1].Z)
			local mid = (a + b) / 2
			local up = if math.abs((b - a).Unit.Y) > 0.99 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
			Parts.Block(model, Vector3.new(0.16, 0.16, (b - a).Magnitude + 0.06), CFrame.lookAt(mid, b, up), wood, { Name = "Limb" })
		end
	end
	Parts.Block(model, Vector3.new(0.04, 3.5, 0.04), CFrame.new(0, 0, 0.42), Color3.fromRGB(240, 240, 230), { Name = "String" })
	Parts.Block(model, Vector3.new(0.06, 0.06, 2.2), CFrame.new(0, 0, -0.6), WOOD, { Name = "Arrow" })
	Parts.Wedge(model, Vector3.new(0.12, 0.18, 0.3), CFrame.new(0, 0, -1.8) * CFrame.Angles(0, math.pi, 0), IRON, { Name = "ArrowTip" })
	muzzle(handle, Vector3.new(0, 0, -1.9))
	if tier >= 3 then
		Parts.Neon(model, Vector3.new(0.06, 3.2, 0.06), CFrame.new(0, 0, 0.1), Color3.fromRGB(140, 255, 140), { Name = "Glow" })
	end
	return finish(model)
end

function Weapons.Quiver(tier: number): Model
	local model = new("Quiver")
	Parts.Cylinder(model, 1.7, 0.6, CFrame.new(0, 0, 0), if tier >= 2 then Color3.fromRGB(110, 60, 35) else Color3.fromRGB(140, 90, 50), "Y", { Name = "Body" })
	for i = 1, 4 do
		local x = (i - 2.5) * 0.12
		Parts.Block(model, Vector3.new(0.06, 0.6, 0.06), CFrame.new(x, 1.1, 0), WOOD, { Name = "Shaft" })
		Parts.Block(model, Vector3.new(0.18, 0.25, 0.05), CFrame.new(x, 1.4, 0), Color3.fromRGB(240, 240, 240), { Name = "Fletch" })
	end
	return finish(model)
end

function Weapons.Pistol(tier: number): Model
	local model, handle = new("Pistol")
	local body = if tier >= 3 then GOLD elseif tier == 2 then GUNMETAL else DARK
	Parts.Block(model, Vector3.new(0.24, 0.55, 0.3), CFrame.new(0, -0.15, 0.05) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(80, 50, 30), { Name = "Grip" })
	Parts.Block(model, Vector3.new(0.26, 0.3, 0.95), CFrame.new(0, 0.25, -0.25), body, { Name = "Slide", Material = Enum.Material.Metal })
	Parts.Cylinder(model, 0.25, 0.16, CFrame.new(0, 0.27, -0.8), DARK, "Z", { Name = "Barrel" })
	muzzle(handle, Vector3.new(0, 0.27, -0.95))
	return finish(model)
end

function Weapons.MachineGun(tier: number): Model
	local model, handle = new("MachineGun")
	local body = if tier >= 3 then Color3.fromRGB(60, 65, 50) else GUNMETAL
	Parts.Block(model, Vector3.new(0.45, 0.5, 1.6), CFrame.new(0, 0.2, -0.3), body, { Name = "Receiver", Material = Enum.Material.Metal })
	Parts.Block(model, Vector3.new(0.3, 0.45, 0.8), CFrame.new(0, 0.05, 0.85), Color3.fromRGB(70, 50, 35), { Name = "Stock" })
	Parts.Block(model, Vector3.new(0.4, 0.45, 0.5), CFrame.new(0, -0.3, -0.4), Color3.fromRGB(80, 90, 60), { Name = "AmmoBox" })
	if tier >= 3 then
		for i = 0, 2 do
			local angle = i * math.pi * 2 / 3
			Parts.Cylinder(model, 1.6, 0.14, CFrame.new(math.cos(angle) * 0.12, 0.2 + math.sin(angle) * 0.12, -1.85), DARK, "Z", { Name = "Barrel" })
		end
		Parts.Cylinder(model, 0.2, 0.42, CFrame.new(0, 0.2, -2.5), GUNMETAL, "Z", { Name = "BarrelRing" })
		muzzle(handle, Vector3.new(0, 0.2, -2.7))
	else
		local length = 1.2 + tier * 0.25
		Parts.Cylinder(model, length, 0.18, CFrame.new(0, 0.22, -1.1 - length / 2), DARK, "Z", { Name = "Barrel" })
		Parts.Block(model, Vector3.new(0.08, 0.5, 0.08), CFrame.new(0, -0.05, -1.3), DARK, { Name = "Bipod" })
		muzzle(handle, Vector3.new(0, 0.22, -1.15 - length))
	end
	-- Лента патронов
	for i = 1, 3 do
		Parts.Block(model, Vector3.new(0.12, 0.08, 0.14), CFrame.new(0.28, -0.1 - i * 0.12, -0.4), GOLD, { Name = "Belt" })
	end
	return finish(model)
end

function Weapons.Sniper(tier: number): Model
	local model, handle = new("Sniper")
	local body = if tier >= 3 then Color3.fromRGB(40, 40, 46) elseif tier == 2 then Color3.fromRGB(70, 80, 60) else Color3.fromRGB(95, 70, 45)
	local length = 2.4 + tier * 0.4
	Parts.Block(model, Vector3.new(0.3, 0.35, 1.8), CFrame.new(0, 0.15, -0.2), body, { Name = "Body" })
	Parts.Block(model, Vector3.new(0.26, 0.5, 0.9), CFrame.new(0, 0.0, 1.1), body, { Name = "Stock" })
	Parts.Cylinder(model, length, 0.14, CFrame.new(0, 0.22, -1.1 - length / 2), DARK, "Z", { Name = "Barrel" })
	Parts.Cylinder(model, 0.9, 0.24, CFrame.new(0, 0.55, -0.3), DARK, "Z", { Name = "Scope" })
	Parts.Neon(model, Vector3.new(0.16, 0.16, 0.05), CFrame.new(0, 0.55, -0.76), Color3.fromRGB(120, 200, 255), { Name = "Lens" })
	if tier >= 2 then
		Parts.Cylinder(model, 0.35, 0.22, CFrame.new(0, 0.22, -1.25 - length), GUNMETAL, "Z", { Name = "Brake" })
	end
	muzzle(handle, Vector3.new(0, 0.22, -1.45 - length))
	return finish(model)
end

function Weapons.ToxicGun(tier: number): Model
	local model, handle = new("ToxicGun")
	local toxic = Color3.fromRGB(110, 255, 80)
	Parts.Block(model, Vector3.new(0.35, 0.4, 1.3), CFrame.new(0, 0.2, -0.2), Color3.fromRGB(60, 70, 60), { Name = "Body" })
	Parts.Cylinder(model, 0.9 + tier * 0.15, 0.45, CFrame.new(0, 0.62, -0.25), toxic, "Z", { Name = "Canister", Material = Enum.Material.Neon, Transparency = 0.15 })
	Parts.Cylinder(model, 0.9, 0.2, CFrame.new(0, 0.22, -1.25), DARK, "Z", { Name = "Nozzle" })
	Parts.Cylinder(model, 0.18, 0.32, CFrame.new(0, 0.22, -1.72), toxic, "Z", { Name = "Tip", Material = Enum.Material.Neon })
	Parts.Block(model, Vector3.new(0.24, 0.5, 0.28), CFrame.new(0, -0.15, 0.2), DARK, { Name = "Grip" })
	muzzle(handle, Vector3.new(0, 0.22, -1.85))
	return finish(model)
end

function Weapons.ToxicTank(tier: number): Model
	local model = new("ToxicTank")
	local toxic = Color3.fromRGB(110, 255, 80)
	for _, x in { -0.35, 0.35 } do
		Parts.Cylinder(model, 1.5, 0.6, CFrame.new(x, 0, 0), toxic, "Y", { Name = "Tank", Material = Enum.Material.Neon, Transparency = 0.2 })
		Parts.Cylinder(model, 0.2, 0.66, CFrame.new(x, 0.8, 0), DARK, "Y", { Name = "Cap" })
	end
	if tier >= 2 then
		Parts.Block(model, Vector3.new(1.3, 0.2, 0.7), CFrame.new(0, -0.6, 0), DARK, { Name = "Frame" })
	end
	return finish(model)
end

function Weapons.Axe(tier: number): Model
	local model = new("Axe")
	local length = 2.6 + tier * 0.3
	local headColor = if tier >= 3 then Color3.fromRGB(230, 70, 60) elseif tier == 2 then STEEL else IRON
	Parts.Block(model, Vector3.new(0.26, 0.26, length), CFrame.new(0, 0, -length / 2 + 0.6), WOOD, { Name = "Shaft" })
	local headZ = -length + 0.75
	local size = 1 + tier * 0.25
	Parts.Block(model, Vector3.new(0.22, 0.5, 0.55), CFrame.new(0, 0.2, headZ), DARK, { Name = "Eye" })
	Parts.Wedge(model, Vector3.new(0.18, size, 0.9 * size), CFrame.new(0, 0.2 + size / 2 + 0.15, headZ) * CFrame.Angles(0, 0, 0), headColor,
		{ Name = "Blade", Material = Enum.Material.Metal, Reflectance = 0.1 })
	if tier >= 3 then
		Parts.Wedge(model, Vector3.new(0.18, size, 0.9 * size), CFrame.new(0, 0.2 - size / 2 - 0.15, headZ) * CFrame.Angles(math.pi, 0, 0), headColor,
			{ Name = "Blade2", Material = Enum.Material.Metal })
		Parts.Neon(model, Vector3.new(0.2, 0.15, 0.9), CFrame.new(0, 0.2, headZ), Color3.fromRGB(255, 140, 60), { Name = "Rune" })
	end
	return finish(model)
end

-- Когти росомахи: три лезвия от костяшек вперёд
function Weapons.Claws(tier: number): Model
	local model = new("Claws")
	local length = 1.4 + tier * 0.35
	local color = if tier >= 3 then Color3.fromRGB(225, 235, 250) else Color3.fromRGB(195, 200, 210)
	for i = -1, 1 do
		local x = i * 0.28
		Parts.Block(model, Vector3.new(0.07, 0.14, length), CFrame.new(x, 0, -length / 2 - 0.1), color,
			{ Name = "Blade", Material = Enum.Material.Metal, Reflectance = 0.35 })
		Parts.Wedge(model, Vector3.new(0.07, 0.14, 0.3), CFrame.new(x, 0, -length - 0.25) * CFrame.Angles(0, math.pi, 0), color,
			{ Name = "Tip", Material = Enum.Material.Metal, Reflectance = 0.35 })
	end
	return finish(model)
end

-- Оружие врагов
function Weapons.Club(): Model
	local model = new("Club")
	Parts.Block(model, Vector3.new(0.3, 0.3, 2.2), CFrame.new(0, 0, -0.8), WOOD, { Name = "Shaft" })
	Parts.Block(model, Vector3.new(0.7, 0.7, 1.1), CFrame.new(0, 0, -2.2), Color3.fromRGB(100, 65, 40), { Name = "Head" })
	return finish(model)
end

function Weapons.Hammer(): Model
	local model = new("Hammer")
	Parts.Block(model, Vector3.new(0.28, 0.28, 2.6), CFrame.new(0, 0, -1), DARK, { Name = "Shaft" })
	Parts.Block(model, Vector3.new(0.9, 0.9, 1.6), CFrame.new(0, 0, -2.4) * CFrame.Angles(0, math.pi / 2, 0), IRON, { Name = "Head", Material = Enum.Material.Metal })
	return finish(model)
end

function Weapons.Greatsword(): Model
	local model = new("Greatsword")
	Parts.Block(model, Vector3.new(0.3, 0.3, 1.2), CFrame.new(0, 0, 0.3), DARK, { Name = "Grip" })
	Parts.Block(model, Vector3.new(1.8, 0.3, 0.3), CFrame.new(0, 0, -0.4), Color3.fromRGB(150, 20, 30), { Name = "Guard" })
	Parts.Block(model, Vector3.new(0.18, 0.6, 4), CFrame.new(0, 0, -2.5), Color3.fromRGB(60, 60, 70), { Name = "Blade", Material = Enum.Material.Metal })
	Parts.Neon(model, Vector3.new(0.2, 0.12, 3.8), CFrame.new(0, 0, -2.5), Color3.fromRGB(255, 50, 60), { Name = "Edge" })
	return finish(model)
end

function Weapons.Staff(): Model
	local model = new("Staff")
	Parts.Cylinder(model, 3.6, 0.18, CFrame.new(0, 0, -0.6), WOOD, "Z", { Name = "Shaft" })
	Parts.Ball(model, 0.55, CFrame.new(0, 0, -2.5), Color3.fromRGB(120, 255, 140), { Name = "Orb", Material = Enum.Material.Neon })
	return finish(model)
end

function Weapons.TowerShield(): Model
	local model = new("TowerShield")
	Parts.Block(model, Vector3.new(1.6, 2.4, 0.2), CFrame.new(0, 0.2, -0.3), Color3.fromRGB(40, 110, 200), { Name = "Plate", Material = Enum.Material.Metal })
	Parts.Neon(model, Vector3.new(1.2, 0.15, 0.05), CFrame.new(0, 0.6, -0.42), Color3.fromRGB(120, 220, 255), { Name = "Stripe" })
	return finish(model)
end

return Weapons
