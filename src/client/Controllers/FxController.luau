--[[
	FxController — превращает пачки событий сервера (MatchFx) в анимации башен,
	снаряды, трассеры, удары, кольца и звуки. Только визуал: урон уже посчитан сервером.
]]

local Players = game:GetService("Players")

local State = require(script.Parent.Parent.State)
local Effects = require(script.Parent.Effects)
local EnemyRenderer = require(script.Parent.EnemyRenderer)
local TowerAnimator = require(script.Parent.TowerAnimator)
local Sound = require(script.Parent.Sound)
local SettingsController = require(script.Parent.SettingsController)

local FxController = {}

FxController.Banner = Instance.new("BindableEvent") -- (text, color, small, subtitle) для HUD
FxController.Reward = Instance.new("BindableEvent") -- (amount) — для анимации денег в HUD

local SHOT = {
	pistol = { Color = Color3.fromRGB(255, 220, 120), Width = 0.12, Sound = "Pistol" },
	mg = { Color = Color3.fromRGB(255, 180, 80), Width = 0.1, Sound = "MachineGun" },
	sniper = { Color = Color3.fromRGB(190, 160, 255), Width = 0.25, Sound = "Sniper" },
}

local function matchId(): number?
	return Players.LocalPlayer:GetAttribute("MatchId")
end

local function handle(entry: any)
	local id = matchId()
	if not id then
		return
	end
	local kind = entry.k
	local tower = if entry.t then TowerAnimator.Get(id, entry.t) else nil
	if kind == "shot" then
		local style = SHOT[entry.w] or SHOT.pistol
		if tower then
			TowerAnimator.Attack(tower)
			local from = TowerAnimator.Muzzle(tower, entry.h)
			Effects.Tracer(from, entry.to + Vector3.new(0, 2.5, 0), style.Color, style.Width)
			Effects.Flash(from, style.Color, if entry.w == "sniper" then 1.4 else 0.7)
		end
		Sound.Play(style.Sound, 0.35)
	elseif kind == "arrow" then
		if tower then
			TowerAnimator.Attack(tower)
			local from = TowerAnimator.Muzzle(tower)
			local last = from
			Effects.Projectile(from, function()
				local p = EnemyRenderer.Position(id, entry.e)
				if p then
					last = p
				end
				return last
			end, entry.d or 0.3, "arrow", nil)
		end
		Sound.Play("Bow", 0.4)
	elseif kind == "toxic" then
		if tower then
			TowerAnimator.Attack(tower)
			local from = TowerAnimator.Muzzle(tower)
			local last = from
			Effects.Projectile(from, function()
				local p = EnemyRenderer.Position(id, entry.e)
				if p then
					last = p
				end
				return last
			end, entry.d or 0.4, "toxic", function(at)
				Effects.Puff(at, Color3.fromRGB(120, 255, 90), 5)
			end)
		end
		Sound.Play("Toxic", 0.4)
	elseif kind == "cloud" then
		Effects.Cloud(entry.at, entry.r)
	elseif kind == "melee" or kind == "axe" or kind == "claws" then
		if tower then
			TowerAnimator.Attack(tower, entry.n)
			local facing = entry.to - tower.Root.Position
			local color = if kind == "axe" then Color3.fromRGB(255, 120, 80) elseif kind == "claws" then Color3.fromRGB(230, 235, 255) else Color3.fromRGB(150, 210, 255)
			Effects.Slash(entry.to, facing, color, if kind == "axe" then 5 else 3.5)
			if kind == "axe" and entry.r and entry.r > 0 then
				Effects.Ring(entry.to, entry.r, Color3.fromRGB(255, 150, 90), 0.35)
			end
			if kind == "claws" and entry.f then
				Effects.Ring(tower.Root.Position - Vector3.new(0, 2.7, 0), 8, Color3.fromRGB(255, 255, 255), 0.4)
			end
		end
		Sound.Play(if kind == "axe" then "Axe" elseif kind == "claws" then "Claws" else "Sword", 0.45, if kind == "claws" then 1.4 else 1)
	elseif kind == "stomp" then
		Effects.Ring(entry.at - Vector3.new(0, 0, 0), entry.r, Color3.fromRGB(255, 80, 60), 0.7)
		Sound.Play("Stomp", 0.7)
	elseif kind == "heal" then
		Effects.Ring(entry.at, entry.r, Color3.fromRGB(110, 255, 140), 0.6)
	elseif kind == "summon" or kind == "enrage" then
		local at = entry.at or EnemyRenderer.Position(id, entry.e or 0)
		if at then
			Effects.Ring(at, 10, Color3.fromRGB(255, 60, 60), 0.6)
		end
	elseif kind == "death" then
		local position = EnemyRenderer.Position(id, entry.e)
		if position then
			Effects.Puff(position, if entry.boss then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(230, 230, 230), if entry.boss then 14 else 6)
			if entry.r and SettingsController.Get("popups") then
				Effects.Popup(position + Vector3.new(0, 1.5, 0), "+$" .. entry.r, Color3.fromRGB(255, 214, 80), if entry.boss then 34 else 22)
			end
		end
		if entry.r then
			FxController.Reward:Fire(entry.r)
		end
		Sound.Play("EnemyDeath", 0.3)
	elseif kind == "place" or kind == "upgrade" then
		if tower then
			Effects.Sparkle(tower.Root.Position, if kind == "upgrade" then Color3.fromRGB(255, 210, 80) else Color3.fromRGB(120, 220, 255))
		end
		Sound.Play(if kind == "upgrade" then "Upgrade" else "Place", 0.5)
	elseif kind == "sell" then
		Effects.Puff(entry.at + Vector3.new(0, 2, 0), Color3.fromRGB(255, 210, 90), 8)
		Sound.Play("Sell", 0.5)
	elseif kind == "leak" then
		Sound.Play("BaseHit", 0.6)
		FxController.Banner:Fire("-" .. tostring(entry.n), Color3.fromRGB(255, 70, 70), true)
	elseif kind == "wave" then
		Sound.Play("WaveStart", 0.5)
		local subtitle = if entry.boss then "Boss Wave!" elseif entry.elite then "Elite Wave" else nil
		FxController.Banner:Fire("Wave " .. entry.n, if entry.boss then Color3.fromRGB(255, 80, 96) elseif entry.elite then Color3.fromRGB(255, 160, 60) else Color3.fromRGB(255, 255, 255),
			false, subtitle)
	elseif kind == "boss" then
		Sound.Play("BossSpawn", 0.8)
	elseif kind == "victory" then
		Sound.Play("Victory", 0.8)
	elseif kind == "defeat" then
		Sound.Play("Defeat", 0.8)
	end
end

function FxController.Init()
	State.Fx.Event:Connect(function(entry)
		local ok, err = pcall(handle, entry)
		if not ok then
			warn("[Fx]", err)
		end
	end)
end

return FxController
