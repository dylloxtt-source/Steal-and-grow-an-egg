--[[
	Выбор башни (клик/тап по модели) и окно башни: превью, уровень, характеристики
	со стрелками к следующему уровню, кнопки Upgrade / Sell и приоритет цели.
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
local Preview = require(script.Parent.Parent.UI.Preview)
local TowerText = require(script.Parent.Parent.UI.TowerText)
local State = require(script.Parent.Parent.State)
local PlacementController = require(script.Parent.PlacementController)
local Sound = require(script.Parent.Sound)

local C = Kit.Theme.Colors

local TowerController = {}

local selected: Model? = nil
local refs: any = {}
local ring: Part
local sellArmedAt = 0

local PRIORITY_NAMES = { First = "First", Last = "Last", Strongest = "Strong", Weakest = "Weak" }

local function towersFolder(): Instance?
	local id = Players.LocalPlayer:GetAttribute("MatchId")
	local active = workspace:FindFirstChild("ActiveMatches")
	local match = id and active and active:FindFirstChild("Match_" .. id)
	return match and match:FindFirstChild("Towers")
end

local function delta(current: string, nextValue: string?): string
	if nextValue and nextValue ~= current then
		return current .. '  <font color="#4CD670">→ ' .. nextValue .. "</font>"
	end
	return current
end

local function build(layer: Instance)
	local panel = Root.Fit(Kit.Panel({ Name = "TowerInfo", Size = UDim2.fromOffset(330, 470), Position = UDim2.new(1, -16, 0.5, 26),
		AnchorPoint = Vector2.new(1, 0.5), Visible = false, Parent = layer }))
	refs.Panel = panel
	local view = Kit.Create("Frame", { Name = "View", BackgroundColor3 = C.PanelLight, Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(12, 12),
		BorderSizePixel = 0, Parent = panel })
	Kit.Corner(view, 12)
	refs.ViewStroke = Kit.Stroke(view, 0, 3, C.Accent)
	refs.View = view
	refs.Name = Kit.Text({ Text = "", Font = "Display", TextSize = 22, Size = UDim2.new(1, -150, 0, 26), Position = UDim2.fromOffset(94, 12), Stroke = true, Parent = panel })
	refs.Level = Kit.Text({ Text = "", Font = "Display", TextSize = 14, TextColor3 = C.Gold, Size = UDim2.new(1, -110, 0, 18), Position = UDim2.fromOffset(94, 40),
		Stroke = true, Parent = panel })
	local pips = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(180, 10), Position = UDim2.fromOffset(94, 66), Parent = panel })
	Kit.List(pips, 5, true)
	refs.Pips = {}
	for i = 1, Towers.MaxLevel do
		local pip = Kit.Create("Frame", { BackgroundColor3 = C.PanelLighter, Size = UDim2.fromOffset(30, 10), LayoutOrder = i, BorderSizePixel = 0, Parent = pips })
		Kit.Round(pip)
		refs.Pips[i] = pip
	end
	Kit.Button({ Name = "Close", Text = "X", Variant = "Danger", Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -10, 0, 10), AnchorPoint = Vector2.new(1, 0),
		TextSize = 16, Radius = 10, Parent = panel, OnClick = function()
			TowerController.Select(nil)
		end })

	local stats = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 124), Position = UDim2.fromOffset(12, 94), Parent = panel })
	Kit.List(stats, 4)
	refs.Stats = {}
	for i, entry in { "Damage", "Range", "Fire rate", "DPS" } do
		local row = Kit.Inset({ Size = UDim2.new(1, 0, 0, 28), LayoutOrder = i, Radius = 8, Parent = stats })
		Kit.Text({ Text = entry, Font = "Display", TextSize = 14, TextColor3 = C.SubText, Size = UDim2.new(0.45, 0, 1, 0),
			Position = UDim2.fromOffset(10, 0), Parent = row })
		refs.Stats[i] = Kit.Text({ Text = "", Font = "Display", TextSize = 15, RichText = true, Size = UDim2.new(0.55, -10, 1, 0), Position = UDim2.fromScale(0.45, 0),
			TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	end
	refs.Special = Kit.Text({ Text = "", Size = UDim2.new(1, -24, 0, 32), Position = UDim2.fromOffset(12, 222), TextSize = 12, Weight = "Bold", TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.Gold, Parent = panel })
	Kit.Text({ Text = "Target", Font = "Display", TextSize = 13, TextColor3 = C.SubText, Size = UDim2.fromOffset(100, 16), Position = UDim2.fromOffset(14, 258), Parent = panel })
	refs.Owner = Kit.Text({ Text = "", Font = "Display", TextSize = 12, TextColor3 = C.Muted, Size = UDim2.fromOffset(180, 16), Position = UDim2.new(1, -14, 0, 258),
		AnchorPoint = Vector2.new(1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = panel })
	local options = {}
	for _, name in Towers.Priorities do
		table.insert(options, { Id = name, Text = PRIORITY_NAMES[name] })
	end
	refs.Priority = Kit.Segmented({ Options = options, Size = UDim2.new(1, -24, 0, 38), Position = UDim2.fromOffset(12, 278), TextSize = 14, Parent = panel,
		OnSelect = function(name)
			if selected and selected:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then
				Sound.Play("Click")
				refs.Priority:Set(name)
				State.Fire("SetPriority", { uid = selected:GetAttribute("Uid"), priority = name })
			end
		end })
	refs.Upgrade = Kit.Button({ Name = "Upgrade", Text = "Upgrade", Variant = "Success", Size = UDim2.new(1, -24, 0, 58), Position = UDim2.fromOffset(12, 328),
		TextSize = 20, Parent = panel, OnClick = function()
			TowerController.Upgrade()
		end })
	refs.Next = Kit.Text({ Text = "", TextSize = 11, Weight = "Bold", TextColor3 = C.SubText, Size = UDim2.new(1, -24, 0, 14), Position = UDim2.fromOffset(12, 390),
		TextXAlignment = Enum.TextXAlignment.Center, Parent = panel })
	refs.Sell = Kit.Button({ Name = "Sell", Text = "Sell", Variant = "Danger", Size = UDim2.new(1, -24, 0, 48), Position = UDim2.fromOffset(12, 410),
		TextSize = 17, Parent = panel, OnClick = function()
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

local shownModel = ""

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
	local nextStats = def.Levels[level + 1]
	local mine = model:GetAttribute("OwnerId") == Players.LocalPlayer.UserId
	local rarity = TowerText.RarityColor(def)
	local key = def.Id .. ":" .. level
	if shownModel ~= key then
		shownModel = key
		for _, child in refs.View:GetChildren() do
			if child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end
		Preview.Tower(def.Id, level, refs.View, UDim2.fromScale(1, 1), nil, "upper")
	end
	refs.ViewStroke.Color = rarity
	refs.Name.Text = def.Name
	refs.Level.Text = string.format("Level %d - %s", level, stats.Text)
	for i, pip in refs.Pips do
		pip.BackgroundColor3 = if i <= level then C.Gold else C.PanelLighter
	end
	local damage = Format.Number(stats.Damage) .. (if stats.Hits then " ×" .. stats.Hits else "")
	local nextDamage = if nextStats then Format.Number(nextStats.Damage) .. (if nextStats.Hits then " ×" .. nextStats.Hits else "") else nil
	refs.Stats[1].Text = delta(damage, nextDamage)
	refs.Stats[2].Text = delta(Format.Decimal(stats.Range), if nextStats then Format.Decimal(nextStats.Range) else nil)
	refs.Stats[3].Text = delta(TowerText.FireRate(stats), if nextStats then TowerText.FireRate(nextStats) else nil)
	refs.Stats[4].Text = delta(Format.Number(Towers.Dps(stats)), if nextStats then Format.Number(Towers.Dps(nextStats)) else nil)
	refs.Special.Text = TowerText.SpecialLine(stats)
	local priority = model:GetAttribute("Priority") or "First"
	refs.Priority:Set(priority)
	refs.Owner.Text = if mine then "Your tower" else tostring(model:GetAttribute("OwnerName") or "Teammate") .. "'s tower"
	refs.Priority.Frame.Visible = mine
	refs.Upgrade.Visible = mine
	refs.Sell.Visible = mine
	refs.Next.Visible = mine
	if nextStats then
		local affordable = State.Cash() >= nextStats.Cost
		Kit.SetText(refs.Upgrade, string.format("Upgrade %s", Format.Cash(nextStats.Cost)))
		Kit.SetVariant(refs.Upgrade, if affordable then "Success" else "Disabled")
		refs.Next.Text = "Next: " .. nextStats.Text .. (if Kit.IsTouch() then "" else "  (U)")
	else
		Kit.SetText(refs.Upgrade, "Max Level")
		Kit.SetVariant(refs.Upgrade, "Gold")
		refs.Upgrade:SetAttribute("Variant", "Disabled")
		refs.Next.Text = "Fully upgraded"
	end
	local refund = math.floor((model:GetAttribute("Spent") or 0) * Economy.SellRefund)
	Kit.SetText(refs.Sell, if os.clock() - sellArmedAt < 2.5 then "Click again to sell" else string.format("Sell %s", Format.Cash(refund)))
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
