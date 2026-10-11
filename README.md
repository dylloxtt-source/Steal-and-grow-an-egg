# Steal and Grow an Egg

Roblox-игра, код синхронизируется в Studio через [Rojo](https://rojo.space).

## Структура

| Папка         | Куда попадает в Studio                        |
|---------------|-----------------------------------------------|
| `src/server`  | `ServerScriptService.Server` (Script)         |
| `src/client`  | `StarterPlayer.StarterPlayerScripts.Client`   |
| `src/shared`  | `ReplicatedStorage.Shared` (ModuleScript-ы)   |

## Подключение к Studio

Один раз:

```
rokit install
rojo plugin install
```

Каждый раз:

```
git pull
rojo serve
```

В Studio: **Plugins → Rojo → Connect** (`localhost:34872`).
