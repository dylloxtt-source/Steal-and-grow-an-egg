--[[
	Интерфейс лобби: верхняя панель (гемы, уровень), меню лифта (карта,
	размер группы, список игроков, готовность, таймер, старт/выход) и коллекция башен.
	Меню лифта обновляется автоматически по снимкам LobbyState.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maps = require(Shared.Config.Maps)
local Towers = require(Shared.Config.Towers)
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Logic.Format)

local Kit = require(script.Parent.Parent.UI.Kit)
local Root = require(script.Parent.Parent.UI.Root)
local Preview = require(script.Parent.Parent.UI.Preview)
local State = require(script.Parent.Parent.State)
local Sound = require(script.Parent.Sound)

local C = Kit.Theme.Colors

local LobbyController = {}

local layer: Frame
local refs: any = {}
local lastElevatorIndex: number? = nil

local STATE_TEXT = { Empty = "Свободен", Waiting = "Ожидание игроков", Starting = "Запуск!", InMatch = "Матч запущен" }
local STATE_COLOR = { Empty = C.Green, Waiting = C.Gold, Starting = C.Orange, InMatch = C.Red }

------------------------------------------------------------------------
-- Верхняя панель
------------------------------------------------------------------------

local function buildTopBar()
	local top = Root.Fit(Kit.Create("Frame", { Name = "Top", BackgroundTransparency = 1, Size = UDim2.fromOffset(560, 80),
		Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), Parent = layer }))
	Kit.List(top, 6, false, Enum.HorizontalAlignment.Center)
	local bar = Kit.Panel({ Name = "TopBar", Size = UDim2.fromOffset(560, 54), LayoutOrder = 1, Parent = top })
	Kit.Padding(bar, 8, 14)
	Kit.List(bar, 14, true)
	refs.Gems = Kit.Text({ Text = "💎 0", Size = UDim2.fromOffset(120, 36), TextSize = 20, Weight = "Heavy", TextColor3 = C.Gem, LayoutOrder = 1, Parent = bar })
	local level = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(170, 36), LayoutOrder = 2, Parent = bar })
	refs.Level = Kit.Text({ Text = "Ур. 1", Size = UDim2.new(1, 0, 0, 18), TextSize = 15, Weight = "Bold", Parent = level })
	refs.Xp = Kit.Bar(level, C.Accent, UDim2.new(1, 0, 0, 10), UDim2.fromOffset(0, 22))
	refs.Wins = Kit.Text({ Text = "🏆 0", Size = UDim2.fromOffset(80, 36), TextSize = 17, Weight = "Bold", TextColor3 = C.Gold, LayoutOrder = 3, Parent = bar })
	Kit.Button({ Text = "📖 Башни", Variant = "Neutral", Size = UDim2.fromOffset(110, 36), TextSize = 15, LayoutOrder = 4, Parent = bar,
		OnClick = function()
			LobbyController.ToggleCollection()
		end })
	refs.Memory = Kit.Text({ Text = "⚠ Тестовый режим: прогресс не сохраняется", Size = UDim2.fromOffset(560, 20),
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Orange, TextSize = 14, Shadow = true, Visible = false,
		LayoutOrder = 2, Parent = top })
	refs.Hint = Root.Fit(Kit.Text({ Text = "Зайди в любой из четырёх лифтов, чтобы собрать команду", Size = UDim2.fromOffset(640, 24),
		Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1), TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 17, Weight = "Bold", Shadow = true, Parent = layer }))
end

local function refreshProfile()
	local profile = State.Profile
	if not profile then
		return
	end
	refs.Gems.Text = "💎 " .. Format.Number(profile.gems)
	refs.Level.Text = "Ур. " .. profile.level
	local need = Economy.Xp.PerLevel(profile.level)
	refs.Xp:Set(profile.xp / need, "")
	refs.Wins.Text = "🏆 " .. profile.stats.wins
	refs.Memory.Visible = State.MemoryMode
end

------------------------------------------------------------------------
-- Меню лифта
------------------------------------------------------------------------

local function buildElevatorPanel()
	local panel = Root.Fit(Kit.Panel({ Name = "Elevator", Size = UDim2.fromOffset(380, 560), Position = UDim2.new(1, -16, 0.5, 20),
		AnchorPoint = Vector2.new(1, 0.5), Visible = false, Parent = layer }))
	Kit.Padding(panel, 14)
	refs.ElevatorPanel = panel
	refs.ElTitle = Kit.Text({ Text = "ЛИФТ 1", Size = UDim2.new(1, 0, 0, 28), TextSize = 24, Weight = "Heavy", Parent = panel })
	refs.ElState = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 30), TextSize = 15, Weight = "Bold", Parent = panel })
	refs.ElTimer = Kit.Text({ Text = "", Size = UDim2.fromOffset(120, 40), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right, TextSize = 32, Weight = "Heavy", TextColor3 = C.Gold, Parent = panel })

	Kit.Text({ Text = "КАРТА", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 62), TextSize = 12, TextColor3 = C.SubText, Weight = "Bold", Parent = panel })
	local maps = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 200), Position = UDim2.fromOffset(0, 80), Parent = panel })
	Kit.List(maps, 5)
	refs.MapRows = {}
	for i, map in Maps.List do
		local row = Kit.Create("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.PanelLight, Size = UDim2.new(1, 0, 0, 36),
			LayoutOrder = i, BorderSizePixel = 0, Parent = maps })
		Kit.Corner(row, 8)
		local stroke = Kit.Stroke(row, 1, 2, C.Accent)
		local swatch = Kit.Create("Frame", { BackgroundColor3 = map.Accent, Size = UDim2.fromOffset(10, 24), Position = UDim2.fromOffset(8, 6), BorderSizePixel = 0, Parent = row })
		Kit.Corner(swatch, 3)
		Kit.Text({ Text = map.Name, Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.fromOffset(28, 0), TextSize = 15, Weight = "Bold", Parent = row })
		local stars = math.clamp(math.floor((map.Difficulty - 1) / 0.13) + 1, 1, 5)
		Kit.Text({ Text = string.rep("★", stars) .. string.rep("☆", 5 - stars), Size = UDim2.new(0.35, 0, 1, 0), Position = UDim2.new(0.62, 0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.Gold, TextSize = 15, Parent = row })
		row.Activated:Connect(function()
			Sound.Play("Click")
			State.Fire("ElevatorSetMap", { map = map.Id })
		end)
		refs.MapRows[map.Id] = { Row = row, Stroke = stroke }
	end

	Kit.Text({ Text = "РАЗМЕР КОМАНДЫ", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 288), TextSize = 12, TextColor3 = C.SubText, Weight = "Bold", Parent = panel })
	local caps = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 306), Parent = panel })
	Kit.List(caps, 8, true)
	refs.CapButtons = {}
	for n = 1, 4 do
		refs.CapButtons[n] = Kit.Button({ Text = tostring(n), Variant = "Neutral", Size = UDim2.fromOffset(78, 36), LayoutOrder = n, Parent = caps,
			OnClick = function()
				State.Fire("ElevatorSetCapacity", { capacity = n })
			end })
	end

	refs.ElPlayersTitle = Kit.Text({ Text = "ИГРОКИ", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 352), TextSize = 12, TextColor3 = C.SubText, Weight = "Bold", Parent = panel })
	local members = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 370), Parent = panel })
	Kit.List(members, 4)
	refs.MemberRows = {}
	for i = 1, 4 do
		local row = Kit.Create("Frame", { BackgroundColor3 = C.PanelLight, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = i, BorderSizePixel = 0, Parent = members })
		Kit.Corner(row, 6)
		local name = Kit.Text({ Text = "", Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.fromOffset(10, 0), TextSize = 14, Parent = row })
		local ready = Kit.Text({ Text = "", Size = UDim2.new(0.3, -10, 1, 0), Position = UDim2.new(0.7, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 14, Weight = "Bold", Parent = row })
		refs.MemberRows[i] = { Row = row, Name = name, Ready = ready }
	end

	local buttons = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -40), Parent = panel })
	Kit.List(buttons, 8, true)
	refs.ReadyButton = Kit.Button({ Text = "Готов", Variant = "Success", Size = UDim2.fromOffset(110, 40), LayoutOrder = 1, Parent = buttons,
		OnClick = function()
			local elevator = State.MyElevator()
			if elevator then
				local me
				for _, member in elevator.members do
					if member.userId == Players.LocalPlayer.UserId then
						me = member
					end
				end
				State.Fire("ElevatorReady", { ready = not (me and me.ready) })
			end
		end })
	refs.StartButton = Kit.Button({ Text = "Старт", Variant = "Primary", Size = UDim2.fromOffset(110, 40), LayoutOrder = 2, Parent = buttons,
		OnClick = function()
			State.Fire("ElevatorStart")
		end })
	Kit.Button({ Text = "Выйти", Variant = "Danger", Size = UDim2.fromOffset(110, 40), LayoutOrder = 3, Parent = buttons,
		OnClick = function()
			State.Fire("ElevatorLeave")
		end })
end

local function refreshElevator()
	local elevator = State.MyElevator()
	local panel = refs.ElevatorPanel
	panel.Visible = elevator ~= nil and not State.InMatch()
	refs.Hint.Visible = elevator == nil
	if not elevator then
		lastElevatorIndex = nil
		return
	end
	if lastElevatorIndex ~= elevator.index then
		lastElevatorIndex = elevator.index
		Sound.Play("ElevatorJoin")
	end
	local isLeader = elevator.leader == Players.LocalPlayer.UserId
	refs.ElTitle.Text = "ЛИФТ " .. elevator.index
	refs.ElState.Text = (STATE_TEXT[elevator.state] or elevator.state) .. (if isLeader then "  •  👑 ты лидер" else "")
	refs.ElState.TextColor3 = STATE_COLOR[elevator.state] or C.Text
	refs.ElTimer.Text = if elevator.state == "Waiting" or elevator.state == "Starting" then tostring(math.ceil(elevator.timer)) else ""
	for mapId, entry in refs.MapRows do
		local selected = mapId == elevator.mapId
		entry.Stroke.Transparency = if selected then 0 else 1
		entry.Row.BackgroundColor3 = if selected then C.PanelLighter else C.PanelLight
		entry.Row.AutoButtonColor = isLeader
	end
	for n, button in refs.CapButtons do
		Kit.SetVariant(button, if n == elevator.capacity then "Primary" elseif isLeader and n >= #elevator.members then "Neutral" else "Disabled")
	end
	refs.ElPlayersTitle.Text = string.format("ИГРОКИ  %d / %d", #elevator.members, elevator.capacity)
	for i, row in refs.MemberRows do
		local member = elevator.members[i]
		row.Row.Visible = i <= elevator.capacity
		if member then
			row.Name.Text = (if member.userId == elevator.leader then "👑 " else "") .. member.name
			row.Name.TextColor3 = if member.userId == Players.LocalPlayer.UserId then C.Accent else C.Text
			row.Ready.Text = if member.ready then "✔ готов" else "…"
			row.Ready.TextColor3 = if member.ready then C.Green else C.Muted
		else
			row.Name.Text = "свободное место"
			row.Name.TextColor3 = C.Muted
			row.Ready.Text = ""
		end
	end
	local me
	for _, member in elevator.members do
		if member.userId == Players.LocalPlayer.UserId then
			me = member
		end
	end
	refs.ReadyButton.Text = if me and me.ready then "Не готов" else "Готов"
	Kit.SetVariant(refs.ReadyButton, if me and me.ready then "Neutral" else "Success")
	refs.StartButton.Visible = isLeader
	Kit.SetVariant(refs.StartButton, if elevator.state == "Waiting" then "Primary" else "Disabled")
end

------------------------------------------------------------------------
-- Коллекция башен
------------------------------------------------------------------------

local function statLine(level: any): string
	local parts = { string.format("⚔ %s", Format.Number(level.Damage)), string.format("◎ %s", Format.Decimal(level.Range)),
		string.format("⏱ %ss", Format.Decimal(level.Cooldown, 2)) }
	if level.Targets and level.Targets > 1 then
		table.insert(parts, "×" .. level.Targets .. " цели")
	end
	if level.Hits then
		table.insert(parts, level.Hits .. " удара")
	end
	if level.Poison then
		table.insert(parts, string.format("☣ %d/с %sс", level.Poison.Dps, Format.Decimal(level.Poison.Duration)))
	end
	if level.Splash then
		table.insert(parts, "область " .. level.Splash)
	end
	if level.Stun then
		table.insert(parts, "оглуш. " .. level.Stun .. "с")
	end
	if level.Pierce then
		table.insert(parts, string.format("пробитие %d%%", level.Pierce * 100))
	end
	if level.Detect then
		table.insert(parts, "👁")
	end
	return table.concat(parts, "  ")
end

local function buildCollection()
	local panel = Root.Fit(Kit.Panel({ Name = "Collection", Size = UDim2.fromOffset(940, 560), Position = UDim2.fromScale(0.5, 0.53),
		AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 20, Parent = layer }))
	Kit.Padding(panel, 16)
	refs.Collection = panel
	Kit.Text({ Text = "КОЛЛЕКЦИЯ БАШЕН", Size = UDim2.new(1, -60, 0, 30), TextSize = 24, Weight = "Heavy", Parent = panel })
	Kit.Button({ Text = "✕", Variant = "Neutral", Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, 0, 0, -4), AnchorPoint = Vector2.new(1, 0),
		Parent = panel, OnClick = function()
			panel.Visible = false
		end })
	local grid = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 420, 1, -44), Position = UDim2.fromOffset(0, 44), Parent = panel })
	Kit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(100, 150), CellPadding = UDim2.fromOffset(6, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local detail = Kit.Create("Frame", { BackgroundColor3 = C.PanelLight, Size = UDim2.new(1, -436, 1, -44), Position = UDim2.fromOffset(436, 44), BorderSizePixel = 0, Parent = panel })
	Kit.Corner(detail, 10)
	Kit.Padding(detail, 14)
	refs.DetailName = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 28), TextSize = 22, Weight = "Heavy", Parent = detail })
	refs.DetailRole = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 30), TextSize = 14, TextColor3 = C.Accent, Weight = "Bold", Parent = detail })
	refs.DetailDesc = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 52), TextSize = 14, TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.SubText, Parent = detail })
	local levels = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -104), Position = UDim2.fromOffset(0, 104), Parent = detail })
	Kit.List(levels, 6)
	refs.LevelRows = {}
	for i = 1, Towers.MaxLevel do
		local row = Kit.Create("Frame", { BackgroundColor3 = C.Panel, Size = UDim2.new(1, 0, 0, 62), LayoutOrder = i, BorderSizePixel = 0, Parent = levels })
		Kit.Corner(row, 8)
		Kit.Padding(row, 6, 10)
		local title = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 18), TextSize = 14, Weight = "Bold", Parent = row })
		local stats = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 20), TextSize = 13, TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None, TextColor3 = C.SubText, Parent = row })
		refs.LevelRows[i] = { Title = title, Stats = stats }
	end
	local function show(tower: any)
		refs.DetailName.Text = tower.Icon .. " " .. tower.Name
		refs.DetailRole.Text = tower.Role
		refs.DetailDesc.Text = tower.Description
		for i, row in refs.LevelRows do
			local level = tower.Levels[i]
			row.Title.Text = string.format("Уровень %d — %s  •  %s", i, level.Text, Format.Cash(level.Cost))
			row.Stats.Text = statLine(level)
		end
	end
	for i, tower in Towers.List do
		local card = Kit.Create("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = C.PanelLight, LayoutOrder = i, BorderSizePixel = 0, Parent = grid })
		Kit.Corner(card, 10)
		Kit.Stroke(card, 0.6, 2, tower.Accent)
		Preview.Tower(tower.Id, 1, card, UDim2.new(1, 0, 0, 110), UDim2.fromOffset(0, 2), "upper")
		Kit.Text({ Text = tower.Name, Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 112), TextSize = 12, Weight = "Bold",
			TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		Kit.Text({ Text = Format.Cash(tower.Levels[1].Cost), Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromOffset(4, 130), TextSize = 12,
			TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		card.Activated:Connect(function()
			show(tower)
		end)
	end
	show(Towers.List[1])
end

function LobbyController.ToggleCollection()
	refs.Collection.Visible = not refs.Collection.Visible
end

function LobbyController.Init(screen: Instance)
	layer = Root.Layer("Lobby")
	buildTopBar()
	buildElevatorPanel()
	buildCollection()
	State.LobbyChanged.Event:Connect(refreshElevator)
	State.ProfileChanged.Event:Connect(refreshProfile)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("ClientAction") == "OpenCollection" then
			refs.Collection.Visible = true
		end
	end)
	local function updateVisibility()
		layer.Visible = not State.InMatch()
		refreshElevator()
	end
	Players.LocalPlayer:GetAttributeChangedSignal("MatchId"):Connect(updateVisibility)
	updateVisibility()
	refreshProfile()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.25 then
			accumulator = 0
			if refs.ElevatorPanel.Visible then
				refreshElevator()
			end
		end
	end)
end

return LobbyController
