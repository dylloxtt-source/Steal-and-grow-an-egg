--[[
	Экран вылупления: яйцо трясётся, вспышка, затем существо с лучами
	цвета редкости, отметкой NEW! и наградой индекса. Закрывается кликом или сам.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Logic.Format)
local Net = require(Shared.Net)

local Kit = require(script.Parent.Kit)
local Preview = require(script.Parent.Preview)
local Sounds = require(script.Parent.Sounds)

local C = Kit.Theme.Colors

local HatchReveal = {}

local overlay: TextButton
local rays: Frame
local stage: Frame
local queue: { any } = {}
local busy = false

local function clearStage()
	for _, child in stage:GetChildren() do
		child:Destroy()
	end
end

local function play(result: any)
	busy = true
	clearStage()
	local def = Creatures.ById[result.creature.species]
	local rarity = Rarities.ById[def.Rarity]
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	Kit.Tween(overlay, 0.25, { BackgroundTransparency = 0.35 })
	for _, ray in rays:GetChildren() do
		if ray:IsA("Frame") then
			ray.BackgroundColor3 = if def.Rarity == "Secret" then C.Pink else rarity.Color
		end
	end
	rays.Visible = false

	-- 1. Тряска яйца
	local egg = Preview.Egg(result.eggId, stage, UDim2.fromOffset(300, 300), UDim2.fromScale(0.5, 0.5))
	egg.AnchorPoint = Vector2.new(0.5, 0.5)
	Sounds.Play("hatch", 0.8)
	local start = os.clock()
	while os.clock() - start < 1.3 do
		local t = os.clock() - start
		local amplitude = 4 + t * 12
		egg.Rotation = math.sin(t * 40) * amplitude
		egg.Size = UDim2.fromOffset(300 + t * 60, 300 + t * 60)
		RunService.RenderStepped:Wait()
	end

	-- 2. Вспышка
	local flash = Kit.Create("Frame", { BackgroundColor3 = C.White, Size = UDim2.fromScale(3, 3), Position = UDim2.fromScale(-1, -1), Parent = stage })
	egg:Destroy()
	Kit.Tween(flash, 0.5, { BackgroundTransparency = 1 })
	Sounds.Play("success", 1.4)

	-- 3. Существо
	rays.Visible = true
	local viewport = Preview.Creature(def.Id, { Stage = result.stage, Mutation = result.creature.mutation }, stage,
		UDim2.fromOffset(340, 340), UDim2.new(0.5, 0, 0.5, -30))
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	local vScale = Kit.Create("UIScale", { Scale = 0.3, Parent = viewport })
	Kit.Tween(vScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	local mutation = if result.creature.mutation ~= "None" then result.creature.mutation .. " " else ""
	Kit.Text({ Text = mutation .. def.Name, Size = UDim2.fromOffset(700, 70), Position = UDim2.new(0.5, 0, 0.5, 150),
		AnchorPoint = Vector2.new(0.5, 0), Stroke = 4, MaxTextSize = 64,
		Gradient = { C.White, if def.Rarity == "Secret" then C.Pink else rarity.Color }, Parent = stage })
	Kit.Text({ Text = string.format("%s • %s • 💵 %s/s", rarity.Name, result.creature.sizeId, Format.Number(def.BaseIncome * result.creature.size)),
		Size = UDim2.fromOffset(700, 36), Position = UDim2.new(0.5, 0, 0.5, 222), AnchorPoint = Vector2.new(0.5, 0),
		TextColor3 = C.Yellow, MaxTextSize = 32, Parent = stage })
	if result.discovered then
		local new = Kit.Text({ Text = "NEW! +" .. Format.Money(result.reward), Size = UDim2.fromOffset(400, 56),
			Position = UDim2.new(0.5, 0, 0.5, -250), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = C.Money, Stroke = 4,
			MaxTextSize = 52, Parent = stage })
		new.Rotation = -6
	end
	Kit.Text({ Text = "Нажми, чтобы продолжить", Size = UDim2.fromOffset(400, 30), Position = UDim2.new(0.5, 0, 1, -60),
		AnchorPoint = Vector2.new(0.5, 0), MaxTextSize = 26, Parent = stage })

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		overlay.Visible = false
		clearStage()
		busy = false
		if #queue > 0 then
			task.spawn(play, table.remove(queue, 1))
		end
	end
	local connection
	connection = overlay.Activated:Connect(function()
		connection:Disconnect()
		close()
	end)
	task.delay(5, function()
		if connection.Connected then
			connection:Disconnect()
		end
		close()
	end)
end

function HatchReveal:Build(screen: ScreenGui)
	overlay = Kit.Create("TextButton", {
		Name = "HatchReveal",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Black,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 80,
		Parent = screen,
	})
	rays = Kit.Create("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(900, 900), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), Parent = overlay,
	})
	for i = 1, 12 do
		Kit.Create("Frame", {
			BackgroundColor3 = C.Yellow, BackgroundTransparency = 0.55, BorderSizePixel = 0,
			Size = UDim2.fromOffset(46, 900), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = i * 15, Parent = rays,
		})
	end
	stage = Kit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = overlay })

	RunService.RenderStepped:Connect(function(dt)
		if overlay.Visible then
			rays.Rotation = (rays.Rotation + dt * 20) % 360
		end
	end)

	Net.Event("Hatched").OnClientEvent:Connect(function(result)
		if type(result) ~= "table" or not result.creature then
			return
		end
		if busy then
			table.insert(queue, result)
		else
			task.spawn(play, result)
		end
	end)
end

function HatchReveal:Open() end
function HatchReveal:Close() end

return HatchReveal
