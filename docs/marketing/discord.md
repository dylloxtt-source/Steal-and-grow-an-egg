# Пост для Discord

Каждая версия короче 2000 символов, её можно отправить одним сообщением без Nitro.
Скопируй блок целиком (между линиями), вставь в Discord и прикрепи `thumbnail.png`.
Перед публикацией впиши цену вместо `___`.

---

## English

```
# ⚔️ R6 TOWER DEFENSE — FULL GAME FOR SALE

A co-op Tower Defense in the classic **R6 + studs** style. Full source code, clean structure, easy to rebrand and publish.

## 🎮 Gameplay
> • **8 R6 towers**, 5 levels each: Swordsman, Archer, Pistol, Toxic, Sniper, Lumberjack, Minigunner, Wolverine
> • **12 enemies + 3 bosses** (Brute, Juggernaut, Warlord): armor, shields, healers, stealth, stun stomps, summons, rage
> • **20 waves, 3 base lives**: every leak hurts
> • **5 studs-style maps**: Greenfield → Desert → Snow → Ruins → Neon City (Easy → Insane)
> • **4-player co-op**: lobby with 4 elevators, the party leader picks the map and party size

## 💎 Progression
> • Gem **tower shop** (Common → Legendary), new players start with the Swordsman
> • 5-slot **loadout**, **auto skip**, x2 speed vote, settings menu
> • **DataStore** saves with session lock, retries and safe error handling

## 🛠 For developers
> • **Rojo** project, 100% Luau, server-authoritative: one rate-limited remote, the server checks every action
> • All balance in config files: towers, enemies, waves, economy, maps
> • **790 unit + 188 integration** automated tests, docs included
> • UI for **PC and mobile**
> • No borrowed assets: procedural animations, no third-party animation or audio IDs

## 📦 You get
Full source · thumbnail + icon · step-by-step setup guide (Rojo → Studio)

💰 **Price:** `___`
📩 **DM me** for more screenshots, a gameplay video or a live demo.

-# Fresh, unreleased project, so there are no player stats yet.
```

---

## Русский

```
# ⚔️ R6 TOWER DEFENSE — ПРОДАЮ ГОТОВУЮ ИГРУ

Кооперативная Tower Defense в классическом стиле **R6 + студы**. Полный исходный код, понятная структура, легко сменить название и опубликовать.

## 🎮 Геймплей
> • **8 R6-башен** по 5 уровней: Swordsman, Archer, Pistol, Toxic, Sniper, Lumberjack, Minigunner, Wolverine
> • **12 врагов + 3 босса** (Brute, Juggernaut, Warlord): броня, щиты, лекари, невидимки, оглушающий топот, призыв, ярость
> • **20 волн, 3 жизни у базы**: каждый прорыв на счету
> • **5 карт в студ-стиле**: Greenfield → Desert → Snow → Ruins → Neon City (от Easy до Insane)
> • **Кооп до 4 игроков**: лобби с 4 лифтами, лидер выбирает карту и размер группы

## 💎 Прогресс
> • **Магазин башен** за гемы (Common → Legendary), новички начинают с мечником
> • **Набор из 5 башен**, **авто-скип**, голосование за x2, меню настроек
> • Сохранение в **DataStore**: защита от двух серверов, повторы, аккуратная обработка ошибок

## 🛠 Для разработчика
> • Проект на **Rojo**, 100% Luau, сервер решает всё: один remote с лимитом запросов, каждое действие проверяется
> • Весь баланс в конфигах: башни, враги, волны, экономика, карты
> • **790 модульных + 188 интеграционных** автотестов, документация в комплекте
> • Интерфейс для **ПК и телефона**
> • Без чужих ассетов: анимации процедурные, без сторонних ID анимаций и звуков

## 📦 Что получаешь
Полный исходник · тумбнейл и иконка · пошаговая инструкция по запуску (Rojo → Studio)

💰 **Цена:** `___`
📩 **Пиши в ЛС**: скину ещё скриншоты, видео геймплея или покажу демо.

-# Свежий проект, ещё не публиковался, поэтому статистики игроков пока нет.
```

---

## Картинки

| Файл | Размер | Куда |
|---|---|---|
| `thumbnail.png` | 1920×1080 | тумбнейл игры на Roblox, картинка к посту |
| `icon.png` | 512×512 | иконка игры на Roblox |

Картинки — настоящий 3D-рендер (three.js в Chromium) тех же моделей башен, врагов и карты Snow Valley,
что строит игра: позы, оружие, студы и цвета — из кода игры. Ночное освещение, северное сияние, туман,
снег и вспышки выстрелов добавлены для обложки: в самой игре Snow Valley дневная, а свет и материалы
Roblox выглядят иначе. Для поста стоит добавить пару настоящих скриншотов или короткое видео из Studio.

Пересобрать:

```
npm i three@0.170.0                        # в любой папке
lune run tools/marketing/scene.luau out    # сцена из моделей игры → out/scene.json
node tools/marketing/render.js out <Fredoka One .ttf> <папка>/node_modules/three
```
