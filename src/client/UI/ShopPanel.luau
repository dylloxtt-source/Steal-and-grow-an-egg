--[[
	Магазин: вкладки Eggs / Food / Seeds / Upgrades / Sell справа от окна (как на референсе).
	Карточки яиц показывают шансы существ (нормализованные веса из конфига).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Creatures = require(Shared.Config.Creatures)
local Foods = require(Shared.Config.Foods)
local Rarities = require(Shared.Config.Rarities)
local Upgrades = require(Shared.Config.Upgrades)
local Format = require(Shared.Logic.Format)
local Economy = require(Shared.Logic.Economy)
local Growth = require(Shared.Logic.Growth)
local WeightedRandom = require(Shared.Logic.WeightedRandom)

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Router)
local Preview = require(script.Parent.Preview)
local State = require(script.Parent.Parent.State)

local C = Kit.Theme.Colors

local ShopPanel = {}

local panel: Kit.Panel
local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Eggs"
local dynamic: { () -> () } = {} -- функции обновления цен/количеств
local eggDynamic: { () -> () } = {}
local sellCards: { [string]: Frame } = {}
local sellConfirm: { [string]: boolean } = {}

local TABS = {
	{ Id = "Eggs", Icon = "🥚", Order = 1 },
	{ Id = "Food", Icon = "🍎", Order = 2 },
	{ Id = "Seeds", Icon = "🌱", Order = 3 },
	{ Id = "Upgrades", Icon = "⬆️", Order = 4 },
	{ Id = "Sell", Icon = "💰", Order = 5 },
}

local function priceButton(parent: Instance, price: number?, size: UDim2, position: UDim2, onClick: () -> ()): TextButton
	local button = Kit.Button({
		Text = if price then "💵 " .. Format.Number(price) else "—",
		Color = "Green",
		Size = size,
		Position = position,
		TextSize = 30,
		OnClick = onClick,
		Parent = parent,
	})
	return button
end

local function setAffordable(button: TextButton, price: number?)
	local profile = State.Profile()
	local ok = profile and price and profile.coins >= price
	Kit.SetButtonColor(button, if ok then "Green" else "Grey")
end

------------------------------------------------------------------------
-- Вкладки
------------------------------------------------------------------------

local function buildEggs(page: ScrollingFrame)
	Kit.SectionTitle(page, "EGGS", C.Yellow, 0)
	for order, egg in Eggs.List do
		local rarity = Rarities.ById[egg.Rarity]
		local card = Kit.Card(page, rarity.Color, rarity.DarkColor, order)
		card.Size = UDim2.new(1, -8, 0, 210)

		Preview.Egg(egg.Id, card, UDim2.fromOffset(150, 150), UDim2.fromOffset(10, 30))
		Kit.Text({
			Text = string.upper(egg.Name), Size = UDim2.fromOffset(420, 44), Position = UDim2.fromOffset(170, 8),
			TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3.5, MaxTextSize = 40,
			Gradient = { C.White, Color3.fromRGB(255, 230, 150) }, Parent = card,
		})
		Kit.Text({
			Text = string.format("%s  •  ⏱ %s  •  %s", rarity.Name, Format.Time(egg.HatchTime), egg.Source),
			Size = UDim2.fromOffset(520, 26), Position = UDim2.fromOffset(172, 52),
			TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, Parent = card,
		})

		-- Шансы существ
		local entries = {}
		for _, entry in egg.Creatures do
			table.insert(entries, { Item = entry.Creature, Weight = entry.Weight })
		end
		local chances = WeightedRandom.Chances(entries)
		local row = Kit.Create("Frame", {
			BackgroundTransparency = 1, Size = UDim2.fromOffset(470, 116), Position = UDim2.fromOffset(170, 84), Parent = card,
		})
		Kit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = row })
		for i, entry in egg.Creatures do
			local def = Creatures.ById[entry.Creature]
			local slot = Kit.Create("Frame", {
				BackgroundColor3 = C.Black, BackgroundTransparency = 0.45, Size = UDim2.fromOffset(104, 112), LayoutOrder = i, Parent = row,
			})
			Kit.Corner(slot, 6)
			Kit.Stroke(slot, 2.5, C.Black, true)
			local profile = State.Profile()
			local known = profile and profile.index[def.Id]
			Preview.Creature(def.Id, nil, slot, UDim2.fromOffset(96, 76), UDim2.fromOffset(4, 2), not known)
			Kit.Text({ Text = if known then def.Name else "???", Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 76),
				MaxTextSize = 15, Parent = slot })
			Kit.Text({ Text = Format.Percent(chances[i]), Size = UDim2.new(1, -6, 0, 20), Position = UDim2.fromOffset(3, 90),
				TextColor3 = if Rarities.ById[def.Rarity].Order > rarity.Order then C.Yellow else C.White, MaxTextSize = 20, Parent = slot })
		end

		if egg.Price then
			local button = priceButton(card, egg.Price, UDim2.fromOffset(170, 62), UDim2.new(1, -184, 1, -76), function()
				State.Fire("Buy", { category = "egg", id = egg.Id, amount = 1 })
			end)
			table.insert(eggDynamic, function()
				setAffordable(button, egg.Price)
			end)
		else
			Kit.Text({ Text = "Только на дорожке!", Size = UDim2.fromOffset(180, 50), Position = UDim2.new(1, -190, 1, -70),
				TextColor3 = C.Pink, MaxTextSize = 24, Parent = card })
		end
	end
end

local function foodCard(page: ScrollingFrame, food: any, order: number, seed: boolean)
	local card = Kit.Card(page, Color3.fromRGB(70, 60, 110), Color3.fromRGB(40, 34, 70), order)
	Kit.Text({ Text = food.Icon, Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 8), Stroke = false, MaxTextSize = 64, Parent = card })
	Kit.Text({ Text = food.Name .. (if seed then " Seed" else ""), Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 80),
		MaxTextSize = 24, Parent = card })
	local info
	if seed then
		info = string.format("⏱ %s  •  x%d урожай", Format.Time(food.Seed.GrowTime), food.Seed.Yield)
	elseif food.IgnoresFullness then
		info = string.format("+%s роста (даже сытым)", Format.Number(food.Growth))
	else
		info = string.format("🍖+%d  ✨+%s", food.Fullness, Format.Number(food.Growth))
	end
	Kit.Text({ Text = info, Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 108), TextColor3 = C.Yellow,
		MaxTextSize = 18, Parent = card })
	local owned = Kit.Text({ Text = "", Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 130), MaxTextSize = 18, Parent = card })
	local price = if seed then food.Seed.Price else food.BuyPrice
	local buy1 = priceButton(card, price, UDim2.new(0.62, -8, 0, 50), UDim2.new(0, 6, 1, -58), function()
		State.Fire("Buy", { category = if seed then "seed" else "food", id = food.Id, amount = 1 })
	end)
	local buy5 = Kit.Button({ Text = "x5", Color = "Blue", Size = UDim2.new(0.38, -6, 0, 50), Position = UDim2.new(0.62, 0, 1, -58),
		TextSize = 26, Parent = card, OnClick = function()
			State.Fire("Buy", { category = if seed then "seed" else "food", id = food.Id, amount = 5 })
		end })
	table.insert(dynamic, function()
		local profile = State.Profile()
		if not profile then
			return
		end
		local count = if seed then profile.seeds[food.Id] else profile.food[food.Id]
		owned.Text = "У тебя: " .. tostring(count or 0)
		setAffordable(buy1, price)
		Kit.SetButtonColor(buy5, if profile.coins >= price * 5 then "Blue" else "Grey")
	end)
end

local function buildFood(page: ScrollingFrame)
	local order = 0
	for _, food in Foods.List do
		if food.BuyPrice then
			order += 1
			foodCard(page, food, order, false)
		end
	end
end

local function buildSeeds(page: ScrollingFrame)
	local order = 0
	for _, food in Foods.List do
		if food.Seed then
			order += 1
			foodCard(page, food, order, true)
		end
	end
end

local function buildUpgrades(page: ScrollingFrame)
	Kit.SectionTitle(page, "BASE UPGRADES", C.Blue, 0)
	for order, upgrade in Upgrades.List do
		local card = Kit.Card(page, Color3.fromRGB(40, 110, 200), Color3.fromRGB(20, 50, 120), order)
		card.Size = UDim2.new(1, -8, 0, 92)
		Kit.Text({ Text = upgrade.Icon, Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(10, 11), Stroke = false, Parent = card })
		Kit.Text({ Text = upgrade.Name, Size = UDim2.fromOffset(380, 38), Position = UDim2.fromOffset(90, 8),
			TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 34, Parent = card })
		local describe = Kit.Text({ Text = "", Size = UDim2.fromOffset(420, 28), Position = UDim2.fromOffset(92, 52),
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Yellow, MaxTextSize = 24, Parent = card })
		local button = priceButton(card, 0, UDim2.fromOffset(190, 64), UDim2.new(1, -204, 0, 12), function()
			State.Fire("Upgrade", { id = upgrade.Id })
		end)
		local label = button:FindFirstChild("Face"):FindFirstChild("Label") :: TextLabel
		table.insert(dynamic, function()
			local profile = State.Profile()
			if not profile then
				return
			end
			local level = profile.upgrades[upgrade.Id]
			local cost = Economy.UpgradeCost(upgrade.Id, level)
			if cost then
				describe.Text = upgrade.Describe(level)
				label.Text = "💵 " .. Format.Number(cost)
				setAffordable(button, cost)
			else
				describe.Text = "Максимальный уровень"
				label.Text = "MAX"
				Kit.SetButtonColor(button, "Yellow")
			end
		end)
	end
end

local function refreshSell(page: ScrollingFrame)
	local profile = State.Profile()
	if not profile then
		return
	end
	local seen = {}
	for uid, creature in profile.creatures do
		seen[uid] = true
		local def = Creatures.ById[creature.species]
		local stage = Growth.Stage(creature)
		local card = sellCards[uid]
		if card and card:GetAttribute("Stage") ~= stage then
			card:Destroy()
			card = nil
		end
		if not card then
			local rarity = Rarities.ById[def.Rarity]
			card = Kit.Card(page, rarity.Color, rarity.DarkColor, -rarity.Order)
			card:SetAttribute("Stage", stage)
			Preview.Creature(def.Id, { Stage = stage, Mutation = creature.mutation }, card, UDim2.new(1, 0, 0, 100), UDim2.fromOffset(0, 4))
			Kit.Text({ Text = def.Name, Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(5, 104), MaxTextSize = 22, Parent = card })
			Kit.Text({ Text = stage .. (if creature.mutation ~= "None" then " • " .. creature.mutation else ""),
				Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 128), TextColor3 = C.Yellow, MaxTextSize = 16, Parent = card })
			local value = Growth.SellValue(creature)
			local button, label = Kit.Button({ Text = "💰 " .. Format.Number(value), Color = "Red", Size = UDim2.new(1, -12, 0, 50),
				Position = UDim2.new(0, 6, 1, -56), TextSize = 26, Parent = card })
			button.Activated:Connect(function()
				if sellConfirm[uid] then
					sellConfirm[uid] = nil
					State.Fire("Sell", { uid = uid })
				else
					sellConfirm[uid] = true
					label.Text = "Точно?"
					task.delay(2.5, function()
						if sellConfirm[uid] then
							sellConfirm[uid] = nil
							label.Text = "💰 " .. Format.Number(value)
						end
					end)
				end
			end)
			sellCards[uid] = card
		end
	end
	for uid, card in sellCards do
		if not seen[uid] then
			card:Destroy()
			sellCards[uid] = nil
		end
	end
end

local function showTab(id: string)
	currentTab = id
	for tabId, page in pages do
		page.Visible = tabId == id
		Kit.SetTabActive(tabButtons[tabId], tabId == id)
	end
	ShopPanel:Refresh()
end

function ShopPanel:Build(screen: ScreenGui)
	panel = Kit.Panel(screen, "Shop", Vector2.new(900, 580))
	panel.Close.Activated:Connect(function()
		Router.Close()
	end)
	for _, tab in TABS do
		local isGrid = tab.Id == "Food" or tab.Id == "Seeds" or tab.Id == "Sell"
		local page = Kit.Scroll(panel.Body, if isGrid then "grid" else "list", UDim2.fromOffset(196, 240), 12)
		page.Visible = false
		pages[tab.Id] = page
		tabButtons[tab.Id] = Kit.Tab(panel, tab.Icon, tab.Id, tab.Order, function()
			showTab(tab.Id)
		end)
	end
	buildFood(pages.Food)
	buildSeeds(pages.Seeds)
	buildUpgrades(pages.Upgrades)
	-- Яйца строим при первом открытии: превью шансов зависят от индекса игрока
end

local eggsBuiltFor = -1

local function discoveredCount(): number
	local profile = State.Profile()
	local count = 0
	if profile then
		for _ in profile.index do
			count += 1
		end
	end
	return count
end

function ShopPanel:Open(tab: string?)
	local discovered = discoveredCount()
	if State.Profile() and eggsBuiltFor ~= discovered then
		eggsBuiltFor = discovered
		for _, child in pages.Eggs:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(eggDynamic)
		buildEggs(pages.Eggs)
	end
	Router.ShowPanel(panel)
	showTab(tab or currentTab)
end

function ShopPanel:Close()
	Router.HidePanel(panel)
end

function ShopPanel:Refresh()
	if not panel.Root.Visible then
		return
	end
	for _, update in dynamic do
		update()
	end
	for _, update in eggDynamic do
		update()
	end
	if currentTab == "Sell" then
		refreshSell(pages.Sell)
	end
end

return ShopPanel
