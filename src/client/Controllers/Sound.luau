--[[
	Проигрывание звуков по ключам из Config/Sounds. Пустой ключ — тишина.
	Частые звуки (пулемёт) ограничены по частоте.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)

local Sound = {}
Sound.Enabled = true

local cache: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}

function Sound.Play(key: string, volume: number?, pitch: number?)
	if not Sound.Enabled then
		return
	end
	local id = Sounds[key]
	if not id or id == "" then
		return
	end
	local now = os.clock()
	if (lastPlayed[key] or 0) + 0.06 > now then
		return
	end
	lastPlayed[key] = now
	local sound = cache[key]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = key
		sound.SoundId = id
		sound.Parent = SoundService
		cache[key] = sound
	end
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(sound)
end

return Sound
