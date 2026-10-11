--[[
	Окно питомцев: слева сетка существ, справа подробности выбранного —
	стадия, размер, мутация, доход, сытость, рост до следующей стадии, черта,
	кнопки Feed / В загон / В хранилище / Продать.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Game = require(Shared.Config.Game)
local Format = require(Shared.Logic.Format)
local Growth = require(Shared.Logic.Growth)

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Router)
local Preview = require(script.Parent.Preview)
local State = require(script.Parent.Parent.State)

local C = Kit.Theme.Colors

local PetsPanel = {}

local panel: Kit.Panel
local grid: ScrollingFrame
local cards: { [string]: any } = {}
local selected: string? = nil
local detail: any = {}
local sellArmed = false

-- Оценка текущей сытости между снимками сервера
function PetsPanel.EstimateFullness(creature: any): number
	if not creature.placed then
		return creature.fullness
	end
	local elapsed = State.Now() - creature.lastTick
	return math.max(0, creature.fullness - Growth.DecayPerSecond(creature.species) * math.max(0, elapsed))
end

local function card(uid: string, creature: any): any
	local def = Creatures.ById[creature.species]
	local stage = Growth.Stage(creature)
	local existing = cards[uid]
	if existing and existing.Stage == stage then
		return existing
	end
	if existing then
		existing.Frame:Destroy()
	end
	local rarity = Rarities.ById[def.Rarity]
	local frame = Kit.Card(grid, rarity.Color, rarity.DarkColor, 0)
	local button = Kit.Create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = frame })
	Preview.Creature(def.Id, { Stage = stage, Mutation = creature.mutation }, frame, UDim2.new(1, 0, 0, 92), UDim2.fromOffset(0, 4))
	Kit.Text({ Text = def.Name, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 96), MaxTextSize = 20, Parent = frame })
	local tag = Kit.Text({ Text = "", Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 118), MaxTextSize = 15,
		TextColor3 = C.Yellow, Parent = frame })
	local hunger = Kit.Progress(frame, C.Orange, UDim2.new(1, -16, 0, 14), UDim2.new(0, 8, 1, -22))
	local entry = { Frame = frame, Stage = stage, Tag = tag, Hunger = hunger }
	button.Activated:Connect(function()
		selected = uid
		sellArmed = false
		PetsPanel:Refresh()
	end)
	cards[uid] = entry
	return entry
end

local function updateDetail(creature: any?)
	detail.Root.Visible = creature ~= nil
	if not creature then
		return
	end
	local def = Creatures.ById[creature.species]
	local rarity = Rarities.ById[def.Rarity]
	local stage = Growth.Stage(creature)
	local key = creature.uid .. stage .. creature.mutation
	if detail.Key ~= key then
		detail.Key = key
		if detail.Viewport then
			detail.Viewport:Destroy()
		end
		detail.Viewport = Preview.Creature(def.Id, { Stage = stage, Mutation = creature.mutation }, detail.Root,
			UDim2.new(1, -20, 0, 150), UDim2.fromOffset(10, 6))
	end
	detail.Name.Text = def.Name
	detail.Name.TextColor3 = if def.Rarity == "Secret" then C.Pink else rarity.Color
	local mutation = if creature.mutation ~= "None" then creature.mutation .. " • " else ""
	detail.Info.Text = string.format("%s • %s%s • %s", rarity.Name, mutation, creature.sizeId, stage)
	local runtime = State.Runtime()
	local bonus = runtime.bonuses and runtime.bonuses.Income or 0
	local fullness = PetsPanel.EstimateFullness(creature)
	local income = Growth.IncomePerSecond(creature, bonus) * (if fullness <= 0 then Game.Growth.HungryIncomeMult else 1)
	detail.Income.Text = if creature.placed then "💵 " .. Format.Money(income) .. "/s" else "💤 В хранилище (не растёт)"
	detail.Hunger:Set(fullness / Game.Growth.FullnessMax, string.format("🍖 Сытость %d%%", math.floor(fullness)))
	local progress, nextStage = Growth.Progress(creature)
	if nextStage == "Ascended" then
		detail.Growth:Set(1, "⭐ Нужен Starfruit → Ascended")
	elseif nextStage then
		detail.Growth:Set(progress, string.format("✨ До %s: %d%%", nextStage, math.floor(progress * 100)))
	else
		detail.Growth:Set(1, "👑 Максимальная стадия")
	end
	detail.Trait.Text = if def.Trait then "Черта (Adult+): " .. def.Trait.Text else def.Description
	detail.PlaceLabel.Text = if creature.placed then "📦 Store" else "🏠 Place"
	detail.SellLabel.Text = if sellArmed then "Точно?" else "💰 " .. Format.Number(Growth.SellValue(creature))
end

function PetsPanel:Refresh()
	if not panel.Root.Visible then
		return
	end
	local profile = State.Profile()
	if not profile then
		return
	end
	local seen = {}
	local placed, total = 0, 0
	for uid, creature in profile.creatures do
		seen[uid] = true
		total += 1
		if creature.placed then
			placed += 1
		end
		local entry = card(uid, creature)
		local def = Creatures.ById[creature.species]
		local rarity = Rarities.ById[def.Rarity]
		entry.Frame.LayoutOrder = (if creature.placed then 0 else 1000) - rarity.Order * 10
		entry.Tag.Text = (if creature.placed then "🏠 " else "📦 ") .. Growth.Stage(creature)
		local fullness = PetsPanel.EstimateFullness(creature)
		entry.Hunger:Set(fullness / Game.Growth.FullnessMax, "")
		local stroke = entry.Frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if uid == selected then C.Yellow else C.Black
			stroke.Thickness = if uid == selected then 5 else 3
		end
	end
	for uid, entry in cards do
		if not seen[uid] then
			entry.Frame:Destroy()
			cards[uid] = nil
		end
	end
	if selected and not profile.creatures[selected] then
		selected = nil
	end
	if not selected then
		selected = next(profile.creatures)
	end
	panel.Title.Text = string.format("Pets  %d/%d 🏠  •  %d всего", placed, profile.upgrades.pens, total)
	updateDetail(if selected then profile.creatures[selected] else nil)
	detail.Empty.Visible = total == 0
end

function PetsPanel:Build(screen: ScreenGui)
	panel = Kit.Panel(screen, "Pets", Vector2.new(960, 600), C.Orange)
	panel.Close.Activated:Connect(function()
		Router.Close()
	end)
	local left = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -350, 1, 0), Parent = panel.Body })
	grid = Kit.Scroll(left, "grid", UDim2.fromOffset(150, 160), 10)

	local root = Kit.Create("Frame", {
		BackgroundColor3 = C.PanelInner, Size = UDim2.new(0, 340, 1, 0), Position = UDim2.new(1, -340, 0, 0), Parent = panel.Body,
	})
	Kit.Corner(root, 8)
	Kit.Stroke(root, 3, C.Black, true)
	detail.Root = root
	detail.Name = Kit.Text({ Text = "", Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 156), MaxTextSize = 34, Parent = root })
	detail.Info = Kit.Text({ Text = "", Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 192), MaxTextSize = 20, Parent = root })
	detail.Income = Kit.Text({ Text = "", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 216), TextColor3 = C.Money, MaxTextSize = 24, Parent = root })
	detail.Hunger = Kit.Progress(root, C.Orange, UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 248))
	detail.Growth = Kit.Progress(root, C.Purple, UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 282))
	detail.Trait = Kit.Text({ Text = "", Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 312), MaxTextSize = 18,
		TextWrapped = true, TextColor3 = C.Yellow, Parent = root })

	Kit.Button({ Text = "🍖 Feed", Color = "Green", Size = UDim2.new(1, -24, 0, 54), Position = UDim2.fromOffset(12, 358), TextSize = 30,
		Parent = root, OnClick = function()
			if selected then
				Router.Open("Feed", selected)
			end
		end })
	local _, placeLabel = Kit.Button({ Text = "🏠 Place", Color = "Blue", Size = UDim2.new(0.5, -16, 0, 54), Position = UDim2.fromOffset(12, 420),
		TextSize = 26, Parent = root, OnClick = function()
			local profile = State.Profile()
			local creature = profile and selected and profile.creatures[selected]
			if creature then
				State.Fire(if creature.placed then "Store" else "Place", { uid = creature.uid })
			end
		end })
	detail.PlaceLabel = placeLabel
	local _, sellLabel = Kit.Button({ Text = "💰", Color = "Red", Size = UDim2.new(0.5, -16, 0, 54), Position = UDim2.new(0.5, 4, 0, 420),
		TextSize = 26, Parent = root, OnClick = function()
			if not selected then
				return
			end
			if sellArmed then
				sellArmed = false
				State.Fire("Sell", { uid = selected })
			else
				sellArmed = true
				PetsPanel:Refresh()
				task.delay(2.5, function()
					sellArmed = false
					PetsPanel:Refresh()
				end)
			end
		end })
	detail.SellLabel = sellLabel
	detail.Empty = Kit.Text({ Text = "Питомцев пока нет — вылупи яйцо!", Size = UDim2.new(1, -350, 0, 60), Position = UDim2.fromOffset(0, 200),
		MaxTextSize = 28, Visible = false, Parent = panel.Body })

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 1 and panel.Root.Visible then
			accumulator = 0
			PetsPanel:Refresh()
		end
	end)
end

function PetsPanel:Open(uid: string?)
	if uid then
		selected = uid
	end
	Router.ShowPanel(panel)
	PetsPanel:Refresh()
end

function PetsPanel:Close()
	Router.HidePanel(panel)
end

return PetsPanel
