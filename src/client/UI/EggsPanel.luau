--[[
	Окно «Growing Eggs» (по референсу): инкубаторы с прогрессом и кнопками
	Hatch / Skip, ниже — яйца в инвентаре с кнопкой Incubate. «Hatch All» в шапке.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Logic.Format)
local Economy = require(Shared.Logic.Economy)

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Router)
local Preview = require(script.Parent.Preview)
local State = require(script.Parent.Parent.State)

local C = Kit.Theme.Colors

local EggsPanel = {}

local panel: Kit.Panel
local list: ScrollingFrame
local rows: { [string]: any } = {}
local incubatorTitle: TextLabel
local inventoryTitle: TextLabel
local emptyLabel: TextLabel

local function makeRow(key: string, eggId: string, order: number): any
	local egg = Eggs.ById[eggId]
	local rarity = Rarities.ById[egg.Rarity]
	local row = Kit.Create("Frame", {
		Name = key,
		BackgroundColor3 = C.PanelInner,
		Size = UDim2.new(1, -8, 0, 96),
		LayoutOrder = order,
		Parent = list,
	})
	Kit.Corner(row, 8)
	Kit.Stroke(row, 3, C.Black, true)
	local iconBg = Kit.Create("Frame", {
		BackgroundColor3 = rarity.Color, Size = UDim2.fromOffset(80, 80), Position = UDim2.fromOffset(8, 8), Parent = row,
	})
	Kit.Corner(iconBg, 8)
	Kit.Gradient(iconBg, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	Kit.Stroke(iconBg, 2.5, C.Black, true)
	Preview.Egg(eggId, iconBg, UDim2.fromScale(1, 1))
	local name = Kit.Text({ Text = egg.Name, Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(100, 8),
		TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 28, Parent = row })
	local sub = Kit.Text({ Text = rarity.Name, Size = UDim2.fromOffset(250, 22), Position = UDim2.fromOffset(100, 38),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if egg.Rarity == "Secret" then C.Pink else rarity.Color,
		MaxTextSize = 20, Parent = row })
	local progress = Kit.Progress(row, C.Yellow, UDim2.fromOffset(250, 24), UDim2.fromOffset(100, 64))
	local button, buttonLabel = Kit.Button({ Text = "Open", Color = "Green", Size = UDim2.fromOffset(150, 62),
		Position = UDim2.new(1, -162, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextSize = 30, Parent = row })
	return { Frame = row, Name = name, Sub = sub, Progress = progress, Button = button, Label = buttonLabel, Action = nil :: any }
end

local function rowFor(key: string, eggId: string, order: number): any
	local row = rows[key]
	if row and row.EggId ~= eggId then
		row.Frame:Destroy()
		row = nil
	end
	if not row then
		row = makeRow(key, eggId, order)
		row.EggId = eggId
		row.Button.Activated:Connect(function()
			if row.Action then
				row.Action()
			end
		end)
		rows[key] = row
	end
	row.Frame.LayoutOrder = order
	return row
end

local function updateIncubatorRow(row: any, slot: number, record: any, now: number)
	local remaining = record.startedAt + record.duration - now
	if record.transit then
		row.Progress:Set(0, "🚨 УКРАДЕНО")
		row.Label.Text = "—"
		Kit.SetButtonColor(row.Button, "Grey")
		row.Action = nil
	elseif remaining <= 0 then
		row.Progress:Set(1, "Готово!")
		row.Label.Text = "Open"
		Kit.SetButtonColor(row.Button, "Green")
		row.Action = function()
			State.Fire("Hatch", { slot = slot })
		end
	else
		row.Progress:Set(1 - remaining / record.duration, Format.Time(remaining))
		local cost = Economy.SkipCost(record.id, remaining, record.duration)
		row.Label.Text = "⏩ " .. Format.Number(cost)
		local profile = State.Profile()
		Kit.SetButtonColor(row.Button, if profile and profile.coins >= cost then "Orange" else "Grey")
		row.Action = function()
			State.Fire("SkipHatch", { slot = slot })
		end
	end
end

function EggsPanel:Refresh()
	if not panel.Root.Visible then
		return
	end
	local profile = State.Profile()
	if not profile then
		return
	end
	local now = State.Now()
	local seen = {}
	local order = 10
	local freeSlots = 0
	for slot = 1, profile.upgrades.incubators do
		local record = profile.incubators[tostring(slot)]
		if record then
			local key = "inc" .. slot
			seen[key] = true
			order += 1
			local row = rowFor(key, record.id, order)
			row.Sub.Text = "Инкубатор " .. slot
			updateIncubatorRow(row, slot, record, now)
		else
			freeSlots += 1
		end
	end
	incubatorTitle.Text = string.format("-- ИНКУБАТОРЫ (%d свободно) --", freeSlots)

	order = 100
	inventoryTitle.LayoutOrder = order
	for _, egg in profile.eggs do
		local key = "egg" .. egg.uid
		seen[key] = true
		order += 1
		local row = rowFor(key, egg.id, order)
		local def = Eggs.ById[egg.id]
		row.Sub.Text = Rarities.ById[def.Rarity].Name .. "  •  ⏱ " .. Format.Time(def.HatchTime)
		row.Progress.Frame.Visible = false
		row.Label.Text = "Incubate"
		Kit.SetButtonColor(row.Button, if freeSlots > 0 then "Blue" else "Grey")
		local uid = egg.uid
		row.Action = function()
			State.Fire("Incubate", { uid = uid })
		end
	end
	inventoryTitle.Visible = #profile.eggs > 0
	emptyLabel.Visible = #profile.eggs == 0 and freeSlots == profile.upgrades.incubators
	for key, row in rows do
		if not seen[key] then
			row.Frame:Destroy()
			rows[key] = nil
		end
	end
end

function EggsPanel:Build(screen: ScreenGui)
	panel = Kit.Panel(screen, "Growing Eggs", Vector2.new(600, 600), Color3.fromRGB(232, 201, 160))
	panel.Root.AnchorPoint = Vector2.new(1, 0.5)
	panel.Root.Position = UDim2.new(1, -120, 0.56, 0)
	panel.Close.Activated:Connect(function()
		Router.Close()
	end)
	local hatchAll = Kit.Button({ Text = "Hatch All", Color = "Orange", Size = UDim2.fromOffset(170, 54),
		Position = UDim2.new(1, -90, 0, 12), AnchorPoint = Vector2.new(1, 0), TextSize = 28, Parent = panel.Root,
		OnClick = function()
			State.Fire("HatchAll")
		end })
	hatchAll.ZIndex = 13
	panel.Title.Size = UDim2.new(0.5, 0, 1, -14)

	list = Kit.Scroll(panel.Body, "list", nil, 10)
	incubatorTitle = Kit.SectionTitle(list, "ИНКУБАТОРЫ", C.Yellow, 1)
	inventoryTitle = Kit.SectionTitle(list, "ИНВЕНТАРЬ", C.Blue, 100)
	emptyLabel = Kit.Text({ Text = "Яиц нет. Беги по дорожке и подбирай яйца [E] или купи в магазине!",
		Size = UDim2.new(1, -20, 0, 80), LayoutOrder = 200, MaxTextSize = 24, Parent = list })
	inventoryTitle.Visible = false

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.5 and panel.Root.Visible then
			accumulator = 0
			EggsPanel:Refresh()
		end
	end)
end

function EggsPanel:Open()
	Router.ShowPanel(panel)
	EggsPanel:Refresh()
end

function EggsPanel:Close()
	Router.HidePanel(panel)
end

return EggsPanel
