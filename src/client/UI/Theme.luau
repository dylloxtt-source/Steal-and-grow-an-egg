--[[
	Визуальная система интерфейса.
	• Display — Fredoka One: заголовки, числа, кнопки (характерный «игровой» вид Roblox).
	• Body — Gotham: описания и мелкий текст, хорошо читается на телефоне.
	• Синие панели с толстой чёрной обводкой, объёмные яркие кнопки с «нижней кромкой»,
	  белый текст с контуром — как в обычных Roblox-играх; цвета редкости башен.
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
	Background = c(14, 20, 40),
	Panel = c(40, 60, 112),
	PanelLight = c(54, 78, 140),
	PanelLighter = c(72, 100, 170),
	Inset = c(24, 36, 72),
	Stroke = c(255, 255, 255),
	Outline = c(0, 0, 0),
	Text = c(255, 255, 255),
	SubText = c(196, 210, 240),
	Muted = c(136, 154, 198),
	Accent = c(52, 168, 255),
	AccentDark = c(22, 98, 196),
	Gold = c(255, 204, 46),
	GoldDark = c(204, 132, 0),
	Gem = c(206, 120, 255),
	Green = c(84, 222, 92),
	GreenDark = c(34, 150, 44),
	Red = c(255, 66, 66),
	RedDark = c(176, 24, 24),
	Orange = c(255, 150, 40),
	Purple = c(168, 92, 255),
	PurpleDark = c(102, 44, 196),
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
	Neutral = { c(86, 114, 190), c(44, 62, 116), Theme.Colors.Text },
	Dark = { c(44, 62, 116), c(26, 38, 74), Theme.Colors.SubText },
	Disabled = { c(96, 102, 122), c(58, 62, 78), c(182, 186, 200) },
}

return Theme
