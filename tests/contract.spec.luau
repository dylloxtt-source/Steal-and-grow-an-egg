-- Контракт клиент-сервер: у каждого действия из Net.Actions есть обработчик на сервере,
-- а каждый счётчик заданий реально увеличивается где-то на сервере.
return function(t)
	local Quests = t.load("Config.Quests")
	local serverCode = ""
	for _, name in t.readDir("src/server/Services") do
		serverCode ..= t.readFile("src/server/Services/" .. name)
	end
	local netCode = t.readFile("src/shared/Net.luau")
	local actionsBlock = string.match(netCode, "Net%.Actions = (%b{})")
	t.ok(actionsBlock ~= nil, "Net.Actions найден")
	for action in string.gmatch(actionsBlock or "", "(%w+) = %d+") do
		t.ok(string.find(serverCode, 'Handle%("' .. action .. '"') ~= nil, "есть обработчик действия " .. action)
	end
	for _, quest in Quests.List do
		t.ok(string.find(serverCode, 'Progress%(session, "' .. quest.Stat .. '"') ~= nil
			or string.find(serverCode, 'Progress%(thiefSession, "' .. quest.Stat .. '"') ~= nil,
			"счётчик задания " .. quest.Stat .. " увеличивается на сервере")
	end
	-- Каждый сервис из папки подключён в init.server.luau
	local init = t.readFile("src/server/init.server.luau")
	for _, name in t.readDir("src/server/Services") do
		local service = string.gsub(name, "%.luau$", "")
		t.ok(string.find(init, '"' .. service .. '"') ~= nil, "сервис " .. service .. " запускается")
	end
end
