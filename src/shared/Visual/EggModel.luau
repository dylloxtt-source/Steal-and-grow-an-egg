--[[
	Воксельное яйцо из слоёв-блоков со студами. Pivot — точка на земле под яйцом.
	Один и тот же билдер используется в мире (сервер) и во ViewportFrame (клиент).
]]

local Config = script.Parent.Parent.Config
local Eggs = require(Config.Eggs)
local Rarities = require(Config.Rarities)
local Studs = require(script.Parent.Studs)

local EggModel = {}

-- Ширина слоя (доля от максимальной) снизу вверх
local LAYERS = { 0.62, 0.88, 1, 1, 0.94, 0.8, 0.6, 0.36 }

-- Детерминированные «пятна»: слой, сторона (0..3), смещение вдоль стороны
local SPOTS = {
	{ 2, 0, -0.2 }, { 3, 1, 0.25 }, { 4, 2, 0 }, { 5, 3, -0.3 },
	{ 3, 3, 0.3 }, { 6, 0, 0.2 }, { 4, 1, -0.3 }, { 5, 2, 0.3 },
}

function EggModel.Build(eggId: string, scale: number?): Model
	local egg = Eggs.ById[eggId]
	assert(egg, "Unknown egg " .. tostring(eggId))
	local rarity = Rarities.ById[egg.Rarity]
	local s = scale or 1
	local width = 2.4 * s
	local layerHeight = 0.42 * s
	local totalHeight = layerHeight * #LAYERS

	local model = Instance.new("Model")
	model.Name = egg.Name

	local root = Studs.Block(model, Vector3.new(width, totalHeight, width),
		CFrame.new(0, totalHeight / 2, 0), egg.Shell,
		{ Name = "Root", Transparency = 1, CanCollide = false, Studs = false })
	model.PrimaryPart = root

	for i, fraction in LAYERS do
		local w = width * fraction
		local y = layerHeight * (i - 0.5)
		Studs.Block(model, Vector3.new(w, layerHeight, w), CFrame.new(0, y, 0), egg.Shell,
			{ Name = "Layer" .. i, CanCollide = false })
	end

	local spotSize = 0.5 * s
	local spotMaterial = if rarity.Order >= 5 then Enum.Material.Neon else Enum.Material.Plastic
	for _, spot in SPOTS do
		local layer, side, offset = spot[1], spot[2], spot[3]
		local w = width * LAYERS[layer]
		local y = layerHeight * (layer - 0.5)
		local outward = w / 2 + spotSize * 0.2
		local along = offset * w
		local pos
		if side == 0 then
			pos = Vector3.new(along, y, outward)
		elseif side == 1 then
			pos = Vector3.new(outward, y, along)
		elseif side == 2 then
			pos = Vector3.new(along, y, -outward)
		else
			pos = Vector3.new(-outward, y, along)
		end
		Studs.Block(model, Vector3.new(spotSize, spotSize, spotSize), CFrame.new(pos), egg.Spots,
			{ Name = "Spot", CanCollide = false, Material = spotMaterial })
	end

	-- Подсветка редких яиц
	if rarity.Order >= 3 then
		local light = Instance.new("PointLight")
		light.Color = if egg.Rarity == "Secret" then egg.Spots else rarity.Color
		light.Range = 6 + rarity.Order
		light.Brightness = 0.6 + rarity.Order * 0.15
		light.Parent = root
	end
	if rarity.Order >= 5 then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "Sparkle"
		sparkle.Rate = 4 + (rarity.Order - 5) * 4
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new(0.25 * s, 0)
		sparkle.Color = ColorSequence.new(rarity.Color, egg.Spots)
		sparkle.LightEmission = 1
		sparkle.Parent = root
	end

	model:SetAttribute("EggId", eggId)
	return model
end

return EggModel
