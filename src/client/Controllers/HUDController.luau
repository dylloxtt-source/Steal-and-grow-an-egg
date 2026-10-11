--[[
	HUD матча: волна и фаза, здоровье базы, деньги, лимит башен, команда,
	голосование за ускорение и пропуск ожидания, полосы боссов, баннеры волн,
	панель восьми башен (клик или клавиши 1–8) и кнопки размещения для телефона.
	Обзорная камера карты — кнопка или клавиша C.
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
local State = require(script.Parent.Parent.State)
local Sound = require(script.Parent.Sound)
local PlacementController = require(script.Parent.PlacementController)
local TowerController = require(script.Parent.TowerController)
local FxController = require(script.Parent.FxController)

local C = Kit.Theme.Colors

local HUDController = {}

local layer: Frame
local refs: any = {}
local snapshotAt = 0
local overview = false
local bannerToken = 0

local HOTKEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
	Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight,
}

local PHASE_TEXT = {
	Prep = "Подготовка",
	Wave = "Идёт волна",
	Intermission = "Перерыв",
	Victory = "Победа!",
	Defeat = "Поражение",
}

------------------------------------------------------------------------
-- Построение
------------------------------------------------------------------------

local function buildTop()
	local top = Root.Fit(Kit.Create("Frame", { Name = "TopCenter", BackgroundTransparency = 1, Size = UDim2.fromOffset(540, 170),
		Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), Parent = layer }))
	Kit.List(top, 6, false, Enum.HorizontalAlignment.Center)
	local wave = Kit.Panel({ Name = "Wave", Size = UDim2.fromOffset(540, 64), LayoutOrder = 1, Parent = top })
	Kit.Padding(wave, 10, 14)
	refs.Wave = Kit.Text({ Text = "ВОЛНА 0 / 30", Size = UDim2.new(0.5, 0, 0, 26), TextSize = 22, Weight = "Heavy", Parent = wave })
	refs.Phase = Kit.Text({ Text = "", Size = UDim2.new(0.5, 0, 0, 18), Position = UDim2.fromOffset(0, 26), TextSize = 14,
		TextColor3 = C.SubText, Parent = wave })
	refs.BaseLabel = Kit.Text({ Text = "❤ База", Size = UDim2.new(0.5, -8, 0, 18), Position = UDim2.new(0.5, 8, 0, 0), TextSize = 14,
		Weight = "Bold", Parent = wave })
	refs.BaseBar = Kit.Bar(wave, C.Green, UDim2.new(0.5, -8, 0, 18), UDim2.new(0.5, 8, 0, 24))
	refs.Leak = Kit.Text({ Text = "", Size = UDim2.fromOffset(120, 30), Position = UDim2.new(1, 22, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
		TextSize = 24, Weight = "Heavy", TextColor3 = C.Red, Shadow = true, Visible = false, Parent = wave })

	refs.Bosses = {}
	for i = 1, 2 do
		local panel = Kit.Panel({ Name = "Boss" .. i, Size = UDim2.fromOffset(540, 46), LayoutOrder = 10 + i, Visible = false, Parent = top })
		Kit.Padding(panel, 6, 12)
		local name = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 14), TextSize = 13, Weight = "Heavy", TextColor3 = C.Red, Parent = panel })
		local hp = Kit.Bar(panel, C.Red, UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 16))
		local shield = Kit.Bar(panel, C.Accent, UDim2.new(1, 0, 0, 4), UDim2.fromOffset(0, 30))
		refs.Bosses[i] = { Panel = panel, Name = name, Hp = hp, Shield = shield }
	end
end

local function buildLeft()
	local cash = Root.Fit(Kit.Panel({ Name = "Cash", Size = UDim2.fromOffset(210, 72), Position = UDim2.fromOffset(16, 10), Parent = layer }))
	Kit.Padding(cash, 8, 14)
	refs.Cash = Kit.Text({ Text = "$0", Size = UDim2.new(1, 0, 0, 32), TextSize = 28, Weight = "Heavy", TextColor3 = C.Gold, Parent = cash })
	refs.TowerCount = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 34), TextSize = 14,
		TextColor3 = C.SubText, Parent = cash })

	local controls = Root.Fit(Kit.Create("Frame", { Name = "Controls", BackgroundTransparency = 1, Size = UDim2.fromOffset(190, 156),
		Position = UDim2.new(0, 16, 0.5, -20), AnchorPoint = Vector2.new(0, 0.5), Parent = layer }))
	Kit.List(controls, 8)
	refs.Skip = Kit.Button({ Text = "⏭ Начать волну", Variant = "Gold", Size = UDim2.fromOffset(190, 44), TextSize = 15, LayoutOrder = 1,
		Parent = controls, OnClick = function()
			State.Fire("VoteSkip")
		end })
	refs.Speed = Kit.Button({ Text = "⏩ Скорость x2", Variant = "Neutral", Size = UDim2.fromOffset(190, 44), TextSize = 15, LayoutOrder = 2,
		Parent = controls, OnClick = function()
			State.Fire("VoteSpeed")
		end })
	refs.Camera = Kit.Button({ Text = "🎥 Обзор  [C]", Variant = "Neutral", Size = UDim2.fromOffset(190, 44), TextSize = 15, LayoutOrder = 3,
		Parent = controls, OnClick = function()
			HUDController.SetOverview(not overview)
		end })
end

local function buildTeam()
	local panel = Root.Fit(Kit.Panel({ Name = "Team", Size = UDim2.fromOffset(240, 132), Position = UDim2.new(1, -16, 0, 10),
		AnchorPoint = Vector2.new(1, 0), Parent = layer }))
	Kit.Padding(panel, 8, 12)
	Kit.Text({ Text = "КОМАНДА", Size = UDim2.new(1, 0, 0, 18), TextSize = 13, Weight = "Heavy", TextColor3 = C.SubText, Parent = panel })
	refs.Team = panel
	refs.TeamRows = {}
	for i = 1, 4 do
		local row = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 20 + (i - 1) * 25),
			Visible = false, Parent = panel })
		local name = Kit.Text({ Text = "", Size = UDim2.new(0.55, 0, 1, 0), TextSize = 14, Weight = "Bold", Parent = row })
		local stats = Kit.Text({ Text = "", Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.fromScale(0.55, 0), TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.Gold, Parent = row })
		refs.TeamRows[i] = { Row = row, Name = name, Stats = stats }
	end
end

local function buildBottom()
	local bottom = Root.Fit(Kit.Create("Frame", { Name = "BottomCenter", BackgroundTransparency = 1, Size = UDim2.fromOffset(780, 196),
		Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), Parent = layer }))
	refs.Reason = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 22), TextSize = 16, Weight = "Bold", Shadow = true,
		TextXAlignment = Enum.TextXAlignment.Center, Visible = false, Parent = bottom })
	local mobile = Kit.Create("Frame", { Name = "PlaceButtons", BackgroundTransparency = 1, Size = UDim2.fromOffset(320, 46),
		Position = UDim2.new(0.5, 0, 0, 28), AnchorPoint = Vector2.new(0.5, 0), Visible = false, Parent = bottom })
	Kit.List(mobile, 12, true, Enum.HorizontalAlignment.Center)
	refs.PlaceButton = Kit.Button({ Text = "✔ Поставить", Variant = "Success", Size = UDim2.fromOffset(154, 46), LayoutOrder = 1,
		Parent = mobile, OnClick = function()
			PlacementController.Confirm()
		end })
	Kit.Button({ Text = "✕ Отмена", Variant = "Danger", Size = UDim2.fromOffset(154, 46), LayoutOrder = 2, Parent = mobile,
		OnClick = function()
			PlacementController.Stop()
		end })
	refs.Mobile = mobile

	local bar = Kit.Panel({ Name = "TowerBar", Size = UDim2.new(1, 0, 0, 112), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1),
		Parent = bottom })
	Kit.Padding(bar, 8, 8)
	Kit.List(bar, 6, true, Enum.HorizontalAlignment.Center)
	refs.Cards = {}
	for i, def in Towers.List do
		local card = Kit.Create("TextButton", { Name = def.Id, Text = "", AutoButtonColor = false, BackgroundColor3 = C.PanelLight,
			Size = UDim2.fromOffset(88, 96), LayoutOrder = i, BorderSizePixel = 0, Parent = bar })
		Kit.Corner(card, 10)
		local stroke = Kit.Stroke(card, 0.85, 2, C.Stroke)
		Preview.Tower(def.Id, 1, card, UDim2.fromOffset(88, 58), UDim2.fromOffset(0, 2), "upper")
		Kit.Text({ Text = tostring(i), Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(5, 4), TextSize = 12, Weight = "Heavy",
			TextColor3 = C.SubText, Parent = card })
		Kit.Text({ Text = def.Name, Size = UDim2.new(1, -6, 0, 14), Position = UDim2.fromOffset(3, 60), TextSize = 11, Weight = "Bold",
			TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		local cost = Kit.Text({ Text = Format.Cash(def.Levels[1].Cost), Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 75),
			TextSize = 14, Weight = "Heavy", TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Gold, Parent = card })
		card.Activated:Connect(function()
			HUDController.Choose(def.Id)
		end)
		refs.Cards[def.Id] = { Card = card, Stroke = stroke, Cost = cost, Price = def.Levels[1].Cost }
	end
end

local function buildBanner()
	refs.Banner = Root.Fit(Kit.Text({ Text = "", Size = UDim2.fromOffset(900, 64), Position = UDim2.fromScale(0.5, 0.32),
		AnchorPoint = Vector2.new(0.5, 0.5), TextSize = 46, Weight = "Heavy", Shadow = true, TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false, Parent = layer }))
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
	local cash = State.Cash()
	local chosen = PlacementController.TowerId()
	for id, card in refs.Cards do
		local affordable = cash >= card.Price
		card.Cost.TextColor3 = if affordable then C.Gold else C.Red
		card.Card.BackgroundColor3 = if id == chosen then C.PanelLighter else C.PanelLight
		card.Stroke.Color = if id == chosen then C.Accent else C.Stroke
		card.Stroke.Transparency = if id == chosen then 0 else 0.85
	end
end

local function refreshTimer()
	local match = State.Match
	if not match then
		return
	end
	local phase = match.phase
	local text = PHASE_TEXT[phase] or phase
	if phase == "Prep" or phase == "Intermission" then
		local left = math.max(0, match.timer - (os.clock() - snapshotAt) * (match.timeScale or 1))
		text ..= "  •  старт через " .. Format.Time(left)
	elseif phase == "Wave" then
		text ..= "  •  врагов: " .. match.enemies
	end
	refs.Phase.Text = text
end

local function refresh()
	local match = State.Match
	if not match then
		return
	end
	local userId = Players.LocalPlayer.UserId
	refs.Wave.Text = string.format("ВОЛНА %d / %d", match.wave, match.maxWave)
	refreshTimer()
	local alpha = if match.baseMaxHp > 0 then match.baseHp / match.baseMaxHp else 0
	refs.BaseLabel.Text = "❤ База  " .. math.max(0, math.ceil(match.baseHp)) .. " / " .. match.baseMaxHp
	refs.BaseBar:Set(alpha, "")
	refs.BaseBar.Fill.BackgroundColor3 = if alpha > 0.5 then C.Green elseif alpha > 0.25 then C.Orange else C.Red

	local me = State.MyTeamEntry()
	refs.Cash.Text = Format.Cash(if me then me.cash else 0)
	refs.TowerCount.Text = string.format("Башни: %d / %d", if me then me.towers else 0, match.towerLimit or 15)

	for i, row in refs.TeamRows do
		local entry = match.team[i]
		row.Row.Visible = entry ~= nil
		if entry then
			row.Name.Text = entry.name
			row.Name.TextColor3 = if entry.userId == userId then C.Accent else C.Text
			row.Stats.Text = Format.Cash(entry.cash) .. "  •  ☠" .. entry.kills
		end
	end
	refs.Team.Size = UDim2.fromOffset(240, 32 + math.max(1, #match.team) * 25)

	local waiting = match.phase == "Prep" or match.phase == "Intermission"
	refs.Skip.Visible = waiting
	local skipMine = contains(match.skipBy, userId)
	refs.Skip.Text = string.format("%s  (%d/%d)", if skipMine then "✔ Готов" else "⏭ Начать волну", match.skipVotes, match.players)
	Kit.SetVariant(refs.Skip, if skipMine then "Primary" else "Gold")
	local speedMine = contains(match.speedBy, userId)
	local fast = (match.timeScale or 1) > 1
	refs.Speed.Text = string.format("%s  (%d/%d)", if fast then "⏩ x2 включено" else "⏩ Скорость x2", match.speedVotes, match.players)
	Kit.SetVariant(refs.Speed, if speedMine then "Primary" else "Neutral")
	refs.Speed.Visible = match.phase ~= "Victory" and match.phase ~= "Defeat"

	for i, boss in refs.Bosses do
		local entry = match.bosses[i]
		boss.Panel.Visible = entry ~= nil
		if entry then
			boss.Name.Text = "☠ " .. string.upper(entry.name)
			boss.Hp:Set(entry.hp / math.max(1, entry.maxHp), Format.Number(entry.hp) .. " / " .. Format.Number(entry.maxHp))
			boss.Shield.Frame.Visible = (entry.maxShield or 0) > 0
			boss.Shield:Set((entry.shield or 0) / math.max(1, entry.maxShield or 1), "")
		end
	end
	refreshCards()
end

local function banner(text: string, color: Color3, small: boolean?)
	if small then
		refs.Leak.Text = text
		refs.Leak.Visible = true
		refs.Leak.TextTransparency = 0
		bannerToken += 1
		local token = bannerToken
		task.delay(1.2, function()
			if token == bannerToken then
				refs.Leak.Visible = false
			end
		end)
		return
	end
	local label = refs.Banner :: TextLabel
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	label.Visible = true
	local scale = label:FindFirstChild("FitScale") :: UIScale
	local base = Root.Scale
	scale.Scale = base * 0.7
	Kit.Tween(scale, 0.25, { Scale = base }, Enum.EasingStyle.Back)
	local shown = text
	task.delay(2.2, function()
		if label.Text == shown then
			Kit.Tween(label, 0.4, { TextTransparency = 1 })
			task.wait(0.4)
			if label.Text == shown then
				label.Visible = false
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
			refs.Reason.TextColor3 = C.Text
			refs.Reason.Text = if UserInputService.TouchEnabled
				then "Коснись поля, чтобы выбрать место"
				else "ЛКМ — поставить  •  Shift+ЛКМ — ещё одну  •  ПКМ / Q — отмена"
		else
			refs.Reason.TextColor3 = C.Red
			refs.Reason.Text = "⛔ " .. (reason or "Здесь нельзя")
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

	State.MatchChanged.Event:Connect(function()
		snapshotAt = os.clock()
		refresh()
	end)
	FxController.Banner.Event:Connect(banner)
	PlacementController.Changed.Event:Connect(onPlacementChanged)

	local function updateVisibility()
		local inMatch = State.InMatch()
		layer.Visible = inMatch
		if not inMatch then
			if overview then
				HUDController.SetOverview(false)
			end
			refs.Banner.Visible = false
		end
	end
	Players.LocalPlayer:GetAttributeChangedSignal("MatchId"):Connect(updateVisibility)
	updateVisibility()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not State.InMatch() then
			return
		end
		for i, key in HOTKEYS do
			if input.KeyCode == key and Towers.List[i] then
				HUDController.Choose(Towers.List[i].Id)
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
