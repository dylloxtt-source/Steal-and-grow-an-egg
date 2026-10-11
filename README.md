# Steal and Grow an Egg

Roblox-игра, код синхронизируется в Studio через [Rojo](https://rojo.space).

## Структура

| Папка         | Куда попадает в Studio                        |
|---------------|-----------------------------------------------|
| `src/server`  | `ServerScriptService.Server` (Script)         |
| `src/client`  | `StarterPlayer.StarterPlayerScripts.Client`   |
| `src/shared`  | `ReplicatedStorage.Shared` (ModuleScript-ы)   |

## Подключение к Studio (без терминала, Windows)

Один раз:

1. **GitHub Desktop** → File → Clone repository → `dylloxtt-source/Steal-and-grow-an-egg`.
2. Скачай `rojo-...-windows-x86_64.zip` с https://github.com/rojo-rbx/rojo/releases
   и положи `rojo.exe` в папку проекта (рядом с `start-rojo.bat`).
3. В Studio установи плагин **Rojo** из Creator Store (Toolbox → Plugins).

Каждый раз:

1. GitHub Desktop → **Fetch origin** → **Pull origin**.
2. Двойной клик по `start-rojo.bat` (окно не закрывать).
3. Studio → **Plugins → Rojo → Connect**.
