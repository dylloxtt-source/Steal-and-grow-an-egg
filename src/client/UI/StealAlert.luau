--[[
	Тревога кражи: красный баннер, метка «THIEF» над вором и луч от игрока к вору.
	Если вора остановили — метка над выпавшим яйцом.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Net = require(Shared.Net)

local Kit = require(script.Parent.Kit)
local Sounds = require(script.Parent.Sounds)

local C = Kit.Theme.Colors

local StealAlert = {}

local banner: Frame
local bannerText: TextLabel
local markers: { Instance } = {}
local localPlayer = Players.LocalPlayer

local function clearMarkers()
	for _, marker in markers do
		marker:Destroy()
	end
	table.clear(markers)
end

local function markerGui(adornee: Instance, text: string): BillboardGui
	local gui = Kit.Create("BillboardGui", {
		Size = UDim2.fromOffset(220, 60),
		StudsOffset = Vector3.new(0, 4, 0),
		AlwaysOnTop = true,
		Adornee = adornee,
		Parent = localPlayer:WaitForChild("PlayerGui"),
	})
	Kit.Text({ Text = text, TextColor3 = C.Red, Stroke = 3, Parent = gui })
	table.insert(markers, gui)
	return gui
end

local function beamTo(part: BasePart)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Parent = part
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(C.Red)
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.2)
	beam.Parent = root
	table.insert(markers, a0)
	table.insert(markers, a1)
	table.insert(markers, beam)
end

local function onAlert(info: any)
	clearMarkers()
	if type(info) ~= "table" then
		return
	end
	if not info.active then
		banner.Visible = false
		return
	end
	local egg = Eggs.ById[info.eggId]
	local eggName = if egg then egg.Name else "яйцо"
	banner.Visible = true
	Sounds.Play("alert", 0.6)
	if info.dropped and typeof(info.position) == "Vector3" then
		bannerText.Text = "🥚 Твоё " .. eggName .. " выпало! Забери его!"
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Transparency = 1
		part.Size = Vector3.one
		part.Position = info.position + Vector3.new(0, 3, 0)
		part.Parent = workspace
		table.insert(markers, part)
		markerGui(part, "⬇ ТВОЁ ЯЙЦО ⬇")
		beamTo(part)
		return
	end
	bannerText.Text = string.format("🚨 %s крадёт твоё %s! Ударь вора битой!", info.thief or "Игрок", eggName)
	local thief = Players:GetPlayerByUserId(info.thiefUserId or 0)
	local character = thief and thief.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if head then
		markerGui(head, "🚨 THIEF 🚨")
		beamTo(head)
	end
end

function StealAlert:Build(screen: ScreenGui)
	banner = Kit.Create("Frame", {
		Name = "StealBanner",
		BackgroundColor3 = C.Red,
		Size = UDim2.fromOffset(720, 64),
		Position = UDim2.new(0.5, 0, 0, 104),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		ZIndex = 40,
		Parent = screen,
	})
	Kit.Corner(banner, 12)
	Kit.Stroke(banner, 4, C.Black, true)
	bannerText = Kit.Text({ Text = "", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), Stroke = 3, MaxTextSize = 32, Parent = banner })

	RunService.RenderStepped:Connect(function()
		if banner.Visible then
			local pulse = (math.sin(os.clock() * 8) + 1) / 2
			banner.BackgroundColor3 = C.Red:Lerp(C.RedDark, pulse)
		end
	end)
	Net.Event("StealAlert").OnClientEvent:Connect(onAlert)
end

function StealAlert:Open() end
function StealAlert:Close() end

return StealAlert
