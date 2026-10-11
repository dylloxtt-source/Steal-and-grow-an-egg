--[[
	Router — корневой ScreenGui, адаптивный масштаб и переключение окон.
	Одновременно открыто не больше одного окна; Esc/крестик закрывают его.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Kit = require(script.Parent.Kit)

local Router = {}

export type PanelModule = {
	Build: (any, ScreenGui) -> (),
	Open: (any, any?) -> (),
	Close: (any) -> (),
	Refresh: ((any) -> ())?,
	IsOpen: ((any) -> boolean)?,
}

local panels: { [string]: any } = {}
local current: string? = nil
Router.Screen = nil :: ScreenGui?
Router.Opened = Instance.new("BindableEvent")

local function updateScale(scale: UIScale)
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.5, 1.3)
end

function Router.Init(): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = Kit.Create("ScreenGui", {
		Name = "SGAE_UI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	local scale = Kit.Create("UIScale", { Parent = screen })
	updateScale(scale)
	local function watchCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				updateScale(scale)
			end)
		end
	end
	watchCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera()
		updateScale(scale)
	end)
	Router.Screen = screen

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			Router.Close()
		end
	end)
	return screen
end

-- Размер экрана в «дизайн-пикселях» (с учётом UIScale)
function Router.DesignSize(): Vector2
	local screen = Router.Screen :: ScreenGui
	local scale = screen:FindFirstChildOfClass("UIScale")
	local s = if scale then scale.Scale else 1
	return screen.AbsoluteSize / s
end

function Router.Register(name: string, module: any)
	panels[name] = module
	module:Build(Router.Screen)
end

function Router.Open(name: string, args: any?)
	local module = panels[name]
	if not module then
		return
	end
	if current and current ~= name then
		panels[current]:Close()
	end
	current = name
	module:Open(args)
	Router.Opened:Fire(name)
end

function Router.Toggle(name: string, args: any?)
	if current == name then
		Router.Close()
	else
		Router.Open(name, args)
	end
end

function Router.Close()
	if current then
		local module = panels[current]
		current = nil
		module:Close()
		Router.Opened:Fire(nil)
	end
end

function Router.Current(): string?
	return current
end

function Router.Get(name: string): any
	return panels[name]
end

function Router.RefreshAll()
	for name, module in panels do
		if module.Refresh and (current == name or module.AlwaysRefresh) then
			module:Refresh()
		end
	end
end

-- Анимация появления окна
function Router.ShowPanel(panel: Kit.Panel)
	panel.Root.Visible = true
	panel.Scale.Scale = 0.75
	Kit.Tween(panel.Scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
end

function Router.HidePanel(panel: Kit.Panel)
	panel.Root.Visible = false
end

return Router
