--[[
	HUD по референсу: слева Shop / Index / Quests и переключатель Slow Mode,
	справа яйца (с бейджами) / питомцы / настройки, снизу слева скорость и деньги,
	снизу справа таймер дня/ночи, сверху — статус переноски, базы и зоны.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Map = require(Shared.Config.Map)
local Zones = require(Shared.Config.Zones)
local Upgrades = require(Shared.Config.Upgrades)
local Quests = require(Shared.Config.Quests)
local Format = require(Shared.Logic.Format)
local Economy = require(Shared.Logic.Economy)
local Growth = require(Shared.Logic.Growth)

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Router)
local State = require(script.Parent.Parent.State)

local C = Kit.Theme.Colors

local Lighting = game:GetService("Lighting")

local HUD = {}
HUD.AlwaysRefresh = true

local refs: any = {}
local seenIndex = -1 -- сколько открытий видел игрок в последний раз (для бейджа Index)

local function sideButton(parent: Instance, text: string, icon: string, color: string, order: number, onClick: () -> ())
	local button = Kit.Button({
		Name = text,
		Text = text,
		Icon = icon,
		Color = color,
		Size = UDim2.fromOffset(186, 70),
		TextSize = 34,
		LayoutOrder = order,
		OnClick = onClick,
		Parent = parent,
	})
	local label = button:FindFirstChild("Face"):FindFirstChild("Label") :: TextLabel
	label.TextXAlignment = Enum.TextXAlignment.Left
	return button
end

local function squareButton(parent: Instance, name: string, icon: string, color: string, order: number, onClick: () -> ())
	local button = Kit.Button({
		Name = name,
		Text = icon,
		Color = color,
		Size = UDim2.fromOffset(84, 84),
		TextSize = 52,
		LayoutOrder = order,
		OnClick = onClick,
		Parent = parent,
	})
	local label = button:FindFirstChild("Face"):FindFirstChild("Label") :: TextLabel
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Enabled = false
	end
	return button
end

local function chip(parent: Instance, name: string, color: Color3, order: number): (Frame, TextLabel)
	local frame = Kit.Create("Frame", {
		Name = name,
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(240, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.Corner(frame, 10)
	Kit.Stroke(frame, 3, C.Black, true)
	Kit.Create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = frame })
	local label = Kit.Text({
		Text = "",
		Size = UDim2.new(0, 0, 1, -6),
		Position = UDim2.fromOffset(0, 3),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = 24,
		Parent = frame,
	})
	return frame, label
end

function HUD:Build(screen: ScreenGui)
	local root = Kit.Create("Frame", { Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = screen })
	refs.Root = root

	-- Левая колонка
	local left = Kit.Create("Frame", {
		Name = "Left",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(200, 330),
		Position = UDim2.new(0, 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = root,
	})
	Kit.Create("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
	refs.Left = left
	refs.Shop = sideButton(left, "Shop", "🛒", "Green", 1, function()
		Router.Toggle("Shop")
	end)
	refs.ShopBadge = Kit.Badge(refs.Shop, "!", C.Red)
	refs.Index = sideButton(left, "Index", "📖", "Blue", 2, function()
		Router.Toggle("Index")
	end)
	refs.IndexBadge = Kit.Badge(refs.Index, "0", C.Red)
	refs.Quests = sideButton(left, "Quests", "📜", "Orange", 3, function()
		Router.Toggle("Quests")
	end)
	refs.QuestBadge = Kit.Badge(refs.Quests, "0", C.Red)

	-- Переключатель Slow Mode
	local toggleRow = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(200, 44), LayoutOrder = 4, Parent = left })
	local track = Kit.Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(90, 70, 50),
		Size = UDim2.fromOffset(84, 40),
		Parent = toggleRow,
	})
	Kit.Corner(track, 8)
	Kit.Stroke(track, 3, C.Black, true)
	local knob = Kit.Create("Frame", {
		BackgroundColor3 = C.Green,
		Size = UDim2.fromOffset(34, 30),
		Position = UDim2.fromOffset(5, 5),
		Parent = track,
	})
	Kit.Corner(knob, 6)
	Kit.Stroke(knob, 2, C.Black, true)
	Kit.Text({ Text = "Slow Mode", Size = UDim2.fromOffset(110, 40), Position = UDim2.fromOffset(92, 0),
		TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 26, Parent = toggleRow })
	refs.SlowKnob = knob
	refs.SlowTrack = track
	track.Activated:Connect(function()
		local profile = State.Profile()
		if profile then
			State.Fire("SetSetting", { key = "slowMode", value = not profile.settings.slowMode })
		end
	end)

	-- Правая колонка
	local right = Kit.Create("Frame", {
		Name = "Right",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(90, 300),
		Position = UDim2.new(1, -16, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = root,
	})
	Kit.Create("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = right })
	refs.Right = right
	refs.Eggs = squareButton(right, "EggsButton", "🥚", "Red", 1, function()
		Router.Toggle("Eggs")
	end)
	refs.EggCount = Kit.Badge(refs.Eggs, "0", C.Red, UDim2.new(0, -14, 1, -20))
	refs.EggReady = Kit.Badge(refs.Eggs, "0", C.GreenDark, UDim2.new(1, -16, 1, -20))
	refs.Pets = squareButton(right, "PetsButton", "🐾", "Orange", 2, function()
		Router.Toggle("Pets")
	end)
	refs.PetBadge = Kit.Badge(refs.Pets, "0", C.Red)
	refs.Settings = squareButton(right, "SettingsButton", "⚙️", "Grey", 3, function()
		Router.Toggle("Settings")
	end)

	-- Скорость и деньги (низ слева)
	local stats = Kit.Create("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(420, 140),
		Position = UDim2.new(0, 16, 1, -40),
		AnchorPoint = Vector2.new(0, 1),
		Parent = root,
	})
	Kit.Text({ Text = "👟", Size = UDim2.fromOffset(64, 64), Stroke = false, Parent = stats })
	refs.Speed = Kit.Text({
		Text = "16", Size = UDim2.fromOffset(330, 62), Position = UDim2.fromOffset(72, 2),
		TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4, MaxTextSize = 56,
		Gradient = { C.Yellow, C.Orange }, Parent = stats,
	})
	Kit.Text({ Text = "💵", Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(0, 70), Stroke = false, Parent = stats })
	refs.Money = Kit.Text({
		Text = "$0", Size = UDim2.fromOffset(340, 66), Position = UDim2.fromOffset(72, 70),
		TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4, MaxTextSize = 60,
		Gradient = { C.Money, C.MoneyDark }, Parent = stats,
	})
	refs.Income = Kit.Text({
		Text = "", Size = UDim2.fromOffset(300, 26), Position = UDim2.fromOffset(76, 136),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Money, MaxTextSize = 22, Parent = stats,
	})

	-- Таймер дня/ночи (низ справа)
	local timer = Kit.Create("Frame", {
		Name = "DayNight",
		BackgroundColor3 = C.Black,
		BackgroundTransparency = 0.45,
		Size = UDim2.fromOffset(300, 70),
		Position = UDim2.new(1, -16, 1, -16),
		AnchorPoint = Vector2.new(1, 1),
		Parent = root,
	})
	Kit.Corner(timer, 12)
	refs.TimerIcon = Kit.Text({ Text = "🌙", Size = UDim2.fromOffset(62, 62), Position = UDim2.fromOffset(6, 4), Stroke = false, Parent = timer })
	refs.Timer = Kit.Text({ Text = "in 0s", Size = UDim2.new(1, -80, 1, -12), Position = UDim2.fromOffset(74, 6),
		TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3, MaxTextSize = 44, Parent = timer })
	refs.Luck = Kit.Text({ Text = "x2 LUCK", Size = UDim2.fromOffset(150, 34), Position = UDim2.new(1, -150, 0, -38),
		TextColor3 = C.Yellow, Visible = false, MaxTextSize = 30, Parent = timer })

	-- Верхние «чипы» статуса
	local top = Kit.Create("Frame", {
		Name = "Top",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 58),
		Parent = root,
	})
	Kit.Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = top,
	})
	refs.ZoneChip, refs.ZoneText = chip(top, "Zone", Color3.fromRGB(60, 60, 70), 1)
	refs.CarryChip, refs.CarryText = chip(top, "Carry", C.Orange, 2)
	refs.BaseChip, refs.BaseText = chip(top, "Base", C.Blue, 3)
end

local function cheapestAffordable(profile: any): boolean
	for _, upgrade in Upgrades.List do
		local cost = Economy.UpgradeCost(upgrade.Id, profile.upgrades[upgrade.Id])
		if cost and cost <= profile.coins then
			return true
		end
	end
	return false
end

function HUD:Refresh()
	local profile = State.Profile()
	if not profile then
		return
	end
	local runtime = State.Runtime()

	refs.Money.Text = Format.Money(profile.coins)
	refs.Speed.Text = Format.Number(runtime.walkSpeed or 16)
	refs.Income.Text = if (runtime.incomePerSecond or 0) > 0 then "+" .. Format.Money(runtime.incomePerSecond) .. "/s" else ""

	refs.ShopBadge.Parent.Visible = cheapestAffordable(profile)

	local discovered = 0
	for _ in profile.index do
		discovered += 1
	end
	if seenIndex < 0 then
		seenIndex = discovered
	end
	if Router.Current() == "Index" then
		seenIndex = discovered
	end
	refs.IndexBadge.Text = tostring(discovered - seenIndex)
	refs.IndexBadge.Parent.Visible = discovered > seenIndex

	local claimable = 0
	for _, entry in profile.quests.list do
		local quest = Quests.ById[entry.id]
		if quest and not entry.claimed and entry.progress >= quest.Target then
			claimable += 1
		end
	end
	refs.QuestBadge.Text = tostring(claimable)
	refs.QuestBadge.Parent.Visible = claimable > 0

	refs.EggCount.Text = tostring(#profile.eggs)
	refs.EggCount.Parent.Visible = #profile.eggs > 0
	refs.EggReady.Text = tostring(runtime.readyEggs or 0)
	refs.EggReady.Parent.Visible = (runtime.readyEggs or 0) > 0

	local hungry = 0
	local now = State.Now()
	for _, creature in profile.creatures do
		if creature.placed then
			local decay = Growth.DecayPerSecond(creature.species)
			if creature.fullness - decay * (now - creature.lastTick) <= 20 then
				hungry += 1
			end
		end
	end
	refs.PetBadge.Text = tostring(hungry)
	refs.PetBadge.Parent.Visible = hungry > 0

	local slow = profile.settings.slowMode
	refs.SlowKnob.Position = if slow then UDim2.fromOffset(45, 5) else UDim2.fromOffset(5, 5)
	refs.SlowKnob.BackgroundColor3 = if slow then C.Green else C.Grey

	local carrying = runtime.carrying or {}
	refs.CarryChip.Visible = #carrying > 0
	if #carrying > 0 then
		local stolen = false
		local names = {}
		for _, item in carrying do
			stolen = stolen or item.stolen
			table.insert(names, Eggs.ById[item.eggId].Name)
		end
		refs.CarryText.Text = string.format("%s %d/%d  %s", if stolen then "🚨" else "🥚", #carrying, runtime.bag or 1,
			table.concat(names, ", "))
		refs.CarryChip.BackgroundColor3 = if stolen then C.Red else C.Orange
	end
end

-- Обновление таймеров и зоны (не требует данных сервера)
local function tick()
	local now = State.Now()
	local night = ReplicatedStorage:GetAttribute("IsNight") == true
	local endsAt = ReplicatedStorage:GetAttribute("PhaseEndsAt") or now
	refs.TimerIcon.Text = if night then "☀️" else "🌙"
	refs.Timer.Text = "in " .. Format.Time(endsAt - now)
	refs.Luck.Visible = night

	local runtime = State.Runtime()
	local lockedUntil = runtime.lockedUntil or 0
	if lockedUntil > now then
		refs.BaseChip.Visible = true
		refs.BaseChip.BackgroundColor3 = C.Blue
		refs.BaseText.Text = "🔒 База заперта: " .. Format.Time(lockedUntil - now)
	elseif runtime.newbie then
		refs.BaseChip.Visible = true
		refs.BaseChip.BackgroundColor3 = C.GreenDark
		refs.BaseText.Text = "🛡️ Защита новичка"
	else
		refs.BaseChip.Visible = false
	end

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local zone = root and Map.InLane(root.Position) and Zones.AtZ(root.Position.Z)
	refs.ZoneChip.Visible = zone ~= nil and zone ~= false
	if zone then
		refs.ZoneText.Text = string.format("📍 %s  •  👟%d+", string.upper(zone.Name), zone.RecommendedSpeed)
		refs.ZoneChip.BackgroundColor3 = zone.Wall[1]
	end
end

function HUD.GetButton(name: string): GuiObject?
	return refs.Root and refs.Root:FindFirstChild(name, true) :: GuiObject?
end

function HUD:Open() end
function HUD:Close() end

-- Пока открыто окно: боковые колонки прячутся, фон размывается (как на референсах)
local blur: BlurEffect? = nil
local function onPanel(name: string?)
	local open = name ~= nil
	refs.Left.Visible = not open
	refs.Right.Visible = not open
	if not blur then
		local effect = Instance.new("BlurEffect")
		effect.Name = "SGAE_PanelBlur"
		effect.Size = 0
		effect.Parent = Lighting
		blur = effect
	end
	Kit.Tween(blur :: BlurEffect, 0.2, { Size = if open then 14 else 0 })
	HUD:Refresh()
end

function HUD:Start()
	Router.Opened.Event:Connect(onPanel)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.25 then
			accumulator = 0
			tick()
		end
	end)
	State.Changed.Event:Connect(function()
		HUD:Refresh()
	end)
end

return HUD
