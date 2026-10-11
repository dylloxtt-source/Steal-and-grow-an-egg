--[[
	Уведомления: плашки сверху по центру с цветной иконкой, не больше трёх одновременно.
	Появляются с «пружиной» и плавно исчезают.
]]

local Kit = require(script.Parent.Kit)
local Root = require(script.Parent.Root)
local State = require(script.Parent.Parent.State)
local Sound = require(script.Parent.Parent.Controllers.Sound)

local C = Kit.Theme.Colors

local Notifications = {}

local holder: Frame
local STYLES = {
	error = { C.Red, "!" },
	success = { C.Green, "+" },
	warn = { C.Orange, "!" },
	boss = { C.Purple, "!" },
	info = { C.Accent, "i" },
	gem = { C.Gem, "+" },
}

function Notifications.Show(text: string, kind: string?)
	local style = STYLES[kind or "info"] or STYLES.info
	local toast = Kit.Panel({ Name = "Toast", Size = UDim2.fromOffset(480, 46), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = -math.floor(os.clock() * 1000), Parent = holder })
	local chip = Kit.Create("Frame", { BackgroundColor3 = style[1], Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(10, 8),
		BorderSizePixel = 0, Parent = toast })
	Kit.Corner(chip, 9)
	Kit.Text({ Text = style[2], Font = "Display", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16,
		Stroke = true, Parent = chip })
	Kit.Text({ Text = text, Size = UDim2.new(1, -60, 0, 46), Position = UDim2.fromOffset(50, 0), TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None, AutomaticSize = Enum.AutomaticSize.Y, TextSize = 15, Weight = "Bold", Parent = toast })
	local scale = Kit.Create("UIScale", { Scale = 0.8, Parent = toast })
	Kit.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	local toasts = {}
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 3 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	if kind == "error" then
		Sound.Play("Error")
	end
	task.delay(3.4, function()
		if toast.Parent then
			Kit.Tween(scale, 0.2, { Scale = 0.85 })
			Kit.Tween(toast, 0.2, { BackgroundTransparency = 1 })
			task.wait(0.2)
			toast:Destroy()
		end
	end)
end

function Notifications.Init(screen: Instance)
	holder = Root.Fit(Kit.Create("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(480, 200),
		Position = UDim2.new(0.5, 0, 0.27, 0), -- ниже верхних панелей и полос боссов
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 25, -- под окнами магазина, настроек и итогов
		Parent = screen,
	}))
	Kit.List(holder, 6, false, Enum.HorizontalAlignment.Center)
	State.Notify.Event:Connect(Notifications.Show)
end

return Notifications
