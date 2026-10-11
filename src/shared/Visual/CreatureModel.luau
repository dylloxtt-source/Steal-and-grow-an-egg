--[[
	Блочные существа в студ-стиле. Модель строится в размере Adult,
	затем масштабируется под стадию роста и размер (Model:ScaleTo).
	Pivot — точка на земле под существом, «вперёд» — ось -Z (LookVector).
]]

local Config = script.Parent.Parent.Config
local Creatures = require(Config.Creatures)
local Game = require(Config.Game)
local Studs = require(script.Parent.Studs)

local CreatureModel = {}

local BLACK = Color3.fromRGB(25, 25, 30)
local WHITE = Color3.fromRGB(255, 255, 255)

local mutationById = {}
for _, mutation in Game.Mutations do
	mutationById[mutation.Id] = mutation
end

local RAINBOW = {
	Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 240, 70),
	Color3.fromRGB(90, 230, 110), Color3.fromRGB(70, 170, 255), Color3.fromRGB(180, 90, 255),
}

type Palette = { Body: Color3, Accent: Color3, Index: number, Rainbow: boolean }

local function bodyColor(palette: Palette): Color3
	if palette.Rainbow then
		palette.Index += 1
		return RAINBOW[(palette.Index - 1) % #RAINBOW + 1]
	end
	return palette.Body
end

local function add(model: Model, name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?)
	return Studs.Block(model, size, CFrame.new(pos), color,
		{ Name = name, CanCollide = false, Material = material, CastShadow = true })
end

local function eyes(model: Model, center: Vector3, spacing: number, size: number, angry: boolean?)
	for _, side in { -1, 1 } do
		local eyePos = center + Vector3.new(side * spacing, 0, 0)
		add(model, "Eye", Vector3.new(size, size, 0.2), eyePos, BLACK)
		add(model, "EyeShine", Vector3.new(size * 0.4, size * 0.4, 0.1),
			eyePos + Vector3.new(side * -size * 0.15, size * 0.18, -0.12), WHITE, Enum.Material.Neon)
		if angry then
			local brow = add(model, "Brow", Vector3.new(size * 1.3, size * 0.3, 0.2),
				eyePos + Vector3.new(0, size * 0.75, -0.05), BLACK)
			brow.CFrame = brow.CFrame * CFrame.Angles(0, 0, math.rad(20 * side))
		end
	end
end

local function buildQuad(model: Model, palette: Palette, angry: boolean?)
	add(model, "Body", Vector3.new(4, 3, 5), Vector3.new(0, 3.1, 0.5), bodyColor(palette))
	add(model, "Belly", Vector3.new(3, 0.4, 4), Vector3.new(0, 1.45, 0.5), palette.Accent)
	add(model, "Head", Vector3.new(3.2, 3, 3), Vector3.new(0, 4.6, -3), bodyColor(palette))
	add(model, "Snout", Vector3.new(1.6, 1.1, 0.8), Vector3.new(0, 3.9, -4.8), palette.Accent)
	add(model, "Nose", Vector3.new(0.6, 0.4, 0.3), Vector3.new(0, 4.3, -5.3), BLACK)
	eyes(model, Vector3.new(0, 5, -4.55), 0.85, 0.6, angry)
	for _, side in { -1, 1 } do
		add(model, "Ear", Vector3.new(0.8, 1.3, 0.6), Vector3.new(side * 1.1, 6.6, -2.8), palette.Accent)
		for _, z in { -1.3, 2.3 } do
			add(model, "Leg", Vector3.new(1, 1.6, 1), Vector3.new(side * 1.4, 0.8, z), bodyColor(palette))
			add(model, "Paw", Vector3.new(1.1, 0.4, 1.2), Vector3.new(side * 1.4, 0.2, z - 0.1), palette.Accent)
		end
	end
	add(model, "Tail", Vector3.new(0.8, 0.8, 2), Vector3.new(0, 4, 3.8), palette.Accent)
end

local function buildBird(model: Model, palette: Palette, angry: boolean?)
	add(model, "Body", Vector3.new(3.4, 3.4, 3.8), Vector3.new(0, 3, 0), bodyColor(palette))
	add(model, "Chest", Vector3.new(2.4, 2.2, 0.4), Vector3.new(0, 2.8, -2), palette.Accent)
	add(model, "Head", Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, 5.6, -0.8), bodyColor(palette))
	add(model, "Beak", Vector3.new(1, 0.7, 1.2), Vector3.new(0, 5.3, -2.6), Color3.fromRGB(255, 170, 40))
	add(model, "Crest", Vector3.new(0.5, 1.2, 1.4), Vector3.new(0, 7.4, -0.6), palette.Accent)
	eyes(model, Vector3.new(0, 6, -2.15), 0.7, 0.55, angry)
	for _, side in { -1, 1 } do
		local wing = add(model, "Wing", Vector3.new(0.5, 2.4, 3), Vector3.new(side * 1.95, 3.4, 0.2), palette.Accent)
		wing.CFrame = wing.CFrame * CFrame.Angles(0, 0, math.rad(-12 * side))
		add(model, "Leg", Vector3.new(0.5, 1.3, 0.5), Vector3.new(side * 0.8, 0.65, 0), Color3.fromRGB(255, 170, 40))
		add(model, "Foot", Vector3.new(0.9, 0.3, 1.1), Vector3.new(side * 0.8, 0.15, -0.3), Color3.fromRGB(255, 170, 40))
	end
	add(model, "TailFeather", Vector3.new(2, 0.4, 1.6), Vector3.new(0, 3.6, 2.5), palette.Accent)
end

local function buildBlob(model: Model, palette: Palette, angry: boolean?)
	add(model, "Body", Vector3.new(4.6, 2.6, 4.6), Vector3.new(0, 1.3, 0), bodyColor(palette))
	add(model, "Top", Vector3.new(3.6, 1.4, 3.6), Vector3.new(0, 3.3, 0), bodyColor(palette))
	add(model, "Cap", Vector3.new(2.2, 0.8, 2.2), Vector3.new(0, 4.4, 0), palette.Accent)
	eyes(model, Vector3.new(0, 3.2, -1.9), 0.8, 0.75, angry)
	add(model, "Mouth", Vector3.new(1.2, 0.3, 0.2), Vector3.new(0, 2.1, -2.35), BLACK)
	for _, side in { -1, 1 } do
		add(model, "Antenna", Vector3.new(0.3, 1.2, 0.3), Vector3.new(side * 0.7, 5.4, 0), palette.Accent)
		add(model, "AntennaTip", Vector3.new(0.6, 0.6, 0.6), Vector3.new(side * 0.7, 6.2, 0), palette.Accent, Enum.Material.Neon)
		add(model, "Cheek", Vector3.new(0.8, 0.5, 0.2), Vector3.new(side * 1.6, 2.6, -2.35), Studs.Lighten(palette.Accent, 0.3))
	end
end

local function buildWyrm(model: Model, palette: Palette, angry: boolean?)
	local segments = 4
	for i = 1, segments do
		local size = 2.8 - (i - 1) * 0.35
		local wave = math.sin(i * 1.2) * 0.6
		add(model, "Segment", Vector3.new(size, size, 2.2), Vector3.new(wave, size / 2 + 0.6, (i - 1) * 2.1), bodyColor(palette))
		add(model, "Spine", Vector3.new(0.5, 0.6, 0.8), Vector3.new(wave, size + 0.9, (i - 1) * 2.1), palette.Accent)
	end
	add(model, "Head", Vector3.new(3, 2.6, 3.2), Vector3.new(0, 2.6, -2.4), bodyColor(palette))
	add(model, "Jaw", Vector3.new(2.4, 0.8, 1.6), Vector3.new(0, 1.4, -3.2), palette.Accent)
	eyes(model, Vector3.new(0, 3.1, -4.05), 0.8, 0.6, angry)
	for _, side in { -1, 1 } do
		local horn = add(model, "Horn", Vector3.new(0.5, 1.6, 0.5), Vector3.new(side * 1, 4.4, -2), palette.Accent)
		horn.CFrame = horn.CFrame * CFrame.Angles(math.rad(-20), 0, math.rad(-15 * side))
		local wing = add(model, "Wing", Vector3.new(2.6, 0.3, 2), Vector3.new(side * 2.4, 3.6, 0.6), palette.Accent)
		wing.CFrame = wing.CFrame * CFrame.Angles(0, 0, math.rad(20 * side))
	end
end

local BUILDERS = {
	quad = buildQuad,
	bird = buildBird,
	blob = buildBlob,
	wyrm = buildWyrm,
}

export type BuildOptions = {
	Stage: string?,
	Size: number?,
	Mutation: string?,
	Angry: boolean?,
	ExtraScale: number?,
}

function CreatureModel.Build(speciesId: string, options: BuildOptions?): Model
	local def = Creatures.ById[speciesId]
	assert(def, "Unknown creature " .. tostring(speciesId))
	local opts: BuildOptions = options or {}
	local stage = opts.Stage or "Adult"
	local mutation = mutationById[opts.Mutation or "None"]

	local palette: Palette = { Body = def.Body, Accent = def.Accent, Index = 0, Rainbow = false }
	if mutation and mutation.Id == "Golden" then
		palette.Body = Color3.fromRGB(255, 205, 40)
		palette.Accent = Color3.fromRGB(255, 240, 150)
	elseif mutation and mutation.Id == "Silver" then
		palette.Body = Color3.fromRGB(205, 215, 230)
		palette.Accent = Studs.Lighten(def.Accent, 0.5)
	elseif mutation and mutation.Id == "Rainbow" then
		palette.Rainbow = true
	end

	local model = Instance.new("Model")
	model.Name = def.Name
	local root = Studs.Block(model, Vector3.new(4, 1, 4), CFrame.new(0, 0.5, 0), def.Body,
		{ Name = "Root", Transparency = 1, CanCollide = false, Studs = false })
	model.PrimaryPart = root

	local builder = BUILDERS[def.Archetype] or buildQuad
	builder(model, palette, opts.Angry)

	if mutation and mutation.Id == "Golden" then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "Root" and part.Name ~= "EyeShine" then
				part.Reflectance = 0.25
			end
		end
	end

	if stage == "Ascended" then
		local halo = Studs.Block(model, Vector3.new(3.4, 0.3, 3.4), CFrame.new(0, 8.4, -1), def.Accent,
			{ Name = "Halo", CanCollide = false, Material = Enum.Material.Neon, Studs = false })
		halo.Transparency = 0.15
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "Aura"
		aura.Rate = 10
		aura.Lifetime = NumberRange.new(1, 1.6)
		aura.Speed = NumberRange.new(1, 2)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Size = NumberSequence.new(0.4, 0)
		aura.Color = ColorSequence.new(def.Accent, WHITE)
		aura.LightEmission = 1
		aura.Parent = root
	end
	if mutation and mutation.Id ~= "None" then
		local glow = Instance.new("PointLight")
		glow.Color = mutation.Color or WHITE
		glow.Range = 8
		glow.Brightness = 1
		glow.Parent = root
	end

	local scale = (Game.Growth.StageScale[stage] or 1) * (opts.Size or 1) * (opts.ExtraScale or 1)
	if math.abs(scale - 1) > 0.001 then
		model:ScaleTo(scale)
	end

	model:SetAttribute("Species", speciesId)
	model:SetAttribute("Stage", stage)
	return model
end

return CreatureModel
