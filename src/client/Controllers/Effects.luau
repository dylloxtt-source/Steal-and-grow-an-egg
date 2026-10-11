--[[
	Визуальные эффекты с переиспользованием деталей (пул) и единым циклом обновления.
	Никаких постоянно живущих ParticleEmitter и бесконечных циклов на эффект:
	каждый эффект — запись {деталь, время жизни, функция обновления}.
	Все детали без коллизий и запросов (CanCollide/CanQuery/CanTouch = false).
]]

local RunService = game:GetService("RunService")

local Effects = {}

local folder: Folder
local pools: { [string]: { BasePart } } = {}
local active: { any } = {}
local HIDDEN = CFrame.new(0, -1000, 0)
local MAX_ACTIVE = 400

local function newPart(kind: string): BasePart
	local part
	if kind == "ball" then
		part = Instance.new("Part")
		part.Shape = Enum.PartType.Ball
	elseif kind == "ring" then
		part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
	else
		part = Instance.new("Part")
	end
	part.Name = "Fx_" .. kind
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = HIDDEN
	part.Parent = folder
	return part
end

local function acquire(kind: string): BasePart
	local pool = pools[kind]
	if pool and #pool > 0 then
		return table.remove(pool) :: BasePart
	end
	return newPart(kind)
end

local function release(kind: string, part: BasePart)
	part.CFrame = HIDDEN
	part.Transparency = 1
	pools[kind] = pools[kind] or {}
	table.insert(pools[kind], part)
end

local function spawn(kind: string, life: number, update: (BasePart, number) -> ()): BasePart?
	if #active >= MAX_ACTIVE then
		return nil
	end
	local part = acquire(kind)
	table.insert(active, { Kind = kind, Part = part, Start = os.clock(), Life = life, Update = update })
	update(part, 0)
	return part
end

-- Трассер пули: тонкий луч от дула к цели, быстро гаснет
function Effects.Tracer(from: Vector3, to: Vector3, color: Color3, width: number?)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local w = width or 0.15
	local cf = CFrame.lookAt((from + to) / 2, to)
	spawn("block", 0.09, function(part, alpha)
		if alpha == 0 then
			part.Color = color
			part.Size = Vector3.new(w, w, length)
			part.CFrame = cf
		end
		part.Transparency = 0.1 + alpha * 0.9
	end)
end

function Effects.Flash(position: Vector3, color: Color3, size: number?)
	local s = size or 0.8
	spawn("ball", 0.07, function(part, alpha)
		part.Color = color
		part.Size = Vector3.one * s * (1 + alpha)
		part.CFrame = CFrame.new(position)
		part.Transparency = 0.2 + alpha * 0.8
	end)
end

-- Снаряд, летящий к движущейся цели (getTarget возвращает текущую точку)
function Effects.Projectile(from: Vector3, getTarget: () -> Vector3, duration: number, style: string, onArrive: ((Vector3) -> ())?)
	local d = math.max(duration, 0.05)
	local arrived = false
	local kind = if style == "toxic" then "ball" else "block"
	spawn(kind, d, function(part, alpha)
		local target = getTarget()
		local position = from:Lerp(target, alpha)
		if style == "arrow" then
			part.Color = Color3.fromRGB(240, 230, 210)
			part.Material = Enum.Material.SmoothPlastic
			part.Size = Vector3.new(0.12, 0.12, 1.6)
			local arc = math.sin(alpha * math.pi) * 1.2
			local next = from:Lerp(target, math.min(1, alpha + 0.05)) + Vector3.new(0, math.sin(math.min(1, alpha + 0.05) * math.pi) * 1.2, 0)
			local here = position + Vector3.new(0, arc, 0)
			part.CFrame = if (next - here).Magnitude > 0.01 then CFrame.lookAt(here, next) else CFrame.new(here)
			part.Transparency = 0
		else
			part.Material = Enum.Material.Neon
			part.Color = Color3.fromRGB(120, 255, 90)
			part.Size = Vector3.one * 0.7
			part.CFrame = CFrame.new(position + Vector3.new(0, math.sin(alpha * math.pi) * 1.5, 0))
			part.Transparency = 0.1
		end
		if alpha >= 1 and not arrived then
			arrived = true
			part.Material = Enum.Material.Neon
			if onArrive then
				onArrive(target)
			end
		end
	end)
end

-- Расходящееся кольцо (топот, лечение, ударная волна)
function Effects.Ring(position: Vector3, radius: number, color: Color3, life: number?)
	spawn("ring", life or 0.5, function(part, alpha)
		part.Color = color
		local r = radius * (0.2 + alpha * 0.8) * 2
		part.Size = Vector3.new(0.3, r, r)
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		part.Transparency = 0.3 + alpha * 0.7
	end)
end

-- Дуга удара мечом/топором/когтями
function Effects.Slash(position: Vector3, facing: Vector3, color: Color3, size: number?)
	local s = size or 4
	local dir = Vector3.new(facing.X, 0, facing.Z)
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, 0, -1)
	local base = CFrame.lookAt(position + Vector3.new(0, 2.5, 0), position + Vector3.new(0, 2.5, 0) + dir)
	spawn("block", 0.18, function(part, alpha)
		part.Color = color
		part.Size = Vector3.new(s * (0.6 + alpha * 0.6), 0.15, 0.5)
		part.CFrame = base * CFrame.Angles(0, 0, math.rad(-50 + alpha * 100))
		part.Transparency = 0.15 + alpha * 0.85
	end)
end

function Effects.Puff(position: Vector3, color: Color3, count: number?)
	for i = 1, count or 6 do
		local angle = (i / (count or 6)) * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0.6 + (i % 3) * 0.3, math.sin(angle))
		spawn("block", 0.5, function(part, alpha)
			part.Material = Enum.Material.SmoothPlastic
			part.Color = color
			part.Size = Vector3.one * (0.6 * (1 - alpha) + 0.1)
			part.CFrame = CFrame.new(position + dir * (alpha * 3)) * CFrame.Angles(alpha * 3, alpha * 2, 0)
			part.Transparency = alpha
		end)
	end
end

function Effects.Cloud(position: Vector3, radius: number)
	spawn("ball", 1.2, function(part, alpha)
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(110, 220, 80)
		local r = radius * 2 * (0.5 + 0.5 * math.min(1, alpha * 3))
		part.Size = Vector3.new(r, r * 0.45, r)
		part.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
		part.Transparency = 0.55 + alpha * 0.45
	end)
end

function Effects.Sparkle(position: Vector3, color: Color3)
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		spawn("block", 0.6, function(part, alpha)
			part.Color = color
			part.Size = Vector3.one * 0.35
			part.CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 2, alpha * 5, math.sin(angle) * 2))
			part.Transparency = alpha
		end)
	end
end

function Effects.Init()
	folder = Instance.new("Folder")
	folder.Name = "ClientFx"
	folder.Parent = workspace
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for i = #active, 1, -1 do
			local effect = active[i]
			local alpha = math.min(1, (now - effect.Start) / effect.Life)
			effect.Update(effect.Part, alpha)
			if alpha >= 1 then
				table.remove(active, i)
				release(effect.Kind, effect.Part)
			end
		end
	end)
end

function Effects.ActiveCount(): number
	return #active
end

return Effects
