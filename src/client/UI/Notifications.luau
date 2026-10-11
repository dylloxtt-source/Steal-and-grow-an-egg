--[[
	Всплывающие уведомления (тосты) сверху по центру. Цвет зависит от типа.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local Kit = require(script.Parent.Kit)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.Parent.State)

local C = Kit.Theme.Colors

local Notifications = {}

local holder: Frame
local MAX = 3

local KIND_COLORS = {
	success = C.GreenDark,
	error = C.RedDark,
	money = Color3.fromRGB(20, 120, 40),
	warn = C.OrangeDark,
	alert = C.Red,
	food = C.PurpleDark,
	night = Color3.fromRGB(40, 40, 110),
	info = C.GreyDark,
}

function Notifications.Show(text: string, kind: string?)
	local k = kind or "info"
	local toast = Kit.Create("Frame", {
		Name = "Toast",
		BackgroundColor3 = KIND_COLORS[k] or KIND_COLORS.info,
		Size = UDim2.fromOffset(520, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = -math.floor(os.clock() * 1000),
		BackgroundTransparency = 0.05,
		ZIndex = 60,
		Parent = holder,
	})
	Kit.Corner(toast, 10)
	Kit.Stroke(toast, 3, C.Black, true)
	Kit.Create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = toast })
	local label = Kit.Text({
		Text = text,
		Size = UDim2.new(1, 0, 0, 28),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextScaled = false,
		TextSize = 21,
		ZIndex = 61,
		TextWrapped = true,
		Parent = toast,
	})
	local scale = Kit.Create("UIScale", { Scale = 0.6, Parent = toast })
	Kit.Tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)

	local toasts = {}
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > MAX then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end

	if k == "error" then
		Sounds.Play("error")
	elseif k == "alert" then
		Sounds.Play("alert", 0.7)
	elseif k == "success" or k == "money" then
		Sounds.Play("success", 1.2)
	end

	task.delay(if k == "alert" then 5 else 3.2, function()
		if toast.Parent then
			Kit.Tween(toast, 0.3, { BackgroundTransparency = 1 })
			Kit.Tween(label, 0.3, { TextTransparency = 1 })
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

function Notifications:Build(screen: ScreenGui)
	holder = Kit.Create("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(520, 200),
		Position = UDim2.new(0.5, 0, 0, 104),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 50,
		Parent = screen,
	})
	Kit.Create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = holder,
	})
	Net.Event("Notify").OnClientEvent:Connect(function(text, kind)
		if type(text) == "string" then
			Notifications.Show(text, kind)
		end
	end)
	State.Notify.Event:Connect(function(text, kind)
		Notifications.Show(text, kind)
	end)
end

function Notifications:Open() end
function Notifications:Close() end

return Notifications
