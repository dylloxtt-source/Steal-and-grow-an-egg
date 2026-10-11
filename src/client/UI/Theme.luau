--[[
	Визуальная система интерфейса: тёмные панели, контрастные акценты,
	шрифт Montserrat (поддерживает кириллицу), мягкие обводки и градиенты.
]]

local Theme = {}

Theme.Font = {
	Regular = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium),
	Semi = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold),
	Bold = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold),
	Heavy = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold),
}

Theme.Colors = {
	Background = Color3.fromRGB(18, 20, 27),
	Panel = Color3.fromRGB(26, 29, 38),
	PanelLight = Color3.fromRGB(36, 40, 52),
	PanelLighter = Color3.fromRGB(48, 53, 68),
	Stroke = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(240, 242, 248),
	SubText = Color3.fromRGB(160, 168, 186),
	Muted = Color3.fromRGB(105, 112, 130),
	Accent = Color3.fromRGB(76, 201, 240),
	AccentDark = Color3.fromRGB(40, 140, 190),
	Gold = Color3.fromRGB(255, 200, 87),
	Gem = Color3.fromRGB(170, 120, 255),
	Green = Color3.fromRGB(74, 222, 128),
	GreenDark = Color3.fromRGB(34, 160, 90),
	Red = Color3.fromRGB(255, 89, 100),
	RedDark = Color3.fromRGB(190, 50, 60),
	Orange = Color3.fromRGB(255, 150, 60),
	Purple = Color3.fromRGB(160, 110, 255),
	Black = Color3.fromRGB(0, 0, 0),
	White = Color3.fromRGB(255, 255, 255),
}

Theme.Radius = 12
Theme.Padding = 12

Theme.Buttons = {
	Primary = { Theme.Colors.Accent, Theme.Colors.AccentDark, Theme.Colors.Background },
	Success = { Theme.Colors.Green, Theme.Colors.GreenDark, Theme.Colors.Background },
	Danger = { Theme.Colors.Red, Theme.Colors.RedDark, Theme.Colors.White },
	Gold = { Theme.Colors.Gold, Color3.fromRGB(200, 150, 50), Theme.Colors.Background },
	Neutral = { Theme.Colors.PanelLighter, Theme.Colors.PanelLight, Theme.Colors.Text },
	Disabled = { Color3.fromRGB(60, 64, 78), Color3.fromRGB(50, 54, 66), Theme.Colors.Muted },
}

return Theme
