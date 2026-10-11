--[[
	Экран завершения матча: победа/поражение, достигнутая волна, личная статистика,
	награды (гемы, опыт, уровни), таблица команды и кнопка возврата в лобби.
	Если игрок ничего не нажал, сервер сам вернёт его в лобби по таймеру.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maps = require(Shared.Config.Maps)
local Format = require(Shared.Logic.Format)

local Kit = require(script.Parent.Parent.UI.Kit)
local Root = require(script.Parent.Parent.UI.Root)
local State = require(script.Parent.Parent.State)
local PlacementController = require(script.Parent.PlacementController)
local TowerController = require(script.Parent.TowerController)

local C = Kit.Theme.Colors

local ResultsController = {}

local refs: any = {}
local token = 0

local function tile(parent: Instance, order: number, title: string): TextLabel
	local frame = Kit.Create("Frame", { BackgroundColor3 = C.PanelLight, Size = UDim2.fromOffset(122, 58), LayoutOrder = order,
		BorderSizePixel = 0, Parent = parent })
	Kit.Corner(frame, 10)
	Kit.Text({ Text = title, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 8), TextSize = 12, TextColor3 = C.SubText,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = frame })
	return Kit.Text({ Text = "0", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 26), TextSize = 20, Weight = "Heavy",
		TextXAlignment = Enum.TextXAlignment.Center, Parent = frame })
end

local function build(layer: Instance)
	local dim = Kit.Create("Frame", { Name = "Results", BackgroundColor3 = C.Black, BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1),
		Visible = false, ZIndex = 40, Active = true, Parent = layer })
	refs.Dim = dim
	local panel = Root.Fit(Kit.Panel({ Name = "Panel", Size = UDim2.fromOffset(580, 520), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), Parent = dim }))
	Kit.Padding(panel, 18)
	refs.Title = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 44), TextSize = 40, Weight = "Heavy", Shadow = true,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = panel })
	refs.Subtitle = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 46), TextSize = 15,
		TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, Parent = panel })

	local tiles = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), Position = UDim2.fromOffset(0, 78), Parent = panel })
	Kit.List(tiles, 8, true, Enum.HorizontalAlignment.Center)
	refs.Kills = tile(tiles, 1, "Убийства")
	refs.Damage = tile(tiles, 2, "Урон")
	refs.Earned = tile(tiles, 3, "Заработано")
	refs.Towers = tile(tiles, 4, "Башен поставлено")

	local rewards = Kit.Create("Frame", { BackgroundColor3 = C.PanelLight, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 146),
		BorderSizePixel = 0, Parent = panel })
	Kit.Corner(rewards, 10)
	Kit.Padding(rewards, 6, 14)
	Kit.List(rewards, 22, true, Enum.HorizontalAlignment.Center)
	refs.Gems = Kit.Text({ Text = "", Size = UDim2.fromOffset(120, 30), TextSize = 22, Weight = "Heavy", TextColor3 = C.Gem,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = rewards })
	refs.Xp = Kit.Text({ Text = "", Size = UDim2.fromOffset(140, 30), TextSize = 20, Weight = "Heavy", TextColor3 = C.Accent,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = rewards })
	refs.LevelUp = Kit.Text({ Text = "", Size = UDim2.fromOffset(170, 30), TextSize = 17, Weight = "Heavy", TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Parent = rewards })

	Kit.Text({ Text = "КОМАНДА", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 210), TextSize = 13, Weight = "Heavy",
		TextColor3 = C.SubText, Parent = panel })
	local header = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 230), Parent = panel })
	local columns = { { "Игрок", 0, 0.4 }, { "Убийства", 0.4, 0.18 }, { "Урон", 0.58, 0.2 }, { "Заработано", 0.78, 0.22 } }
	for _, column in columns do
		Kit.Text({ Text = column[1], Size = UDim2.new(column[3], 0, 1, 0), Position = UDim2.fromScale(column[2], 0), TextSize = 12,
			TextColor3 = C.Muted, Parent = header })
	end
	refs.Rows = {}
	for i = 1, 4 do
		local row = Kit.Create("Frame", { BackgroundColor3 = C.PanelLight, BackgroundTransparency = if i % 2 == 1 then 0.4 else 1,
			Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 250 + (i - 1) * 28), BorderSizePixel = 0, Visible = false, Parent = panel })
		Kit.Corner(row, 6)
		local cells = {}
		for j, column in columns do
			cells[j] = Kit.Text({ Text = "", Size = UDim2.new(column[3], -6, 1, 0), Position = UDim2.new(column[2], 6, 0, 0), TextSize = 14,
				Weight = if j == 1 then "Bold" else "Semi", Parent = row })
		end
		refs.Rows[i] = { Row = row, Cells = cells }
	end

	refs.Saved = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -76), TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = panel })
	refs.Return = Kit.Button({ Text = "В лобби", Variant = "Primary", Size = UDim2.fromOffset(260, 48), Position = UDim2.new(0.5, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1), TextSize = 18, Parent = panel, OnClick = function()
			Kit.SetVariant(refs.Return, "Disabled")
			State.Fire("ReturnToLobby", nil, function(ok)
				if not ok then
					Kit.SetVariant(refs.Return, "Primary")
				end
			end)
		end })
end

function ResultsController.Show(results: any)
	PlacementController.Stop()
	TowerController.Select(nil)
	local map = Maps.ById[results.mapId]
	refs.Title.Text = if results.victory then "ПОБЕДА!" else "ПОРАЖЕНИЕ"
	refs.Title.TextColor3 = if results.victory then C.Green else C.Red
	refs.Subtitle.Text = string.format("%s  •  волна %d / %d  •  пройдено волн: %d  •  %s", if map then map.Name else "?", results.wave,
		results.maxWave, results.wavesCleared, Format.Time(results.time or 0))
	refs.Kills.Text = Format.Number(results.you.kills)
	refs.Damage.Text = Format.Number(results.you.damage)
	refs.Earned.Text = Format.Cash(results.you.earned)
	refs.Towers.Text = tostring(results.you.towers)
	refs.Gems.Text = "💎 +" .. Format.Number(results.rewards.gems)
	refs.Xp.Text = "⭐ +" .. Format.Number(results.rewards.xp) .. " XP"
	refs.LevelUp.Text = if (results.levelsGained or 0) > 0 then "🎉 Новый уровень!" else ""
	local myName = Players.LocalPlayer.Name
	for i, row in refs.Rows do
		local entry = results.team[i]
		row.Row.Visible = entry ~= nil
		if entry then
			row.Cells[1].Text = entry.name .. (if entry.connected == false then " (вышел)" else "")
			row.Cells[1].TextColor3 = if entry.name == myName then C.Accent else C.Text
			row.Cells[2].Text = Format.Number(entry.kills)
			row.Cells[3].Text = Format.Number(entry.damage)
			row.Cells[4].Text = Format.Cash(entry.earned)
		end
	end
	refs.Saved.Text = if results.saved then "✔ Прогресс сохранён" else "⚠ Тестовый режим: прогресс не сохраняется"
	refs.Saved.TextColor3 = if results.saved then C.Green else C.Orange
	Kit.SetVariant(refs.Return, "Primary")
	refs.Dim.Visible = true
	token += 1
	local mine = token
	local deadline = os.clock() + (results.returnIn or 30)
	task.spawn(function()
		while mine == token and refs.Dim.Visible do
			local left = math.max(0, math.ceil(deadline - os.clock()))
			refs.Return.Text = string.format("В лобби  (%d)", left)
			task.wait(0.25)
		end
	end)
end

function ResultsController.Hide()
	token += 1
	refs.Dim.Visible = false
end

function ResultsController.Init(screen: Instance)
	local layer = Root.Layer("Results")
	build(layer)
	State.Ended.Event:Connect(ResultsController.Show)
	Players.LocalPlayer:GetAttributeChangedSignal("MatchId"):Connect(function()
		if not State.InMatch() then
			ResultsController.Hide()
		end
	end)
end

return ResultsController
