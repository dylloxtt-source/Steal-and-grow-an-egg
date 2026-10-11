--[[
	Визуальная система UI по референсам: толстые чёрные обводки, шрифт Fredoka One,
	насыщенные кнопки с «нижней гранью», тёмные панели со студами и зелёной шапкой.
]]

local Theme = {}

Theme.Font = Enum.Font.FredokaOne
-- В Fredoka One нет кириллицы: русский текст рисуем округлым Nunito Heavy
Theme.CyrillicFace = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy)

Theme.Colors = {
	Green = Color3.fromRGB(92, 227, 92),
	GreenDark = Color3.fromRGB(40, 150, 40),
	Blue = Color3.fromRGB(46, 168, 255),
	BlueDark = Color3.fromRGB(20, 100, 190),
	Red = Color3.fromRGB(229, 48, 43),
	RedDark = Color3.fromRGB(150, 20, 20),
	Orange = Color3.fromRGB(255, 150, 30),
	OrangeDark = Color3.fromRGB(190, 90, 10),
	Yellow = Color3.fromRGB(255, 210, 31),
	YellowDark = Color3.fromRGB(190, 140, 0),
	Purple = Color3.fromRGB(150, 70, 230),
	PurpleDark = Color3.fromRGB(80, 30, 150),
	Pink = Color3.fromRGB(240, 70, 200),
	Grey = Color3.fromRGB(130, 130, 140),
	GreyDark = Color3.fromRGB(80, 80, 90),
	Panel = Color3.fromRGB(46, 46, 54),
	PanelStud = Color3.fromRGB(62, 62, 72),
	PanelInner = Color3.fromRGB(34, 34, 40),
	Black = Color3.fromRGB(16, 16, 20),
	White = Color3.fromRGB(255, 255, 255),
	Money = Color3.fromRGB(110, 255, 90),
	MoneyDark = Color3.fromRGB(30, 160, 30),
}

Theme.Stroke = 3
Theme.Radius = 8

-- Пары цветов кнопок: основной и цвет нижней грани
Theme.Buttons = {
	Green = { Theme.Colors.Green, Theme.Colors.GreenDark },
	Blue = { Theme.Colors.Blue, Theme.Colors.BlueDark },
	Red = { Theme.Colors.Red, Theme.Colors.RedDark },
	Orange = { Theme.Colors.Orange, Theme.Colors.OrangeDark },
	Yellow = { Theme.Colors.Yellow, Theme.Colors.YellowDark },
	Purple = { Theme.Colors.Purple, Theme.Colors.PurpleDark },
	Grey = { Theme.Colors.Grey, Theme.Colors.GreyDark },
}

return Theme
