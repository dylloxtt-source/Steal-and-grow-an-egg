--[[
	Фабрика деталей в «студ»-стиле: классические студы сверху, inlet снизу,
	пластик и яркие цвета. Используется и картой, и моделями яиц/существ.
]]

local Studs = {}

export type BlockOptions = {
	Name: string?,
	Material: Enum.Material?,
	Transparency: number?,
	CanCollide: boolean?,
	Anchored: boolean?,
	Shape: Enum.PartType?,
	Studs: boolean?, -- false — гладкая деталь без студов
	CastShadow: boolean?,
	CanQuery: boolean?,
	CanTouch: boolean?,
}

function Studs.Block(parent: Instance?, size: Vector3, cframe: CFrame, color: Color3, options: BlockOptions?): Part
	local opts: BlockOptions = options or {}
	local part = Instance.new("Part")
	part.Name = opts.Name or "Block"
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = opts.Material or Enum.Material.Plastic
	part.Transparency = opts.Transparency or 0
	part.Anchored = if opts.Anchored == nil then true else opts.Anchored
	part.CanCollide = if opts.CanCollide == nil then true else opts.CanCollide
	part.CastShadow = if opts.CastShadow == nil then true else opts.CastShadow
	if opts.CanQuery ~= nil then
		part.CanQuery = opts.CanQuery
	end
	if opts.CanTouch ~= nil then
		part.CanTouch = opts.CanTouch
	end
	if opts.Shape then
		part.Shape = opts.Shape
	end
	if opts.Studs == false then
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
	else
		part.TopSurface = Enum.SurfaceType.Studs
		part.BottomSurface = Enum.SurfaceType.Inlet
	end
	part.Parent = parent
	return part
end

-- Блок, стоящий на земле: pos — точка на земле (низ блока)
function Studs.Ground(parent: Instance?, size: Vector3, pos: Vector3, color: Color3, options: BlockOptions?): Part
	return Studs.Block(parent, size, CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)), color, options)
end

-- Сваривает все BasePart модели с её PrimaryPart. Используется для переносимых моделей.
function Studs.WeldModel(model: Model)
	local root = model.PrimaryPart
	assert(root, "WeldModel: model has no PrimaryPart")
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
			descendant.Anchored = false
		end
	end
end

function Studs.SetModelPhysics(model: Model, anchored: boolean, canCollide: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant == model.PrimaryPart then
				descendant.Anchored = anchored
			end
			descendant.CanCollide = canCollide
			descendant.Massless = true
		end
	end
end

function Studs.Lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

function Studs.Darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

return Studs
