--[[
	Уведомления: компактные плашки сверху по центру, не больше трёх одновременно.
]]

local Kit = require(script.Parent.Kit)
local Root = require(script.Parent.Root)
local State = require(script.Parent.Parent.State)
local Sound = require(script.Parent.Parent.Controllers.Sound)

local C = Kit.Theme.Colors

local Notifications = {}

local holder: Frame
local COLORS = {
	error = C.Red, success = C.Green, warn = C.Orange, boss = C.Purple, info = C.Accent,
}

function Notifications.Show(text: string, kind: string?)
	local color = COLORS[kind or "info"] or C.Accent
	local toast = Kit.Panel({
		Name = "Toast",
		Size = UDim2.fromOffset(460, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = -math.floor(os.clock() * 1000),
		Parent = holder,
	})
	local bar = Kit.Create("Frame", { BackgroundColor3 = color, Size = UDim2.new(0, 4, 1, -12), Position = UDim2.fromOffset(8, 6),
		BorderSizePixel = 0, Parent = toast })
	Kit.Corner(bar, 2)
	Kit.Text({ Text = text, Size = UDim2.new(1, -28, 0, 40), Position = UDim2.fromOffset(20, 0), TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None, AutomaticSize = Enum.AutomaticSize.Y, TextSize = 15, Parent = toast })
	local scale = Kit.Create("UIScale", { Scale = 0.85, Parent = toast })
	Kit.Tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
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
	task.delay(3.2, function()
		if toast.Parent then
			Kit.Tween(toast, 0.25, { BackgroundTransparency = 1 })
			task.wait(0.25)
			toast:Destroy()
		end
	end)
end

function Notifications.Init(screen: Instance)
	holder = Root.Fit(Kit.Create("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(460, 200),
		Position = UDim2.new(0.5, 0, 0.25, 0), -- ниже верхних панелей и полос боссов
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 50,
		Parent = screen,
	}))
	Kit.List(holder, 6, false, Enum.HorizontalAlignment.Center)
	State.Notify.Event:Connect(Notifications.Show)
end

return Notifications
