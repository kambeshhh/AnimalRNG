-- DataService: ProfileStore-pattern session-locked player data (UpdateAsync session lock + BindToClose + plain-table sanitization)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Modules.Config)
local AnimalData = require(RS.Modules.AnimalData)
local Net = require(RS.Modules.Net)

local DataService = {}
local S
local store
pcall(function() store = DataStoreService:GetDataStore(Config.DataStoreName) end)
local SESSION_ID = (game.JobId ~= "" and game.JobId) or ("Studio_" .. HttpService:GenerateGUID(false))
local LOCK_TTL = 210 -- seconds before an orphaned lock from a crashed server can be claimed
local profiles = {} -- [Player] = { Data, CanSave, Released, Session = { Start, Gifts } }

local function default()
	return {
		Coins = Config.StartingCoins, Inventory = {}, Equipped = "", Slots = Config.Inventory.StartSlots, Overflow = false,
		Materials = { FrostCore = 0, MagmaHeart = 0, EclipseDust = 0 },
		Totems = {}, EquippedTotems = {}, Potions = { Lucky = 0, Elixir = 0 }, LuckyUntil = 0, ElixirArmed = false,
		Essence = 0, Rank = 1, Index = {}, NextId = 1,
		Stats = { Rolls = 0, RarestPull = 0, RarestName = "", AlphaTime = 0, Crafts = 0, Forges = 0, Sacrifices = 0, BonusCounter = 0, UnluckyStreak = 0, StreakStacks = 0, Rebirths = 0, Crits = 0, Breakthroughs = 0, Overdrives = 0, BountiesDone = 0 },
		Vault = {}, Settings = { CutsceneMin = 4, ReduceOthersFX = false, AutoFilterTier = 0, AutoEquipRarer = true, AlwaysCutsceneNew = true }, LuckBoostUntil = 0, Purchases = {}, StudioPasses = {},
		-- Fusion systems: Anime Dice ladder, Slime RNG Rebirth & Skill Tree, Active Companion Pack, Promo Codes & Lucky Spins
		Dice = { Wooden = true }, EquippedDie = "Wooden",
		Relics = {}, EquippedRelics = {},
		Rebirth = 0, World2Unlocked = false,
		InfinitePaidLuck = 0,
		Skills = { CoinYield = 0, RollSpeed = 0, SuperLuck = 0, OfflineCap = 0, BonusCycle = 0 },
		Pack = {}, -- up to 3 companion item Ids
		LuckySpins = 1, LuckySpinArmed = false,
		RedeemedCodes = {},
		LastSeenOs = 0, OfflineCoinsPending = 0,
		-- V6 Hype systems
		Overdrive = 0,
		Bounties = {},
	}
end

local function reconcile(data, def)
	for k, v in pairs(def) do
		if data[k] == nil then data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then reconcile(data[k], v) end
	end
	return data
end

-- Plain, serializable data only. Strips any Instance, userdata, function, or thread before saving.
local function sanitizePlain(v: any): any
	local t = typeof(v)
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return 0 end
		return v
	elseif t == "string" or t == "boolean" then
		return v
	elseif t == "table" then
		local out = {}
		for k, val in pairs(v) do
			local kt = typeof(k)
			if (kt == "string" or kt == "number") and k ~= "_SessionLock" then
				local sv = sanitizePlain(val)
				if sv ~= nil then out[k] = sv end
			end
		end
		return out
	end
	return nil
end

function DataService.Init(services) S = services end
function DataService.Get(player) local p = profiles[player]; return p and p.Data end
function DataService.SetCanSave(player, on) local p = profiles[player]; if p then p.CanSave = on and store ~= nil end end -- Studio test hook: sandbox a session
function DataService.CanSave(player) local p = profiles[player]; return p ~= nil and p.CanSave end
function DataService.Session(player) local p = profiles[player]; return p and p.Session end
function DataService.Notify(player, kind, payload) Net.Get("Notify"):FireClient(player, kind, payload) end
function DataService.Toast(player, text, color) DataService.Notify(player, "Toast", { Text = text, Color = color }) end

function DataService.IndexCount(data)
	local n = 0
	for _ in pairs(data.Index) do n += 1 end
	return n
end
function DataService.CoinMult(data)
	local indexMult = 1 + DataService.IndexCount(data) * 0.01
	local skillMult = 1 + ((data.Skills and data.Skills.CoinYield or 0) * Config.Skills.Nodes.CoinYield.Step)
	local rebirthMult = Config.RebirthCoinMult(data.Rebirth or 0)
	return indexMult * skillMult * rebirthMult
end

function DataService.PackCPS(data)
	local raw = 0
	for _, id in ipairs(data.Pack or {}) do
		local it = DataService.FindItem(data, id)
		if it and it.Id ~= data.Equipped then
			raw += Config.CompanionCPS(AnimalData.ItemRarity(it))
		end
	end
	return math.floor(raw * DataService.CoinMult(data))
end

function DataService.AutoFillPack(data)
	data.Pack = data.Pack or {}
	for i = #data.Pack, 1, -1 do
		local it = DataService.FindItem(data, data.Pack[i])
		if not it or it.Id == data.Equipped then table.remove(data.Pack, i) end
	end
	if #data.Pack >= Config.Pack.MaxCompanions then return end
	local candidates = {}
	for _, it in ipairs(data.Inventory) do
		if it.Id ~= data.Equipped and not table.find(data.Pack, it.Id) then
			table.insert(candidates, it)
		end
	end
	table.sort(candidates, function(a, b) return AnimalData.ItemRarity(a) > AnimalData.ItemRarity(b) end)
	for _, it in ipairs(candidates) do
		if #data.Pack >= Config.Pack.MaxCompanions then break end
		table.insert(data.Pack, it.Id)
	end
end

function DataService.FindItem(data, id)
	for i, it in ipairs(data.Inventory) do if it.Id == id then return it, i end end
	return nil
end

function DataService.NewItem(data, roll)
	local item = { Id = "a" .. data.NextId, Animal = roll.Animal, Tier = roll.Tier or 1, Mutation = roll.Mutation or "Normal", Locked = false }
	data.NextId += 1
	return item
end

-- Adds a freshly rolled animal:
-- 1) Smart Auto-Filter (Sol's RNG x Slime RNG): if below AutoFilterTier (and not a NEW! Index discovery or rare Mutation), auto-transmutes into 100% Coins + 25% Essence.
-- 2) Keep if there's room (and Auto-Equip if rarer than current equipped morph when AutoEquipRarer is enabled).
-- 3) Rare pulls (1 in 1,000+ or T7+) go to Vault when full; commons auto-sell.
function DataService.AddRolled(player, roll, isNewIndex)
	local data = DataService.Get(player)
	local item = DataService.NewItem(data, roll)
	local rarity = AnimalData.ItemRarity(item)
	local st = data.Settings or {}
	local filterTier = tonumber(st.AutoFilterTier) or 0
	local isSpecialMut = (item.Mutation or "Normal") ~= "Normal"

	if filterTier > 0 and (item.Tier or 1) < filterTier and not isNewIndex and not isSpecialMut then
		local coins = math.floor(Config.SellValue(rarity) * DataService.CoinMult(data))
		local essence = math.max(1, math.floor(rarity * 0.25))
		data.Coins += coins
		data.Essence = (data.Essence or 0) + essence
		return "Filtered", item, coins, essence
	end

	if #data.Inventory < data.Slots then
		table.insert(data.Inventory, item)
		-- Auto-Equip If Rarer (Sol's RNG x PETS GO! QoL)
		if st.AutoEquipRarer ~= false then
			local curEq = data.Equipped and DataService.FindItem(data, data.Equipped)
			local curRarity = curEq and AnimalData.ItemRarity(curEq) or 0
			if rarity > curRarity then
				data.Equipped = item.Id
				DataService.AutoFillPack(data)
				if S.MorphService and S.MorphService.Spawn then task.defer(S.MorphService.Spawn, player, true) end
				return "Kept", item, 0, 0
			end
		end
		if #(data.Pack or {}) < Config.Pack.MaxCompanions and item.Id ~= data.Equipped then
			DataService.AutoFillPack(data)
			if S.MorphService and S.MorphService.RefreshPack then task.defer(S.MorphService.RefreshPack, player) end
		end
		return "Kept", item, 0, 0
	elseif (rarity >= Config.Roll.StarThreshold or (item.Tier or 1) >= 7) and #data.Vault < Config.Roll.VaultSize then
		table.insert(data.Vault, item)
		return "Vault", item, 0, 0
	end
	local coins = math.floor(Config.SellValue(rarity) * DataService.CoinMult(data))
	local essence = math.max(1, math.floor(rarity * 0.15))
	data.Coins += coins
	data.Essence = (data.Essence or 0) + essence
	return "Sold", item, coins, essence
end

function DataService.RemoveItem(data, id)
	local _, i = DataService.FindItem(data, id)
	if i then table.remove(data.Inventory, i) end
	if data.Equipped == id then data.Equipped = data.Inventory[1] and data.Inventory[1].Id or "" end
	if data.Pack then
		local pi = table.find(data.Pack, id)
		if pi then table.remove(data.Pack, pi) end
	end
end

function DataService.UpdateLeaderstats(player)
	local data = DataService.Get(player); if not data then return end
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder"); ls.Name = "leaderstats"
		local c = Instance.new("IntValue"); c.Name = "Coins"; c.Parent = ls
		local r = Instance.new("IntValue"); r.Name = "Rolls"; r.Parent = ls
		local b = Instance.new("StringValue"); b.Name = "Rarest"; b.Parent = ls
		ls.Parent = player
	end
	ls.Coins.Value = math.min(data.Coins, 9e15)
	ls.Rolls.Value = data.Stats.Rolls
	ls.Rarest.Value = data.Stats.RarestPull > 0 and AnimalData.FormatRarityShort(data.Stats.RarestPull) or "-"
	player:SetAttribute("Rebirth", data.Rebirth or 0)
	player:SetAttribute("EquippedDie", data.EquippedDie or "Wooden")
	player:SetAttribute("PackCPS", DataService.PackCPS(data))
end

function DataService.Sync(player)
	local p = profiles[player]; if not p then return end
	local d = p.Data
	Net.Get("Sync"):FireClient(player, {
		Coins = d.Coins, Inventory = d.Inventory, Equipped = d.Equipped, Slots = d.Slots, Vault = d.Vault,
		Materials = d.Materials, Totems = d.Totems, EquippedTotems = d.EquippedTotems, Potions = d.Potions,
		LuckyUntil = d.LuckyUntil, ElixirArmed = d.ElixirArmed, Essence = d.Essence, Rank = d.Rank, Stats = d.Stats,
		Index = d.Index, SessionStart = p.Session.Start, GiftsClaimed = p.Session.Gifts, ServerOsTime = os.time(),
		TotemSlots = S.TotemService and S.TotemService.Slots(player) or 1,
		Settings = d.Settings, LuckBoostUntil = d.LuckBoostUntil,
		Passes = S.MonetizationService and S.MonetizationService.OwnedPasses(player) or {},
		PaidRandomRestricted = S.MonetizationService and S.MonetizationService.IsPaidRandomRestricted(player) or false,
		Dice = d.Dice, EquippedDie = d.EquippedDie, Rebirth = d.Rebirth, Skills = d.Skills,
		Relics = d.Relics, EquippedRelics = d.EquippedRelics, World2Unlocked = d.World2Unlocked,
		InfinitePaidLuck = d.InfinitePaidLuck or 0,
		Pack = d.Pack, PackCPS = DataService.PackCPS(d), CoinMult = DataService.CoinMult(d),
		LuckySpins = d.LuckySpins, LuckySpinArmed = d.LuckySpinArmed, RedeemedCodes = d.RedeemedCodes,
		OfflineCoinsPending = d.OfflineCoinsPending,
		Overdrive = d.Overdrive or 0, Bounties = d.Bounties or {},
	})
	DataService.UpdateLeaderstats(player)
end

function DataService.Load(player)
	local data, canSave = nil, store ~= nil
	local lockConflict = false
	if store then
		for attempt = 1, 3 do
			if player.Parent ~= Players then return nil end
			lockConflict = false
			local ok, res = pcall(function()
				return store:UpdateAsync("u_" .. player.UserId, function(old)
					if type(old) == "table" and type(old._SessionLock) == "table" then
						local lock = old._SessionLock
						local age = os.time() - (lock.Timestamp or 0)
						if lock.JobId and lock.JobId ~= "" and lock.JobId ~= SESSION_ID and age < LOCK_TTL and attempt < 3 then
							lockConflict = true
							return nil -- wait for other server to release on server-hop
						end
					end
					local clean = type(old) == "table" and old or default()
					clean._SessionLock = { JobId = SESSION_ID, PlaceId = game.PlaceId, Timestamp = os.time() }
					return clean
				end)
			end)
			if ok and not lockConflict then
				data = res
				break
			end
			if not ok then
				warn("[DataService] load failed for " .. player.Name .. ": " .. tostring(res))
				if string.find(tostring(res), "403") or string.find(tostring(res), "Studio") then canSave = false; break end
			end
			if attempt == 3 then canSave = false end
			task.wait(1.5)
		end
	end
	-- Anti-exploit & session-lock safety: kick on live servers if profile session could not be established
	if not canSave and not RunService:IsStudio() then
		player:Kick("Data could not load. Please rejoin.")
		return nil
	end
	if type(data) == "table" then data._SessionLock = nil end
	data = reconcile(type(data) == "table" and data or default(), default())
	-- v2 items: {Animal, Tier, Mutation}. Old {Titan, Color} items migrate in place; nothing is dropped unless its creature no longer exists.
	for _, list in ipairs({ data.Inventory, data.Vault }) do
		for i = #list, 1, -1 do
			AnimalData.Migrate(list[i])
			if not AnimalData.Animals[list[i].Animal] then table.remove(list, i) end
		end
	end
	if type(data.Overflow) == "table" then AnimalData.Migrate(data.Overflow) end
	if not data.IndexV2 then
		local newIndex = {}
		local map = { TITAN = "Gilded", Void = "Gilded", Celestial = "Prismatic" }
		for key in pairs(data.Index) do
			local a, v = key:match("^([^|]+)|?(.*)$")
			if a == "EclipseSovereign" then a = "Ouroboros" end
			if AnimalData.Animals[a] then
				newIndex[a] = true
				if v ~= "" then newIndex[a .. "|" .. (map[v] or v)] = true end
			end
		end
		for _, list in ipairs({ data.Inventory, data.Vault }) do
			for _, it in ipairs(list) do for _, k in ipairs(AnimalData.IndexKeys(it)) do newIndex[k] = true end end
		end
		data.Index = newIndex; data.IndexV2 = true
		data.Stats.RarestPull, data.Stats.RarestName = 0, ""
		for _, list in ipairs({ data.Inventory, data.Vault }) do
			for _, it in ipairs(list) do
				local r = AnimalData.ItemRarity(it)
				if r > data.Stats.RarestPull then data.Stats.RarestPull = r; data.Stats.RarestName = AnimalData.ItemName(it) end
			end
		end
	end
	-- migrate the old single overflow slot into the Vault
	if type(data.Overflow) == "table" then table.insert(data.Vault, data.Overflow) end
	data.Overflow = nil
	if not table.find(Config.Cutscene.Options, data.Settings.CutsceneMin) then data.Settings.CutsceneMin = Config.Cutscene.Default end
	if #data.Inventory == 0 then
		local starter = DataService.NewItem(data, { Animal = "MeadowRabbit", Tier = 1, Mutation = "Normal" })
		table.insert(data.Inventory, starter)
		data.Index.MeadowRabbit = true
	end
	if not DataService.FindItem(data, data.Equipped) then data.Equipped = data.Inventory[1].Id end
	data.Dice = data.Dice or { Wooden = true }; data.Dice.Wooden = true
	if not Config.Dice.Types[data.EquippedDie or ""] then data.EquippedDie = "Wooden" end
	DataService.AutoFillPack(data)
	-- Calculate Offline Sanctuary earnings if player was away >= 60 seconds
	local nowOs = os.time()
	if (data.LastSeenOs or 0) > 0 and (nowOs - data.LastSeenOs) >= 60 then
		local awaySec = math.min(nowOs - data.LastSeenOs, (Config.Pack.OfflineMaxHours or 12) * 3600)
		local eff = (Config.Pack.BaseOfflineEfficiency or 0.25) + ((data.Skills and data.Skills.OfflineCap or 0) * Config.Skills.Nodes.OfflineCap.Step)
		local earned = math.floor(DataService.PackCPS(data) * awaySec * eff)
		if earned > 0 then
			data.OfflineCoinsPending = (data.OfflineCoinsPending or 0) + earned
		end
	end
	data.LastSeenOs = nowOs
	profiles[player] = { Data = data, CanSave = canSave, Released = false, Session = { Start = workspace:GetServerTimeNow(), Gifts = {} } }
	if not canSave then warn("[DataService] saving disabled for " .. player.Name .. " (enable Studio API access to persist)") end
	DataService.UpdateLeaderstats(player)
	return data
end

function DataService.Save(player, releaseLock: boolean?)
	local p = profiles[player]
	if not p or not p.CanSave or p.Released or not store then return end
	p.Data.LastSeenOs = os.time()
	local stolen = false
	local payload = sanitizePlain(p.Data)
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync("u_" .. player.UserId, function(old)
				if type(old) == "table" and type(old._SessionLock) == "table" then
					local lock = old._SessionLock
					if lock.JobId and lock.JobId ~= "" and lock.JobId ~= SESSION_ID then
						stolen = true
						return nil -- another server took the session lock; do not overwrite
					end
				end
				if releaseLock then
					payload._SessionLock = nil
				else
					payload._SessionLock = { JobId = SESSION_ID, PlaceId = game.PlaceId, Timestamp = os.time() }
				end
				return payload
			end)
		end)
		if ok then
			if stolen then
				p.Released = true
				profiles[player] = nil
				if player.Parent == Players then
					player:Kick("Your data was loaded in another server. Please rejoin.")
				end
			elseif releaseLock then
				p.Released = true
			end
			return
		end
		warn("[DataService] save attempt " .. attempt .. " failed for " .. player.Name .. ": " .. tostring(err))
		task.wait(1)
	end
end

function DataService.Release(player)
	DataService.Save(player, true)
	profiles[player] = nil
end

function DataService.Start()
	game:BindToClose(function()
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function() DataService.Release(player); pending -= 1 end)
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do task.wait() end
	end)
	task.spawn(function()
		while true do
			task.wait(90)
			for player in pairs(profiles) do task.spawn(DataService.Save, player, false) end
		end
	end)
	-- Active Companion Pack passive coin generator (Slime RNG x Anime Dice)
	task.spawn(function()
		local interval = Config.Pack.TickInterval or 2
		while true do
			task.wait(interval)
			for player, p in pairs(profiles) do
				local d = p.Data
				if d then
					local cps = DataService.PackCPS(d)
					if cps > 0 then
						local gain = math.floor(cps * interval)
						d.Coins += gain
						DataService.UpdateLeaderstats(player)
						DataService.Notify(player, "PackIncome", { Gain = gain, CPS = cps, Coins = d.Coins })
					end
				end
			end
		end
	end)
end

return DataService
