--[[
	Корневой ScreenGui и адаптивный масштаб. Дизайн-разрешение 1280×720.

	Масштабируется не весь экран, а каждый крупный блок (панель, колонка кнопок):
	Root.Fit(block) добавляет блоку UIScale. Блок привязан якорем к краю или центру
	экрана, поэтому на телефоне он уменьшается и остаётся на своём месте,
	а на большом мониторе — немного увеличивается. Слои — просто полноэкранные рамки.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Kit = require(script.Parent.Kit)

local Root = {}

Root.Screen = nil :: ScreenGui?
Root.Scale = 1

local scales: { UIScale } = {}

local function compute(): number
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	if size.X < 1 or size.Y < 1 then
		size = Vector2.new(1280, 720)
	end
	local scale = math.min(size.X / 1280, size.Y / 720)
	-- Телефоны: чуть крупнее, чтобы текст читался, а кнопки было удобно нажимать
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		scale *= 1.15
	end
	return math.clamp(scale, 0.55, 1.35)
end

local function update()
	Root.Scale = compute()
	local alive = {}
	for _, scale in scales do
		if scale.Parent then
			scale.Scale = Root.Scale
			table.insert(alive, scale)
		end
	end
	scales = alive
end

function Root.Init(): ScreenGui
	local screen = Kit.Create("ScreenGui", {
		Name = "TD_UI",
		ResetOnSpawn = false,
		-- Не залезаем под системные кнопки Roblox (меню, чат) в верхней полосе
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	Root.Screen = screen
	update()
	local function watch()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
	end
	watch()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watch()
		update()
	end)
	return screen
end

-- Полноэкранный прозрачный слой (без масштаба)
function Root.Layer(name: string): Frame
	return Kit.Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = Root.Screen,
	})
end

-- Подключить блок к адаптивному масштабу
function Root.Fit<T>(block: T): T
	local scale = Kit.Create("UIScale", { Name = "FitScale", Scale = Root.Scale, Parent = block })
	table.insert(scales, scale)
	return block
end

return Root
