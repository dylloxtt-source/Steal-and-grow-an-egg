--[[
	Индекс: коллекция всех существ. Неоткрытые показаны силуэтами.
	Каждое открытие даёт +2% к доходу базы навсегда (Game.Index).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Game = require(Shared.Config.Game)
local Format = require(Shared.Logic.Format)

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Router)
local Preview = require(script.Parent.Preview)
local State = require(script.Parent.Parent.State)

local C = Kit.Theme.Colors

local IndexPanel = {}

local panel: Kit.Panel
local grid: ScrollingFrame
local summary: TextLabel
local cards: { [string]: any } = {}

local function buildCard(def: any, known: boolean, order: number)
	local old = cards[def.Id]
	if old and old.Known == known then
		return
	end
	if old then
		old.Frame:Destroy()
	end
	local rarity = Rarities.ById[def.Rarity]
	local frame = if known then Kit.Card(grid, rarity.Color, rarity.DarkColor, order)
		else Kit.Card(grid, Color3.fromRGB(70, 70, 80), Color3.fromRGB(40, 40, 46), order)
	Preview.Creature(def.Id, nil, frame, UDim2.new(1, 0, 0, 104), UDim2.fromOffset(0, 4), not known)
	Kit.Text({ Text = if known then def.Name else "???", Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 108), MaxTextSize = 22, Parent = frame })
	Kit.Text({ Text = rarity.Name, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 132), MaxTextSize = 16,
		TextColor3 = if def.Rarity == "Secret" then C.Pink else rarity.Color, Parent = frame })
	Kit.Text({ Text = if known then "💵 " .. Format.Number(def.BaseIncome) .. "/s" else "Найди в яйце",
		Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 152), MaxTextSize = 16, TextColor3 = C.Money, Parent = frame })
	cards[def.Id] = { Frame = frame, Known = known }
end

function IndexPanel:Refresh()
	if not panel.Root.Visible then
		return
	end
	local profile = State.Profile()
	if not profile then
		return
	end
	local found = 0
	for order, def in Creatures.List do
		local known = profile.index[def.Id] == true
		if known then
			found += 1
		end
		buildCard(def, known, order)
	end
	summary.Text = string.format("Открыто %d/%d  •  Бонус дохода +%d%%", found, #Creatures.List,
		math.floor(found * Game.Index.IncomeBonusPerSpecies * 100 + 0.5))
end

function IndexPanel:Build(screen: ScreenGui)
	panel = Kit.Panel(screen, "Index", Vector2.new(900, 580), C.Blue)
	panel.Close.Activated:Connect(function()
		Router.Close()
	end)
	summary = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 34), TextColor3 = C.Yellow, MaxTextSize = 30, Parent = panel.Body })
	local holder = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -40), Position = UDim2.fromOffset(0, 40), Parent = panel.Body })
	grid = Kit.Scroll(holder, "grid", UDim2.fromOffset(150, 176), 10)
end

function IndexPanel:Open()
	Router.ShowPanel(panel)
	IndexPanel:Refresh()
end

function IndexPanel:Close()
	Router.HidePanel(panel)
end

return IndexPanel
