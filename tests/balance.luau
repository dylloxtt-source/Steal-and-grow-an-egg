--[[
	Балансный прогон: бот-игрок проходит матч на каждой карте (ускоренно, без клиента).
	Запуск: lune run tests/balance.luau [players] [mapId]
	Бот выбирает места с наибольшим покрытием дороги, ставит смесь башен и улучшает их.
]]

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local Engine = require("./sim/Engine")
local Vector3 = roblox.Vector3

local playerCount = tonumber(process.args[1]) or 1
local onlyMap = process.args[2]
local verbose = process.args[3] == "v"

local server = Engine.Realm(true)
server.require(Engine.ServerNode)
local S = Engine.ServerNode.Services
local MatchService = server.require(S.MatchService)
local Maps = server.require(Engine.SharedNode.Config.Maps)
local Towers = server.require(Engine.SharedNode.Config.Towers)
local Placement = server.require(Engine.SharedNode.Logic.Placement)
local MapLayout = server.require(Engine.SharedNode.Logic.MapLayout)

local players = {}
for i = 1, playerCount do
	local p = Engine.NewPlayer("Bot" .. i)
	Engine.Join(p)
	Engine.SpawnCharacter(p, Vector3.new(i * 3, 3, 40))
	table.insert(players, p)
end
task.wait(0.3)

local ORDER = { "archer", "swordsman", "archer", "toxic", "pistol", "sniper", "minigunner", "lumberjack", "wolverine", "sniper", "toxic", "minigunner" }

local function spots(mapId: string, range: number)
	local layout = MapLayout.Get(mapId)
	local map = layout.Map
	local samples = {}
	local d = 0
	while d < layout.Path.Length do
		table.insert(samples, (layout.Path:At(d)))
		d += 2
	end
	local list = {}
	for x = -map.Bounds.X + 2, map.Bounds.X - 2, 3 do
		for z = -map.Bounds.Y + 2, map.Bounds.Y - 2, 3 do
			if Placement.Check(mapId, x, z, {}) then
				local cover = 0
				for _, s in samples do
					if (s - Vector3.new(x, 0, z)).Magnitude <= range then
						cover += 1
					end
				end
				table.insert(list, { X = x, Z = z, Cover = cover })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Cover > b.Cover
	end)
	return list
end

local function run(mapId: string)
	local match = MatchService:Create(players, mapId)
	assert(match, "match not created")
	if verbose then
		local original = match.Enemies.Leak
		match.Enemies.Leak = function(self, enemy)
			if enemy.Def.Boss or enemy.Def.Elite then
				print(string.format("   LEAK %s hp %d/%d shield %d wave %d", enemy.Def.Name, enemy.Health, enemy.MaxHealth, enemy.Shield, match.Waves.Wave))
			end
			return original(self, enemy)
		end
	end
	local spotCache = {}
	local placedIndex = {}
	local nextDecision = 0
	local simulated = 0
	local reportedWave = 0
	while not match.Ended and simulated < 4000 do
		if match.Time >= nextDecision then
			nextDecision = match.Time + 1
			for pi, player in players do
				local state = match.PlayerState[player.UserId]
				-- Жадная стратегия: действие с наибольшим приростом DPS на монету
				local bestAction, bestValue = nil, 0
				for _, tower in match.Towers.List do
					if tower.OwnerId == player.UserId and tower.Level < 5 then
						local nextStats = tower.Def.Levels[tower.Level + 1]
						local gain = Towers.Dps(nextStats) - Towers.Dps(tower.Stats) + (if nextStats.Detect and not tower.Stats.Detect then 15 else 0)
						local value = gain / nextStats.Cost
						if value > bestValue then
							bestAction, bestValue = { Kind = "upgrade", Tower = tower, Cost = nextStats.Cost }, value
						end
					end
				end
				local count = match.Towers:CountFor(player.UserId)
				placedIndex[pi] = placedIndex[pi] or 0
				if count < 15 then
					local nextTower = ORDER[(placedIndex[pi] % #ORDER) + 1]
					local def = Towers.ById[nextTower]
					local value = Towers.Dps(def.Levels[1]) * 1.4 / def.Levels[1].Cost
					if value > bestValue or bestAction == nil then
						bestAction, bestValue = { Kind = "place", TowerId = nextTower, Cost = def.Levels[1].Cost }, value
					end
				end
				if bestAction and state.Cash >= bestAction.Cost then
					if bestAction.Kind == "upgrade" then
						match.Towers:Upgrade(player, bestAction.Tower.Uid)
					else
						local def = Towers.ById[bestAction.TowerId]
						local range = def.Levels[1].Range
						local key = mapId .. math.floor(range)
						spotCache[key] = spotCache[key] or spots(mapId, range)
						for _, spot in spotCache[key] do
							if Placement.Check(mapId, spot.X, spot.Z, match.Towers:Footprints()) then
								local ok, _, data = match.Towers:Place(player, bestAction.TowerId, spot.X, spot.Z)
								if ok then
									placedIndex[pi] += 1
									if bestAction.TowerId == "sniper" then
										match.Towers:SetPriority(player, data.uid, "Strongest")
									end
								end
								break
							end
						end
					end
				end
			end
		end
		match:Step(0.5)
		simulated += 0.5
		if verbose and match.Waves.Wave ~= reportedWave and match.Waves.Wave % 2 == 0 then
			reportedWave = match.Waves.Wave
			local state = match.PlayerState[players[1].UserId]
			local dps = 0
			for _, tower in match.Towers.List do
				dps += Towers.Dps(tower.Stats)
			end
			print(string.format("   wave %2d t=%4d earned %6d cash %5d towers %2d dps %5d base %3d leaked %d", match.Waves.Wave, match.Time,
				state.Earned, state.Cash, #match.Towers.List, dps, match.BaseHealth, match.Enemies.Leaked))
		end
	end
	local result = match.Result or "Timeout"
	local levels = {}
	for _, tower in match.Towers.List do
		levels[tower.TowerId] = (levels[tower.TowerId] or "") .. tower.Level
	end
	local summary = {}
	for id, l in levels do
		table.insert(summary, id .. ":" .. l)
	end
	print(string.format("%-10s %-8s wave %2d/%d  base %3d/%d  leaked %3d  killed %4d  t=%4ds  towers %s", mapId, result,
		match.Waves.Wave, match.Waves.Max, match.BaseHealth, match.BaseMaxHealth, match.Enemies.Leaked, match.Enemies.Killed,
		math.floor(match.Time), table.concat(summary, " ")))
	MatchService:Close(match)
end

for _, map in Maps.List do
	if not onlyMap or onlyMap == map.Id then
		local ok, err = pcall(run, map.Id)
		if not ok then
			print("ERROR", map.Id, err)
			process.exit(1)
		end
	end
end
for _, w in Engine.Warnings do
	print("warn", w)
end
process.exit(0)
