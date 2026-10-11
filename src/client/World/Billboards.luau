--[[
	Billboards — подписи над объектами мира, которые клиент рисует сам по атрибутам
	от сервера (таймеры считаются локально — меньше сетевого трафика и плавнее).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Foods = require(Shared.Config.Foods)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Logic.Format)

local Kit = require(script.Parent.Parent.UI.Kit)

local C = Kit.Theme.Colors

local Billboards = {}

local localPlayer = Players.LocalPlayer
local folder: Folder
local entries: { [Instance]: { Gui: BillboardGui, Update: () -> () } } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function isMine(instance: Instance): boolean
	return instance:GetAttribute("OwnerId") == localPlayer.UserId
end

local function makeGui(adornee: Instance, size: Vector2, offset: Vector3, maxDistance: number): BillboardGui
	return Kit.Create("BillboardGui", {
		Size = UDim2.fromOffset(size.X, size.Y),
		StudsOffsetWorldSpace = offset,
		AlwaysOnTop = false,
		MaxDistance = maxDistance,
		LightInfluence = 0,
		Adornee = adornee,
		Parent = folder,
	})
end

local function bar(parent: Instance, color: Color3, position: UDim2, size: UDim2): Frame
	local back = Kit.Create("Frame", { BackgroundColor3 = C.PanelInner, Position = position, Size = size, Parent = parent })
	Kit.Corner(back, 6)
	Kit.Stroke(back, 2, C.Black, true)
	local fill = Kit.Create("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(0, 1), Parent = back })
	Kit.Corner(fill, 6)
	return fill
end

local BUILDERS: { [string]: (Instance) -> { Gui: BillboardGui, Update: () -> () }? } = {}

BUILDERS.Incubator = function(model)
	local adornee = (model :: Model).PrimaryPart
	if not adornee then
		return nil
	end
	local gui = makeGui(adornee, Vector2.new(170, 64), Vector3.new(0, 7.2, 0), 70)
	local title = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 30), Parent = gui })
	local fill = bar(gui, C.Yellow, UDim2.new(0.05, 0, 0, 34), UDim2.new(0.9, 0, 0, 22))
	local timeLabel = Kit.Text({ Text = "", Size = UDim2.new(0.9, 0, 0, 22), Position = UDim2.new(0.05, 0, 0, 34), MaxTextSize = 18, Parent = gui })
	local barFrame = fill.Parent :: Frame
	return {
		Gui = gui,
		Update = function()
			local state = model:GetAttribute("State")
			local mine = isMine(model)
			gui.Enabled = state ~= "locked" or mine
			barFrame.Visible = state == "incubating"
			timeLabel.Visible = state == "incubating"
			if state == "locked" then
				title.Text = "🔒 Upgrade"
				title.TextColor3 = C.Grey
			elseif state == "empty" then
				title.Text = if mine then "＋ Incubate" else ""
				title.TextColor3 = C.White
			elseif state == "stolen" then
				title.Text = "🚨 STOLEN!"
				title.TextColor3 = C.Red
			else
				local egg = Eggs.ById[model:GetAttribute("EggId") :: string]
				local rarity = egg and Rarities.ById[egg.Rarity]
				if state == "ready" then
					title.Text = "✅ READY!"
					title.TextColor3 = C.Green
				else
					title.Text = if egg then egg.Name else ""
					title.TextColor3 = if rarity and egg.Rarity ~= "Secret" then rarity.Color else C.Pink
					local startedAt = model:GetAttribute("StartedAt") or 0
					local duration = model:GetAttribute("Duration") or 1
					local remaining = startedAt + duration - now()
					fill.Size = UDim2.fromScale(math.clamp(1 - remaining / duration, 0, 1), 1)
					timeLabel.Text = Format.Time(remaining)
				end
			end
		end,
	}
end

BUILDERS.FarmPlot = function(model)
	local adornee = (model :: Model).PrimaryPart
	if not adornee then
		return nil
	end
	local gui = makeGui(adornee, Vector2.new(150, 40), Vector3.new(0, 4.5, 0), 60)
	local label = Kit.Text({ Text = "", MaxTextSize = 24, Parent = gui })
	return {
		Gui = gui,
		Update = function()
			local state = model:GetAttribute("State")
			local mine = isMine(model)
			gui.Enabled = mine
			if not mine then
				return
			end
			local food = Foods.ById[model:GetAttribute("Seed") or ""]
			if state == "locked" then
				label.Text = "🔒"
			elseif state == "empty" then
				label.Text = "🌱 Plant"
			elseif state == "ready" and food then
				label.Text = "✅ " .. food.Icon .. " Harvest"
			elseif food then
				label.Text = food.Icon .. " " .. Format.Time((model:GetAttribute("ReadyAt") or 0) - now())
			end
		end,
	}
end

BUILDERS.Vault = function(part)
	local gui = makeGui(part, Vector2.new(200, 56), Vector3.new(0, 4, 0), 80)
	local label = Kit.Text({ Text = "", Gradient = { C.Money, C.MoneyDark }, Stroke = 3, Parent = gui })
	return {
		Gui = gui,
		Update = function()
			local plot = part.Parent
			local mine = isMine(part)
			gui.Enabled = mine
			if mine and plot then
				label.Text = "💰 " .. Format.Money(plot:GetAttribute("Vault") or 0)
			end
		end,
	}
end

BUILDERS.LockPad = function(part)
	local gui = makeGui(part, Vector2.new(180, 44), Vector3.new(0, 3.5, 0), 60)
	local label = Kit.Text({ Text = "", MaxTextSize = 26, Parent = gui })
	return {
		Gui = gui,
		Update = function()
			local plot = part.Parent
			if not plot then
				return
			end
			local t = now()
			local lockedUntil = plot:GetAttribute("LockedUntil") or 0
			local cooldown = plot:GetAttribute("LockCooldownUntil") or 0
			local protectedUntil = plot:GetAttribute("ProtectedUntil") or 0
			if lockedUntil > t then
				label.Text = "🔒 " .. Format.Time(lockedUntil - t)
				label.TextColor3 = C.Blue
			elseif protectedUntil > t then
				label.Text = "🛡️ " .. Format.Time(protectedUntil - t)
				label.TextColor3 = C.Green
			elseif cooldown > t then
				label.Text = "⏳ " .. Format.Time(cooldown - t)
				label.TextColor3 = C.Grey
			else
				label.Text = if plot:GetAttribute("OwnerId") == localPlayer.UserId then "🔒 LOCK" else "🔓"
				label.TextColor3 = C.White
			end
		end,
	}
end

BUILDERS.PenCreature = function(model)
	local adornee = (model :: Model).PrimaryPart
	if not adornee then
		return nil
	end
	local extents = (model :: Model):GetExtentsSize()
	local gui = makeGui(adornee, Vector2.new(170, 58), Vector3.new(0, extents.Y + 1.5, 0), 60)
	local rarity = Rarities.ById[model:GetAttribute("Rarity") or "Common"]
	local mutation = model:GetAttribute("Mutation")
	local name = Kit.Text({
		Text = (if mutation and mutation ~= "None" then mutation .. " " else "") .. (model:GetAttribute("DisplayName") or ""),
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = if rarity.Id == "Secret" then C.Pink else rarity.Color,
		Parent = gui,
	})
	local stage = Kit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 24), MaxTextSize = 15, Parent = gui })
	local fill = bar(gui, C.Orange, UDim2.new(0.15, 0, 0, 42), UDim2.new(0.7, 0, 0, 12))
	local _ = name
	return {
		Gui = gui,
		Update = function()
			local fullness = model:GetAttribute("Fullness") or 0
			stage.Text = (model:GetAttribute("Stage") or "") .. (if fullness <= 0 then " • 😫 Голоден" else "")
			fill.Size = UDim2.fromScale(math.clamp(fullness / 100, 0, 1), 1)
			fill.BackgroundColor3 = if fullness <= 20 then C.Red else C.Orange
			;(fill.Parent :: Frame).Visible = isMine(model)
		end,
	}
end

BUILDERS.WorldEgg = function(model)
	local adornee = (model :: Model).PrimaryPart
	if not adornee then
		return nil
	end
	local egg = Eggs.ById[model:GetAttribute("EggId") or ""]
	if not egg then
		return nil
	end
	local rarity = Rarities.ById[egg.Rarity]
	local gui = makeGui(adornee, Vector2.new(180, 46), Vector3.new(0, 4.6, 0), 90)
	local owner = model:GetAttribute("OwnerName")
	Kit.Text({ Text = egg.Name, Size = UDim2.new(1, 0, 0, 26), TextColor3 = if egg.Rarity == "Secret" then C.Pink else rarity.Color, Parent = gui })
	Kit.Text({ Text = if owner then "🚨 " .. owner else rarity.Name, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 26),
		MaxTextSize = 16, Parent = gui })
	return { Gui = gui, Update = function() end }
end

local function track(tag: string, instance: Instance)
	if entries[instance] then
		return
	end
	local builder = BUILDERS[tag]
	local ok, entry = pcall(builder, instance)
	if ok and entry then
		entries[instance] = entry
		entry.Update()
	end
end

local function untrack(instance: Instance)
	local entry = entries[instance]
	if entry then
		entry.Gui:Destroy()
		entries[instance] = nil
	end
end

function Billboards.Start()
	folder = Instance.new("Folder")
	folder.Name = "WorldBillboards"
	folder.Parent = localPlayer:WaitForChild("PlayerGui")
	for tag in BUILDERS do
		for _, instance in CollectionService:GetTagged(tag) do
			task.spawn(track, tag, instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			-- Ждём, пока реплицируются атрибуты и дочерние детали
			task.wait(0.1)
			track(tag, instance)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		for instance, entry in entries do
			if instance.Parent then
				local ok, err = pcall(entry.Update)
				if not ok then
					warn("[Billboards]", err)
					untrack(instance)
				end
			else
				untrack(instance)
			end
		end
	end)
end

return Billboards
