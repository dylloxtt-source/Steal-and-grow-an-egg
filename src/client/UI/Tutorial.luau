--[[
	Обучение: подсказка внизу экрана и жёлтый луч-указатель к цели в мире
	(или пульсирующая обводка кнопки HUD).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Map = require(Shared.Config.Map)
local TutorialConfig = require(Shared.Config.Tutorial)

local Kit = require(script.Parent.Kit)
local HUD = require(script.Parent.HUD)
local State = require(script.Parent.Parent.State)

local C = Kit.Theme.Colors

local Tutorial = {}

local frame: Frame
local text: TextLabel
local stepLabel: TextLabel
local guidePart: Part
local beam: Beam
local rootAttachment: Attachment?
local highlighted: UIStroke?
local currentStep = 0

local function targetPosition(target: string, plotIndex: number?): Vector3?
	if target == "lane" then
		return Vector3.new(0, 2, 140)
	end
	if not plotIndex then
		return nil
	end
	if target == "base" then
		return Map.PlotWorld(plotIndex, Map.PlotLayout.Delivery) + Vector3.new(0, 2, 0)
	elseif target == "incubator" then
		return Map.PlotWorld(plotIndex, Map.PlotLayout.Incubators[1]) + Vector3.new(0, 4, 0)
	elseif target == "pen" then
		return Map.PlotWorld(plotIndex, (Map.PlotLayout.PenMin + Map.PlotLayout.PenMax) / 2) + Vector3.new(0, 2, 0)
	elseif target == "vault" then
		return Map.PlotWorld(plotIndex, Map.PlotLayout.Vault) + Vector3.new(0, 2, 0)
	end
	return nil
end

local function setHighlight(button: GuiObject?)
	if highlighted then
		highlighted:Destroy()
		highlighted = nil
	end
	if button then
		highlighted = Kit.Create("UIStroke", {
			Thickness = 6, Color = C.Yellow, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button,
		})
	end
end

local function refresh()
	local profile = State.Profile()
	if not profile then
		return
	end
	local step = TutorialConfig.Steps[profile.tutorial]
	frame.Visible = step ~= nil
	if not step then
		beam.Enabled = false
		setHighlight(nil)
		currentStep = profile.tutorial
		return
	end
	text.Text = step.Text
	stepLabel.Text = string.format("ОБУЧЕНИЕ %d/%d", profile.tutorial, #TutorialConfig.Steps)
	if currentStep ~= profile.tutorial then
		currentStep = profile.tutorial
		local scale = frame:FindFirstChildOfClass("UIScale") :: UIScale
		scale.Scale = 0.8
		Kit.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	if step.Target == "eggs_button" then
		setHighlight(HUD.GetButton("EggsButton"))
		beam.Enabled = false
	else
		setHighlight(nil)
		local position = targetPosition(step.Target, State.Runtime().plotIndex)
		if position then
			guidePart.Position = position
			beam.Enabled = true
		else
			beam.Enabled = false
		end
	end
end

local function attachToCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "TutorialAttachment"
	attachment.Parent = root
	rootAttachment = attachment
	beam.Attachment0 = attachment
end

function Tutorial:Build(screen: ScreenGui)
	frame = Kit.Create("Frame", {
		Name = "Tutorial",
		BackgroundColor3 = C.Panel,
		Size = UDim2.fromOffset(640, 96),
		Position = UDim2.new(0.5, 0, 1, -120),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		Parent = screen,
	})
	Kit.Corner(frame, 12)
	Kit.Stroke(frame, 4, C.Black, true)
	Kit.Create("UIScale", { Parent = frame })
	stepLabel = Kit.Text({ Text = "", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 4),
		TextColor3 = C.Yellow, MaxTextSize = 22, Parent = frame })
	text = Kit.Text({ Text = "", Size = UDim2.new(1, -24, 0, 56), Position = UDim2.fromOffset(12, 32), TextWrapped = true,
		MaxTextSize = 26, Parent = frame })

	guidePart = Instance.new("Part")
	guidePart.Name = "TutorialGuide"
	guidePart.Anchored = true
	guidePart.CanCollide = false
	guidePart.CanQuery = false
	guidePart.CanTouch = false
	guidePart.Transparency = 1
	guidePart.Size = Vector3.one
	guidePart.Parent = workspace
	local target = Instance.new("Attachment")
	target.Parent = guidePart
	beam = Instance.new("Beam")
	beam.Attachment1 = target
	beam.Color = ColorSequence.new(C.Yellow)
	beam.Width0 = 0.8
	beam.Width1 = 0.8
	beam.FaceCamera = true
	beam.LightEmission = 0.8
	beam.Transparency = NumberSequence.new(0.25)
	beam.Enabled = false
	beam.Parent = guidePart
	local marker = Kit.Create("BillboardGui", {
		Size = UDim2.fromOffset(120, 120), AlwaysOnTop = true, Adornee = guidePart,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local arrow = Kit.Text({ Text = "⬇", TextColor3 = C.Yellow, Stroke = 4, Parent = marker })

	RunService.RenderStepped:Connect(function()
		marker.Enabled = beam.Enabled
		if beam.Enabled then
			arrow.Position = UDim2.fromOffset(0, math.sin(os.clock() * 5) * 10)
		end
		if highlighted then
			highlighted.Transparency = (math.sin(os.clock() * 6) + 1) / 3
		end
	end)

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(attachToCharacter)
	if player.Character then
		task.spawn(attachToCharacter, player.Character)
	end
	State.Changed.Event:Connect(refresh)
	local _ = rootAttachment
end

function Tutorial:Open() end
function Tutorial:Close() end

return Tutorial
