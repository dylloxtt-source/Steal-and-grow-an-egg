--[[
	Ежедневные задания с прогрессом и кнопкой Claim. Награда зависит от дохода базы.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local Format = require(Shared.Logic.Format)
local Economy = require(Shared.Logic.Economy)

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Router)
local State = require(script.Parent.Parent.State)

local C = Kit.Theme.Colors

local QuestsPanel = {}

local panel: Kit.Panel
local list: ScrollingFrame
local resetLabel: TextLabel
local rows: { any } = {}

function QuestsPanel:Refresh()
	if not panel.Root.Visible then
		return
	end
	local profile = State.Profile()
	if not profile then
		return
	end
	local income = State.Runtime().incomePerSecond or 0
	for i, row in rows do
		local entry = profile.quests.list[i]
		row.Frame.Visible = entry ~= nil
		if entry then
			local quest = Quests.ById[entry.id]
			row.Text.Text = string.format(quest.Text, quest.Target)
			row.Progress:Set(entry.progress / quest.Target, string.format("%d/%d", entry.progress, quest.Target))
			local reward = Economy.QuestReward(income, quest.RewardSeconds)
			if entry.claimed then
				row.Label.Text = "✔"
				Kit.SetButtonColor(row.Button, "Grey")
			else
				row.Label.Text = "💵 " .. Format.Number(reward)
				Kit.SetButtonColor(row.Button, if entry.progress >= quest.Target then "Green" else "Grey")
			end
			row.Id = entry.id
		end
	end
	local secondsLeft = 86400 - (os.time() % 86400)
	resetLabel.Text = "Новые задания через " .. Format.Time(secondsLeft)
end

function QuestsPanel:Build(screen: ScreenGui)
	panel = Kit.Panel(screen, "Quests", Vector2.new(640, 480), C.Orange)
	panel.Close.Activated:Connect(function()
		Router.Close()
	end)
	list = Kit.Scroll(panel.Body, "list", nil, 10)
	for i = 1, 3 do
		local frame = Kit.Create("Frame", { BackgroundColor3 = C.PanelInner, Size = UDim2.new(1, -8, 0, 104), LayoutOrder = i, Parent = list })
		Kit.Corner(frame, 8)
		Kit.Stroke(frame, 3, C.Black, true)
		local text = Kit.Text({ Text = "", Size = UDim2.new(1, -220, 0, 40), Position = UDim2.fromOffset(14, 10),
			TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, MaxTextSize = 26, Parent = frame })
		local progress = Kit.Progress(frame, C.Green, UDim2.new(1, -230, 0, 28), UDim2.fromOffset(14, 62))
		local row: any = { Frame = frame, Text = text, Progress = progress }
		local button, label = Kit.Button({ Text = "Claim", Color = "Green", Size = UDim2.fromOffset(190, 66), Position = UDim2.new(1, -202, 0, 19),
			TextSize = 28, Parent = frame, OnClick = function()
				if row.Id then
					State.Fire("ClaimQuest", { id = row.Id })
				end
			end })
		row.Button = button
		row.Label = label
		rows[i] = row
	end
	resetLabel = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 10, TextColor3 = C.Yellow, MaxTextSize = 24, Parent = list })
end

function QuestsPanel:Open()
	Router.ShowPanel(panel)
	QuestsPanel:Refresh()
end

function QuestsPanel:Close()
	Router.HidePanel(panel)
end

return QuestsPanel
