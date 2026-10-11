--[[
	Противники — тоже R6 (см. Visual/EnemyModel). Различаются цветами, бронёй,
	шлемами, щитами, оружием, размером и, главное, поведением.

	Health/Speed/Armor/Shield — базовые значения (масштабируются волной, см. Config/Waves).
	Armor — плоское снижение урона за каждый удар (не ниже 20 % урона, см. Logic/Combat).
	Leak  — сколько HP базы снимает враг, дошедший до конца.
	Reward — монет каждому игроку за убийство.
	Look  — внешний вид: цвета частей тела и набор снаряжения.
]]

export type Ability = {
	Kind: string,
	Interval: number?,
	Radius: number?,
	Duration: number?,
	Amount: number?,
	Thresholds: { number }?,
	Summon: string?,
	Count: number?,
	Delay: number?,
}

export type Enemy = {
	Id: string,
	Name: string,
	Description: string,
	Health: number,
	Speed: number,
	Armor: number,
	Shield: number,
	Leak: number,
	Reward: number,
	Scale: number,
	Stealth: boolean?,
	Boss: boolean?,
	Elite: boolean?,
	CcImmune: boolean?, -- не оглушается и не замедляется
	Abilities: { Ability },
	Look: { Head: Color3, Torso: Color3, Arms: Color3, Legs: Color3, Gear: { string } },
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local SKIN = c(245, 205, 48)

local list: { Enemy } = {
	{ Id = "basic", Name = "Grunt", Description = "A regular foot soldier.",
		Health = 22, Speed = 7, Armor = 0, Shield = 0, Leak = 1, Reward = 13, Scale = 1, Abilities = {},
		Look = { Head = SKIN, Torso = c(110, 110, 120), Arms = SKIN, Legs = c(60, 60, 70), Gear = { "hood" } } },
	{ Id = "runner", Name = "Runner", Description = "Fast but fragile.",
		Health = 14, Speed = 12, Armor = 0, Shield = 0, Leak = 1, Reward = 12, Scale = 0.9, Abilities = {},
		Look = { Head = SKIN, Torso = c(255, 140, 40), Arms = SKIN, Legs = c(40, 40, 50), Gear = { "headband" } } },
	{ Id = "tank", Name = "Tank", Description = "Slow and very tough.",
		Health = 140, Speed = 4.5, Armor = 1, Shield = 0, Leak = 4, Reward = 38, Scale = 1.35, Abilities = {},
		Look = { Head = SKIN, Torso = c(120, 80, 50), Arms = c(120, 80, 50), Legs = c(70, 50, 35), Gear = { "plates", "cap" } } },
	{ Id = "armored", Name = "Knight", Description = "Heavy armor reduces the damage of every hit. Use strong shots or poison.",
		Health = 60, Speed = 6, Armor = 3, Shield = 0, Leak = 3, Reward = 30, Scale = 1.05, Abilities = {},
		Look = { Head = SKIN, Torso = c(170, 175, 185), Arms = c(170, 175, 185), Legs = c(120, 125, 135), Gear = { "knightHelmet", "chestplate" } } },
	{ Id = "regenerator", Name = "Mender", Description = "Regenerates health if not hit for 1.5 seconds.",
		Health = 70, Speed = 6.5, Armor = 0, Shield = 0, Leak = 2, Reward = 30, Scale = 1,
		Abilities = { { Kind = "Regen", Amount = 0.07, Delay = 1.5 } },
		Look = { Head = SKIN, Torso = c(130, 60, 190), Arms = SKIN, Legs = c(70, 30, 110), Gear = { "regenCross" } } },
	{ Id = "shielded", Name = "Guard", Description = "An energy shield absorbs damage until it breaks. Poison goes through it.",
		Health = 45, Speed = 6.5, Armor = 0, Shield = 55, Leak = 3, Reward = 32, Scale = 1.05, Abilities = {},
		Look = { Head = SKIN, Torso = c(40, 110, 200), Arms = SKIN, Legs = c(30, 60, 120), Gear = { "towerShield", "visor" } } },
	{ Id = "healer", Name = "Medic", Description = "Heals nearby allies within 11 studs every 3 seconds.",
		Health = 55, Speed = 6, Armor = 0, Shield = 0, Leak = 2, Reward = 36, Scale = 1,
		Abilities = { { Kind = "Heal", Interval = 3, Radius = 11, Amount = 0.12 } },
		Look = { Head = SKIN, Torso = c(240, 240, 240), Arms = c(240, 240, 240), Legs = c(200, 200, 205), Gear = { "medCap", "staff" } } },
	{ Id = "stealth", Name = "Shade", Description = "Invisible to towers without hidden detection (see upgrades).",
		Health = 40, Speed = 8.5, Armor = 0, Shield = 0, Leak = 2, Reward = 33, Scale = 1, Stealth = true, Abilities = {},
		Look = { Head = c(30, 30, 40), Torso = c(30, 30, 40), Arms = c(30, 30, 40), Legs = c(20, 20, 28), Gear = { "ninjaMask" } } },
	{ Id = "elite", Name = "Elite Vanguard", Description = "An empowered enemy: armor, lots of health, immune to stuns and slows.",
		Health = 300, Speed = 6, Armor = 3, Shield = 0, Leak = 6, Reward = 110, Scale = 1.25, Elite = true, CcImmune = true, Abilities = {},
		Look = { Head = SKIN, Torso = c(150, 20, 30), Arms = c(40, 40, 45), Legs = c(30, 30, 35), Gear = { "spikedHelmet", "chestplate", "cape" } } },
	{ Id = "boss_brute", Name = "Brute", Description = "Wave 10 boss. Its stomp stuns nearby towers.",
		Health = 1100, Speed = 3.6, Armor = 1, Shield = 0, Leak = 25, Reward = 450, Scale = 2.2, Boss = true, CcImmune = true,
		Abilities = { { Kind = "Stomp", Interval = 9, Radius = 12, Duration = 1.5 } },
		Look = { Head = SKIN, Torso = c(90, 60, 40), Arms = SKIN, Legs = c(60, 40, 30), Gear = { "crown", "club" } } },
	{ Id = "boss_juggernaut", Name = "Juggernaut", Description = "Wave 20 boss. Stomps and summons knights at 66% and 33% health.",
		Health = 4000, Speed = 3.2, Armor = 4, Shield = 0, Leak = 40, Reward = 900, Scale = 2.5, Boss = true, CcImmune = true,
		Abilities = {
			{ Kind = "Stomp", Interval = 8, Radius = 13, Duration = 1.8 },
			{ Kind = "Summon", Thresholds = { 0.66, 0.33 }, Summon = "armored", Count = 4 },
		},
		Look = { Head = SKIN, Torso = c(80, 85, 95), Arms = c(80, 85, 95), Legs = c(55, 60, 70), Gear = { "knightHelmet", "chestplate", "hammer" } } },
	{ Id = "boss_warlord", Name = "Warlord", Description = "Final boss. Shield, stomp, summons knights at 66% and 33% health and enrages at 30%.",
		Health = 8500, Speed = 3.0, Armor = 4, Shield = 1500, Leak = 100, Reward = 1800, Scale = 2.8, Boss = true, CcImmune = true,
		Abilities = {
			{ Kind = "Stomp", Interval = 8, Radius = 14, Duration = 2 },
			{ Kind = "Summon", Thresholds = { 0.66, 0.33 }, Summon = "armored", Count = 4 },
			{ Kind = "Enrage", Thresholds = { 0.3 }, Amount = 1.4 },
		},
		Look = { Head = SKIN, Torso = c(25, 25, 30), Arms = c(150, 20, 30), Legs = c(25, 25, 30), Gear = { "crown", "spikedHelmet", "cape", "greatsword" } } },
}

local byId: { [string]: Enemy } = {}
for _, enemy in list do
	assert(byId[enemy.Id] == nil, "Duplicate enemy " .. enemy.Id)
	byId[enemy.Id] = enemy
end

return {
	List = list,
	ById = byId,
}
