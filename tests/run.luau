--[[
	Юнит-тесты чистой логики и конфигов. Запуск (нужен Lune: https://lune-org.github.io):
	    lune run tests/run.luau
	Модули из src/shared загружаются с эмуляцией Roblox-дерева (script.Parent.X),
	поэтому тестируется ровно тот же код, что и в игре.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = "src/shared"
local cache = {}
local nodes = {}

-- Lune читает файлы с yield, а метаметоды не могут уступать управление,
-- поэтому заранее загружаем всё дерево src/shared в память.
local files: { [string]: string } = {}
local dirs: { [string]: boolean } = {}
local function preload(path: string)
	dirs[path] = true
	for _, name in fs.readDir(path) do
		local full = path .. "/" .. name
		if fs.isDir(full) then
			preload(full)
		elseif string.match(name, "%.luau$") then
			files[full] = fs.readFile(full)
		end
	end
end
preload(ROOT)

-- Простая замена Roblox Random (детерминированная, LCG)
local RandomStub = {}
RandomStub.__index = RandomStub
function RandomStub.new(seed: number?)
	return setmetatable({ state = (seed or os.clock() * 1e6) % 2147483647 }, RandomStub)
end
function RandomStub:NextNumber(min: number?, max: number?)
	self.state = (self.state * 48271) % 2147483647
	local r = self.state / 2147483647
	if min and max then
		return min + (max - min) * r
	end
	return r
end
function RandomStub:NextInteger(min: number, max: number)
	return math.floor(self:NextNumber(min, max + 1))
end

local requireNode

local function node(path: string, parent: any?)
	if nodes[path] then
		return nodes[path]
	end
	local n = setmetatable({ __path = path, Parent = parent }, {
		__index = function(self, key)
			local childPath = path .. "/" .. key
			if dirs[childPath] or files[childPath .. ".luau"] then
				return node(childPath, self)
			end
			error("No child " .. key .. " in " .. path)
		end,
	})
	nodes[path] = n
	return n
end

requireNode = function(n: any)
	local path = rawget(n, "__path")
	if cache[path] ~= nil then
		return cache[path]
	end
	local file = if files[path .. ".luau"] then path .. ".luau" else path .. "/init.luau"
	local env = setmetatable({
		script = n,
		require = requireNode,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		Color3 = roblox.Color3,
		CFrame = roblox.CFrame,
		Random = RandomStub,
	}, { __index = getfenv(0) })
	local chunk = luau.load(files[file], { debugName = file, environment = env })
	local result = chunk()
	cache[path] = result
	return result
end

local shared = node(ROOT, nil)
local function load(dotted: string)
	local current = shared
	for part in string.gmatch(dotted, "[^%.]+") do
		current = current[part]
	end
	return requireNode(current)
end

-- Мини-фреймворк
local passed, failed = 0, 0
local currentSuite = ""
local t = {}
function t.ok(cond: any, message: string)
	if cond then
		passed += 1
	else
		failed += 1
		print(string.format("  ✗ [%s] %s", currentSuite, message))
	end
end
function t.eq(actual: any, expected: any, message: string)
	t.ok(actual == expected, string.format("%s (ожидалось %s, получено %s)", message, tostring(expected), tostring(actual)))
end
function t.near(actual: number, expected: number, eps: number, message: string)
	t.ok(math.abs(actual - expected) <= eps, string.format("%s (ожидалось ≈%s, получено %s)", message, tostring(expected), tostring(actual)))
end
t.load = load
t.Random = RandomStub
t.readFile = fs.readFile
t.readDir = fs.readDir
t.isFile = fs.isFile

for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") then
		currentSuite = name
		local spec = luau.load(fs.readFile("tests/" .. name), { debugName = name })()
		local ok, err = pcall(spec, t)
		if not ok then
			failed += 1
			print(string.format("  ✗ [%s] crashed: %s", name, tostring(err)))
		end
	end
end

print(string.format("\nПройдено: %d, провалено: %d", passed, failed))
process.exit(if failed == 0 then 0 else 1)
