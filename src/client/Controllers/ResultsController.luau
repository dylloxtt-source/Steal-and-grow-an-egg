--[[
	Экран завершения матча: победа/поражение, карта и волна, личная статистика,
	награды (гемы и опыт с анимацией счёта, новый уровень), таблица команды с MVP,
	статус сохранения и кнопка возврата в лобби с таймером.
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

local function tile(parent: Instance, order: number, icon: string, title: string): TextLabel
	local frame = Kit.Inset({ Size = UDim2.fromOffset(146, 74), LayoutOrder = order, Parent = parent })
	Kit.Text({ Text = icon .. "  " .. title, Font = "Display", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 10), TextSize = 13, TextColor3 = C.SubText,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = frame })
	return Kit.Text({ Text = "0", Font = "Display", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 32), TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center, Stroke = true, Parent = frame })
end

local function build(layer: Instance)
	local dim = Kit.Create("Frame", { Name = "Results", BackgroundColor3 = C.Black, BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1),
		Visible = false, ZIndex = 40, Active = true, Parent = layer })
	refs.Dim = dim
	local panel = Root.Fit(Kit.Panel({ Name = "Panel", Size = UDim2.fromOffset(660, 560), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), Parent = dim }))
	refs.Panel = panel
	local ribbon = Kit.Create("Frame", { Name = "Ribbon", BackgroundColor3 = C.Green, Size = UDim2.new(1, 0, 0, 96), BorderSizePixel = 0, Parent = panel })
	Kit.Corner(ribbon, Kit.Theme.Radius)
	Kit.Gradient(ribbon, Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 150))
	refs.Ribbon = ribbon
	refs.Title = Kit.Text({ Text = "", Font = "Display", Size = UDim2.new(1, 0, 0, 62), Position = UDim2.fromOffset(0, 4), TextSize = 56,
		TextXAlignment = Enum.TextXAlignment.Center, Stroke = true, StrokeThickness = 3, Parent = ribbon })
	refs.Subtitle = Kit.Text({ Text = "", Font = "Display", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 66), TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center, Stroke = true, Parent = ribbon })

	local tiles = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -32, 0, 74), Position = UDim2.fromOffset(16, 110), Parent = panel })
	Kit.List(tiles, 10, true, Enum.HorizontalAlignment.Center)
	refs.Kills = tile(tiles, 1, "☠", "KILLS")
	refs.Damage = tile(tiles, 2, "⚔", "DAMAGE")
	refs.Earned = tile(tiles, 3, "💵", "EARNED")
	refs.Towers = tile(tiles, 4, "🏰", "TOWERS")

	local rewards = Kit.Inset({ Size = UDim2.new(1, -32, 0, 58), Position = UDim2.fromOffset(16, 196), Parent = panel })
	Kit.List(rewards, 26, true, Enum.HorizontalAlignment.Center)
	refs.Gems = Kit.Text({ Text = "", Font = "Display", Size = UDim2.fromOffset(150, 40), TextSize = 30, TextColor3 = C.Gem, Stroke = true, StrokeThickness = 2,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = rewards })
	refs.Xp = Kit.Text({ Text = "", Font = "Display", Size = UDim2.fromOffset(170, 40), TextSize = 26, TextColor3 = C.Accent, Stroke = true, StrokeThickness = 2,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = rewards })
	refs.LevelUp = Kit.Badge({ Text = "🎉 LEVEL UP!", Color = C.Gold, Size = UDim2.fromOffset(160, 32), TextSize = 17, LayoutOrder = 3, Parent = rewards })

	Kit.Text({ Text = "TEAM", Font = "Display", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(20, 266), TextSize = 15, TextColor3 = C.SubText, Parent = panel })
	local header = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -32, 0, 16), Position = UDim2.fromOffset(16, 288), Parent = panel })
	local columns = { { "PLAYER", 0, 0.4 }, { "KILLS", 0.4, 0.18 }, { "DAMAGE", 0.58, 0.2 }, { "EARNED", 0.78, 0.22 } }
	for _, column in columns do
		Kit.Text({ Text = column[1], Font = "Display", Size = UDim2.new(column[3], -8, 1, 0), Position = UDim2.new(column[2], 8, 0, 0), TextSize = 12,
			TextColor3 = C.Muted, Parent = header })
	end
	refs.Rows = {}
	for i = 1, 4 do
		local row = Kit.Inset({ Size = UDim2.new(1, -32, 0, 30), Position = UDim2.fromOffset(16, 308 + (i - 1) * 34), Radius = 8, Visible = false, Parent = panel })
		local cells = {}
		for j, column in columns do
			cells[j] = Kit.Text({ Text = "", Font = "Display", Size = UDim2.new(column[3], -8, 1, 0), Position = UDim2.new(column[2], 8, 0, 0), TextSize = 15,
				TextColor3 = if j == 4 then C.Gold else C.Text, Parent = row })
		end
		refs.Rows[i] = { Row = row, Cells = cells }
	end

	refs.Saved = Kit.Text({ Text = "", Font = "Display", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -104), TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = panel })
	refs.Return = Kit.Button({ Name = "Return", Text = "RETURN TO LOBBY", Variant = "Primary", Size = UDim2.fromOffset(320, 58), Position = UDim2.new(0.5, 0, 1, -16),
		AnchorPoint = Vector2.new(0.5, 1), TextSize = 21, Parent = panel, OnClick = function()
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
	local victory = results.victory == true
	refs.Title.Text = if victory then "VICTORY!" else "DEFEAT"
	refs.Ribbon.BackgroundColor3 = if victory then C.Green else C.Red
	refs.Subtitle.Text = string.format("%s  •  WAVE %d / %d  •  %s", if map then string.upper(map.Name) else "?", results.wave, results.maxWave,
		Format.Time(results.time or 0))
	refs.Kills.Text = Format.Thousands(results.you.kills)
	refs.Damage.Text = Format.Number(results.you.damage)
	refs.Earned.Text = Format.Cash(results.you.earned)
	refs.Towers.Text = tostring(results.you.towers)
	Kit.CountUp(refs.Gems, 0, results.rewards.gems, 1.2, function(n)
		return "💎 +" .. Format.Thousands(math.floor(n + 0.5))
	end)
	Kit.CountUp(refs.Xp, 0, results.rewards.xp, 1.2, function(n)
		return "⭐ +" .. Format.Thousands(math.floor(n + 0.5)) .. " XP"
	end)
	refs.LevelUp.Visible = (results.levelsGained or 0) > 0
	local myName = Players.LocalPlayer.Name
	local mvp, best = nil, -1
	for _, entry in results.team do
		if entry.damage > best then
			mvp, best = entry, entry.damage
		end
	end
	for i, row in refs.Rows do
		local entry = results.team[i]
		row.Row.Visible = entry ~= nil
		if entry then
			row.Cells[1].Text = (if entry == mvp and #results.team > 1 then "👑 " else "") .. entry.name .. (if entry.connected == false then " (left)" else "")
			row.Cells[1].TextColor3 = if entry.name == myName then C.Accent else C.Text
			row.Cells[2].Text = Format.Thousands(entry.kills)
			row.Cells[3].Text = Format.Number(entry.damage)
			row.Cells[4].Text = Format.Cash(entry.earned)
		end
	end
	ResultsController.SetSaved(results.saved)
	Kit.SetVariant(refs.Return, "Primary")
	refs.Dim.Visible = true
	local scale = refs.Panel:FindFirstChild("FitScale") :: UIScale
	scale.Scale = Root.Scale * 0.8
	Kit.Tween(scale, 0.35, { Scale = Root.Scale }, Enum.EasingStyle.Back)
	token += 1
	local mine = token
	local deadline = os.clock() + (results.returnIn or 30)
	task.spawn(function()
		while mine == token and refs.Dim.Visible do
			local left = math.max(0, math.ceil(deadline - os.clock()))
			Kit.SetText(refs.Return, string.format("RETURN TO LOBBY  (%d)", left))
			task.wait(0.25)
		end
	end)
end

-- saved: true — записано, false — не сохраняется (тестовый режим / ошибка), nil — идёт сохранение
function ResultsController.SetSaved(saved: boolean?)
	if saved == nil then
		refs.Saved.Text = "Saving progress…"
		refs.Saved.TextColor3 = C.SubText
	elseif saved then
		refs.Saved.Text = "✔ Progress saved"
		refs.Saved.TextColor3 = C.Green
	else
		refs.Saved.Text = if State.MemoryMode then "⚠ Test mode: progress is not saved" else "⚠ Could not save — we will retry automatically"
		refs.Saved.TextColor3 = C.Orange
	end
end

function ResultsController.Hide()
	token += 1
	refs.Dim.Visible = false
end

function ResultsController.Init(screen: Instance)
	local layer = Root.Layer("Results")
	layer.ZIndex = 60 -- поверх HUD и уведомлений
	build(layer)
	State.Ended.Event:Connect(function(results)
		if results.savedUpdate then
			ResultsController.SetSaved(results.saved)
		else
			ResultsController.Show(results)
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("MatchId"):Connect(function()
		if not State.InMatch() then
			ResultsController.Hide()
		end
	end)
end

return ResultsController
