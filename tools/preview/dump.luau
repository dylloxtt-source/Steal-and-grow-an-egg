--[[
	Строит игру в эмуляторе (tests/sim/Engine.luau), заполняет профиль демо-данными,
	открывает окна и выгружает дерево GUI в JSON для предпросмотра в браузере.
	Запуск:  lune run tools/preview/dump.luau <папка-вывода>
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local task = require("@lune/task")
local roblox = require("@lune/roblox")
local Engine = require("../../tests/sim/Engine")

local Vector3 = roblox.Vector3
local outDir = process.args[1] or "preview-out"
if not fs.isDir(outDir) then
	fs.writeDir(outDir)
end

local server = Engine.Realm(true)
server.require(Engine.ServerNode)
local Map = server.require(Engine.SharedNode.Config.Map)
local DataService = server.require(Engine.ServerNode.Services.DataService)
local CarryService = server.require(Engine.ServerNode.Services.CarryService)

local player = Engine.NewPlayer("Player")
Engine.LocalPlayer = player
Engine.Join(player)
Engine.SpawnCharacter(player, Map.Spawn + Vector3.new(0, 3, 0))
task.wait(0.3)
local session = DataService:GetSession(player)
local profile = session.Profile

-- Демо-данные, похожие на поздний этап игры
profile.coins = 481_800_000
profile.upgrades.speed = 30
profile.upgrades.incubators = 4
profile.upgrades.pens = 8
profile.tutorial = 2
local now = math.floor(Engine.Now())
profile.incubators["1"] = { uid = "d1", id = "star_egg", startedAt = now - 600, duration = 1500 }
profile.incubators["2"] = { uid = "d2", id = "magma_egg", startedAt = now - 700, duration = 600 }
profile.incubators["3"] = { uid = "d3", id = "frost_egg", startedAt = now - 30, duration = 240 }
profile.eggs = { { uid = "d4", id = "void_egg" }, { uid = "d5", id = "prism_egg" }, { uid = "d6", id = "dune_egg" } }
local species = { "nebulynx", "starwing", "emberhorn", "glacimoth", "cactoad", "mossbun", "prismadon", "clucklet" }
for i, id in species do
	local uid = "c" .. i
	profile.creatures[uid] = {
		uid = uid, species = id, size = if i % 3 == 0 then 1.2 else 1, sizeId = if i % 3 == 0 then "Big" else "Normal",
		mutation = if i == 2 then "Golden" elseif i == 5 then "Rainbow" else "None",
		growth = i * 900, fullness = 100 - i * 11, ascended = i == 1, placed = i <= 6, lastTick = now,
	}
	profile.index[id] = true
end
profile.food = { pellet = 12, berry = 7, frost_apple = 3, starfruit = 1, growth_tonic = 2 }
profile.seeds = { berry = 4, dune_fig = 2 }
profile.quests.list[1].progress = 5
CarryService:Add(session, { Kind = "lane", EggId = "star_egg" })
DataService:MarkDirty(player)
task.wait(0.3)

local client = Engine.Realm(false)
client.require(Engine.ClientNode)
task.wait(0.6)
local Router = client.require(Engine.ClientNode.UI.Router)
local Notifications = client.require(Engine.ClientNode.UI.Notifications)
for _ = 1, 3 do
	client.RunService.Heartbeat:FireSync(0.3)
end

------------------------------------------------------------------------
-- Выгрузка дерева
------------------------------------------------------------------------

local function get(instance, property)
	local ok, value = pcall(function()
		return instance[property]
	end)
	return if ok then value else nil
end

local function udim2(value)
	if not value then
		return nil
	end
	return { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
end

local function color(value)
	if not value then
		return nil
	end
	return { math.floor(value.R * 255 + 0.5), math.floor(value.G * 255 + 0.5), math.floor(value.B * 255 + 0.5) }
end

local function enumName(value)
	return if value then value.Name else nil
end

local function dump(instance)
	local class = instance.ClassName
	local node = { c = class, n = instance.Name, children = {}, mods = {} }
	if instance:IsA("GuiObject") then
		node.size = udim2(get(instance, "Size"))
		node.pos = udim2(get(instance, "Position"))
		local anchor = get(instance, "AnchorPoint")
		node.anchor = if anchor then { anchor.X, anchor.Y } else { 0, 0 }
		node.vis = get(instance, "Visible")
		node.bg = color(get(instance, "BackgroundColor3"))
		node.bgt = get(instance, "BackgroundTransparency")
		node.z = get(instance, "ZIndex")
		node.rot = get(instance, "Rotation")
		node.lo = get(instance, "LayoutOrder")
		node.clip = get(instance, "ClipsDescendants")
		node.autosize = enumName(get(instance, "AutomaticSize"))
		if instance:IsA("TextLabel") or instance:IsA("TextButton") then
			node.text = get(instance, "Text")
			node.tc = color(get(instance, "TextColor3"))
			node.tsize = get(instance, "TextSize")
			node.tscaled = get(instance, "TextScaled")
			node.wrap = get(instance, "TextWrapped")
			node.xa = enumName(get(instance, "TextXAlignment"))
			node.tt = get(instance, "TextTransparency")
		end
		if class == "ViewportFrame" then
			local model = instance:FindFirstChildOfClass("Model")
			if model then
				node.viewport = { egg = model:GetAttribute("EggId"), species = model:GetAttribute("Species") }
				local colors = {}
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") and part.Name ~= "Root" and #colors < 3 then
						local c = color(part.Color)
						table.insert(colors, c)
					end
				end
				node.viewport.colors = colors
			end
		end
		if node.vis == false then
			return node -- скрытые ветки не рисуются
		end
	elseif class == "ScreenGui" then
		node.screen = true
	end
	for _, child in instance:GetChildren() do
		local cc = child.ClassName
		if cc == "UIListLayout" then
			node.mods.list = {
				dir = enumName(get(child, "FillDirection")),
				pad = { get(child, "Padding").Scale, get(child, "Padding").Offset },
				ha = enumName(get(child, "HorizontalAlignment")),
			}
		elseif cc == "UIGridLayout" then
			node.mods.grid = { cell = udim2(get(child, "CellSize")), pad = udim2(get(child, "CellPadding")), ha = enumName(get(child, "HorizontalAlignment")) }
		elseif cc == "UIPadding" then
			node.mods.pad = {
				get(child, "PaddingLeft").Offset, get(child, "PaddingRight").Offset,
				get(child, "PaddingTop").Offset, get(child, "PaddingBottom").Offset,
				get(child, "PaddingLeft").Scale, get(child, "PaddingTop").Scale,
			}
		elseif cc == "UICorner" then
			local r = get(child, "CornerRadius")
			node.mods.corner = { r.Scale, r.Offset }
		elseif cc == "UIStroke" then
			if get(child, "Enabled") ~= false then
				node.mods.strokes = node.mods.strokes or {}
				table.insert(node.mods.strokes, {
					t = get(child, "Thickness"), c = color(get(child, "Color")),
					border = enumName(get(child, "ApplyStrokeMode")) == "Border", tr = get(child, "Transparency"),
				})
			end
		elseif cc == "UIGradient" then
			local seq = get(child, "Color")
			local kps = seq and seq.Keypoints
			if kps then
				node.mods.gradient = { a = color(kps[1].Value), b = color(kps[#kps].Value), rot = get(child, "Rotation") }
			end
		elseif cc == "UITextSizeConstraint" then
			node.mods.maxText = get(child, "MaxTextSize")
		elseif cc == "UIScale" then
			node.mods.scale = get(child, "Scale")
		else
			table.insert(node.children, dump(child))
		end
	end
	return node
end

local function scene(name, setup)
	setup()
	for _ = 1, 2 do
		client.RunService.Heartbeat:FireSync(0.3)
	end
	local gui = player.PlayerGui:FindFirstChild("SGAE_UI")
	fs.writeFile(outDir .. "/" .. name .. ".json", serde.encode("json", dump(gui)))
	print("scene", name)
end

scene("hud", function()
	Router.Close()
	Notifications.Show("🥚 Star Egg готово к вылуплению!", "success")
	Notifications.Show("🌙 Ночь! Редкие яйца ×2, появились Moon Melon", "night")
end)
scene("shop_eggs", function()
	Router.Open("Shop", "Eggs")
end)
scene("shop_food", function()
	Router.Open("Shop", "Food")
end)
scene("shop_upgrades", function()
	Router.Open("Shop", "Upgrades")
end)
scene("eggs", function()
	Router.Open("Eggs")
end)
scene("pets", function()
	Router.Open("Pets", "c1")
end)
scene("feed", function()
	Router.Open("Feed", "c3")
end)
scene("index", function()
	Router.Open("Index")
end)
scene("quests", function()
	Router.Open("Quests")
end)
process.exit(0)
