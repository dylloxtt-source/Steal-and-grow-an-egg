--[[
	UI Kit: все элементы интерфейса собираются здесь, чтобы стиль был единым.
	Кнопки — «объёмные»: лицевая сторона над тёмной кромкой, при нажатии проседает.
	Панели — тёмные с градиентом и контуром, с шапкой (заголовок, иконка, крестик).
	Плашки (pill), переключатели, сегментные выборы, бейджи, аватары, подсказки.
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

function Kit.Round(parent: Instance): UICorner
	return Kit.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
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

-- Тёмный контур вокруг блока: отделяет интерфейс от яркого 3D-мира
function Kit.Outline(parent: Instance, thickness: number?, transparency: number?): UIStroke
	return Kit.Stroke(parent, transparency or 0, thickness or 3, C.Outline)
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

function Kit.Tween(instance: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

export type TextProps = { [string]: any }

--[[
	Текст. Font = "Display" (Fredoka) или Weight = "Regular"/"Semi"/"Bold"/"Heavy" (Gotham).
	Stroke = true — тёмная обводка букв (читается поверх 3D-мира).
]]
function Kit.Text(props: TextProps): TextLabel
	local face = if props.Font == "Display" then Theme.Font.Display else Theme.Font[props.Weight or "Semi"] or Theme.Font.Semi
	local label = Kit.Create("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = face,
		TextColor3 = C.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	for key, value in props do
		if key ~= "Weight" and key ~= "Parent" and key ~= "Shadow" and key ~= "Stroke" and key ~= "Font" and key ~= "StrokeThickness" then
			(label :: any)[key] = value
		end
	end
	if props.Stroke or props.Shadow then
		Kit.Create("UIStroke", { Thickness = props.StrokeThickness or 2, Transparency = 0, Color = C.Outline, Parent = label })
	end
	label.Parent = props.Parent
	return label
end

-- Панель: тёмная подложка с градиентом и контуром
function Kit.Panel(props: { [string]: any }): Frame
	local frame = Kit.Create("Frame", {
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
	})
	for key, value in props do
		if key ~= "Parent" and key ~= "Radius" then
			(frame :: any)[key] = value
		end
	end
	Kit.Corner(frame, props.Radius)
	Kit.Outline(frame)
	Kit.Gradient(frame, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 176, 200))
	frame.Parent = props.Parent
	return frame
end

-- Вложенная «утопленная» область внутри панели
function Kit.Inset(props: { [string]: any }): Frame
	local frame = Kit.Create("Frame", { BackgroundColor3 = C.Inset, BackgroundTransparency = 0.15, BorderSizePixel = 0 })
	for key, value in props do
		if key ~= "Parent" and key ~= "Radius" then
			(frame :: any)[key] = value
		end
	end
	Kit.Corner(frame, props.Radius or 10)
	frame.Parent = props.Parent
	return frame
end

------------------------------------------------------------------------
-- Кнопки
------------------------------------------------------------------------

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
	Radius: number?,
	Visible: boolean?,
	ZIndex: number?,
}

local buttons: { [Instance]: any } = setmetatable({}, { __mode = "k" }) :: any

function Kit.Button(props: ButtonProps): TextButton
	local variant = Theme.Buttons[props.Variant or "Primary"] or Theme.Buttons.Primary
	local radius = props.Radius or 12
	local root = Kit.Create("TextButton", {
		Name = props.Name or "Button",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromOffset(150, 46),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = if props.Visible == nil then true else props.Visible,
		ZIndex = props.ZIndex or 1,
	})
	local base = Kit.Create("Frame", { Name = "Base", BackgroundColor3 = variant[2], Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Parent = root })
	Kit.Corner(base, radius)
	Kit.Outline(base, 2, 0.1)
	local face = Kit.Create("Frame", { Name = "Face", BackgroundColor3 = variant[1], Size = UDim2.new(1, 0, 1, -5), BorderSizePixel = 0, Parent = root })
	Kit.Corner(face, radius)
	Kit.Gradient(face, Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 205))
	local label = Kit.Text({ Name = "Label", Text = props.Text, Font = "Display", TextSize = props.TextSize or 18, TextColor3 = variant[3],
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0), TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None, Stroke = true, StrokeThickness = 1.4, Parent = face })
	local scale = Kit.Create("UIScale", { Parent = root })
	buttons[root] = { Face = face, Base = base, Label = label }
	root:SetAttribute("Variant", props.Variant or "Primary")
	root.MouseEnter:Connect(function()
		if root:GetAttribute("Variant") ~= "Disabled" then
			Kit.Tween(scale, 0.12, { Scale = 1.04 }, Enum.EasingStyle.Back)
		end
	end)
	root.MouseLeave:Connect(function()
		Kit.Tween(scale, 0.12, { Scale = 1 })
	end)
	if props.OnClick then
		local onClick = props.OnClick
		root.Activated:Connect(function()
			if root:GetAttribute("Variant") == "Disabled" then
				return
			end
			face.Position = UDim2.fromOffset(0, 3)
			Kit.Tween(face, 0.14, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
			onClick()
		end)
	end
	root.Parent = props.Parent
	return root
end

function Kit.SetVariant(button: Instance, variantName: string)
	local parts = buttons[button]
	local variant = Theme.Buttons[variantName] or Theme.Buttons.Primary
	if parts then
		parts.Face.BackgroundColor3 = variant[1]
		parts.Base.BackgroundColor3 = variant[2]
		parts.Label.TextColor3 = variant[3]
	end
	button:SetAttribute("Variant", variantName)
end

function Kit.SetText(button: Instance, text: string)
	local parts = buttons[button]
	if parts then
		parts.Label.Text = text
	end
end

function Kit.ButtonLabel(button: Instance): TextLabel?
	local parts = buttons[button]
	return parts and parts.Label
end

------------------------------------------------------------------------
-- Полосы, плашки, бейджи
------------------------------------------------------------------------

export type Bar = { Frame: Frame, Fill: Frame, Label: TextLabel, Set: (Bar, number, string?) -> () }

function Kit.Bar(parent: Instance, color: Color3, size: UDim2?, position: UDim2?, textSize: number?): Bar
	local frame = Kit.Create("Frame", {
		BackgroundColor3 = C.Inset,
		BackgroundTransparency = 0.05,
		Size = size or UDim2.new(1, 0, 0, 16),
		Position = position or UDim2.new(),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Parent = parent,
	})
	Kit.Round(frame)
	Kit.Outline(frame, 1.5, 0.2)
	local fill = Kit.Create("Frame", { Name = "Fill", BackgroundColor3 = color, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Parent = frame })
	Kit.Round(fill)
	Kit.Gradient(fill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 180, 180))
	local label = Kit.Text({ Text = "", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = textSize or 13,
		Font = "Display", Stroke = true, ZIndex = 3, Parent = frame })
	local bar = { Frame = frame, Fill = fill, Label = label, Alpha = 1 } :: any
	function bar.Set(self: Bar, alpha: number, text: string?)
		local a = math.clamp(alpha, 0, 1)
		if math.abs(a - (self :: any).Alpha) > 0.001 then
			(self :: any).Alpha = a
			Kit.Tween(self.Fill, 0.25, { Size = UDim2.fromScale(a, 1) })
		end
		self.Fill.Visible = a > 0.001
		self.Label.Text = text or ""
	end
	return bar
end

------------------------------------------------------------------------
-- Нарисованные значки (без эмодзи): монета, гем, сердце, звезда
------------------------------------------------------------------------

local function disk(parent: Instance, color: Color3, size: UDim2, position: UDim2, z: number?): Frame
	local frame = Kit.Create("Frame", { BackgroundColor3 = color, Size = size, Position = position, AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0, ZIndex = z or 1, Parent = parent })
	Kit.Round(frame)
	return frame
end

function Kit.Icon(kind: string, parent: Instance, size: number, position: UDim2?, z: number?): Frame
	local holder = Kit.Create("Frame", { Name = "Icon_" .. kind, BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.new(), ZIndex = z or 1, Parent = parent })
	local zi = (z or 1) + 1
	if kind == "coin" then
		local outer = disk(holder, C.GoldDark, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), zi)
		Kit.Stroke(outer, 0, 2, C.Outline)
		local inner = disk(holder, C.Gold, UDim2.fromScale(0.74, 0.74), UDim2.fromScale(0.5, 0.5), zi)
		Kit.Gradient(inner, Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 205))
		Kit.Text({ Text = "$", Font = "Display", TextSize = math.floor(size * 0.62), TextColor3 = C.GoldDark, Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = zi + 1, Parent = holder })
	elseif kind == "gem" then
		local back = Kit.Create("Frame", { BackgroundColor3 = C.PurpleDark, Size = UDim2.fromScale(0.68, 0.68), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BorderSizePixel = 0, ZIndex = zi, Parent = holder })
		Kit.Corner(back, math.max(2, math.floor(size * 0.1)))
		Kit.Stroke(back, 0, 2, C.Outline)
		Kit.Gradient(back, Color3.fromRGB(255, 220, 255), Color3.fromRGB(150, 90, 220), 45)
		local shine = Kit.Create("Frame", { BackgroundColor3 = C.White, BackgroundTransparency = 0.35, Size = UDim2.fromScale(0.22, 0.22),
			Position = UDim2.fromScale(0.36, 0.32), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BorderSizePixel = 0, ZIndex = zi + 1, Parent = holder })
		Kit.Corner(shine, 2)
	elseif kind == "heart" or kind == "heartEmpty" then
		local color = if kind == "heart" then C.Red else Color3.fromRGB(70, 70, 86)
		-- Контур: чёрное сердце чуть больше, сверху — цветное
		for layer, scale in { 1, 0.78 } do
			local col = if layer == 1 then C.Outline else color
			local sq = Kit.Create("Frame", { BackgroundColor3 = col, Size = UDim2.fromScale(0.5 * scale, 0.5 * scale), Position = UDim2.fromScale(0.5, 0.56),
				AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BorderSizePixel = 0, ZIndex = zi + layer, Parent = holder })
			Kit.Corner(sq, 2)
			disk(holder, col, UDim2.fromScale(0.42 * scale, 0.42 * scale), UDim2.fromScale(0.5 - 0.17 * scale, 0.4), zi + layer)
			disk(holder, col, UDim2.fromScale(0.42 * scale, 0.42 * scale), UDim2.fromScale(0.5 + 0.17 * scale, 0.4), zi + layer)
		end
	elseif kind == "star" then
		Kit.Text({ Text = "*", Font = "Display", TextSize = math.floor(size * 1.4), TextColor3 = C.Gold, Size = UDim2.fromScale(1, 1.2),
			TextXAlignment = Enum.TextXAlignment.Center, Stroke = true, ZIndex = zi, Parent = holder })
	end
	return holder
end

export type Pill = { Frame: Frame, Label: TextLabel, Icon: Frame, Set: (Pill, string) -> () }

-- Плашка «иконка + значение» (деньги, гемы, победы)
function Kit.Pill(props: { [string]: any }): Pill
	local frame = Kit.Create("Frame", { Name = props.Name or "Pill", BackgroundColor3 = C.Inset, BackgroundTransparency = 0.1,
		Size = props.Size or UDim2.fromOffset(150, 40), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0, BorderSizePixel = 0, Parent = props.Parent })
	Kit.Round(frame)
	Kit.Outline(frame, 2, 0.1)
	local h = (props.Size and props.Size.Y.Offset) or 40
	local icon = Kit.Icon(props.Icon or "coin", frame, h - 10, UDim2.fromOffset(6, 5))
	local label = Kit.Text({ Text = props.Text or "", Font = "Display", Size = UDim2.new(1, -(h + 12), 1, 0), Position = UDim2.fromOffset(h + 2, 0),
		TextSize = props.TextSize or math.floor(h * 0.55), TextColor3 = props.Color or C.Text, Stroke = true, Parent = frame })
	local pill = { Frame = frame, Label = label, Icon = icon } :: any
	function pill.Set(self: Pill, text: string)
		self.Label.Text = text
	end
	return pill
end

function Kit.Badge(props: { [string]: any }): TextLabel
	local badge = Kit.Text({ Text = props.Text, Font = "Display", TextSize = props.TextSize or 13, TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = props.Color or C.Accent, BackgroundTransparency = 0, Size = props.Size or UDim2.fromOffset(64, 22),
		Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, TextColor3 = props.TextColor or C.White,
		Stroke = true, StrokeThickness = 1.2, LayoutOrder = props.LayoutOrder or 0, ZIndex = props.ZIndex or 1, Name = props.Name or "Badge",
		Parent = props.Parent })
	Kit.Round(badge)
	return badge
end

-- Аватар игрока (официальная миниатюра Roblox по UserId)
function Kit.Headshot(parent: Instance, userId: number, size: number, position: UDim2?): ImageLabel
	local image = Kit.Create("ImageLabel", {
		Name = "Headshot",
		BackgroundColor3 = C.PanelLighter,
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.new(),
		Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", math.max(1, userId)),
		BorderSizePixel = 0,
		Parent = parent,
	})
	Kit.Round(image)
	Kit.Stroke(image, 0.3, 2, C.Outline)
	return image
end

------------------------------------------------------------------------
-- Переключатель и сегментный выбор
------------------------------------------------------------------------

export type Toggle = { Frame: TextButton, Set: (Toggle, boolean) -> (), Value: boolean }

function Kit.Toggle(props: { [string]: any }): Toggle
	local track = Kit.Create("TextButton", { Name = props.Name or "Toggle", Text = "", AutoButtonColor = false, BackgroundColor3 = C.PanelLighter,
		Size = props.Size or UDim2.fromOffset(62, 32), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0, BorderSizePixel = 0, Parent = props.Parent })
	Kit.Round(track)
	Kit.Outline(track, 2, 0.15)
	local knob = Kit.Create("Frame", { Name = "Knob", BackgroundColor3 = C.White, Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(0, 4, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0, Parent = track })
	Kit.Round(knob)
	local state = { Frame = track, Value = false } :: any
	function state.Set(self: Toggle, value: boolean)
		self.Value = value
		track.BackgroundColor3 = if value then C.Green else C.PanelLighter
		knob.Position = if value then UDim2.new(1, -28, 0.5, 0) else UDim2.new(0, 4, 0.5, 0)
	end
	state:Set(props.Value == true)
	track.Activated:Connect(function()
		state:Set(not state.Value)
		if props.OnChanged then
			props.OnChanged(state.Value)
		end
	end)
	return state
end

export type Segmented = { Frame: Frame, Buttons: { [string]: TextButton }, Set: (Segmented, string) -> (), Value: string? }

function Kit.Segmented(props: { [string]: any }): Segmented
	local frame = Kit.Inset({ Name = props.Name or "Segmented", Size = props.Size or UDim2.fromOffset(280, 40), Position = props.Position or UDim2.new(),
		LayoutOrder = props.LayoutOrder or 0, Radius = 12, Parent = props.Parent })
	Kit.Padding(frame, 4)
	local layout = Kit.List(frame, 4, true, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local control = { Frame = frame, Buttons = {}, Value = nil } :: any
	local count = #props.Options
	for i, option in props.Options do
		local button = Kit.Create("TextButton", { Name = option.Id, Text = option.Text, FontFace = Theme.Font.Display, TextSize = props.TextSize or 15,
			TextColor3 = C.SubText, AutoButtonColor = false, BackgroundColor3 = C.Accent, BackgroundTransparency = 1, LayoutOrder = i,
			Size = UDim2.new(1 / count, -4 * (count - 1) / count, 1, 0), BorderSizePixel = 0, Parent = frame })
		Kit.Corner(button, 9)
		control.Buttons[option.Id] = button
		button.Activated:Connect(function()
			if button:GetAttribute("Disabled") then
				return
			end
			if props.OnSelect then
				props.OnSelect(option.Id)
			end
		end)
	end
	function control.Set(self: Segmented, id: string)
		self.Value = id
		for key, button in self.Buttons do
			local selected = key == id
			button.BackgroundTransparency = if selected then 0 else 1
			button.TextColor3 = if selected then C.White elseif button:GetAttribute("Disabled") then C.Muted else C.SubText
		end
	end
	if props.Value then
		control:Set(props.Value)
	end
	return control
end

------------------------------------------------------------------------
-- Шапка окна и подсказки
------------------------------------------------------------------------

-- Шапка окна: акцентная полоса, иконка, заголовок, крестик. Возвращает (шапку, крестик)
function Kit.Header(panel: Instance, props: { [string]: any }): (Frame, TextButton?)
	local accent = props.Accent or C.Accent
	local header = Kit.Create("Frame", { Name = "Header", BackgroundColor3 = accent, Size = UDim2.new(1, 0, 0, props.Height or 54),
		BorderSizePixel = 0, Parent = panel })
	Kit.Corner(header, Theme.Radius)
	Kit.Gradient(header, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 160))
	-- Нижняя часть шапки без скругления
	local fill = Kit.Create("Frame", { BackgroundColor3 = accent, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
		BorderSizePixel = 0, Parent = header })
	Kit.Gradient(fill, Color3.fromRGB(170, 170, 180), Color3.fromRGB(150, 150, 160))
	Kit.Text({ Name = "Title", Text = props.Title, Font = "Display", TextSize = props.TextSize or 28,
		Size = UDim2.new(1, -120, 1, 0), Position = UDim2.fromOffset(18, 0), Stroke = true, StrokeThickness = 2, ZIndex = 2, Parent = header })
	local close = nil
	if props.OnClose then
		close = Kit.Button({ Name = "Close", Text = "X", Variant = "Danger", Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5), TextSize = 18, Radius = 10, ZIndex = 3, Parent = header, OnClick = props.OnClose })
	end
	return header, close
end

local tooltip: any = nil

function Kit.InitTooltip(screen: Instance)
	local frame = Kit.Panel({ Name = "Tooltip", Size = UDim2.fromOffset(240, 60), AutomaticSize = Enum.AutomaticSize.Y, Visible = false,
		ZIndex = 200, Parent = screen })
	Kit.Padding(frame, 10)
	local label = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None, RichText = true, TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 201, Parent = frame })
	tooltip = { Frame = frame, Label = label, Owner = nil }
end

-- Подсказка при наведении мыши (над элементом)
function Kit.AttachTooltip(target: GuiObject, getText: () -> string?)
	target.MouseEnter:Connect(function()
		if not tooltip or Kit.IsTouch() then
			return
		end
		local text = getText()
		if not text then
			return
		end
		tooltip.Owner = target
		tooltip.Label.Text = text
		local position = target.AbsolutePosition
		local size = target.AbsoluteSize
		tooltip.Frame.Position = UDim2.fromOffset(position.X + size.X / 2 - 120, position.Y - 12)
		tooltip.Frame.AnchorPoint = Vector2.new(0, 1)
		tooltip.Frame.Visible = true
	end)
	target.MouseLeave:Connect(function()
		if tooltip and tooltip.Owner == target then
			tooltip.Frame.Visible = false
			tooltip.Owner = nil
		end
	end)
end

-- Плавный счётчик для чисел (деньги, награды)
function Kit.CountUp(label: TextLabel, from: number, to: number, duration: number, format: (number) -> string)
	local token = ((label:GetAttribute("CountToken") :: number?) or 0) + 1
	label:SetAttribute("CountToken", token)
	task.spawn(function()
		local start = os.clock()
		while label:GetAttribute("CountToken") == token do
			local t = math.clamp((os.clock() - start) / duration, 0, 1)
			local eased = 1 - (1 - t) ^ 3
			label.Text = format(from + (to - from) * eased)
			if t >= 1 then
				break
			end
			task.wait(1 / 30)
		end
	end)
end

function Kit.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

return Kit
