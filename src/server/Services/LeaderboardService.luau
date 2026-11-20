-- LeaderboardService: 3 global boards (OrderedDataStore, 60s refresh) + crowns for the top 3
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Config = require(RS.Modules.Config)
local AnimalData = require(RS.Modules.AnimalData)

local LB = {}
local S
local BOARDS = {
	{ Key = "Rolls",      Stat = "Rolls",      Board = "RollsBoard",  Title = "Total Rolls", Store = "LB_Rolls_v1" },
	{ Key = "RarestPull", Stat = "RarestPull", Board = "RarestBoard", Title = "Rarest Pull", Store = "LB_Rarest_v2", Log = true },
	{ Key = "AlphaTime",  Stat = "AlphaTime",  Board = "AlphaBoard",  Title = "Alpha Zone",  Store = "LB_Alpha_v1" },
}
local stores, online = {}, true
local names = {}

function LB.Init(services) S = services end

local function fmt(key, v)
	if key == "RarestPull" then return v > 0 and AnimalData.FormatRarityShort(v) or "-" end
	if key == "AlphaTime" then
		local s = math.floor(v); return string.format("%dh %02dm %02ds", s // 3600, (s % 3600) // 60, s % 60)
	end
	return AnimalData.Comma(v)
end

local function nameOf(userId)
	if names[userId] then return names[userId] end
	local p = Players:GetPlayerByUserId(userId)
	if p then names[userId] = p.DisplayName; return p.DisplayName end
	local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	names[userId] = ok and n or ("User " .. userId)
	return names[userId]
end

local function refresh()
	local results = {}
	for _, b in ipairs(BOARDS) do
		local entries = {}
		if online and stores[b.Key] then
			for _, p in ipairs(Players:GetPlayers()) do
				local d = S.DataService.Get(p)
				if d and S.DataService.CanSave(p) then -- sandboxed test sessions never reach the global boards
					local ok = pcall(function() stores[b.Key]:SetAsync(tostring(p.UserId), b.Log and math.floor(math.log10(math.max(1, d.Stats[b.Stat] or 1)) * 1e9 + 0.5) or math.floor(d.Stats[b.Stat] or 0)) end)
					if not ok then online = false; break end
				end
			end
			if online then
				local ok, pages = pcall(function() return stores[b.Key]:GetSortedAsync(false, 10) end)
				if ok then
					for _, e in ipairs(pages:GetCurrentPage()) do table.insert(entries, { UserId = tonumber(e.key), Value = b.Log and math.floor(10 ^ (e.value / 1e9) + 0.5) or e.value }) end
				else online = false end
			end
		end
		-- live values always win (fresher than the store)
		local seen = {}
		for _, e in ipairs(entries) do seen[e.UserId] = e end
		for _, p in ipairs(Players:GetPlayers()) do
			local d = S.DataService.Get(p)
			if d then
				local v = math.floor(d.Stats[b.Stat] or 0)
				if seen[p.UserId] then seen[p.UserId].Value = v else local e = { UserId = p.UserId, Value = v }; table.insert(entries, e); seen[p.UserId] = e end
			end
		end
		table.sort(entries, function(x, y) return x.Value > y.Value end)
		results[b.Key] = entries
		local gui = workspace.Hub.Leaderboards[b.Board].Screen.BoardGui
		local medal = { "🥇", "🥈", "🥉" }
		for i = 1, 10 do
			local e = entries[i]
			gui.Rows["Row" .. i].Text = (e and e.Value > 0) and string.format("%s  %s  —  %s", medal[i] or ("#" .. i), nameOf(e.UserId), fmt(b.Key, e.Value)) or ""
		end
	end
	-- crowns: best placement across boards (Rarest > Rolls > Alpha)
	for _, p in ipairs(Players:GetPlayers()) do
		local title = ""
		for _, b in ipairs({ BOARDS[2], BOARDS[1], BOARDS[3] }) do
			for i = 1, 3 do
				local e = results[b.Key][i]
				if e and e.UserId == p.UserId and e.Value > 0 then title = string.format("👑 #%d %s", i, b.Title); break end
			end
			if title ~= "" then break end
		end
		if p:GetAttribute("Title") ~= title then p:SetAttribute("Title", title) end
	end
end

function LB.Start()
	for _, b in ipairs(BOARDS) do
		local ok, st = pcall(function() return DataStoreService:GetOrderedDataStore(b.Store) end)
		if ok then stores[b.Key] = st else online = false end
	end
	task.wait(5)
	while true do
		local ok, err = pcall(refresh)
		if not ok then warn("[LeaderboardService] " .. tostring(err)) end
		task.wait(Config.LeaderboardRefresh)
	end
end

LB.Refresh = refresh
return LB
