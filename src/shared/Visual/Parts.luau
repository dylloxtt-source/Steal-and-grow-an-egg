--[[
	Мелкие фабрики деталей для low-poly моделей: блоки, цилиндры, клинья, шары.
	Все детали гладкие (SmoothPlastic), без студов — единый «чистый» стиль.
]]

local Parts = {}

export type Options = {
	Name: string?,
	Material: Enum.Material?,
	Transparency: number?,
	Anchored: boolean?,
	CanCollide: boolean?,
	Shape: Enum.PartType?,
	Reflectance: number?,
	CastShadow: boolean?,
}

function Parts.Make(className: string, parent: Instance?, size: Vector3, cframe: CFrame, color: Color3, options: Options?): BasePart
	local opts: Options = options or {}
	local part = Instance.new(className) :: BasePart
	part.Name = opts.Name or className
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = opts.Material or Enum.Material.SmoothPlastic
	part.Transparency = opts.Transparency or 0
	part.Reflectance = opts.Reflectance or 0
	part.Anchored = if opts.Anchored == nil then true else opts.Anchored
	part.CanCollide = if opts.CanCollide == nil then false else opts.CanCollide
	part.CanTouch = false
	part.CastShadow = if opts.CastShadow == nil then true else opts.CastShadow
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if opts.Shape and part:IsA("Part") then
		part.Shape = opts.Shape
	end
	part.Parent = parent
	return part
end

function Parts.Block(parent: Instance?, size: Vector3, cframe: CFrame, color: Color3, options: Options?): BasePart
	return Parts.Make("Part", parent, size, cframe, color, options)
end

function Parts.Wedge(parent: Instance?, size: Vector3, cframe: CFrame, color: Color3, options: Options?): BasePart
	return Parts.Make("WedgePart", parent, size, cframe, color, options)
end

function Parts.Corner(parent: Instance?, size: Vector3, cframe: CFrame, color: Color3, options: Options?): BasePart
	return Parts.Make("CornerWedgePart", parent, size, cframe, color, options)
end

-- Цилиндр: в Roblox ось цилиндра — X. axis = "Y" или "Z" поворачивает его.
function Parts.Cylinder(parent: Instance?, length: number, diameter: number, cframe: CFrame, color: Color3, axis: string?, options: Options?): BasePart
	local opts = table.clone(options or {}) :: Options
	opts.Shape = Enum.PartType.Cylinder
	local rotation = CFrame.new()
	if axis == "Y" then
		rotation = CFrame.Angles(0, 0, math.pi / 2)
	elseif axis == "Z" then
		rotation = CFrame.Angles(0, math.pi / 2, 0)
	end
	return Parts.Make("Part", parent, Vector3.new(length, diameter, diameter), cframe * rotation, color, opts)
end

function Parts.Ball(parent: Instance?, diameter: number, cframe: CFrame, color: Color3, options: Options?): BasePart
	local opts = table.clone(options or {}) :: Options
	opts.Shape = Enum.PartType.Ball
	return Parts.Make("Part", parent, Vector3.new(diameter, diameter, diameter), cframe, color, opts)
end

function Parts.Neon(parent: Instance?, size: Vector3, cframe: CFrame, color: Color3, options: Options?): BasePart
	local opts = table.clone(options or {}) :: Options
	opts.Material = Enum.Material.Neon
	opts.CastShadow = false
	return Parts.Make("Part", parent, size, cframe, color, opts)
end

function Parts.Darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function Parts.Lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

return Parts
