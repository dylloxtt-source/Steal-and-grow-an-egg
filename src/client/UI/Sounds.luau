--[[
	Короткие звуки интерфейса из встроенных ресурсов клиента Roblox (rbxasset://).
	Если звук недоступен, он просто не проиграется — ошибок не будет.
]]

local SoundService = game:GetService("SoundService")

local Sounds = {}

local IDS = {
	click = "rbxasset://sounds/electronicpingshort.wav",
	success = "rbxasset://sounds/electronicpingshort.wav",
	error = "rbxasset://sounds/clickfast.wav",
	alert = "rbxasset://sounds/electronicpingshort.wav",
	hatch = "rbxasset://sounds/swoosh.wav",
	hit = "rbxasset://sounds/swoosh.wav",
}

local cache: { [string]: Sound } = {}
Sounds.Enabled = true

function Sounds.Play(name: string, pitch: number?)
	if not Sounds.Enabled then
		return
	end
	local id = IDS[name]
	if not id then
		return
	end
	local sound = cache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = 0.5
		sound.Parent = SoundService
		cache[name] = sound
	end
	sound.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(sound)
end

return Sounds
