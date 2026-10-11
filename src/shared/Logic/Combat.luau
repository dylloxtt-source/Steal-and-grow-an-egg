--[[
	Расчёт урона и эффектов. Правила:
	• Броня — плоское снижение урона за удар; Pierce игнорирует долю брони.
	  Удар никогда не наносит меньше 20 % исходного урона.
	• Щит поглощает урон до разрушения; излишек проходит в здоровье.
	• Яд игнорирует броню и щит. На враге одновременно действует ОДИН яд:
	  новое попадание берёт максимум из DPS и обновляет длительность,
	  но длительность не превышает длительности самого сильного примененного яда.
	• Оглушение не работает на элите и боссах (CcImmune); после оглушения
	  враг 1.5 сек. невосприимчив к новому (нет «вечного станлока»).
	• Замедление: берётся сильнейшее активное, не суммируется.
]]

local Combat = {}

Combat.MinDamageFraction = 0.2
Combat.StunImmunity = 1.5

export type Target = {
	Health: number,
	MaxHealth: number,
	Shield: number,
	Armor: number,
	CcImmune: boolean,
	PoisonDps: number,
	PoisonUntil: number,
	SlowFactor: number,
	SlowUntil: number,
	StunUntil: number,
	StunImmuneUntil: number,
	LastHit: number,
}

function Combat.Mitigate(damage: number, armor: number, pierce: number?): number
	local effectiveArmor = armor * (1 - math.clamp(pierce or 0, 0, 1))
	return math.max(damage * Combat.MinDamageFraction, damage - effectiveArmor)
end

-- Прямой урон. Возвращает фактически нанесённый урон (здоровье + щит).
function Combat.Hit(target: Target, damage: number, pierce: number?, now: number): number
	if target.Health <= 0 or damage <= 0 then
		return 0
	end
	local amount = Combat.Mitigate(damage, target.Armor, pierce)
	local dealt = 0
	if target.Shield > 0 then
		local absorbed = math.min(target.Shield, amount)
		target.Shield -= absorbed
		amount -= absorbed
		dealt += absorbed
	end
	local toHealth = math.min(target.Health, amount)
	target.Health -= toHealth
	dealt += toHealth
	target.LastHit = now
	return dealt
end

function Combat.ApplyPoison(target: Target, dps: number, duration: number, now: number)
	if target.Health <= 0 then
		return
	end
	local active = target.PoisonUntil > now
	if active then
		target.PoisonDps = math.max(target.PoisonDps, dps)
		target.PoisonUntil = math.max(target.PoisonUntil, now + duration)
	else
		target.PoisonDps = dps
		target.PoisonUntil = now + duration
	end
end

-- Тик яда за dt. Возвращает нанесённый урон.
function Combat.TickPoison(target: Target, dt: number, now: number): number
	if target.PoisonUntil <= now or target.Health <= 0 then
		if target.PoisonUntil <= now then
			target.PoisonDps = 0
		end
		return 0
	end
	local amount = math.min(target.Health, target.PoisonDps * dt)
	target.Health -= amount
	target.LastHit = now
	return amount
end

function Combat.ApplyStun(target: Target, duration: number, now: number): boolean
	if target.CcImmune or target.Health <= 0 or now < target.StunImmuneUntil then
		return false
	end
	target.StunUntil = math.max(target.StunUntil, now + duration)
	target.StunImmuneUntil = target.StunUntil + Combat.StunImmunity
	return true
end

function Combat.ApplySlow(target: Target, factor: number, duration: number, now: number): boolean
	if target.CcImmune or target.Health <= 0 then
		return false
	end
	if target.SlowUntil > now and target.SlowFactor >= factor then
		target.SlowUntil = math.max(target.SlowUntil, now + duration)
		return true
	end
	target.SlowFactor = factor
	target.SlowUntil = now + duration
	return true
end

-- Множитель скорости с учётом оглушения и замедления
function Combat.SpeedFactor(target: Target, now: number): number
	if target.StunUntil > now then
		return 0
	end
	if target.SlowUntil > now then
		return 1 - target.SlowFactor
	end
	return 1
end

function Combat.Heal(target: Target, amount: number)
	if target.Health > 0 then
		target.Health = math.min(target.MaxHealth, target.Health + amount)
	end
end

return Combat
