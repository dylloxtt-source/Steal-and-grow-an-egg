--[[
	UI Kit: все элементы интерфейса собираются здесь, чтобы стиль был единым.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local Kit = {}
Kit.Theme = Theme
local C = Theme.Colors

function Kit.Create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Kit.Corner(parent: Instance, radius: number?): UICorner
	return Kit.Create("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius), Parent = parent })
end

function Kit.Stroke(parent: Instance, transparency: number?, thickness: number?, color: Color3?): UIStroke
	return Kit.Create("UIStroke", {
		Color = color or C.Stroke,
		Transparency = transparency or 0.88,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Kit.Padding(parent: Instance, all: number, horizontal: number?)
	return Kit.Create("UIPadding", {
		PaddingLeft = UDim.new(0, horizontal or all), PaddingRight = UDim.new(0, horizontal or all),
		PaddingTop = UDim.new(0, all), PaddingBottom = UDim.new(0, all),
		Parent = parent,
	})
end

function Kit.List(parent: Instance, padding: number?, horizontal: boolean?, align: Enum.HorizontalAlignment?): UIListLayout
	return Kit.Create("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Kit.Gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	return Kit.Create("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90, Parent = parent })
end

function Kit.Tween(instance: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

export type TextProps = { [string]: any }

-- Текст с подбором веса шрифта
function Kit.Text(props: TextProps): TextLabel
	local weight = props.Weight or "Semi"
	local label = Kit.Create("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Theme.Font[weight] or Theme.Font.Semi,
		TextColor3 = C.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	for key, value in props do
		if key ~= "Weight" and key ~= "Parent" and key ~= "Shadow" then
			(label :: any)[key] = value
		end
	end
	if props.Shadow then
		Kit.Create("UIStroke", { Thickness = 1.5, Transparency = 0.45, Color = C.Black, Parent = label })
	end
	label.Parent = props.Parent
	return label
end

-- Панель: тёмная подложка, скругление, тонкая обводка, мягкий градиент
function Kit.Panel(props: { [string]: any }): Frame
	local frame = Kit.Create("Frame", {
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
	})
	for key, value in props do
		if key ~= "Parent" and key ~= "Radius" then
			(frame :: any)[key] = value
		end
	end
	Kit.Corner(frame, props.Radius)
	Kit.Stroke(frame, 0.9)
	Kit.Gradient(frame, Color3.new(1, 1, 1), Color3.fromRGB(205, 210, 220))
	frame.Parent = props.Parent
	return frame
end

export type ButtonProps = {
	Text: string,
	Variant: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	TextSize: number?,
	Parent: Instance?,
	OnClick: (() -> ())?,
	Name: string?,
}

function Kit.Button(props: ButtonProps): TextButton
	local variant = Theme.Buttons[props.Variant or "Primary"] or Theme.Buttons.Primary
	local button = Kit.Create("TextButton", {
		Name = props.Name or "Button",
		Text = props.Text,
		FontFace = Theme.Font.Bold,
		TextSize = props.TextSize or 16,
		TextColor3 = variant[3],
		AutoButtonColor = false,
		BackgroundColor3 = variant[1],
		Size = props.Size or UDim2.fromOffset(140, 40),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		BorderSizePixel = 0,
	})
	Kit.Corner(button, 10)
	Kit.Gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215))
	local scale = Kit.Create("UIScale", { Parent = button })
	button:SetAttribute("Variant", props.Variant or "Primary")
	button.MouseEnter:Connect(function()
		Kit.Tween(scale, 0.1, { Scale = 1.04 })
	end)
	button.MouseLeave:Connect(function()
		Kit.Tween(scale, 0.1, { Scale = 1 })
	end)
	if props.OnClick then
		local onClick = props.OnClick
		button.Activated:Connect(function()
			if button:GetAttribute("Variant") == "Disabled" then
				return
			end
			Kit.Tween(scale, 0.05, { Scale = 0.95 }).Completed:Connect(function()
				Kit.Tween(scale, 0.1, { Scale = 1 })
			end)
			onClick()
		end)
	end
	button.Parent = props.Parent
	return button
end

function Kit.SetVariant(button: TextButton, variantName: string)
	local variant = Theme.Buttons[variantName] or Theme.Buttons.Primary
	button.BackgroundColor3 = variant[1]
	button.TextColor3 = variant[3]
	button:SetAttribute("Variant", variantName)
end

export type Bar = { Frame: Frame, Fill: Frame, Label: TextLabel, Set: (Bar, number, string?) -> () }

function Kit.Bar(parent: Instance, color: Color3, size: UDim2?, position: UDim2?): Bar
	local frame = Kit.Create("Frame", {
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.2,
		Size = size or UDim2.new(1, 0, 0, 14),
		Position = position or UDim2.new(),
		BorderSizePixel = 0,
		Parent = parent,
	})
	Kit.Corner(frame, 7)
	local fill = Kit.Create("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Parent = frame })
	Kit.Corner(fill, 7)
	Kit.Gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	local label = Kit.Text({ Text = "", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12,
		Weight = "Bold", Shadow = true, ZIndex = 3, Parent = frame })
	local bar = { Frame = frame, Fill = fill, Label = label } :: any
	function bar.Set(self: Bar, alpha: number, text: string?)
		self.Fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		self.Label.Text = text or ""
	end
	return bar
end

function Kit.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

return Kit
