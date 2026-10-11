--[[
	Грядка: выбор семени для посадки или статус роста. Открывается подсказкой у грядки.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Foods = require(Shared.Config.Foods)
local Format = require(Shared.Logic.Format)

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Router)
local State = require(script.Parent.Parent.State)

local C = Kit.Theme.Colors

local FarmPanel = {}

local panel: Kit.Panel
local list: ScrollingFrame
local status: TextLabel
local progress: Kit.Progress
local rows: { [string]: any } = {}
local emptyLabel: TextLabel
local slot = 1

function FarmPanel:Refresh()
	if not panel.Root.Visible then
		return
	end
	local profile = State.Profile()
	if not profile then
		return
	end
	local record = profile.farm[tostring(slot)]
	local now = State.Now()
	list.Visible = record == nil
	progress.Frame.Visible = record ~= nil
	if record then
		local food = Foods.ById[record.seed]
		local remaining = record.readyAt - now
		if remaining <= 0 then
			status.Text = string.format("%s %s готов! Нажми [E] у грядки", food.Icon, food.Name)
			progress:Set(1, "Готово")
		else
			status.Text = string.format("%s %s растёт", food.Icon, food.Name)
			progress:Set(1 - remaining / (record.readyAt - record.plantedAt), Format.Time(remaining))
		end
		return
	end
	status.Text = string.format("Грядка %d — выбери семя", slot)
	local any = false
	for _, food in Foods.List do
		local row = rows[food.Id]
		if row then
			local count = profile.seeds[food.Id] or 0
			row.Frame.Visible = count > 0
			row.Count.Text = "x" .. count
			any = any or count > 0
		end
	end
	emptyLabel.Visible = not any
end

function FarmPanel:Build(screen: ScreenGui)
	panel = Kit.Panel(screen, "Garden", Vector2.new(560, 520), Color3.fromRGB(150, 100, 60))
	panel.Close.Activated:Connect(function()
		Router.Close()
	end)
	status = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 34), MaxTextSize = 28, Parent = panel.Body })
	progress = Kit.Progress(panel.Body, C.Green, UDim2.new(1, -40, 0, 36), UDim2.fromOffset(20, 60))
	local holder = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -44), Position = UDim2.fromOffset(0, 44), Parent = panel.Body })
	list = Kit.Scroll(holder, "list", nil, 8)
	for order, food in Foods.List do
		if food.Seed then
			local frame = Kit.Create("Frame", { BackgroundColor3 = C.PanelInner, Size = UDim2.new(1, -8, 0, 72), LayoutOrder = order, Parent = list })
			Kit.Corner(frame, 8)
			Kit.Stroke(frame, 3, C.Black, true)
			Kit.Text({ Text = "🌱" .. food.Icon, Size = UDim2.fromOffset(80, 56), Position = UDim2.fromOffset(6, 8), Stroke = false, Parent = frame })
			Kit.Text({ Text = food.Name, Size = UDim2.fromOffset(220, 30), Position = UDim2.fromOffset(92, 6),
				TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 26, Parent = frame })
			Kit.Text({ Text = string.format("⏱ %s • урожай x%d", Format.Time(food.Seed.GrowTime), food.Seed.Yield),
				Size = UDim2.fromOffset(240, 22), Position = UDim2.fromOffset(94, 40), TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.Yellow, MaxTextSize = 20, Parent = frame })
			local count = Kit.Text({ Text = "", Size = UDim2.fromOffset(60, 30), Position = UDim2.new(1, -210, 0, 20), MaxTextSize = 26, Parent = frame })
			Kit.Button({ Text = "Plant", Color = "Green", Size = UDim2.fromOffset(130, 56), Position = UDim2.new(1, -140, 0, 8), TextSize = 28,
				Parent = frame, OnClick = function()
					State.Fire("Plant", { slot = slot, seed = food.Id }, function(ok)
						if ok then
							Router.Close()
						end
					end)
				end })
			rows[food.Id] = { Frame = frame, Count = count }
		end
	end
	emptyLabel = Kit.Text({ Text = "Нет семян. Купи их во вкладке Seeds магазина.", Size = UDim2.new(1, -20, 0, 60),
		TextWrapped = true, MaxTextSize = 24, LayoutOrder = 999, Parent = list })
	Kit.Button({ Text = "🛒 Семена", Color = "Blue", Size = UDim2.fromOffset(220, 54), LayoutOrder = 1000, TextSize = 26,
		Parent = list, OnClick = function()
			Router.Open("Shop", "Seeds")
		end })

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.5 and panel.Root.Visible then
			accumulator = 0
			FarmPanel:Refresh()
		end
	end)
end

function FarmPanel:Open(farmSlot: number?)
	slot = farmSlot or slot
	Router.ShowPanel(panel)
	FarmPanel:Refresh()
end

function FarmPanel:Close()
	Router.HidePanel(panel)
end

return FarmPanel
