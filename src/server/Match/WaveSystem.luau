--[[
	WaveSystem — фазы матча и волны.
	Prep (подготовка) → Wave → Intermission → Wave → ... → Victory / Defeat.

	• Волна закончена, когда все враги волны выпущены и живых не осталось.
	• Защита от зависаний: если волна идёт дольше лимита, следующая начинается сама;
	  враги, застрявшие дольше расчётного времени, считаются дошедшими (EnemySystem).
	• Победа: выпущена последняя волна и живых врагов (включая боссов) нет.
	• Пропуск паузы: если все игроки проголосовали «Skip».
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Waves = require(Shared.Config.Waves)
local Economy = require(Shared.Config.Economy)
local Game = require(Shared.Config.Game)

local WaveSystem = {}
WaveSystem.__index = WaveSystem

function WaveSystem.new(match: any)
	return setmetatable({
		Match = match,
		Wave = 0,
		Max = Waves.Max,
		Phase = "Prep",
		Timer = Game.Match.PrepTime,
		Queue = {} :: { { At: number, Enemy: string } },
		Config = nil :: any,
		WaveStart = 0,
		Rewarded = {} :: { [number]: boolean },
	}, WaveSystem)
end

function WaveSystem:CurrentConfig(): any
	return self.Config or Waves.Get(math.max(1, self.Wave))
end

function WaveSystem:StartWave(number: number)
	local match = self.Match
	-- Бонус за предыдущую волну, если её «перебила» следующая
	if self.Wave > 0 then
		self:Reward(self.Wave)
	end
	self.Wave = number
	self.Config = Waves.Get(number)
	self.Phase = "Wave"
	self.WaveStart = match.Time
	self.Queue = {}
	for _, group in self.Config.Groups do
		for i = 0, group.Count - 1 do
			table.insert(self.Queue, { At = match.Time + group.Start + group.Interval * i, Enemy = group.Enemy })
		end
	end
	table.sort(self.Queue, function(a, b)
		return a.At < b.At
	end)
	match:ClearVotes("Skip")
	match:Fx({ k = "wave", n = number, elite = self.Config.Elite, boss = self.Config.Boss })
	if self.Config.Elite then
		match:Notify("⚠ Elite wave " .. number, "warn")
	end
	match:MarkDirty()
end

function WaveSystem:Reward(number: number)
	if self.Rewarded[number] then
		return
	end
	self.Rewarded[number] = true
	self.Match:RewardAll(Economy.WaveBonusBase + Economy.WaveBonusPerWave * number)
	self.Match.WavesCleared = math.max(self.Match.WavesCleared, number)
end

function WaveSystem:Skip(): boolean
	if self.Phase == "Prep" or self.Phase == "Intermission" then
		self.Timer = 0
		return true
	end
	return false
end

function WaveSystem:Step(dt: number)
	local match = self.Match
	if self.Phase == "Prep" or self.Phase == "Intermission" then
		self.Timer -= dt
		if self.Timer <= 0 then
			self:StartWave(self.Wave + 1)
		end
		return
	end
	if self.Phase ~= "Wave" then
		return
	end
	-- Выпуск врагов по расписанию
	while #self.Queue > 0 and self.Queue[1].At <= match.Time do
		local entry = table.remove(self.Queue, 1)
		match.Enemies:Spawn(entry.Enemy, self.Config)
	end
	local alive = match.Enemies:Count()
	if #self.Queue == 0 and alive == 0 then
		self:Reward(self.Wave)
		if self.Wave >= self.Max then
			match:Finish(true)
		else
			self.Phase = "Intermission"
			self.Timer = Game.Match.Intermission
			match:MarkDirty()
		end
		return
	end
	local limit = Game.Match.WaveTimeLimitBase + Game.Match.WaveTimeLimitPerWave * self.Wave
	if #self.Queue == 0 and self.Wave < self.Max and match.Time - self.WaveStart > limit then
		self:StartWave(self.Wave + 1)
	end
end

-- Сколько секунд до следующего события для HUD
function WaveSystem:TimerValue(): number
	if self.Phase == "Prep" or self.Phase == "Intermission" then
		return math.max(0, self.Timer)
	end
	return 0
end

return WaveSystem
