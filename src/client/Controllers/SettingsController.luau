--[[
	Настройки игрока (сохраняются в профиле): авто-скип волн, звуки, всплывающие
	награды и упрощённые эффекты. Открываются из лобби и из матча.
	Переключатель меняется сразу, сервер подтверждает и сохраняет.
]]

local Kit = require(script.Parent.Parent.UI.Kit)
local Root = require(script.Parent.Parent.UI.Root)
local State = require(script.Parent.Parent.State)
local Sound = require(script.Parent.Sound)
local Effects = require(script.Parent.Effects)

local C = Kit.Theme.Colors

local SettingsController = {}

local refs: any = {}

local OPTIONS = {
	{ Key = "autoSkip", Title = "Auto Skip", Icon = "⏭", Text = "Start the next wave as soon as everyone is ready" },
	{ Key = "sfx", Title = "Sound Effects", Icon = "🔊", Text = "Weapon, wave and interface sounds" },
	{ Key = "popups", Title = "Reward Popups", Icon = "💵", Text = "Show +$ above defeated enemies" },
	{ Key = "lowFx", Title = "Low Effects", Icon = "⚡", Text = "Fewer particles for slower devices" },
}

SettingsController.Changed = Instance.new("BindableEvent") -- (key, value)

function SettingsController.Get(key: string): boolean
	local profile = State.Profile
	local settings = profile and profile.settings
	if settings and settings[key] ~= nil then
		return settings[key]
	end
	return key == "sfx" or key == "popups"
end

function SettingsController.Set(key: string, value: boolean)
	if State.Profile and State.Profile.settings then
		State.Profile.settings[key] = value -- сразу на клиенте; сервер пришлёт подтверждённый профиль
	end
	SettingsController.Apply()
	SettingsController.Changed:Fire(key, value)
	State.Fire("SetSetting", { key = key, value = value })
end

function SettingsController.Apply()
	Sound.Enabled = SettingsController.Get("sfx")
	Effects.Low = SettingsController.Get("lowFx")
	for key, toggle in refs.Toggles or {} do
		local value = SettingsController.Get(key)
		if toggle.Value ~= value then
			toggle:Set(value)
		end
	end
end

local function build(screen: Instance)
	local layer = Root.Layer("Settings")
	layer.ZIndex = 35
	layer.Visible = false
	refs.Layer = layer
	local dim = Kit.Create("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Black, BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1), Parent = layer })
	dim.Activated:Connect(function()
		SettingsController.Close()
	end)
	local window = Root.Fit(Kit.Panel({ Name = "Window", Size = UDim2.fromOffset(480, 72 + #OPTIONS * 76), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), Parent = layer }))
	refs.Window = window
	Kit.Header(window, { Title = "SETTINGS", Icon = "⚙", Accent = C.PanelLighter, OnClose = SettingsController.Close })
	refs.Toggles = {}
	for i, option in OPTIONS do
		local row = Kit.Inset({ Name = option.Key, Size = UDim2.new(1, -28, 0, 66), Position = UDim2.fromOffset(14, 64 + (i - 1) * 76), Parent = window })
		Kit.Text({ Text = option.Icon, Size = UDim2.fromOffset(44, 66), Position = UDim2.fromOffset(6, 0), TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center,
			Parent = row })
		Kit.Text({ Text = option.Title, Font = "Display", TextSize = 19, Size = UDim2.new(1, -140, 0, 24), Position = UDim2.fromOffset(54, 10), Stroke = true, Parent = row })
		Kit.Text({ Text = option.Text, TextSize = 12, Weight = "Semi", TextColor3 = C.SubText, Size = UDim2.new(1, -140, 0, 18), Position = UDim2.fromOffset(54, 36),
			Parent = row })
		refs.Toggles[option.Key] = Kit.Toggle({ Name = "Toggle", Value = SettingsController.Get(option.Key), Position = UDim2.new(1, -14, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5), Parent = row, OnChanged = function(value)
				Sound.Play("Click")
				SettingsController.Set(option.Key, value)
			end })
	end
end

function SettingsController.Open()
	refs.Layer.Visible = true
	local scale = refs.Window:FindFirstChild("FitScale") :: UIScale
	scale.Scale = Root.Scale * 0.9
	Kit.Tween(scale, 0.2, { Scale = Root.Scale }, Enum.EasingStyle.Back)
	SettingsController.Apply()
end

function SettingsController.Close()
	refs.Layer.Visible = false
end

function SettingsController.Toggle()
	if refs.Layer.Visible then
		SettingsController.Close()
	else
		SettingsController.Open()
	end
end

function SettingsController.Init(screen: Instance)
	build(screen)
	State.ProfileChanged.Event:Connect(SettingsController.Apply)
	SettingsController.Apply()
end

return SettingsController
