--[[
	Визуальная система интерфейса.
	• Display — Fredoka One: заголовки, числа, кнопки (характерный «игровой» вид Roblox).
	• Body — Gotham: описания и мелкий текст, хорошо читается на телефоне.
	• Тёмные полупрозрачные панели, объёмные кнопки с «нижней кромкой», яркие акценты,
	  цвета редкости башен.
]]

local Theme = {}

local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"
local FREDOKA = "rbxasset://fonts/families/FredokaOne.json"

Theme.Font = {
	Display = Font.new(FREDOKA, Enum.FontWeight.Regular),
	Regular = Font.new(GOTHAM, Enum.FontWeight.Medium),
	Semi = Font.new(GOTHAM, Enum.FontWeight.SemiBold),
	Bold = Font.new(GOTHAM, Enum.FontWeight.Bold),
	Heavy = Font.new(GOTHAM, Enum.FontWeight.Heavy),
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Theme.Colors = {
	Background = c(12, 14, 22),
	Panel = c(24, 28, 40),
	PanelLight = c(34, 39, 56),
	PanelLighter = c(46, 52, 74),
	Inset = c(16, 19, 28),
	Stroke = c(255, 255, 255),
	Outline = c(6, 7, 12),
	Text = c(246, 248, 253),
	SubText = c(170, 178, 200),
	Muted = c(112, 120, 144),
	Accent = c(64, 168, 255),
	AccentDark = c(30, 102, 196),
	Gold = c(255, 198, 62),
	GoldDark = c(196, 128, 18),
	Gem = c(196, 128, 255),
	Green = c(76, 214, 112),
	GreenDark = c(30, 142, 66),
	Red = c(242, 72, 88),
	RedDark = c(160, 30, 48),
	Orange = c(255, 150, 54),
	Purple = c(160, 108, 255),
	PurpleDark = c(98, 58, 190),
	Black = c(0, 0, 0),
	White = c(255, 255, 255),
}

Theme.Rarity = {
	Starter = c(150, 162, 186),
	Common = c(124, 206, 120),
	Uncommon = c(72, 172, 255),
	Rare = c(176, 108, 255),
	Epic = c(255, 112, 78),
	Legendary = c(255, 198, 52),
}

Theme.Radius = 14
Theme.Padding = 12

-- { лицевая сторона, нижняя кромка, текст }
Theme.Buttons = {
	Primary = { Theme.Colors.Accent, Theme.Colors.AccentDark, Theme.Colors.White },
	Success = { Theme.Colors.Green, Theme.Colors.GreenDark, Theme.Colors.White },
	Danger = { Theme.Colors.Red, Theme.Colors.RedDark, Theme.Colors.White },
	Gold = { Theme.Colors.Gold, Theme.Colors.GoldDark, Theme.Colors.White },
	Purple = { Theme.Colors.Purple, Theme.Colors.PurpleDark, Theme.Colors.White },
	Neutral = { c(64, 72, 98), c(38, 43, 60), Theme.Colors.Text },
	Dark = { c(40, 45, 62), c(22, 25, 36), Theme.Colors.SubText },
	Disabled = { c(58, 62, 76), c(36, 39, 50), c(126, 132, 150) },
}

return Theme
