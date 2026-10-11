--[[
	UI Kit — конструктор интерфейса в едином студ-стиле.
	Все панели и кнопки игры собираются из этих функций, поэтому стиль меняется в одном месте.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local Kit = {}
Kit.Theme = Theme

local C = Theme.Colors

function Kit.Create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Kit.Corner(parent: Instance, radius: number?): UICorner
	return Kit.Create("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius), Parent = parent })
end

function Kit.Stroke(parent: Instance, thickness: number?, color: Color3?, border: boolean?): UIStroke
	return Kit.Create("UIStroke", {
		Thickness = thickness or Theme.Stroke,
		Color = color or C.Black,
		ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function Kit.Gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	return Kit.Create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

function Kit.Padding(parent: Instance, all: number)
	return Kit.Create("UIPadding", {
		PaddingLeft = UDim.new(0, all), PaddingRight = UDim.new(0, all),
		PaddingTop = UDim.new(0, all), PaddingBottom = UDim.new(0, all),
		Parent = parent,
	})
end

function Kit.Tween(instance: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- Шрифт по содержимому: латиница — Fredoka One (как на референсах), кириллица — Nunito
function Kit.ApplyFont(label: any)
	if string.find(label.Text, "[\208\209]") then
		label.FontFace = Theme.CyrillicFace
	else
		label.Font = Theme.Font
	end
end

-- Текст с чёрной обводкой (как весь текст на референсах)
function Kit.Text(props: { [string]: any }): TextLabel
	local label = Kit.Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = C.White,
		TextScaled = props.TextSize == nil,
		Size = UDim2.fromScale(1, 1),
	})
	local strokeThickness = props.Stroke
	local gradient = props.Gradient
	for key, value in props do
		if key ~= "Stroke" and key ~= "Gradient" and key ~= "Parent" and key ~= "MaxTextSize" then
			(label :: any)[key] = value
		end
	end
	if strokeThickness ~= false then
		Kit.Stroke(label, if type(strokeThickness) == "number" then strokeThickness else 2.5)
	end
	if gradient then
		Kit.Gradient(label, gradient[1], gradient[2])
	end
	if props.TextScaled ~= false and props.TextSize == nil then
		Kit.Create("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 48, Parent = label })
	end
	Kit.ApplyFont(label)
	label:GetPropertyChangedSignal("Text"):Connect(function()
		Kit.ApplyFont(label)
	end)
	label.Parent = props.Parent
	return label
end

-- Узор из студов: создаётся лениво по размеру рамки
function Kit.StudPattern(frame: GuiObject, color: Color3?, pitch: number?, transparency: number?)
	local step = pitch or 30
	local layer = Kit.Create("Frame", {
		Name = "Studs",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = frame.ZIndex,
		Parent = frame,
	})
	Kit.Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(step * 0.52, step * 0.52),
		CellPadding = UDim2.fromOffset(step * 0.48, step * 0.48),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = layer,
	})
	Kit.Create("UIPadding", {
		PaddingLeft = UDim.new(0, step * 0.24), PaddingTop = UDim.new(0, step * 0.24),
		Parent = layer,
	})
	local built = 0
	local function fill()
		local size = layer.AbsoluteSize
		local need = math.ceil(size.X / step + 1) * math.ceil(size.Y / step + 1)
		need = math.min(need, 900)
		for _ = built + 1, need do
			local stud = Kit.Create("Frame", {
				BackgroundColor3 = color or C.PanelStud,
				BackgroundTransparency = transparency or 0,
				BorderSizePixel = 0,
				ZIndex = frame.ZIndex,
				Parent = layer,
			})
			Kit.Corner(stud, 100)
			Kit.Create("UIStroke", { Thickness = 1.5, Color = Color3.new(0, 0, 0), Transparency = 0.75, Parent = stud })
		end
		built = math.max(built, need)
	end
	layer:GetPropertyChangedSignal("AbsoluteSize"):Connect(fill)
	task.defer(fill)
	return layer
end

export type ButtonOptions = {
	Text: string?,
	Icon: string?,
	Color: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Parent: Instance?,
	OnClick: (() -> ())?,
	TextSize: number?,
	LayoutOrder: number?,
	Name: string?,
	Depth: number?,
}

-- Кнопка с «нижней гранью» и анимацией нажатия
function Kit.Button(opts: ButtonOptions): (TextButton, TextLabel)
	local pair = Theme.Buttons[opts.Color or "Green"] or Theme.Buttons.Green
	local depth = opts.Depth or 5
	local button = Kit.Create("TextButton", {
		Name = opts.Name or "Button",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = pair[2],
		Size = opts.Size or UDim2.fromOffset(160, 56),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	Kit.Corner(button, Theme.Radius)
	Kit.Stroke(button, Theme.Stroke, C.Black, true)
	local face = Kit.Create("Frame", {
		Name = "Face",
		BackgroundColor3 = pair[1],
		Size = UDim2.new(1, 0, 1, -depth),
		Parent = button,
	})
	Kit.Corner(face, Theme.Radius)
	Kit.Create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)),
		Rotation = 90,
		Parent = face,
	})
	-- Блик сверху
	local shine = Kit.Create("Frame", {
		Name = "Shine",
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.75,
		Size = UDim2.new(1, -12, 0.28, 0),
		Position = UDim2.fromOffset(6, 4),
		Parent = face,
	})
	Kit.Corner(shine, 6)
	local text = (opts.Icon and (opts.Icon .. " ") or "") .. (opts.Text or "")
	local label = Kit.Text({
		Name = "Label",
		Text = text,
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromOffset(6, 4),
		MaxTextSize = opts.TextSize or 30,
		Parent = face,
	})
	local scale = Kit.Create("UIScale", { Parent = button })

	button.MouseEnter:Connect(function()
		Kit.Tween(scale, 0.12, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		Kit.Tween(scale, 0.12, { Scale = 1 })
		face.Position = UDim2.new()
	end)
	button.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, depth - 1)
	end)
	button.MouseButton1Up:Connect(function()
		face.Position = UDim2.new()
	end)
	if opts.OnClick then
		local onClick = opts.OnClick
		button.Activated:Connect(function()
			Kit.Tween(scale, 0.06, { Scale = 0.94 }).Completed:Connect(function()
				Kit.Tween(scale, 0.1, { Scale = 1 })
			end)
			onClick()
		end)
	end
	button.Parent = opts.Parent
	return button, label
end

function Kit.SetButtonColor(button: TextButton, colorName: string)
	local pair = Theme.Buttons[colorName] or Theme.Buttons.Green
	button.BackgroundColor3 = pair[2]
	local face = button:FindFirstChild("Face") :: Frame?
	if face then
		face.BackgroundColor3 = pair[1]
	end
end

function Kit.Badge(parent: GuiObject, text: string, color: Color3?, position: UDim2?): TextLabel
	local badge = Kit.Create("Frame", {
		Name = "Badge",
		BackgroundColor3 = color or C.Red,
		Size = UDim2.fromOffset(30, 30),
		Position = position or UDim2.new(1, -16, 0, -12),
		ZIndex = (parent.ZIndex or 1) + 5,
		Parent = parent,
	})
	Kit.Corner(badge, 100)
	Kit.Stroke(badge, 2.5, C.Black, true)
	local label = Kit.Text({ Text = text, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = badge.ZIndex + 1, Parent = badge })
	return label
end

export type Progress = { Frame: Frame, Fill: Frame, Label: TextLabel, Set: (Progress, number, string?) -> () }

function Kit.Progress(parent: Instance, color: Color3?, size: UDim2?, position: UDim2?): Progress
	local frame = Kit.Create("Frame", {
		Name = "Progress",
		BackgroundColor3 = C.PanelInner,
		Size = size or UDim2.new(1, 0, 0, 22),
		Position = position or UDim2.new(),
		Parent = parent,
	})
	Kit.Corner(frame, 8)
	Kit.Stroke(frame, 2.5, C.Black, true)
	local fill = Kit.Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = color or C.Green,
		Size = UDim2.fromScale(0, 1),
		Parent = frame,
	})
	Kit.Corner(fill, 8)
	Kit.Gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	local label = Kit.Text({ Text = "", Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), ZIndex = 3, Parent = frame })
	local progress = { Frame = frame, Fill = fill, Label = label } :: any
	function progress.Set(self: Progress, alpha: number, text: string?)
		self.Fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		self.Label.Text = text or ""
	end
	return progress
end

-- Прокручиваемый список/сетка с автоматическим размером холста
function Kit.Scroll(parent: Instance, layout: "grid" | "list", cell: UDim2?, padding: number?): ScrollingFrame
	local scroll = Kit.Create("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.White,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
	if layout == "grid" then
		Kit.Create("UIGridLayout", {
			CellSize = cell or UDim2.fromOffset(180, 220),
			CellPadding = UDim2.fromOffset(padding or 12, padding or 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Parent = scroll,
		})
	else
		Kit.Create("UIListLayout", {
			Padding = UDim.new(0, padding or 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Parent = scroll,
		})
	end
	Kit.Create("UIPadding", {
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 12),
		Parent = scroll,
	})
	return scroll
end

export type Panel = {
	Root: Frame,
	Body: Frame,
	Header: Frame,
	Title: TextLabel,
	Tabs: Frame,
	Close: TextButton,
	Scale: UIScale,
}

-- Окно в стиле референса: зелёная шапка с бликом, красный крестик, тёмное тело со студами
function Kit.Panel(parent: Instance, title: string, size: Vector2, headerColor: Color3?): Panel
	local root = Kit.Create("Frame", {
		Name = title .. "Panel",
		BackgroundColor3 = C.Black,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.56),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	})
	Kit.Corner(root, 10)
	Kit.Stroke(root, 4, C.Black, true)
	local scale = Kit.Create("UIScale", { Parent = root })

	local header = Kit.Create("Frame", {
		Name = "Header",
		BackgroundColor3 = headerColor or C.Green,
		Size = UDim2.new(1, -8, 0, 68),
		Position = UDim2.fromOffset(4, 4),
		ZIndex = 11,
		Parent = root,
	})
	Kit.Corner(header, 8)
	Kit.Gradient(header, Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205))
	Kit.StudPattern(header, Color3.new(1, 1, 1), 22, 0.85)
	-- Диагональные блики, как на референсе
	for i, x in { 0.42, 0.5 } do
		Kit.Create("Frame", {
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.7,
			Size = UDim2.new(0, 26 - i * 8, 1.6, 0),
			Position = UDim2.new(x, 0, -0.3, 0),
			Rotation = 25,
			ZIndex = 11,
			Parent = header,
		})
	end
	header.ClipsDescendants = true

	local titleLabel = Kit.Text({
		Name = "Title",
		Text = title,
		Size = UDim2.new(0.6, 0, 1, -14),
		Position = UDim2.fromOffset(22, 7),
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 3.5,
		MaxTextSize = 46,
		ZIndex = 12,
		Parent = header,
	})

	local close = Kit.Button({
		Name = "Close",
		Text = "X",
		Color = "Red",
		Size = UDim2.fromOffset(62, 62),
		Position = UDim2.new(1, -14, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 40,
		Parent = root,
	})
	close.ZIndex = 13
	for _, d in close:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 14
		end
	end

	local body = Kit.Create("Frame", {
		Name = "Body",
		BackgroundColor3 = C.Panel,
		Size = UDim2.new(1, -8, 1, -80),
		Position = UDim2.fromOffset(4, 76),
		ZIndex = 10,
		Parent = root,
	})
	Kit.Corner(body, 8)
	Kit.StudPattern(body, C.PanelStud, 30)
	local content = Kit.Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 1, -16),
		Position = UDim2.fromOffset(10, 8),
		ZIndex = 11,
		Parent = body,
	})

	-- Вкладки справа от окна (как Stars / Featured / Speed / Money)
	local tabs = Kit.Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 120, 1, -20),
		Position = UDim2.new(1, 14, 0, 10),
		Parent = root,
	})
	Kit.Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabs })

	return {
		Root = root,
		Body = content,
		Header = header,
		Title = titleLabel,
		Tabs = tabs,
		Close = close,
		Scale = scale,
	}
end

-- Вкладка-иконка справа от окна
function Kit.Tab(panel: Panel, icon: string, text: string, order: number, onClick: () -> ()): TextButton
	local button = Kit.Create("TextButton", {
		Name = text,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 96),
		LayoutOrder = order,
		Parent = panel.Tabs,
	})
	Kit.Text({ Name = "Icon", Text = icon, Size = UDim2.new(1, 0, 0, 58), Stroke = false, MaxTextSize = 54, Parent = button })
	Kit.Text({ Name = "Label", Text = text, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 60), Parent = button })
	local scale = Kit.Create("UIScale", { Parent = button })
	button.Activated:Connect(function()
		Kit.Tween(scale, 0.06, { Scale = 0.9 }).Completed:Connect(function()
			Kit.Tween(scale, 0.12, { Scale = 1 })
		end)
		onClick()
	end)
	return button
end

function Kit.SetTabActive(button: TextButton, active: boolean)
	local label = button:FindFirstChild("Label") :: TextLabel?
	if label then
		label.TextColor3 = if active then C.Yellow else C.White
	end
	local scale = button:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = if active then 1.08 else 1
	end
end

-- Заголовок секции «-- EGGS --»
function Kit.SectionTitle(parent: Instance, text: string, color: Color3?, order: number?): TextLabel
	return Kit.Text({
		Name = "Section",
		Text = "-- " .. text .. " --",
		Size = UDim2.new(1, 0, 0, 44),
		TextColor3 = color or C.Yellow,
		Gradient = { Color3.new(1, 1, 1), Color3.fromRGB(220, 220, 220) },
		LayoutOrder = order or 0,
		Stroke = 3,
		Parent = parent,
	})
end

-- Карточка товара/существа с градиентом
function Kit.Card(parent: Instance, top: Color3, bottom: Color3, order: number?): Frame
	local card = Kit.Create("Frame", {
		Name = "Card",
		BackgroundColor3 = C.White,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Kit.Corner(card, 8)
	Kit.Stroke(card, 3, C.Black, true)
	Kit.Gradient(card, top, bottom)
	return card
end

function Kit.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return Kit
