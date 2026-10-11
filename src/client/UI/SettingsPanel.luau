--[[
	Настройки: медленный режим, звуки, пропуск обучения и справка по управлению.
]]

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Router)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.Parent.State)

local C = Kit.Theme.Colors

local SettingsPanel = {}

local panel: Kit.Panel
local slowLabel: TextLabel
local soundLabel: TextLabel

function SettingsPanel:Refresh()
	if not panel.Root.Visible then
		return
	end
	local profile = State.Profile()
	if profile then
		slowLabel.Text = "Slow Mode: " .. (if profile.settings.slowMode then "ON" else "OFF")
	end
	soundLabel.Text = "Звуки: " .. (if Sounds.Enabled then "ON" else "OFF")
end

function SettingsPanel:Build(screen: ScreenGui)
	panel = Kit.Panel(screen, "Settings", Vector2.new(560, 520), C.Grey)
	panel.Close.Activated:Connect(function()
		Router.Close()
	end)
	local list = Kit.Scroll(panel.Body, "list", nil, 12)
	local _, slow = Kit.Button({ Text = "Slow Mode", Color = "Green", Size = UDim2.new(1, -20, 0, 62), LayoutOrder = 1, TextSize = 30,
		Parent = list, OnClick = function()
			local profile = State.Profile()
			if profile then
				State.Fire("SetSetting", { key = "slowMode", value = not profile.settings.slowMode })
			end
		end })
	slowLabel = slow
	local _, sound = Kit.Button({ Text = "Звуки", Color = "Blue", Size = UDim2.new(1, -20, 0, 62), LayoutOrder = 2, TextSize = 30,
		Parent = list, OnClick = function()
			Sounds.Enabled = not Sounds.Enabled
			SettingsPanel:Refresh()
		end })
	soundLabel = sound
	Kit.Button({ Text = "Пропустить обучение", Color = "Orange", Size = UDim2.new(1, -20, 0, 62), LayoutOrder = 3, TextSize = 28,
		Parent = list, OnClick = function()
			State.Fire("Tutorial", { skip = true })
		end })
	Kit.Text({
		Text = "Управление:\n[E] — подобрать / открыть\n[F] (удерживать) — украсть яйцо\nКлик / тап с битой — удар\nСтой на золотой кассе — забрать доход",
		Size = UDim2.new(1, -20, 0, 170), LayoutOrder = 4, TextWrapped = true, MaxTextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.White, Parent = list,
	})
end

function SettingsPanel:Open()
	Router.ShowPanel(panel)
	SettingsPanel:Refresh()
end

function SettingsPanel:Close()
	Router.HidePanel(panel)
end

return SettingsPanel
