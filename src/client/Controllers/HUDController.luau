--[[
	HUD матча.
	• Сверху по центру — волна, фаза с таймером, прогресс волны и здоровье базы; под ним полосы боссов.
	• Слева сверху — деньги (с анимацией прибавки) и число башен; справа — команда.
	• Слева — пропуск ожидания (голосование), переключатель авто-скипа, ускорение x2,
	  обзорная камера и настройки.
	• Снизу — панель башен из набора игрока (клавиши 1–5), подсказки и кнопки для телефона.
	Все числа приходят со снимка сервера; клиент только плавно досчитывает таймер.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Config.Towers)
local Maps = require(Shared.Config.Maps)
local Format = require(Shared.Logic.Format)

local Kit = require(script.Parent.Parent.UI.Kit)
local Root = require(script.Parent.Parent.UI.Root)
local Preview = require(script.Parent.Parent.UI.Preview)
local TowerText = require(script.Parent.Parent.UI.TowerText)
local State = require(script.Parent.Parent.State)
local Sound = require(script.Parent.Sound)
local PlacementController = require(script.Parent.PlacementController)
local TowerController = require(script.Parent.TowerController)
local FxController = require(script.Parent.FxController)
local SettingsController = require(script.Parent.SettingsController)

local C = Kit.Theme.Colors

local HUDController = {}

local layer: Frame
local refs: any = {}
local snapshotAt = 0
local overview = false
local leakToken = 0
local bannerToken = 0
local gainToken = 0
local gainAmount = 0
local loadoutKey = ""

local HOTKEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight }

local PHASE_STYLE = {
	Prep = { "Get ready", C.Accent },
	Wave = { "Wave in progress", C.Red },
	Intermission = { "Wave cleared", C.Green },
	Victory = { "Victory!", C.Gold },
	Defeat = { "Defeat", C.Red },
}

-- Башни, доступные в этом матче: набор игрока из снимка (сервер), иначе из профиля
local function loadout(): { string }
	local me = State.MyTeamEntry()
	if me and me.loadout then
		return me.loadout
	end
	local profile = State.Profile
	return if profile and profile.loadout then profile.loadout else { Towers.Starter }
end

------------------------------------------------------------------------
-- Построение
------------------------------------------------------------------------

local function buildTop()
	local top = Root.Fit(Kit.Create("Frame", { Name = "TopCenter", BackgroundTransparency = 1, Size = UDim2.fromOffset(600, 210),
		Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), Parent = layer }))
	Kit.List(top, 6, false, Enum.HorizontalAlignment.Center)
	local wave = Kit.Panel({ Name = "Wave", Size = UDim2.fromOffset(600, 88), LayoutOrder = 1, Parent = top })
	refs.WavePanel = wave
	refs.Wave = Kit.Text({ Text = "Wave 0", Font = "Display", TextSize = 36, RichText = true, Size = UDim2.fromOffset(280, 42), Position = UDim2.fromOffset(18, 4),
		Stroke = true, StrokeThickness = 2.5, Parent = wave })
	refs.Phase = Kit.Badge({ Text = "", Color = C.Accent, Size = UDim2.fromOffset(250, 26), Position = UDim2.fromOffset(18, 48), TextSize = 14, Parent = wave })
	Kit.Text({ Text = "Lives", Font = "Display", TextSize = 18, Size = UDim2.fromOffset(150, 22), Position = UDim2.fromOffset(340, 8), Stroke = true, Parent = wave })
	refs.Hearts = {}
	for i = 1, 3 do
		local full = Kit.Icon("heart", wave, 42, UDim2.fromOffset(334 + (i - 1) * 50, 32))
		local empty = Kit.Icon("heartEmpty", wave, 42, UDim2.fromOffset(334 + (i - 1) * 50, 32))
		empty.Visible = false
		refs.Hearts[i] = { Full = full, Empty = empty }
	end
	refs.LivesText = Kit.Text({ Text = "", Font = "Display", TextSize = 16, TextColor3 = C.SubText, Size = UDim2.fromOffset(90, 40),
		Position = UDim2.fromOffset(490, 34), Stroke = true, Parent = wave })
	refs.Progress = Kit.Bar(wave, C.Gold, UDim2.new(1, -36, 0, 6), UDim2.new(0, 18, 1, -11))
	refs.Leak = Kit.Text({ Text = "", Font = "Display", Size = UDim2.fromOffset(120, 34), Position = UDim2.new(1, 14, 0, 30),
		TextSize = 28, TextColor3 = C.Red, Stroke = true, StrokeThickness = 2, Visible = false, Parent = wave })

	refs.Bosses = {}
	for i = 1, 2 do
		local panel = Kit.Panel({ Name = "Boss" .. i, Size = UDim2.fromOffset(600, 56), LayoutOrder = 10 + i, Visible = false, Parent = top })
		local name = Kit.Text({ Text = "", Font = "Display", TextSize = 17, TextColor3 = C.Red, Size = UDim2.new(1, -28, 0, 20), Position = UDim2.fromOffset(14, 5),
			Stroke = true, Parent = panel })
		local hp = Kit.Bar(panel, C.Red, UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 27), 13)
		local shield = Kit.Bar(panel, C.Accent, UDim2.new(1, -60, 0, 6), UDim2.fromOffset(30, 46))
		refs.Bosses[i] = { Panel = panel, Name = name, Hp = hp, Shield = shield }
	end
end

local function buildLeft()
	local cash = Root.Fit(Kit.Panel({ Name = "Cash", Size = UDim2.fromOffset(236, 86), Position = UDim2.fromOffset(16, 10), Parent = layer }))
	Kit.Icon("coin", cash, 40, UDim2.fromOffset(12, 10))
	refs.Cash = Kit.Text({ Text = "$0", Font = "Display", TextSize = 34, TextColor3 = C.Gold, Size = UDim2.new(1, -66, 0, 44), Position = UDim2.fromOffset(56, 6),
		Stroke = true, StrokeThickness = 2, Parent = cash })
	refs.TowerCount = Kit.Text({ Text = "", Font = "Display", TextSize = 14, TextColor3 = C.SubText, Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(14, 58),
		Stroke = true, Parent = cash })
	refs.Gain = Kit.Text({ Text = "", Font = "Display", TextSize = 22, TextColor3 = C.Green, Size = UDim2.fromOffset(120, 30), Position = UDim2.new(1, 10, 0, 14),
		Stroke = true, StrokeThickness = 2, Visible = false, Parent = cash })

	local controls = Root.Fit(Kit.Create("Frame", { Name = "Controls", BackgroundTransparency = 1, Size = UDim2.fromOffset(206, 240),
		Position = UDim2.new(0, 16, 0.5, -10), AnchorPoint = Vector2.new(0, 0.5), Parent = layer }))
	Kit.List(controls, 8)
	refs.Skip = Kit.Button({ Name = "Skip", Text = "Skip", Variant = "Gold", Size = UDim2.fromOffset(206, 52), TextSize = 19, LayoutOrder = 1,
		Parent = controls, OnClick = function()
			State.Fire("VoteSkip")
		end })
	local auto = Kit.Panel({ Name = "AutoSkip", Size = UDim2.fromOffset(206, 48), LayoutOrder = 2, Parent = controls })
	Kit.Text({ Text = "Auto Skip", Font = "Display", TextSize = 17, Size = UDim2.fromOffset(120, 48), Position = UDim2.fromOffset(14, 0), Stroke = true, Parent = auto })
	refs.AutoSkip = Kit.Toggle({ Value = SettingsController.Get("autoSkip"), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = auto,
		OnChanged = function(value)
			Sound.Play("Click")
			SettingsController.Set("autoSkip", value)
		end })
	refs.Speed = Kit.Button({ Name = "Speed", Text = "Speed x2", Variant = "Neutral", Size = UDim2.fromOffset(206, 50), TextSize = 17, LayoutOrder = 3,
		Parent = controls, OnClick = function()
			State.Fire("VoteSpeed")
		end })
	local row = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(206, 50), LayoutOrder = 4, Parent = controls })
	Kit.List(row, 8, true)
	refs.Camera = Kit.Button({ Name = "Camera", Text = "Camera", Variant = "Neutral", Size = UDim2.fromOffset(99, 50), TextSize = 15, LayoutOrder = 1, Parent = row,
		OnClick = function()
			HUDController.SetOverview(not overview)
		end })
	Kit.Button({ Name = "Settings", Text = "Settings", Variant = "Neutral", Size = UDim2.fromOffset(99, 50), TextSize = 15, LayoutOrder = 2, Parent = row,
		OnClick = function()
			Sound.Play("Click")
			SettingsController.Toggle()
		end })
end

local function buildTeam()
	local panel = Root.Fit(Kit.Panel({ Name = "Team", Size = UDim2.fromOffset(250, 150), Position = UDim2.new(1, -16, 0, 10), AnchorPoint = Vector2.new(1, 0),
		Parent = layer }))
	Kit.Text({ Text = "Team", Font = "Display", TextSize = 16, TextColor3 = C.SubText, Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 4),
		Stroke = true, Parent = panel })
	refs.Team = panel
	refs.TeamRows = {}
	for i = 1, 4 do
		local row = Kit.Inset({ Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 28 + (i - 1) * 34), Radius = 8, Visible = false, Parent = panel })
		local avatar = Kit.Headshot(row, 1, 24, UDim2.fromOffset(4, 3))
		local name = Kit.Text({ Text = "", Font = "Display", TextSize = 14, Size = UDim2.new(0.55, -34, 1, 0), Position = UDim2.fromOffset(34, 0), Parent = row })
		local stats = Kit.Text({ Text = "", Font = "Display", TextSize = 14, TextColor3 = C.Gold, Size = UDim2.new(0.45, -8, 1, 0), Position = UDim2.fromScale(0.55, 0),
			TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		refs.TeamRows[i] = { Row = row, Name = name, Stats = stats, Avatar = avatar, UserId = 0 }
	end
end

local function buildBottom()
	local bottom = Root.Fit(Kit.Create("Frame", { Name = "BottomCenter", BackgroundTransparency = 1, Size = UDim2.fromOffset(640, 214),
		Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), Parent = layer }))
	refs.Reason = Kit.Badge({ Text = "", Color = C.Panel, Size = UDim2.fromOffset(520, 30), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0),
		TextSize = 15, Parent = bottom })
	refs.Reason.Visible = false
	Kit.Outline(refs.Reason, 2, 0.1)
	local mobile = Kit.Create("Frame", { Name = "PlaceButtons", BackgroundTransparency = 1, Size = UDim2.fromOffset(340, 52),
		Position = UDim2.new(0.5, 0, 0, 36), AnchorPoint = Vector2.new(0.5, 0), Visible = false, Parent = bottom })
	Kit.List(mobile, 12, true, Enum.HorizontalAlignment.Center)
	refs.PlaceButton = Kit.Button({ Name = "Place", Text = "Place", Variant = "Success", Size = UDim2.fromOffset(160, 52), LayoutOrder = 1,
		Parent = mobile, OnClick = function()
			PlacementController.Confirm()
		end })
	Kit.Button({ Name = "Cancel", Text = "Cancel", Variant = "Danger", Size = UDim2.fromOffset(160, 52), LayoutOrder = 2, Parent = mobile,
		OnClick = function()
			PlacementController.Stop()
		end })
	refs.Mobile = mobile

	local bar = Kit.Panel({ Name = "TowerBar", Size = UDim2.fromOffset(600, 128), Position = UDim2.fromScale(0.5, 1), AnchorPoint = Vector2.new(0.5, 1), Parent = bottom })
	Kit.Padding(bar, 8, 10)
	Kit.List(bar, 8, true, Enum.HorizontalAlignment.Center)
	refs.TowerBar = bar
	refs.Cards = {}
end

-- Карточки панели башен пересобираются, если набор изменился
local function rebuildCards()
	local ids = loadout()
	local key = table.concat(ids, ",")
	if key == loadoutKey then
		return
	end
	loadoutKey = key
	for _, card in refs.Cards do
		card.Card:Destroy()
	end
	refs.Cards = {}
	for i, towerId in ids do
		local def = Towers.ById[towerId]
		if def then
			local rarity = TowerText.RarityColor(def)
			local card = Kit.Create("TextButton", { Name = def.Id, Text = "", AutoButtonColor = false, BackgroundColor3 = C.PanelLight,
				Size = UDim2.fromOffset(106, 110), LayoutOrder = i, BorderSizePixel = 0, ClipsDescendants = true, Parent = refs.TowerBar })
			Kit.Corner(card, 12)
			local stroke = Kit.Stroke(card, 0.4, 3, rarity)
			local glow = Kit.Create("Frame", { BackgroundColor3 = rarity, BackgroundTransparency = 0.6, Size = UDim2.new(1, 0, 0.6, 0), BorderSizePixel = 0, Parent = card })
			Kit.Gradient(glow, Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 40, 50))
			Preview.Tower(def.Id, 1, card, UDim2.new(1, 0, 0, 66), UDim2.fromOffset(0, 2), "upper")
			Kit.Badge({ Text = tostring(i), Color = C.Outline, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(5, 5), TextSize = 13, ZIndex = 3, Parent = card })
			Kit.Text({ Text = def.Name, Font = "Display", Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 66), TextSize = if #def.Name > 12 then 11 else 13,
				TextXAlignment = Enum.TextXAlignment.Center, Stroke = true, ZIndex = 3, Parent = card })
			local cost = Kit.Badge({ Text = Format.Cash(def.Levels[1].Cost), Color = C.Outline, TextColor = C.Gold, Size = UDim2.new(1, -16, 0, 22),
				Position = UDim2.new(0.5, 0, 1, -5), AnchorPoint = Vector2.new(0.5, 1), TextSize = 14, ZIndex = 3, Parent = card })
			local dim = Kit.Create("Frame", { Name = "Dim", BackgroundColor3 = C.Black, BackgroundTransparency = 0.55, Size = UDim2.fromScale(1, 1), Visible = false,
				ZIndex = 2, BorderSizePixel = 0, Parent = card })
			Kit.Corner(dim, 12)
			card.Activated:Connect(function()
				HUDController.Choose(def.Id)
			end)
			Kit.AttachTooltip(card, function()
				return TowerText.Tooltip(def)
			end)
			refs.Cards[def.Id] = { Card = card, Stroke = stroke, Cost = cost, Dim = dim, Price = def.Levels[1].Cost, Rarity = rarity }
		end
	end
	refs.TowerBar.Size = UDim2.fromOffset(math.max(240, #ids * 114 + 12), 128)
end

local function buildBanner()
	local banner = Root.Fit(Kit.Create("Frame", { Name = "Banner", BackgroundTransparency = 1, Size = UDim2.fromOffset(900, 120), Position = UDim2.fromScale(0.5, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = layer }))
	refs.Banner = banner
	refs.BannerText = Kit.Text({ Text = "", Font = "Display", TextSize = 72, Size = UDim2.new(1, 0, 0, 80), TextXAlignment = Enum.TextXAlignment.Center,
		Stroke = true, StrokeThickness = 4, Parent = banner })
	refs.BannerSub = Kit.Text({ Text = "", Font = "Display", TextSize = 28, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 80),
		TextXAlignment = Enum.TextXAlignment.Center, Stroke = true, StrokeThickness = 3, Parent = banner })
end

------------------------------------------------------------------------
-- Обновление
------------------------------------------------------------------------

local function contains(list: { number }?, userId: number): boolean
	for _, id in (list or {}) :: { number } do
		if id == userId then
			return true
		end
	end
	return false
end

local function refreshCards()
	rebuildCards()
	local cash = State.Cash()
	local chosen = PlacementController.TowerId()
	for id, card in refs.Cards do
		local affordable = cash >= card.Price
		card.Cost.TextColor3 = if affordable then C.Gold else C.Red
		card.Dim.Visible = not affordable and id ~= chosen
		card.Stroke.Color = if id == chosen then C.Gold else card.Rarity
		card.Stroke.Transparency = if id == chosen then 0 else 0.4
		card.Card.BackgroundColor3 = if id == chosen then C.PanelLighter else C.PanelLight
	end
end

local function phaseLeft(match: any): number
	return math.max(0, match.timer - (os.clock() - snapshotAt) * (match.timeScale or 1))
end

local function refreshTimer()
	local match = State.Match
	if not match then
		return
	end
	local phase = match.phase
	local style = PHASE_STYLE[phase] or { phase, C.Accent }
	local text = style[1]
	if phase == "Prep" then
		text = "Get ready! " .. Format.Time(phaseLeft(match))
	elseif phase == "Intermission" then
		text = "Next wave in " .. Format.Time(phaseLeft(match))
	elseif phase == "Wave" then
		text = match.enemies .. (if match.enemies == 1 then " enemy left" else " enemies left")
	end
	refs.Phase.Text = text
	refs.Phase.BackgroundColor3 = style[2]
end

local function refresh()
	local match = State.Match
	if not match then
		return
	end
	local userId = Players.LocalPlayer.UserId
	refs.Wave.Text = string.format('Wave %d<font size="22" color="#C4D2F0"> / %d</font>', match.wave, match.maxWave)
	refreshTimer()
	local lives = math.max(0, math.ceil(match.baseHp))
	for i, heart in refs.Hearts do
		heart.Full.Visible = i <= lives
		heart.Empty.Visible = i > lives
	end
	refs.LivesText.Text = lives .. "/" .. match.baseMaxHp
	local total = math.max(1, match.waveTotal or 0)
	refs.Progress:Set(if match.phase == "Wave" then 1 - math.clamp(match.enemies / total, 0, 1) else (if match.phase == "Prep" then 0 else 1), "")

	local me = State.MyTeamEntry()
	refs.Cash.Text = Format.Cash(if me then me.cash else 0)
	refs.TowerCount.Text = string.format("Towers %d/%d", if me then me.towers else 0, match.towerLimit or 15)

	for i, row in refs.TeamRows do
		local entry = match.team[i]
		row.Row.Visible = entry ~= nil
		if entry then
			if row.UserId ~= entry.userId then
				row.UserId = entry.userId
				row.Avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", math.max(1, entry.userId))
			end
			row.Name.Text = entry.name
			row.Name.TextColor3 = if entry.userId == userId then C.Accent else C.Text
			row.Stats.Text = Format.Cash(entry.cash)
		end
	end
	refs.Team.Size = UDim2.fromOffset(250, 34 + math.max(1, #match.team) * 34)

	local waiting = match.phase == "Prep" or match.phase == "Intermission"
	refs.Skip.Visible = waiting
	local skipMine = contains(match.skipBy, userId)
	Kit.SetText(refs.Skip, string.format("%s %d/%d", if skipMine then "Ready" else "Skip", match.skipVotes, match.players))
	Kit.SetVariant(refs.Skip, if skipMine then "Primary" else "Gold")
	local speedMine = contains(match.speedBy, userId)
	local fast = (match.timeScale or 1) > 1
	Kit.SetText(refs.Speed, string.format("%s %d/%d", if fast then "x2 On" else "Speed x2", match.speedVotes, match.players))
	Kit.SetVariant(refs.Speed, if fast then "Primary" elseif speedMine then "Purple" else "Neutral")
	refs.Speed.Visible = match.phase ~= "Victory" and match.phase ~= "Defeat"
	if me and me.autoSkip ~= nil and refs.AutoSkip.Value ~= me.autoSkip then
		refs.AutoSkip:Set(me.autoSkip)
	end

	for i, boss in refs.Bosses do
		local entry = match.bosses[i]
		boss.Panel.Visible = entry ~= nil
		if entry then
			boss.Name.Text = entry.name
			boss.Hp:Set(entry.hp / math.max(1, entry.maxHp), Format.Thousands(entry.hp) .. " / " .. Format.Thousands(entry.maxHp))
			boss.Shield.Frame.Visible = (entry.maxShield or 0) > 0
			boss.Shield:Set((entry.shield or 0) / math.max(1, entry.maxShield or 1), "")
		end
	end
	refreshCards()
end

local function showGain(amount: number)
	gainAmount += amount
	gainToken += 1
	local token = gainToken
	refs.Gain.Text = "+" .. Format.Cash(gainAmount)
	refs.Gain.Visible = true
	refs.Gain.TextTransparency = 0
	task.delay(0.9, function()
		if token == gainToken then
			gainAmount = 0
			refs.Gain.Visible = false
		end
	end)
end

local function banner(text: string, color: Color3, small: boolean?, subtitle: string?)
	if small then
		refs.Leak.Text = text
		refs.Leak.Visible = true
		leakToken += 1
		local token = leakToken
		task.delay(1.2, function()
			if token == leakToken then
				refs.Leak.Visible = false
			end
		end)
		return
	end
	bannerToken += 1
	local token = bannerToken
	refs.BannerText.Text = text
	refs.BannerText.TextColor3 = color
	refs.BannerText.TextTransparency = 0
	refs.BannerSub.Text = subtitle or ""
	refs.BannerSub.TextColor3 = color
	refs.BannerSub.TextTransparency = 0
	refs.Banner.Visible = true
	local scale = refs.Banner:FindFirstChild("FitScale") :: UIScale
	scale.Scale = Root.Scale * 1.5
	Kit.Tween(scale, 0.35, { Scale = Root.Scale }, Enum.EasingStyle.Back)
	task.delay(2, function()
		if token == bannerToken then
			Kit.Tween(refs.BannerText, 0.4, { TextTransparency = 1 })
			Kit.Tween(refs.BannerSub, 0.4, { TextTransparency = 1 })
			task.wait(0.4)
			if token == bannerToken then
				refs.Banner.Visible = false
			end
		end
	end)
end

------------------------------------------------------------------------
-- Камера
------------------------------------------------------------------------

function HUDController.SetOverview(enabled: boolean)
	local camera = workspace.CurrentCamera
	local match = State.Match
	local map = match and Maps.ById[match.mapId]
	if enabled and map and match then
		overview = true
		local origin = match.origin :: Vector3
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(origin + map.Camera.Position, origin + map.Camera.LookAt)
	else
		overview = false
		camera.CameraType = Enum.CameraType.Custom
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	Kit.SetVariant(refs.Camera, if overview then "Primary" else "Neutral")
end

function HUDController.Overview(): boolean
	return overview
end

------------------------------------------------------------------------
-- Выбор башни для установки
------------------------------------------------------------------------

function HUDController.Choose(towerId: string)
	if PlacementController.TowerId() == towerId then
		PlacementController.Stop()
		return
	end
	if not table.find(loadout(), towerId) then
		return
	end
	local def = Towers.ById[towerId]
	if State.Cash() < def.Levels[1].Cost then
		Sound.Play("Error")
	end
	PlacementController.Start(towerId)
	refreshCards()
end

local function onPlacementChanged(active: boolean, valid: boolean, reason: string?)
	refs.Mobile.Visible = active and UserInputService.TouchEnabled
	refs.Reason.Visible = active
	if active then
		if valid then
			refs.Reason.BackgroundColor3 = C.Panel
			refs.Reason.Text = if UserInputService.TouchEnabled
				then "Tap the ground to move the tower"
				else "Click to place  -  hold Shift to place more  -  right click to cancel"
		else
			refs.Reason.BackgroundColor3 = C.RedDark
			refs.Reason.Text = reason or "Can't place here"
		end
		Kit.SetVariant(refs.PlaceButton, if valid then "Success" else "Disabled")
	end
	refreshCards()
end

------------------------------------------------------------------------

function HUDController.Init(screen: Instance)
	layer = Root.Layer("Match")
	layer.Visible = false
	buildTop()
	buildLeft()
	buildTeam()
	buildBottom()
	buildBanner()
	TowerController.Init(layer)
	rebuildCards()

	State.MatchChanged.Event:Connect(function()
		snapshotAt = os.clock()
		refresh()
	end)
	State.ProfileChanged.Event:Connect(refreshCards)
	FxController.Banner.Event:Connect(banner)
	FxController.Reward.Event:Connect(showGain)
	PlacementController.Changed.Event:Connect(onPlacementChanged)
	SettingsController.Changed.Event:Connect(function(key, value)
		if key == "autoSkip" and refs.AutoSkip.Value ~= value then
			refs.AutoSkip:Set(value)
		end
	end)

	local function updateVisibility()
		local inMatch = State.InMatch()
		layer.Visible = inMatch
		if not inMatch then
			if overview then
				HUDController.SetOverview(false)
			end
			refs.Banner.Visible = false
			loadoutKey = ""
		end
	end
	Players.LocalPlayer:GetAttributeChangedSignal("MatchId"):Connect(updateVisibility)
	updateVisibility()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not State.InMatch() then
			return
		end
		local ids = loadout()
		for i, key in HOTKEYS do
			if input.KeyCode == key and ids[i] then
				HUDController.Choose(ids[i])
				return
			end
		end
		if input.KeyCode == Enum.KeyCode.C then
			HUDController.SetOverview(not overview)
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.2 and layer.Visible then
			accumulator = 0
			refreshTimer()
			-- На маленьком экране окно башни занимает правую сторону: прячем список команды
			refs.Team.Visible = not (TowerController.Selected() ~= nil and Root.Scale < 0.8)
		end
	end)
	-- Персонаж возродился — вернуть камеру на него, если обзор выключен
	Players.LocalPlayer.CharacterAdded:Connect(function()
		if not overview then
			task.defer(HUDController.SetOverview, false)
		end
	end)
	refresh()
end

return HUDController
