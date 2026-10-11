--[[
	Выбор башни (клик/тап по модели) и окно башни: уровень, характеристики,
	следующее улучшение, кнопки Upgrade / Sell и приоритет цели.
	Клавиши: U — улучшить, X — продать (повторное нажатие подтверждает), Esc — закрыть.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Config.Towers)
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Logic.Format)

local Kit = require(script.Parent.Parent.UI.Kit)
local Root = require(script.Parent.Parent.UI.Root)
local State = require(script.Parent.Parent.State)
local PlacementController = require(script.Parent.PlacementController)
local Sound = require(script.Parent.Sound)

local C = Kit.Theme.Colors

local TowerController = {}

local selected: Model? = nil
local refs: any = {}
local ring: Part
local sellArmedAt = 0

local PRIORITY_NAMES = { First = "Первый", Last = "Последний", Strongest = "Сильный", Weakest = "Слабый" }

local function towersFolder(): Instance?
	local id = Players.LocalPlayer:GetAttribute("MatchId")
	local active = workspace:FindFirstChild("ActiveMatches")
	local match = id and active and active:FindFirstChild("Match_" .. id)
	return match and match:FindFirstChild("Towers")
end

local function special(level: any): string
	local parts = {}
	if level.Targets and level.Targets > 1 then
		table.insert(parts, level.Targets .. " цели")
	end
	if level.Hits then
		table.insert(parts, level.Hits .. " удара в серии")
	end
	if level.Poison then
		table.insert(parts, string.format("яд %d/с на %sс", level.Poison.Dps, Format.Decimal(level.Poison.Duration)))
	end
	if level.Cloud then
		table.insert(parts, "облако " .. level.Cloud)
	end
	if level.Slow then
		table.insert(parts, string.format("замедление %d%%", level.Slow.Factor * 100))
	end
	if level.Splash then
		table.insert(parts, "область " .. level.Splash)
	end
	if level.Stun then
		table.insert(parts, "оглушение " .. level.Stun .. "с")
	end
	if level.Pierce then
		table.insert(parts, string.format("пробитие %d%%", level.Pierce * 100))
	end
	if level.SpinMax then
		table.insert(parts, string.format("раскрутка +%d%%", level.SpinMax * 100))
	end
	if level.FrenzyEvery then
		table.insert(parts, "ярость каждые " .. level.FrenzyEvery)
	end
	if level.Detect then
		table.insert(parts, "👁 видит скрытных")
	end
	return if #parts > 0 then "✦ " .. table.concat(parts, " • ") else "Без особых эффектов"
end

local function build(layer: Instance)
	local panel = Root.Fit(Kit.Panel({ Name = "TowerInfo", Size = UDim2.fromOffset(310, 430), Position = UDim2.new(1, -16, 0.5, -20),
		AnchorPoint = Vector2.new(1, 0.5), Visible = false, Parent = layer }))
	Kit.Padding(panel, 14)
	refs.Panel = panel
	refs.Name = Kit.Text({ Text = "", Size = UDim2.new(1, -40, 0, 26), TextSize = 20, Weight = "Heavy", Parent = panel })
	Kit.Button({ Text = "✕", Variant = "Neutral", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, 0, 0, -2), AnchorPoint = Vector2.new(1, 0),
		Parent = panel, OnClick = function()
			TowerController.Select(nil)
		end })
	refs.Level = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 28), TextSize = 14, TextColor3 = C.Accent, Weight = "Bold", Parent = panel })
	refs.LevelBar = Kit.Bar(panel, C.Accent, UDim2.new(1, 0, 0, 6), UDim2.fromOffset(0, 50))
	local stats = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 64), Parent = panel })
	Kit.List(stats, 2)
	refs.Stats = {}
	for i, name in { "Урон", "Дальность", "Атак в сек.", "Урон в сек.", "Цель" } do
		local row = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = i, Parent = stats })
		Kit.Text({ Text = name, Size = UDim2.new(0.5, 0, 1, 0), TextSize = 14, TextColor3 = C.SubText, Parent = row })
		refs.Stats[i] = Kit.Text({ Text = "", Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromScale(0.5, 0), TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 14, Weight = "Bold", Parent = row })
	end
	refs.Special = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 180), TextSize = 13, TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.Gold, Parent = panel })
	refs.Next = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 212), TextSize = 13, TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.SubText, Parent = panel })
	refs.Owner = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 252), TextSize = 13, TextColor3 = C.Muted, Parent = panel })

	local priority = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 276), Parent = panel })
	Kit.List(priority, 4, true)
	refs.PriorityButtons = {}
	for i, name in Towers.Priorities do
		refs.PriorityButtons[name] = Kit.Button({ Text = PRIORITY_NAMES[name], Variant = "Neutral", Size = UDim2.fromOffset(67, 30), TextSize = 12,
			LayoutOrder = i, Parent = priority, OnClick = function()
				if selected then
					State.Fire("SetPriority", { uid = selected:GetAttribute("Uid"), priority = name })
				end
			end })
	end
	refs.Upgrade = Kit.Button({ Text = "Улучшить", Variant = "Success", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 1, -96),
		TextSize = 16, Parent = panel, OnClick = function()
			TowerController.Upgrade()
		end })
	refs.Sell = Kit.Button({ Text = "Продать", Variant = "Danger", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -44),
		TextSize = 15, Parent = panel, OnClick = function()
			TowerController.Sell()
		end })

	ring = Instance.new("Part")
	ring.Name = "SelectedRange"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = C.Accent
	ring.Transparency = 1
	ring.Parent = workspace
end

local function refresh()
	local model = selected
	if not model or not model.Parent then
		if refs.Panel.Visible then
			TowerController.Select(nil)
		end
		return
	end
	local def = Towers.ById[model:GetAttribute("TowerId")]
	local level = model:GetAttribute("Level") or 1
	local stats = def.Levels[level]
	local mine = model:GetAttribute("OwnerId") == Players.LocalPlayer.UserId
	refs.Name.Text = def.Icon .. " " .. def.Name
	refs.Level.Text = string.format("Уровень %d / %d  •  %s", level, Towers.MaxLevel, stats.Text)
	refs.LevelBar:Set(level / Towers.MaxLevel, "")
	refs.Stats[1].Text = Format.Number(stats.Damage) .. (if stats.Hits then " ×" .. stats.Hits else "")
	refs.Stats[2].Text = Format.Decimal(stats.Range)
	refs.Stats[3].Text = Format.Decimal(1 / stats.Cooldown, 2)
	refs.Stats[4].Text = Format.Number(Towers.Dps(stats))
	local priority = model:GetAttribute("Priority") or "First"
	refs.Stats[5].Text = PRIORITY_NAMES[priority] or priority
	refs.Special.Text = special(stats)
	local nextStats = def.Levels[level + 1]
	if nextStats then
		refs.Next.Text = string.format("Далее: %s — урон %s → %s, дальность %s → %s", nextStats.Text, Format.Number(stats.Damage),
			Format.Number(nextStats.Damage), Format.Decimal(stats.Range), Format.Decimal(nextStats.Range))
	else
		refs.Next.Text = "Максимальный уровень достигнут"
	end
	refs.Owner.Text = if mine then "Твоя башня" else "Башня союзника"
	for name, button in refs.PriorityButtons do
		button.Visible = mine
		Kit.SetVariant(button, if name == priority then "Primary" else "Neutral")
	end
	refs.Upgrade.Visible = mine
	refs.Sell.Visible = mine
	if nextStats then
		local affordable = State.Cash() >= nextStats.Cost
		refs.Upgrade.Text = string.format("Улучшить  %s  [U]", Format.Cash(nextStats.Cost))
		Kit.SetVariant(refs.Upgrade, if affordable then "Success" else "Disabled")
	else
		refs.Upgrade.Text = "Max Level"
		Kit.SetVariant(refs.Upgrade, "Disabled")
	end
	local refund = math.floor((model:GetAttribute("Spent") or 0) * Economy.SellRefund)
	refs.Sell.Text = if os.clock() - sellArmedAt < 2.5 then "Точно продать?  [X]" else string.format("Продать  +%s  [X]", Format.Cash(refund))
	local root = model.PrimaryPart
	if root then
		local range = stats.Range
		ring.Size = Vector3.new(0.15, range * 2, range * 2)
		ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = 0.8
	end
end

function TowerController.Select(model: Model?)
	selected = model
	sellArmedAt = 0
	refs.Panel.Visible = model ~= nil
	if not model then
		ring.Transparency = 1
	else
		Sound.Play("Click")
		refresh()
	end
end

function TowerController.Selected(): Model?
	return selected
end

function TowerController.Upgrade()
	if selected and selected:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then
		local uid = selected:GetAttribute("Uid")
		State.Fire("UpgradeTower", { uid = uid }, function(ok)
			if ok then
				-- Модель пересоздаётся сервером: выбираем новую с тем же Uid
				task.wait(0.15)
				local folder = towersFolder()
				if folder then
					for _, model in folder:GetChildren() do
						if model:GetAttribute("Uid") == uid then
							TowerController.Select(model)
						end
					end
				end
			end
		end)
	end
end

function TowerController.Sell()
	if not selected or selected:GetAttribute("OwnerId") ~= Players.LocalPlayer.UserId then
		return
	end
	if os.clock() - sellArmedAt < 2.5 then
		local uid = selected:GetAttribute("Uid")
		sellArmedAt = 0
		State.Fire("SellTower", { uid = uid })
		TowerController.Select(nil)
	else
		sellArmedAt = os.clock()
		refresh()
	end
end

local function pick(position: Vector2, isTouch: boolean): Model?
	local folder = towersFolder()
	if not folder then
		return nil
	end
	local camera = workspace.CurrentCamera
	local ray = if isTouch then camera:ScreenPointToRay(position.X, position.Y) else camera:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if result then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		while model and model.Parent ~= folder do
			model = model:FindFirstAncestorOfClass("Model")
		end
		return model
	end
	return nil
end

function TowerController.Init(layer: Instance)
	build(layer)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not State.InMatch() then
			return
		end
		if input.KeyCode == Enum.KeyCode.U then
			TowerController.Upgrade()
		elseif input.KeyCode == Enum.KeyCode.X then
			TowerController.Sell()
		elseif input.KeyCode == Enum.KeyCode.Escape and selected then
			TowerController.Select(nil)
		end
		if processed or PlacementController.Active() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			TowerController.Select(pick(UserInputService:GetMouseLocation(), false))
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local model = pick(Vector2.new(input.Position.X, input.Position.Y), true)
			if model then
				TowerController.Select(model)
			end
		end
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.2 then
			accumulator = 0
			if selected then
				refresh()
			end
		end
	end)
	PlacementController.Changed.Event:Connect(function(active)
		if active then
			TowerController.Select(nil)
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("MatchId"):Connect(function()
		TowerController.Select(nil)
	end)
end

return TowerController
