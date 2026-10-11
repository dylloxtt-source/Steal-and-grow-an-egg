--[[
	Магазин башен и набор на матч (loadout).
	Слева — все башни (цвет редкости, цена в гемах или «OWNED/EQUIPPED»), справа —
	подробности выбранной башни и кнопка Buy / Equip / Unequip, внизу — 5 слотов набора.
	Клик по слоту выбирает его: следующая «Equip» поставит башню именно туда.
	Все покупки и изменения набора проверяет сервер (ShopService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Towers = require(Shared.Config.Towers)
local Format = require(Shared.Logic.Format)

local Kit = require(script.Parent.Parent.UI.Kit)
local Root = require(script.Parent.Parent.UI.Root)
local Preview = require(script.Parent.Parent.UI.Preview)
local TowerText = require(script.Parent.Parent.UI.TowerText)
local State = require(script.Parent.Parent.State)
local Sound = require(script.Parent.Sound)

local C = Kit.Theme.Colors

local ShopController = {}

local refs: any = {}
local selected = Towers.Starter
local selectedSlot: number? = nil

local function profile(): any
	return State.Profile or { gems = 0, owned = { [Towers.Starter] = true }, loadout = { Towers.Starter } }
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("ViewportFrame") then
			child:Destroy()
		end
	end
end

local function buildCard(parent: Instance, def: any, index: number)
	local rarity = TowerText.RarityColor(def)
	local card = Kit.Create("TextButton", { Name = def.Id, Text = "", AutoButtonColor = false, BackgroundColor3 = C.PanelLight, LayoutOrder = index,
		BorderSizePixel = 0, ClipsDescendants = true, Parent = parent })
	Kit.Corner(card, 12)
	local stroke = Kit.Stroke(card, 0.6, 3, rarity)
	local glow = Kit.Create("Frame", { BackgroundColor3 = rarity, BackgroundTransparency = 0.55, Size = UDim2.new(1, 0, 0.62, 0), BorderSizePixel = 0, Parent = card })
	Kit.Gradient(glow, Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 40, 50))
	Kit.Text({ Text = def.Rarity, Font = "Display", TextSize = 12, TextColor3 = rarity, Size = UDim2.new(1, -10, 0, 16), Position = UDim2.fromOffset(8, 4),
		Stroke = true, Parent = card })
	Preview.Tower(def.Id, 1, card, UDim2.new(1, 0, 0, 104), UDim2.fromOffset(0, 12), "upper")
	Kit.Text({ Text = def.Name, Font = "Display", TextSize = 15, Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 116),
		TextXAlignment = Enum.TextXAlignment.Center, Stroke = true, Parent = card })
	local status = Kit.Badge({ Text = "", Color = C.Gem, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1),
		TextSize = 14, Parent = card })
	card.Activated:Connect(function()
		Sound.Play("Click")
		ShopController.Select(def.Id)
	end)
	Kit.AttachTooltip(card, function()
		return TowerText.Tooltip(def)
	end)
	refs.Cards[def.Id] = { Card = card, Stroke = stroke, Status = status }
end

local function buildDetail(parent: Instance)
	local detail = Kit.Inset({ Name = "Detail", Size = UDim2.fromOffset(404, 354), Position = UDim2.fromOffset(580, 70), Parent = parent })
	Kit.Padding(detail, 12)
	refs.DetailView = Kit.Create("Frame", { Name = "View", BackgroundColor3 = C.PanelLight, Size = UDim2.fromOffset(140, 160), BorderSizePixel = 0, Parent = detail })
	Kit.Corner(refs.DetailView, 12)
	refs.DetailViewStroke = Kit.Stroke(refs.DetailView, 0.2, 3, C.Accent)
	refs.DetailName = Kit.Text({ Text = "", Font = "Display", TextSize = 26, Size = UDim2.new(1, -152, 0, 30), Position = UDim2.fromOffset(152, 0), Stroke = true,
		Parent = detail })
	refs.DetailRarity = Kit.Badge({ Text = "", Size = UDim2.fromOffset(96, 22), Position = UDim2.fromOffset(152, 34), TextSize = 12, Parent = detail })
	refs.DetailRole = Kit.Text({ Text = "", Size = UDim2.new(1, -152, 0, 18), Position = UDim2.fromOffset(152, 62), TextSize = 14, Weight = "Bold",
		TextColor3 = C.SubText, Parent = detail })
	refs.Action = Kit.Button({ Name = "Action", Text = "Buy", Variant = "Purple", Size = UDim2.new(1, -152, 0, 52), Position = UDim2.fromOffset(152, 98),
		TextSize = 20, Parent = detail, OnClick = function()
			ShopController.Act()
		end })
	refs.DetailDesc = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 168), TextSize = 13, TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.SubText, Parent = detail })
	local levels = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 116), Position = UDim2.fromOffset(0, 212), Parent = detail })
	Kit.List(levels, 3)
	refs.LevelRows = {}
	for i = 1, Towers.MaxLevel do
		local row = Kit.Create("Frame", { BackgroundColor3 = C.PanelLight, BackgroundTransparency = if i % 2 == 1 then 0.3 else 0.7, Size = UDim2.new(1, 0, 0, 21),
			LayoutOrder = i, BorderSizePixel = 0, Parent = levels })
		Kit.Corner(row, 6)
		Kit.Text({ Text = "LV" .. i, Font = "Display", TextSize = 13, TextColor3 = C.Gold, Size = UDim2.fromOffset(34, 21), Position = UDim2.fromOffset(6, 0), Parent = row })
		local text = Kit.Text({ Text = "", TextSize = 12, Weight = "Bold", Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(40, 0), Parent = row })
		refs.LevelRows[i] = text
	end
end

local function buildLoadout(parent: Instance)
	local strip = Kit.Inset({ Name = "Loadout", Size = UDim2.new(1, -32, 0, 156), Position = UDim2.new(0, 16, 1, -168), Parent = parent })
	refs.LoadoutTitle = Kit.Text({ Text = "Loadout", Font = "Display", TextSize = 17, Size = UDim2.fromOffset(300, 22), Position = UDim2.fromOffset(14, 8),
		Stroke = true, Parent = strip })
	Kit.Text({ Text = "Pick a slot, then press Equip", TextSize = 12, Weight = "Semi",
		TextColor3 = C.SubText, Size = UDim2.fromOffset(560, 18), Position = UDim2.new(1, -14, 0, 10), AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = strip })
	local row = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -28, 0, 110), Position = UDim2.fromOffset(14, 36), Parent = strip })
	Kit.List(row, 12, true, Enum.HorizontalAlignment.Center)
	refs.Slots = {}
	for i = 1, Towers.LoadoutSize do
		local slot = Kit.Create("TextButton", { Name = "Slot" .. i, Text = "", AutoButtonColor = false, BackgroundColor3 = C.PanelLight, Size = UDim2.fromOffset(160, 108),
			LayoutOrder = i, BorderSizePixel = 0, ClipsDescendants = true, Parent = row })
		Kit.Corner(slot, 12)
		local stroke = Kit.Stroke(slot, 0.7, 3, C.Accent)
		local number = Kit.Badge({ Text = tostring(i), Color = C.PanelLighter, Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(6, 6), TextSize = 13, ZIndex = 3,
			Parent = slot })
		local name = Kit.Text({ Text = "", Font = "Display", TextSize = 14, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.new(0, 4, 1, -22),
			TextXAlignment = Enum.TextXAlignment.Center, Stroke = true, ZIndex = 3, Parent = slot })
		local empty = Kit.Text({ Text = "Empty", Font = "Display", TextSize = 16, TextColor3 = C.Muted, Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.None, Parent = slot })
		local remove = Kit.Button({ Name = "Remove", Text = "X", Variant = "Danger", Size = UDim2.fromOffset(28, 30), Position = UDim2.new(1, -6, 0, 6),
			AnchorPoint = Vector2.new(1, 0), TextSize = 13, Radius = 8, ZIndex = 4, Parent = slot, OnClick = function()
				local towerId = profile().loadout[i]
				if towerId then
					State.Fire("UnequipTower", { tower = towerId })
				end
			end })
		slot.Activated:Connect(function()
			Sound.Play("Click")
			selectedSlot = if selectedSlot == i then nil else i
			local towerId = profile().loadout[i]
			if towerId then
				selected = towerId
			end
			ShopController.Refresh()
		end)
		refs.Slots[i] = { Slot = slot, Stroke = stroke, Name = name, Empty = empty, Remove = remove, Number = number, Shown = nil }
	end
end

local function build(screen: Instance)
	local layer = Root.Layer("Shop")
	layer.ZIndex = 30
	layer.Visible = false
	refs.Layer = layer
	local dim = Kit.Create("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Black, BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1), Parent = layer })
	dim.Activated:Connect(function()
		ShopController.Close()
	end)
	local window = Root.Fit(Kit.Panel({ Name = "Window", Size = UDim2.fromOffset(1000, 600), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = layer }))
	refs.Window = window
	Kit.Header(window, { Title = "Tower Shop", Accent = C.Gold, OnClose = ShopController.Close })
	refs.Gems = Kit.Pill({ Icon = "gem", Text = "0", Color = C.Gem, Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -62, 0, 7), AnchorPoint = Vector2.new(1, 0),
		Parent = window })
	refs.Gems.Frame.ZIndex = 3

	local grid = Kit.Create("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.fromOffset(550, 354), Position = UDim2.fromOffset(16, 70), Parent = window })
	Kit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(130, 172), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	refs.Cards = {}
	for i, def in Towers.List do
		buildCard(grid, def, i)
	end
	buildDetail(window)
	buildLoadout(window)
end

local function slotOf(towerId: string): number?
	return table.find(profile().loadout, towerId)
end

function ShopController.Select(towerId: string)
	selected = towerId
	ShopController.Refresh()
end

function ShopController.Act()
	local def = Towers.ById[selected]
	local data = profile()
	if not data.owned[selected] then
		if data.gems < def.Price then
			State.Notify:Fire(string.format("You need %s more gems for %s", Format.Thousands(def.Price - data.gems), def.Name), "error")
			return
		end
		Kit.SetVariant(refs.Action, "Disabled")
		State.Fire("BuyTower", { tower = selected }, function(ok)
			if ok then
				Sound.Play("Upgrade")
				State.Notify:Fire("Unlocked " .. def.Name .. "!", "gem")
			end
			ShopController.Refresh()
		end)
	elseif slotOf(selected) and not selectedSlot then
		State.Fire("UnequipTower", { tower = selected })
	else
		local slot = selectedSlot
		selectedSlot = nil
		State.Fire("EquipTower", { tower = selected, slot = slot }, function(ok)
			if ok then
				Sound.Play("Place")
			end
		end)
	end
end

function ShopController.Refresh()
	if not refs.Window then
		return
	end
	local data = profile()
	refs.Gems:Set(Format.Thousands(data.gems))
	for id, card in refs.Cards do
		local def = Towers.ById[id]
		local owned = data.owned[id] == true
		local equipped = slotOf(id) ~= nil
		card.Status.Text = if equipped then "Equipped" elseif owned then "Owned" else Format.Thousands(def.Price) .. " Gems"
		card.Status.BackgroundColor3 = if equipped then C.Green elseif owned then C.PanelLighter elseif data.gems >= def.Price then C.Purple else C.PanelLighter
		card.Status.TextColor3 = if not owned and data.gems < def.Price then C.Gem else C.White
		card.Stroke.Transparency = if id == selected then 0 else 0.65
		card.Card.BackgroundColor3 = if id == selected then C.PanelLighter else C.PanelLight
	end

	local def = Towers.ById[selected]
	local rarity = TowerText.RarityColor(def)
	if refs.DetailShown ~= selected then
		refs.DetailShown = selected
		clear(refs.DetailView)
		Preview.Tower(selected, Towers.MaxLevel, refs.DetailView, UDim2.fromScale(1, 1), nil, "upper")
	end
	refs.DetailViewStroke.Color = rarity
	refs.DetailName.Text = def.Name
	refs.DetailRarity.Text = def.Rarity
	refs.DetailRarity.BackgroundColor3 = rarity
	refs.DetailRole.Text = def.Role
	refs.DetailDesc.Text = def.Description
	for i, label in refs.LevelRows do
		local level = def.Levels[i]
		label.Text = string.format("%s   %s   DMG %s   RNG %s   %s", level.Text, Format.Cash(level.Cost), Format.Number(level.Damage),
			Format.Decimal(level.Range), TowerText.FireRate(level))
	end
	local owned = data.owned[selected] == true
	local equipped = slotOf(selected)
	if not owned then
		Kit.SetText(refs.Action, "Buy for " .. Format.Thousands(def.Price) .. " Gems")
		Kit.SetVariant(refs.Action, if data.gems >= def.Price then "Purple" else "Disabled")
	elseif equipped and not selectedSlot then
		Kit.SetText(refs.Action, if #data.loadout <= 1 then "Equipped" else "Unequip")
		Kit.SetVariant(refs.Action, if #data.loadout <= 1 then "Disabled" else "Danger")
	elseif selectedSlot then
		Kit.SetText(refs.Action, "Equip to slot " .. selectedSlot)
		Kit.SetVariant(refs.Action, "Success")
	else
		Kit.SetText(refs.Action, if #data.loadout >= Towers.LoadoutSize then "Loadout full" else "Equip")
		Kit.SetVariant(refs.Action, if #data.loadout >= Towers.LoadoutSize then "Disabled" else "Success")
	end

	refs.LoadoutTitle.Text = string.format("Loadout %d/%d", #data.loadout, Towers.LoadoutSize)
	for i, slot in refs.Slots do
		local towerId = data.loadout[i]
		slot.Empty.Visible = towerId == nil
		slot.Remove.Visible = towerId ~= nil and #data.loadout > 1
		slot.Stroke.Transparency = if selectedSlot == i then 0 else 0.75
		slot.Stroke.Color = if selectedSlot == i then C.Gold else (if towerId then TowerText.RarityColor(Towers.ById[towerId]) else C.Accent)
		slot.Name.Text = if towerId then Towers.ById[towerId].Name else ""
		if slot.Shown ~= towerId then
			slot.Shown = towerId
			clear(slot.Slot)
			if towerId then
				Preview.Tower(towerId, 1, slot.Slot, UDim2.new(1, 0, 1, -18), UDim2.fromOffset(0, 0), "upper")
			end
		end
	end
end

function ShopController.Open()
	if State.InMatch() then
		return
	end
	refs.Layer.Visible = true
	local scale = refs.Window:FindFirstChild("FitScale") :: UIScale
	scale.Scale = Root.Scale * 0.9
	Kit.Tween(scale, 0.2, { Scale = Root.Scale }, Enum.EasingStyle.Back)
	ShopController.Refresh()
end

function ShopController.Close()
	refs.Layer.Visible = false
	selectedSlot = nil
end

function ShopController.Toggle()
	if refs.Layer.Visible then
		ShopController.Close()
	else
		ShopController.Open()
	end
end

function ShopController.IsOpen(): boolean
	return refs.Layer ~= nil and refs.Layer.Visible
end

function ShopController.Init(screen: Instance)
	build(screen)
	State.ProfileChanged.Event:Connect(ShopController.Refresh)
	game:GetService("Players").LocalPlayer:GetAttributeChangedSignal("MatchId"):Connect(function()
		if State.InMatch() then
			ShopController.Close()
		end
	end)
	ShopController.Refresh()
end

return ShopController
