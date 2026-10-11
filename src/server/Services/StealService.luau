--[[
	StealService — кража яиц из инкубаторов и защита баз.

	Правила (сервер — единственный источник истины):
	• Красть можно только яйца в инкубаторах (греющиеся или готовые) и яйца,
	  которые кто-то несёт (их выбивают битой). Яйца в инвентаре и вылупившиеся
	  существа украсть нельзя.
	• Нельзя красть у базы под замком, у новичка (первые 15 минут игры, пока он сам
	  никого не обокрал) и у игрока, которого обокрали меньше минуты назад.
	• Во время переноса яйцо остаётся в профиле владельца (record.transit = вор).
	  Владение меняется ТОЛЬКО в момент доставки на базу вора — одной операцией без
	  yield, после чего оба профиля сохраняются. Дюп невозможен.
	• Вор подсвечивается красным и замедлен, владелец получает тревогу со стрелкой.
	• Если вора выбили, яйцо падает: владелец может забрать его сразу, другие — подобрать
	  (кража продолжается уже ими). Через 25 сек. яйцо само возвращается владельцу.
	• Вышел вор — яйцо возвращается. Вышел владелец — кража отменяется, яйцо остаётся у него.
	• Владелец получает страховку (Eggs.StealRefund от ценности яйца).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Game = require(Shared.Config.Game)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Logic.Format)
local Profile = require(Shared.Logic.Profile)
local Net = require(Shared.Net)

local StealService = {}

local services
local alertEvent: RemoteEvent
local drops: { [any]: Model } = {} -- item -> модель на земле

local function now(): number
	return workspace:GetServerTimeNow()
end

function StealService:IsLocked(session: any): boolean
	return (session.LockedUntil or 0) > now()
end

function StealService:IsNewbie(session: any): boolean
	if session.Profile.stats.stolen > 0 then
		return false
	end
	return services.DataService:PlayTime(session) < Game.Steal.NewbieProtection
end

-- Защищена ли база от краж прямо сейчас (замок или новичок)
function StealService:IsProtected(session: any): boolean
	return StealService:IsLocked(session) or StealService:IsNewbie(session)
end

local function alert(session: any, info: any)
	if session.Player.Parent then
		alertEvent:FireClient(session.Player, info)
	end
end

local function refreshPlotAttributes(session: any)
	local plot = session.Plot
	if not plot then
		return
	end
	plot.Model:SetAttribute("LockedUntil", session.LockedUntil or 0)
	plot.Model:SetAttribute("LockCooldownUntil", session.LockCooldownUntil or 0)
	local protectedFor = 0
	if StealService:IsNewbie(session) then
		protectedFor = Game.Steal.NewbieProtection - services.DataService:PlayTime(session)
	end
	plot.Model:SetAttribute("ProtectedUntil", if protectedFor > 0 then now() + protectedFor else 0)
end

-- Возвращает яйцо в инкубатор владельца (кража сорвалась)
local function returnToOwner(item: any, result: string)
	local owner = item.Owner
	if not owner or owner.Released then
		return
	end
	local record = owner.Profile.incubators[tostring(item.Slot)]
	if record and record.uid == item.EggUid then
		record.transit = nil
	end
	services.IncubatorService:RefreshSlot(owner, item.Slot)
	alert(owner, { active = false, result = result, eggId = item.EggId })
	services.DataService:MarkDirty(owner.Player)
end

function StealService:OnStealPrompt(thief: Player, plotIndex: number, slot: number)
	local thiefSession = services.DataService:GetSession(thief)
	local plot = services.PlotService:GetPlot(plotIndex)
	local victim = plot and plot.Owner
	if not thiefSession or not victim or victim == thief then
		return
	end
	local victimSession = services.DataService:GetSession(victim)
	if not victimSession then
		return
	end
	local function deny(message: string)
		services.DataService:Notify(thief, message, "error")
	end
	local record = victimSession.Profile.incubators[tostring(slot)]
	if not record or record.transit then
		return
	end
	if StealService:IsLocked(victimSession) then
		deny("🔒 База заперта")
		return
	end
	if StealService:IsNewbie(victimSession) then
		deny("🛡️ Новичок под защитой")
		return
	end
	if (victimSession.LastRobbedAt or 0) + Game.Steal.VictimCooldown > now() then
		deny("Этого игрока недавно обокрали — подожди")
		return
	end
	if services.CarryService:IsStunned(thiefSession) then
		return
	end
	if not services.CarryService:HasRoom(thiefSession) then
		deny("🎒 Сумка полна")
		return
	end

	record.transit = thief.UserId
	local item = { Kind = "stolen", EggId = record.id, Owner = victimSession, Slot = slot, EggUid = record.uid }
	services.CarryService:Add(thiefSession, item)
	services.IncubatorService:RefreshSlot(victimSession, slot)

	local eggName = Eggs.ById[record.id].Name
	alert(victimSession, { active = true, thief = thief.DisplayName, thiefUserId = thief.UserId, eggId = record.id })
	services.DataService:Notify(victim, string.format("🚨 %s крадёт твоё %s! Догони и ударь битой!", thief.DisplayName, eggName), "alert")
	services.DataService:Notify(thief, "Беги на свою базу! Тебя подсвечивают для всех", "warn")
	services.DataService:MarkDirty(victim)
end

-- Вызывается из CarryService при доставке. true — владение передано.
function StealService:CompleteSteal(thiefSession: any, item: any): boolean
	local owner = item.Owner
	if not owner or owner.Released or not owner.Loaded then
		services.DataService:Notify(thiefSession.Player, "Владелец ушёл — яйцо вернулось к нему", "warn")
		return false
	end
	local key = tostring(item.Slot)
	local record = owner.Profile.incubators[key]
	if not record or record.uid ~= item.EggUid or record.transit ~= thiefSession.UserId then
		return false
	end
	local thiefProfile = thiefSession.Profile
	if #thiefProfile.eggs >= Game.Inventory.MaxEggs then
		services.DataService:Notify(thiefSession.Player, "Инвентарь яиц полон — яйцо вернулось владельцу", "error")
		returnToOwner(item, "returned")
		return false
	end

	-- Атомарная передача владения
	owner.Profile.incubators[key] = nil
	table.insert(thiefProfile.eggs, { uid = Profile.NewUid(thiefProfile), id = item.EggId })
	local refund = Economy.StealRefund(item.EggId)
	owner.Profile.coins += refund
	owner.Profile.stats.robbed += 1
	thiefProfile.stats.stolen += 1
	owner.LastRobbedAt = now()

	services.IncubatorService:RefreshSlot(owner, item.Slot)
	services.QuestService:Progress(thiefSession, "Steal", 1)
	alert(owner, { active = false, result = "stolen", eggId = item.EggId, refund = refund })
	services.DataService:Notify(owner.Player, string.format("💔 Яйцо украдено. Страховка: +%s", Format.Money(refund)), "alert")
	services.DataService:Notify(thiefSession.Player, "🥚 Украдено: " .. Eggs.ById[item.EggId].Name, "success")
	services.DataService:MarkDirty(owner.Player)
	refreshPlotAttributes(thiefSession) -- вор теряет защиту новичка
	services.IncubatorService:RefreshAll(thiefSession)
	services.DataService:SaveNow(owner.Player)
	services.DataService:SaveNow(thiefSession.Player)
	return true
end

-- Вора выбили/поймали: яйцо падает на землю
function StealService:OnStolenDropped(item: any, position: Vector3, reason: string)
	local owner = item.Owner
	if not owner or owner.Released then
		return
	end
	if reason == "leave" then
		returnToOwner(item, "returned")
		services.DataService:Notify(owner.Player, "Вор сбежал из игры — яйцо вернулось!", "success")
		return
	end
	local record = owner.Profile.incubators[tostring(item.Slot)]
	if not record or record.uid ~= item.EggUid then
		return
	end
	record.transit = -1 -- лежит на земле
	alert(owner, { active = true, dropped = true, position = position, eggId = item.EggId })
	services.DataService:Notify(owner.Player, "Вора остановили! Твоё яйцо лежит на земле — забери его", "success")

	local model
	model = services.WorldEggService:CreatePickup(item.EggId, position + Vector3.new(0, 0.3, 0), "Grab", function(player)
		local session = services.DataService:GetSession(player)
		if not session then
			return
		end
		if player == owner.Player then
			model:SetAttribute("Taken", true)
			model:Destroy()
			drops[item] = nil
			returnToOwner(item, "recovered")
			services.DataService:Notify(player, "Яйцо возвращено в инкубатор!", "success")
			return
		end
		if services.CarryService:IsStunned(session) or not services.CarryService:HasRoom(session) then
			return
		end
		model:SetAttribute("Taken", true)
		model:Destroy()
		drops[item] = nil
		record.transit = player.UserId
		services.CarryService:Add(session, item)
		alert(owner, { active = true, thief = player.DisplayName, thiefUserId = player.UserId, eggId = item.EggId })
	end)
	model:SetAttribute("StolenFrom", owner.UserId)
	model:SetAttribute("OwnerName", owner.Player.DisplayName)
	drops[item] = model

	task.delay(Game.Carry.StolenEggReturn, function()
		if drops[item] == model and model.Parent and not model:GetAttribute("Taken") then
			model:Destroy()
			drops[item] = nil
			returnToOwner(item, "returned")
			services.DataService:Notify(owner.Player, "Яйцо вернулось в инкубатор", "success")
		end
	end)
end

function StealService:LockBase(player: Player)
	local session = services.DataService:GetSession(player)
	if not session or not session.Plot then
		return
	end
	local t = now()
	if StealService:IsLocked(session) then
		return
	end
	if (session.LockCooldownUntil or 0) > t then
		services.DataService:Notify(player, "Замок перезаряжается: " .. Format.Time(session.LockCooldownUntil - t), "error")
		return
	end
	local bonuses = services.CreatureService:GetBonuses(session)
	local duration = Economy.LockDuration(session.Profile.upgrades.lock, bonuses.Lock)
	session.LockedUntil = t + duration
	session.LockCooldownUntil = t + duration + Game.Steal.LockCooldown
	services.PlotService:SetBarrier(session.Plot, true)
	refreshPlotAttributes(session)
	services.IncubatorService:RefreshAll(session)
	services.DataService:Notify(player, string.format("🔒 База заперта на %d сек.", duration), "success")
	services.DataService:MarkDirty(player)

	local lockedUntil = session.LockedUntil
	task.delay(duration, function()
		if session.LockedUntil == lockedUntil and session.Plot and not session.Released then
			services.PlotService:SetBarrier(session.Plot, false)
			refreshPlotAttributes(session)
			services.IncubatorService:RefreshAll(session)
			services.DataService:Notify(player, "🔓 Замок базы открылся", "warn")
			services.DataService:MarkDirty(player)
		end
	end)
end

function StealService:Init(registry)
	services = registry
	alertEvent = Net.Event("StealAlert")
end

function StealService:Start()
	services.DataService:OnLoaded(function(_player, session)
		refreshPlotAttributes(session)
		-- Когда защита новичка закончится — включаем кнопки кражи
		task.spawn(function()
			while session.Loaded and not session.Released and StealService:IsNewbie(session) do
				task.wait(5)
			end
			if not session.Released then
				refreshPlotAttributes(session)
				services.IncubatorService:RefreshAll(session)
			end
		end)
	end)

	services.DataService:OnRemoving(function(_player, session)
		-- Отменяем все кражи, где ушедший — владелец
		for _, other in services.DataService.Sessions do
			if other ~= session and other.Carry then
				for i = #other.Carry, 1, -1 do
					local item = other.Carry[i]
					if item.Owner == session then
						services.CarryService:Remove(other, item)
						services.DataService:Notify(other.Player, "Владелец ушёл — украденное яйцо исчезло", "warn")
					end
				end
			end
		end
		for item, model in drops do
			if item.Owner == session then
				model:Destroy()
				drops[item] = nil
			end
		end
		for _, record in session.Profile.incubators do
			record.transit = nil
		end
	end)

	services.DataService:AddViewContributor(function(session, runtime)
		runtime.lockedUntil = session.LockedUntil or 0
		runtime.lockCooldownUntil = session.LockCooldownUntil or 0
		runtime.newbie = StealService:IsNewbie(session)
	end)
end

return StealService
