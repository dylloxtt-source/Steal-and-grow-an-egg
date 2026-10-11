# Этап 1. Исследование оригинала «Steal an Egg»

## Как проводилось исследование и его ограничения

- Поиск по открытым источникам: новостные статьи, гайды фан-сайтов, фан-вики.
- **Ограничение среды:** страницы по ссылкам открыть не удалось (DNS для загрузки страниц заблокирован в этой среде).
  Все выводы ниже сделаны по **сводкам результатов поиска**, а не по полному тексту статей. Поэтому точные
  числа (таймеры, шансы, цены) оригинала я **не использую как данные** — только как ориентир порядка величин.
- Официальная страница игры на Roblox недоступна для проверки; по данным Massively OP (август 2026) игра
  была снята Roblox с платформы, а затем Roblox ввёл ограничения на «ленточные» механики наград для младших игроков.
  Текущий статус игры противоречив в разных источниках.
- Исходный код, модели, текстуры и названия существ оригинала **не копировались**.

Обозначения уверенности: **П** — подтверждено несколькими независимыми источниками; **И** — один источник
или противоречия; **Н** — наблюдение по присланным скриншотам; **С** — собственное решение.

## Таблица механик

| Механика оригинала | Как работает | Источник / уверенность | Чем интересна | Адаптация в нашей игре | Изменения под выращивание |
|---|---|---|---|---|---|
| Основной цикл | Взять яйцо в биоме → донести до базы → вылупить → питомец приносит деньги → улучшения скорости и базы → новые биомы | games.gg, Sportskeeda, FPT Shop — **П** | Короткий понятный цикл риска и награды | Тот же каркас: дорожка с 5 биомами, база, доход | Вылупление — лишь начало: дальше кормление, 4 стадии роста, черты |
| Биомы и стражи | В каждом биоме гнездо с животным-стражем; страж догоняет и сбивает игрока; дальние биомы требуют всё большей скорости | games.gg, mmoexp, androidguias — **П** (пороги скорости — **И**) | Скорость становится главным показателем прогрессии | Стражи в зонах 2–5 гонятся только за теми, кто несёт яйцо; скорость стража 20→42 | Дальние зоны дают редкие яйца и редкую еду (Ember Pepper, Starfruit) |
| Скорость и беговая дорожка | Скорость растёт на «беговой дорожке» на базе (с встроенной видеолентой), часть продаётся за Robux | Dexerto, Sportskeeda, allthings.how — **П** | Наглядная цифра роста | Скорость покупается за монеты (64 уровня) + черты существ. **Без** механик бесконечной ленты и AFK-фарма | Черты Speed у взрослых существ — причина растить, а не только продавать |
| Кража у игроков | Игроки сбивают несущих яйцо (бита, капканы), подбирают выпавшее; берут незащищённые яйца с баз | allthings.how, gameboost, Sportskeeda — **П** (детали — **И**) | Социальное напряжение, перехваты | Бита выбивает яйца; кража из инкубатора по удержанию [F]; украденное можно отбить | Вылупившихся существ украсть **нельзя** (честность); страховка 20 % владельцу |
| Бита и капканы | Бита — короткая дистанция, сбивает с ног; капкан держит 5 с | allthings.how — **И** | Простой PvP-инструмент | Бита (кулдаун 0,8 с, 8 студов, оглушение 1,2 с). Капканы не делали (MVP) | — |
| Безопасная зона | Есть Safe Zone у старта; базы не безопасны | гайды — **И**; скриншот 1 — **Н** | Место для магазинов и передышки | Площадь — Safe Zone (нельзя бить, стражи не заходят) | Магазины еды/семян в Safe Zone |
| Ночь | Яйца в биомах обновляются в начале ночи (около 4,5 мин), ночью особые бонусы/биомы | robloxgameswiki, скриншоты 1 и 5 — **И/Н** | Повод возвращаться по таймеру | Цикл 270 с день + 90 с ночь; ночью яйца перезагружаются, удача Rare+ ×2, Moon Melon, мутации ×2 | Ночная еда для быстрого роста |
| Редкости | Common → Uncommon → Rare → Epic → Legendary → Mythic → Cosmic → Secret → … | games.gg — **И** | Длинная лестница целей | 7 редкостей: Common…Mythic + Secret (только с дорожки, чаще ночью) | Пороги роста и аппетит растут с редкостью |
| Мутации и размеры | Множители дохода (Silver, Golden, Rainbow…), размер влияет на доход | allthings.how, gameboost — **П** (числа — **И**) | Повод открывать ещё | Мутации None/Silver ×1.25/Golden ×2/Rainbow ×3 и размеры Tiny/Normal/Big/Huge | Мутация видна на модели и на всех стадиях |
| Fuse Machine | 3 одинаковых питомца → 1 более редкий | eldorado, скриншот 1 («Fuse Machine 0/3») — **П/Н** | Сток лишних питомцев | Не в MVP: роль стока выполняет продажа и рост | Кандидат на этап «Расширение» |
| Index | Коллекция питомцев, за открытия награды скоростью и деньгами | eldorado/techwiser, скриншоты — **П/Н** | Коллекционирование | Индекс: награда при открытии + **постоянный** +2 % дохода за вид | — |
| Таймеры яиц | Яйца на базе вылупляются по своим таймерам, открываются вручную | eldorado, скриншот 4 — **П/Н** | Возврат на базу | Таймеры идут и офлайн; кнопка Open, «Hatch All», ускорение за монеты | Инкубатор можно ускорить улучшением и чертами |
| Монетизация | Платные яйца, скорость, звёзды-маунты, недельный сток | скриншоты 2, 3 — **Н** | — | **Без pay-to-win**: всё за игровую валюту | — |

## Выводы для дизайна

1. Цикл «рискнуть → донести → вырастить» оставляем, но центр тяжести смещаем в **выращивание**: стадии, еда, черты и ферма.
2. Скорость — главный барьер дальних зон, но копится через экономику базы, а не через AFK.
3. Кража должна быть напряжённой и при этом **не катастрофической**: страхуем владельца, защищаем новичков,
   даём замок базы и перезарядку жертвы, существ не крадут вовсе.
4. Слабые места оригинала, которые мы исправляем: pay-to-win, AFK-фарм, потеря ценного без шанса отыграться,
   долгие пустые пробежки без занятий (у нас на дорожке есть еда, стражи и чужие воры).

## Источники

- [Massively OP — Roblox clamps down … after Steal an Egg goes viral](https://massivelyop.com/2026/08/29/roblox-clamps-down-on-gen-ai-brainrot-scrolling-games-after-steal-an-egg-goes-viral/)
- [Player.One — Roblox's Steal An Egg Is Beating Some of the Platform's Biggest Games](https://www.player.one/robloxs-steal-egg-beating-some-platforms-biggest-games-164086)
- [Dexerto — Viral Roblox game recreates Black Mirror's treadmill scroll](https://www.dexerto.com/roblox/viral-roblox-game-recreates-black-mirrors-iconic-treadmill-scroll-3401534/)
- [PCGamesN — Steal an Egg codes](https://www.pcgamesn.com/roblox/steal-an-egg-codes)
- [games.gg — All eggs, pets and income rates](https://games.gg/roblox/guides/steal-an-egg-all-eggs-pets-and-income-rates/)
- [games.gg — Beginner Guide: Master the Nest-to-Base Loop](https://games.gg/roblox/guides/steal-an-egg-beginner-guide/)
- [Sportskeeda — Steal An Egg: A beginner's guide](https://www.sportskeeda.com/roblox-news/steal-an-egg-a-beginner-s-guide)
- [allthings.how — Mutations: all multipliers](https://allthings.how/steal-an-egg-mutations-all-multipliers-and-how-to-get-them/)
- [allthings.how — How to use the Bat and Bear Traps](https://allthings.how/how-to-use-the-bat-and-bear-traps-in-steal-an-egg-roblox/)
- [Steal An Egg Wiki (фан) — All Eggs Reference](https://steal-an-egg.robloxgameswiki.com/guide/all-eggs)
- [GameBoost — Mutations and Sizes](https://gameboost.com/blog/steal-an-egg-mutation-sizes)
- [GameBoost — PvP Guide: Baseball Bat, Traps & Base Defense](https://gameboost.com/blog/steal-an-egg-pvp-guide)
- [Eldorado — Trails, Treadmills & How to Get Speed](https://www.eldorado.gg/blog/steal-an-egg/steal-an-egg-trails-treadmills-how-to-get-speed/)
- [mmoexp — Best Eggs, Pets, Speed, Biomes](https://www.mmoexp.com/News/roblox-steal-an-egg-guide-best-eggs-pets-speed-biomes-and-beginner-tips.html)
- [FPT Shop — Hướng dẫn chơi Steal an Egg](https://fptshop.com.vn/tin-tuc/giai-tri/steal-an-egg-roblox-212206)
