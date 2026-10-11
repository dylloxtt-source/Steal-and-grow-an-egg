--[[ Таблицы баланса из конфигов (для документации). Запуск: lune run tools/tables.luau ]]
local Engine = require("../tests/sim/Engine")
local realm = Engine.Realm(true)
local S = Engine.SharedNode
local Towers = realm.require(S.Config.Towers)
local Enemies = realm.require(S.Config.Enemies)
local Maps = realm.require(S.Config.Maps)
local Waves = realm.require(S.Config.Waves)
print("| # | Башня | Роль | Цена | Урон L1 | Радиус L1 | Атак/с L1 | DPS L1 → L5 | Всего за L5 | Особое |")
print("|---|---|---|---|---|---|---|---|---|---|")
for i, t in Towers.List do
  local l1, l5 = t.Levels[1], t.Levels[5]
  print(string.format("| %d | %s %s | %s | $%d | %d | %s | %.2f | %d → %d | $%d | %s |", i, t.Icon, t.Name, t.Role, l1.Cost, l1.Damage, tostring(l1.Range), 1/l1.Cooldown, Towers.Dps(l1), Towers.Dps(l5), Towers.TotalSpent(t.Id, 5), l5.Text))
end
print()
print("| Враг | HP | Скорость | Броня | Щит | Урон базе | Награда | Особенность |")
print("|---|---|---|---|---|---|---|---|")
for _, e in Enemies.List do
  local ab = {}
  for _, a in e.Abilities do table.insert(ab, a.Kind) end
  if e.Stealth then table.insert(ab, "Stealth") end
  if e.CcImmune then table.insert(ab, "без контроля") end
  print(string.format("| %s | %d | %s | %d | %d | %d | %d | %s |", e.Name, e.Health, tostring(e.Speed), e.Armor, e.Shield, e.Leak, e.Reward, table.concat(ab, ", ")))
end
print()
for _, m in Maps.List do print(m.Id, m.Name, m.Difficulty, m.BaseHealth, m.Theme, m.Description) end
for n = 1, 30 do local w = Waves.Get(n); local g = {} for _, x in w.Groups do table.insert(g, x.Enemy .. "×" .. x.Count) end print(n, w.Total, w.Boss or "", w.Elite and "elite" or "", table.concat(g, " "), string.format("hp×%.2f", w.HealthMult)) end
