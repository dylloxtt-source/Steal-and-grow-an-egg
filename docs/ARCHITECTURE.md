# Этап 4. Архитектура

Движок: **Roblox (Luau)**, синхронизация через **Rojo** (`default.project.json`). Сервер авторитетен:
клиент присылает только намерения («купить meadow_egg», «покормить u7»), всё остальное считает сервер.

## Структура проекта

```
src/
  shared/                     → ReplicatedStorage.Shared (общий код)
    Config/                   ← ВЕСЬ баланс игры
      Rarities  Eggs  Creatures  Foods  Upgrades  Zones  Map  Game  Quests  Tutorial
    Logic/                    ← чистые функции без сервисов (покрыты юнит-тестами)
      WeightedRandom  Format  Growth  Economy  Profile
    Visual/                   ← билдеры моделей в студ-стиле
      Studs  EggModel  CreatureModel
    Net.luau                  ← сетевой контракт (имена действий и лимиты частоты)
  server/                     → ServerScriptService.Server
    init.server.luau          ← порядок Init/Start сервисов
    Services/
      DataService     сохранение, сессии, замок сессии, автосейв, BindToClose, офлайн-тик
      NetService      единый RemoteFunction «Action», rate limit, валидация
      MapService      процедурная карта (земля, стены, биомы, площадь, ларьки)
      PlotService     6 баз, выдача/освобождение, слоты, телепорт домой
      IncubatorService  инкубация, таймеры, ускорение, вылупление
      CreatureService   рост, голод, доход в кассу, загон, кормление, продажа, бонусы черт
      FarmService     грядки, посадка, урожай
      CarryService    переноска яиц, замедление, доставка, падение
      StealService    кража, замок базы, защита новичка, тревоги, возврат
      WorldEggService яйца и еда на дорожке, ночная перезагрузка
      GuardianService стражи биомов
      CombatService   бита
      ShopService     покупки, улучшения, настройки
      DayNightService цикл дня и ночи
      QuestService    ежедневные задания
      TutorialService обучение
  client/                     → StarterPlayerScripts.Client
    init.client.luau
    State.luau                ← снимок профиля от сервера + обёртка запросов
    UI/   Theme Kit Router HUD ShopPanel EggsPanel PetsPanel FeedPanel FarmPanel
          IndexPanel QuestsPanel SettingsPanel Notifications HatchReveal StealAlert Tutorial Preview Sounds
    World/ Prompts Billboards Animator Effects
tests/   юнит-тесты, интеграционный эмулятор движка
tools/   генератор таблиц баланса, предпросмотр UI в браузере
docs/    исследование, GDD, архитектура, тестирование, превью
```

## Сеть

| Канал | Тип | Направление | Назначение |
|---|---|---|---|
| `Action` | RemoteFunction | клиент → сервер | Все действия: Incubate, Hatch, HatchAll, SkipHatch, Buy, Upgrade, Feed, Place, Store, Sell, Plant, Harvest, ClaimQuest, SetSetting, Tutorial, RequestState |
| `State` | RemoteEvent | сервер → клиент | Полный снимок профиля + runtime (доход/с, бонусы, переноска, замок), склеивается за 0.12 с |
| `Notify` | RemoteEvent | сервер → клиент | Уведомления |
| `Hatched` | RemoteEvent | сервер → клиент | Экран вылупления |
| `StealAlert` | RemoteEvent | сервер → клиент | Тревога кражи |
| `Effect` | RemoteEvent | сервер → клиент | Отбрасывание, тряска |

Подбор яиц, кража, сбор урожая, касса, замок — через **ProximityPrompt/Touched на сервере** (сервер сам
знает игрока и дистанцию). Таймеры (инкубаторы, грядки, замок) передаются атрибутами-временем, клиент считает их сам.

### Защита от злоупотреблений
- Только объявленные действия; лимит частоты на каждое (token bucket).
- Типы и диапазоны полезной нагрузки проверяются (`NetService.Check`), цены и шансы — только из серверных конфигов.
- Обработчики не уступают управление (нет yield), поэтому проверка и изменение атомарны: двойной клик не выдаёт награду дважды.
- Подбор яйца помечается `Taken` до любых других действий; вылупление удаляет запись инкубатора до выдачи существа.
- Кража: яйцо в пути остаётся у владельца до доставки; при выходе любого участника кража корректно откатывается.

## Сохранение

- DataStore `SGAE_Players_v1`, ключ `u_<UserId>`, схема с `version` и миграциями (`Logic/Profile`).
- `UpdateAsync` с замком сессии `{ jobId, time }`: второй сервер ждёт освобождения (до 5 попыток), протухший замок (10 мин) снимается.
- Автосейв каждые 90 с, при выходе (с снятием замка) и в `BindToClose`; после кражи — немедленное сохранение обоих игроков.
- Сверка при загрузке: неизвестные ID удаляются, уровни ограничиваются, недостающие поля добавляются.
- Studio без доступа к API → режим памяти с предупреждением. Живой сервер без DataStore → игрок кикается
  с просьбой перезайти, чтобы не перезаписать прогресс пустым профилем.
- Время — `os.time()`/`GetServerTimeNow()` (UTC), поэтому таймеры и офлайн-прогресс корректны между серверами.

## Порядок реализации

1. Конфиги и чистая логика + тесты → 2. Сохранение и сеть → 3. Карта и базы → 4. Яйца/инкубаторы/существа →
5. Дорожка, переноска, кража, стражи, бита → 6. Ферма, магазин, задания, обучение, день/ночь → 7. UI → 8. Эмулятор и интеграционные тесты → 9. Предпросмотр UI и полировка.

## Как расширять

- Новое яйцо/существо/еда — одна запись в `Config/*`. Тест `config.spec` проверит ссылки и шансы.
- Новое действие клиента — строка в `Net.Actions` + `NetService:Handle(...)` в сервисе (тест `contract.spec` проверит пару).
- Новая зона — запись в `Config/Zones` (зоны должны идти подряд) + декор в `MapService.DECOR`.
