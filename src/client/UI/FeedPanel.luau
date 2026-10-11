--[[
	Кормление: список еды из инвентаря для выбранного существа.
	Открывается кнопкой Feed в окне питомцев или подсказкой «Feed» в загоне.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Foods = require(Shared.Config.Foods)
local Game = require(Shared.Config.Game)
local Format = require(Shared.Logic.Format)
local Growth = require(Shared.Logic.Growth)

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Router)
local State = require(script.Parent.Parent.State)

local C = Kit.Theme.Colors

local FeedPanel = {}

local panel: Kit.Panel
local list: ScrollingFrame
local hunger: Kit.Progress
local growth: Kit.Progress
local title: TextLabel
local emptyLabel: TextLabel
local target: string? = nil
local rows: { [string]: any } = {}

local function estimate(creature: any): number
	if not creature.placed then
		return creature.fullness
	end
	return math.max(0, creature.fullness - Growth.DecayPerSecond(creature.species) * math.max(0, State.Now() - creature.lastTick))
end

function FeedPanel:Refresh()
	if not panel.Root.Visible then
		return
	end
	local profile = State.Profile()
	local creature = profile and target and profile.creatures[target]
	if not creature then
		Router.Close()
		return
	end
	local def = Creatures.ById[creature.species]
	local stage = Growth.Stage(creature)
	title.Text = string.format("%s • %s", def.Name, stage)
	local fullness = estimate(creature)
	hunger:Set(fullness / Game.Growth.FullnessMax, string.format("🍖 %d%%", math.floor(fullness)))
	local progress, nextStage = Growth.Progress(creature)
	growth:Set(progress, if nextStage then "✨ → " .. nextStage else "👑 MAX")

	local any = false
	for order, food in Foods.List do
		local count = profile.food[food.Id] or 0
		local row = rows[food.Id]
		row.Frame.Visible = count > 0
		row.Frame.LayoutOrder = order
		if count > 0 then
			any = true
			row.Count.Text = "x" .. count
			local blocked = not food.IgnoresFullness and fullness >= Game.Growth.FeedBlockAt and not (food.Catalyst and stage == "Adult")
			Kit.SetButtonColor(row.Button, if blocked then "Grey" else "Green")
			row.Hint.Text = if food.Catalyst and stage == "Adult" then "⭐ Превратит в Ascended!"
				elseif food.IgnoresFullness then string.format("+%s роста", Format.Number(food.Growth))
				else string.format("🍖+%d  ✨+%s", food.Fullness, Format.Number(food.Growth))
		end
	end
	emptyLabel.Visible = not any
end

function FeedPanel:Build(screen: ScreenGui)
	panel = Kit.Panel(screen, "Feed", Vector2.new(560, 560), C.Green)
	panel.Close.Activated:Connect(function()
		Router.Close()
	end)
	title = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 34), MaxTextSize = 30, Parent = panel.Body })
	hunger = Kit.Progress(panel.Body, C.Orange, UDim2.new(0.5, -6, 0, 28), UDim2.fromOffset(0, 40))
	growth = Kit.Progress(panel.Body, C.Purple, UDim2.new(0.5, -6, 0, 28), UDim2.new(0.5, 6, 0, 40))
	local holder = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -80), Position = UDim2.fromOffset(0, 80), Parent = panel.Body })
	list = Kit.Scroll(holder, "list", nil, 8)
	for _, food in Foods.List do
		local frame = Kit.Create("Frame", { BackgroundColor3 = C.PanelInner, Size = UDim2.new(1, -8, 0, 72), Visible = false, Parent = list })
		Kit.Corner(frame, 8)
		Kit.Stroke(frame, 3, C.Black, true)
		Kit.Text({ Text = food.Icon, Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(8, 6), Stroke = false, Parent = frame })
		Kit.Text({ Text = food.Name, Size = UDim2.fromOffset(240, 30), Position = UDim2.fromOffset(76, 6),
			TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 26, Parent = frame })
		local hint = Kit.Text({ Text = "", Size = UDim2.fromOffset(260, 22), Position = UDim2.fromOffset(78, 40),
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Yellow, MaxTextSize = 20, Parent = frame })
		local count = Kit.Text({ Text = "", Size = UDim2.fromOffset(70, 30), Position = UDim2.new(1, -220, 0, 20), MaxTextSize = 26, Parent = frame })
		local button = Kit.Button({ Text = "Feed", Color = "Green", Size = UDim2.fromOffset(130, 56), Position = UDim2.new(1, -140, 0, 8),
			TextSize = 28, Parent = frame, OnClick = function()
				if target then
					State.Fire("Feed", { uid = target, food = food.Id })
				end
			end })
		rows[food.Id] = { Frame = frame, Hint = hint, Count = count, Button = button }
	end
	emptyLabel = Kit.Text({ Text = "Нет еды! Подбирай её на дорожке, выращивай на грядках или купи в магазине.",
		Size = UDim2.new(1, -20, 0, 90), TextWrapped = true, MaxTextSize = 24, LayoutOrder = 999, Parent = list })
	Kit.Button({ Text = "🛒 Купить еду", Color = "Blue", Size = UDim2.fromOffset(240, 54), LayoutOrder = 1000, TextSize = 26,
		Parent = list, OnClick = function()
			Router.Open("Shop", "Food")
		end })
end

function FeedPanel:Open(uid: string?)
	target = uid or target
	Router.ShowPanel(panel)
	FeedPanel:Refresh()
end

function FeedPanel:Close()
	Router.HidePanel(panel)
end

return FeedPanel
