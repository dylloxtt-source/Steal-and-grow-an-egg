--[[
	Интерфейс лобби: карточка профиля (аватар, уровень, опыт), гемы и победы,
	кнопки магазина башен и настроек, подсказка и меню лифта (карта, размер группы,
	игроки, готовность, таймер, старт/выход). Меню обновляется по снимкам LobbyState.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maps = require(Shared.Config.Maps)
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Logic.Format)

local Kit = require(script.Parent.Parent.UI.Kit)
local Root = require(script.Parent.Parent.UI.Root)
local State = require(script.Parent.Parent.State)
local Sound = require(script.Parent.Sound)
local ShopController = require(script.Parent.ShopController)
local SettingsController = require(script.Parent.SettingsController)

local C = Kit.Theme.Colors

local LobbyController = {}

local layer: Frame
local refs: any = {}
local lastElevatorIndex: number? = nil

local STATE_TEXT = { Empty = "Open", Waiting = "Waiting for players", Starting = "Starting!", InMatch = "Departed" }
local DIFFICULTY = { "Easy", "Medium", "Hard", "Insane", "Insane" }
local STATE_COLOR = { Empty = C.Green, Waiting = C.Gold, Starting = C.Orange, InMatch = C.Red }

local function difficultyPips(parent: Instance, difficulty: number, position: UDim2)
	local stars = math.clamp(math.floor((difficulty - 1) / 0.13) + 1, 1, 5)
	local row = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(5 * 14, 10), Position = position, Parent = parent })
	Kit.List(row, 4, true)
	for i = 1, 5 do
		local pip = Kit.Create("Frame", { BackgroundColor3 = if i <= stars then (if stars >= 4 then C.Red elseif stars >= 3 then C.Orange else C.Gold) else C.PanelLighter,
			Size = UDim2.fromOffset(10, 10), LayoutOrder = i, BorderSizePixel = 0, Parent = row })
		Kit.Corner(pip, 3)
	end
	return row
end

------------------------------------------------------------------------
-- Верхняя панель
------------------------------------------------------------------------

local function buildTopBar()
	local card = Root.Fit(Kit.Panel({ Name = "Profile", Size = UDim2.fromOffset(330, 76), Position = UDim2.fromOffset(16, 12), Parent = layer }))
	Kit.Headshot(card, Players.LocalPlayer.UserId, 56, UDim2.fromOffset(10, 10))
	Kit.Text({ Text = Players.LocalPlayer.DisplayName, Font = "Display", TextSize = 21, Size = UDim2.new(1, -86, 0, 26), Position = UDim2.fromOffset(76, 8),
		Stroke = true, Parent = card })
	refs.Level = Kit.Badge({ Text = "Lv 1", Color = C.Gold, Size = UDim2.fromOffset(58, 22), Position = UDim2.fromOffset(76, 40), Parent = card })
	refs.Xp = Kit.Bar(card, C.Accent, UDim2.fromOffset(180, 18), UDim2.fromOffset(142, 42), 11)

	local right = Root.Fit(Kit.Create("Frame", { Name = "TopRight", BackgroundTransparency = 1, Size = UDim2.fromOffset(560, 56),
		Position = UDim2.new(1, -16, 0, 12), AnchorPoint = Vector2.new(1, 0), Parent = layer }))
	local list = Kit.List(right, 8, true, Enum.HorizontalAlignment.Right)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	refs.Gems = Kit.Pill({ Icon = "gem", Text = "0", Color = C.Gem, Size = UDim2.fromOffset(150, 46), LayoutOrder = 1, Parent = right })
	refs.Wins = Kit.Pill({ Icon = "star", Text = "0", Color = C.Gold, Size = UDim2.fromOffset(104, 46), LayoutOrder = 2, Parent = right })
	Kit.Button({ Name = "ShopButton", Text = "Shop", Variant = "Gold", Size = UDim2.fromOffset(118, 52), TextSize = 22, LayoutOrder = 3, Parent = right,
		OnClick = function()
			Sound.Play("Click")
			ShopController.Toggle()
		end })
	Kit.Button({ Name = "SettingsButton", Text = "Settings", Variant = "Neutral", Size = UDim2.fromOffset(122, 52), TextSize = 19, LayoutOrder = 4, Parent = right,
		OnClick = function()
			Sound.Play("Click")
			SettingsController.Toggle()
		end })

	refs.Memory = Root.Fit(Kit.Badge({ Text = "Test mode - progress is not saved", Color = C.Orange, Size = UDim2.fromOffset(330, 26), TextSize = 14,
		Position = UDim2.new(0.5, 0, 0, 16), AnchorPoint = Vector2.new(0.5, 0), Parent = layer }))
	refs.Memory.Visible = false

	local hint = Root.Fit(Kit.Panel({ Name = "Hint", Size = UDim2.fromOffset(520, 64), Position = UDim2.new(0.5, 0, 1, -18), AnchorPoint = Vector2.new(0.5, 1),
		Parent = layer }))
	Kit.Text({ Text = "Walk into an elevator to play!", Font = "Display", TextSize = 24, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 8),
		TextXAlignment = Enum.TextXAlignment.Center, Stroke = true, Parent = hint })
	Kit.Text({ Text = "Get new towers in the Shop", TextSize = 14, Weight = "Semi", TextColor3 = C.SubText, Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 38), TextXAlignment = Enum.TextXAlignment.Center, Parent = hint })
	refs.Hint = hint
end

local function refreshProfile()
	local profile = State.Profile
	if not profile then
		return
	end
	local previous = tonumber(refs.Gems.Label:GetAttribute("Value")) or profile.gems
	refs.Gems.Label:SetAttribute("Value", profile.gems)
	Kit.CountUp(refs.Gems.Label, previous, profile.gems, 0.6, function(n)
		return Format.Thousands(math.floor(n + 0.5))
	end)
	refs.Level.Text = "Lv " .. profile.level
	local need = Economy.Xp.PerLevel(profile.level)
	refs.Xp:Set(profile.xp / need, string.format("%s / %s XP", Format.Thousands(math.floor(profile.xp)), Format.Thousands(need)))
	refs.Wins:Set(Format.Thousands(profile.stats.wins))
	refs.Memory.Visible = State.MemoryMode
end

------------------------------------------------------------------------
-- Меню лифта
------------------------------------------------------------------------

local function buildElevatorPanel()
	local panel = Root.Fit(Kit.Panel({ Name = "Elevator", Size = UDim2.fromOffset(400, 556), Position = UDim2.new(1, -16, 0.5, 20),
		AnchorPoint = Vector2.new(1, 0.5), Visible = false, Parent = layer }))
	refs.ElevatorPanel = panel
	local header = Kit.Header(panel, { Title = "Elevator 1" })
	refs.ElTitle = header:FindFirstChild("Title")
	refs.ElTimer = Kit.Text({ Text = "", Font = "Display", TextSize = 34, TextColor3 = C.White, Size = UDim2.fromOffset(90, 54), Position = UDim2.new(1, -16, 0, 0),
		AnchorPoint = Vector2.new(1, 0), TextXAlignment = Enum.TextXAlignment.Right, Stroke = true, StrokeThickness = 2, ZIndex = 3, Parent = header })

	local body = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -28, 1, -68), Position = UDim2.fromOffset(14, 62), Parent = panel })
	refs.ElState = Kit.Badge({ Text = "", Color = C.Gold, Size = UDim2.new(1, 0, 0, 28), TextSize = 15, Parent = body })

	Kit.Text({ Text = "Map", Font = "Display", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(2, 38), TextSize = 14, TextColor3 = C.SubText, Parent = body })
	local maps = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 138), Position = UDim2.fromOffset(0, 58), Parent = body })
	Kit.Create("UIGridLayout", { CellSize = UDim2.new(1 / 3, -5, 0, 66), CellPadding = UDim2.fromOffset(7, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = maps })
	refs.MapCards = {}
	for i, map in Maps.List do
		local card = Kit.Create("TextButton", { Name = map.Id, Text = "", AutoButtonColor = false, BackgroundColor3 = C.PanelLight, LayoutOrder = i,
			BorderSizePixel = 0, ClipsDescendants = true, Parent = maps })
		Kit.Corner(card, 10)
		local stroke = Kit.Stroke(card, 1, 3, C.Accent)
		local band = Kit.Create("Frame", { BackgroundColor3 = map.Accent, Size = UDim2.new(1, 0, 0, 22), BorderSizePixel = 0, Parent = card })
		Kit.Gradient(band, Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 160, 160))
		Kit.Text({ Text = DIFFICULTY[math.clamp(math.floor((map.Difficulty - 1) / 0.13) + 1, 1, 5)], Font = "Display", TextSize = 12, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(6, 0), Stroke = true,
			Parent = band })
		Kit.Text({ Text = map.Name, Font = "Display", TextSize = 14, Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(6, 26), Stroke = true, Parent = card })
		difficultyPips(card, map.Difficulty, UDim2.fromOffset(6, 48))
		card.Activated:Connect(function()
			Sound.Play("Click")
			State.Fire("ElevatorSetMap", { map = map.Id })
		end)
		Kit.AttachTooltip(card, function()
			return string.format("<b>%s</b>\n%s", map.Name, map.Description)
		end)
		refs.MapCards[map.Id] = { Card = card, Stroke = stroke }
	end

	Kit.Text({ Text = "Party size", Font = "Display", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(2, 204), TextSize = 14, TextColor3 = C.SubText,
		Parent = body })
	refs.Capacity = Kit.Segmented({ Options = { { Id = "1", Text = "Solo" }, { Id = "2", Text = "2" }, { Id = "3", Text = "3" }, { Id = "4", Text = "4" } },
		Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 224), Parent = body, OnSelect = function(id)
			Sound.Play("Click")
			State.Fire("ElevatorSetCapacity", { capacity = tonumber(id) })
		end })
	refs.Capacity.Frame.Position = UDim2.fromOffset(0, 224)

	refs.ElPlayersTitle = Kit.Text({ Text = "Players", Font = "Display", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(2, 274), TextSize = 14,
		TextColor3 = C.SubText, Parent = body })
	local members = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 132), Position = UDim2.fromOffset(0, 294), Parent = body })
	Kit.List(members, 3)
	refs.MemberRows = {}
	for i = 1, 4 do
		local row = Kit.Inset({ Size = UDim2.new(1, 0, 0, 28), LayoutOrder = i, Radius = 8, Parent = members })
		local avatar = Kit.Headshot(row, 1, 22, UDim2.fromOffset(4, 3))
		local name = Kit.Text({ Text = "", Font = "Display", Size = UDim2.new(0.68, -36, 1, 0), Position = UDim2.fromOffset(36, 0), TextSize = 15, Parent = row })
		local ready = Kit.Text({ Text = "", Font = "Display", Size = UDim2.new(0.32, -10, 1, 0), Position = UDim2.new(0.68, 0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right, TextSize = 14, Parent = row })
		refs.MemberRows[i] = { Row = row, Name = name, Ready = ready, Avatar = avatar, UserId = 0 }
	end

	local buttons = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 1, -52), Parent = body })
	Kit.List(buttons, 8, true, Enum.HorizontalAlignment.Center)
	refs.ReadyButton = Kit.Button({ Name = "Ready", Text = "Ready", Variant = "Success", Size = UDim2.new(1 / 3, -6, 1, 0), LayoutOrder = 1, Parent = buttons,
		OnClick = function()
			local me = LobbyController.Me()
			State.Fire("ElevatorReady", { ready = not (me and me.ready) })
		end })
	refs.StartButton = Kit.Button({ Name = "Start", Text = "Start", Variant = "Gold", Size = UDim2.new(1 / 3, -6, 1, 0), LayoutOrder = 2, Parent = buttons,
		OnClick = function()
			State.Fire("ElevatorStart")
		end })
	Kit.Button({ Name = "Leave", Text = "Leave", Variant = "Danger", Size = UDim2.new(1 / 3, -6, 1, 0), LayoutOrder = 3, Parent = buttons,
		OnClick = function()
			State.Fire("ElevatorLeave")
		end })
end

function LobbyController.Me(): any?
	local elevator = State.MyElevator()
	if elevator then
		for _, member in elevator.members do
			if member.userId == Players.LocalPlayer.UserId then
				return member
			end
		end
	end
	return nil
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
	refs.ElTitle.Text = "Elevator " .. elevator.index
	local status = STATE_TEXT[elevator.state] or elevator.state
	refs.ElState.Text = status
	refs.ElState.BackgroundColor3 = STATE_COLOR[elevator.state] or C.Accent
	refs.ElTimer.Text = if elevator.state == "Waiting" or elevator.state == "Starting" then tostring(math.ceil(elevator.timer)) else ""
	refs.ElTimer.TextColor3 = if elevator.state == "Starting" then C.Gold else C.White
	for mapId, entry in refs.MapCards do
		local selected = mapId == elevator.mapId
		entry.Stroke.Transparency = if selected then 0 else 1
		entry.Card.BackgroundColor3 = if selected then C.PanelLighter else C.PanelLight
	end
	refs.Capacity:Set(tostring(elevator.capacity))
	for n, button in refs.Capacity.Buttons do
		button:SetAttribute("Disabled", not isLeader or tonumber(n) < #elevator.members)
	end
	refs.Capacity:Set(tostring(elevator.capacity))
	refs.ElPlayersTitle.Text = string.format("Players %d/%d", #elevator.members, elevator.capacity)
	for i, row in refs.MemberRows do
		local member = elevator.members[i]
		row.Row.Visible = i <= elevator.capacity
		row.Avatar.Visible = member ~= nil
		if member then
			if row.UserId ~= member.userId then
				row.UserId = member.userId
				row.Avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", math.max(1, member.userId))
			end
			row.Name.Text = member.name .. (if member.userId == elevator.leader then " (Leader)" else "")
			row.Name.TextColor3 = if member.userId == Players.LocalPlayer.UserId then C.Accent else C.Text
			row.Ready.Text = if member.ready then "Ready" else "..."
			row.Ready.TextColor3 = if member.ready then C.Green else C.Muted
		else
			row.Name.Text = "Empty slot"
			row.Name.TextColor3 = C.Muted
			row.Ready.Text = ""
		end
	end
	local me = LobbyController.Me()
	Kit.SetText(refs.ReadyButton, if me and me.ready then "Not ready" else "Ready")
	Kit.SetVariant(refs.ReadyButton, if me and me.ready then "Neutral" else "Success")
	refs.StartButton.Visible = isLeader
	Kit.SetVariant(refs.StartButton, if elevator.state == "Waiting" then "Gold" else "Disabled")
end

function LobbyController.Init(screen: Instance)
	layer = Root.Layer("Lobby")
	buildTopBar()
	buildElevatorPanel()
	State.LobbyChanged.Event:Connect(refreshElevator)
	State.ProfileChanged.Event:Connect(refreshProfile)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local action = prompt:GetAttribute("ClientAction")
		if action == "OpenShop" or action == "OpenCollection" or action == "OpenLoadout" then
			ShopController.Open()
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
