-- DataService: persistent player data (pcall retries + BindToClose), inventory helpers, client sync
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Modules.Config)
local AnimalData = require(RS.Modules.AnimalData)
local Net = require(RS.Modules.Net)

local DataService = {}
local S
local store
pcall(function() store = DataStoreService:GetDataStore(Config.DataStoreName) end)
local profiles = {} -- [Player] = { Data, CanSave, Session = { Start, Gifts } }

local function default()
	return {
		Coins = Config.StartingCoins, Inventory = {}, Equipped = "", Slots = Config.Inventory.StartSlots, Overflow = false,
		Materials = { FrostCore = 0, MagmaHeart = 0, EclipseDust = 0 },
		Totems = {}, EquippedTotems = {}, Potions = { Lucky = 0, Elixir = 0 }, LuckyUntil = 0, ElixirArmed = false,
		Essence = 0, Rank = 1, Index = {}, NextId = 1,
		Stats = { Rolls = 0, RarestPull = 0, RarestName = "", AlphaTime = 0, Crafts = 0, Forges = 0, Sacrifices = 0, BonusCounter = 0 },
		Vault = {}, Settings = { CutsceneMin = 4, ReduceOthersFX = false }, LuckBoostUntil = 0, Purchases = {}, StudioPasses = {},
	}
end

local function reconcile(data, def)
	for k, v in pairs(def) do
		if data[k] == nil then data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then reconcile(data[k], v) end
	end
	return data
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
function DataService.CoinMult(data) return 1 + DataService.IndexCount(data) * 0.01 end

function DataService.FindItem(data, id)
	for i, it in ipairs(data.Inventory) do if it.Id == id then return it, i end end
	return nil
end

function DataService.NewItem(data, roll)
	local item = { Id = "a" .. data.NextId, Animal = roll.Animal, Tier = roll.Tier or 1, Mutation = roll.Mutation or "Normal", Locked = false }
	data.NextId += 1
	return item
end

-- Adds a freshly rolled animal: keep if there's room, rare pulls (1 in 1,000+) go to the Vault (never lost), commons auto-sell
function DataService.AddRolled(player, roll)
	local data = DataService.Get(player)
	local item = DataService.NewItem(data, roll)
	local rarity = AnimalData.ItemRarity(item)
	if #data.Inventory < data.Slots then
		table.insert(data.Inventory, item)
		return "Kept", item, 0
	elseif (rarity >= Config.Roll.StarThreshold or (item.Tier or 1) >= 7) and #data.Vault < Config.Roll.VaultSize then
		table.insert(data.Vault, item)
		return "Vault", item, 0
	end
	local coins = math.floor(Config.SellValue(rarity) * DataService.CoinMult(data))
	data.Coins += coins
	return "Sold", item, coins
end

function DataService.RemoveItem(data, id)
	local _, i = DataService.FindItem(data, id)
	if i then table.remove(data.Inventory, i) end
	if data.Equipped == id then data.Equipped = data.Inventory[1] and data.Inventory[1].Id or "" end
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
	})
	DataService.UpdateLeaderstats(player)
end

function DataService.Load(player)
	local data, canSave = nil, store ~= nil
	if store then
		for attempt = 1, 3 do
			local ok, res = pcall(function() return store:GetAsync("u_" .. player.UserId) end)
			if ok then data = res; break end
			warn("[DataService] load failed for " .. player.Name .. ": " .. tostring(res))
			if string.find(tostring(res), "403") or string.find(tostring(res), "Studio") then canSave = false; break end
			if attempt == 3 then canSave = false end
			task.wait(1.5)
		end
	end
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
	profiles[player] = { Data = data, CanSave = canSave, Session = { Start = workspace:GetServerTimeNow(), Gifts = {} } }
	if not canSave then warn("[DataService] saving disabled for " .. player.Name .. " (enable Studio API access to persist)") end
	DataService.UpdateLeaderstats(player)
	return data
end

function DataService.Save(player)
	local p = profiles[player]
	if not p or not p.CanSave or not store then return end
	for attempt = 1, 3 do
		local ok, err = pcall(function() store:UpdateAsync("u_" .. player.UserId, function() return p.Data end) end)
		if ok then return end
		warn("[DataService] save attempt " .. attempt .. " failed for " .. player.Name .. ": " .. tostring(err))
		task.wait(1)
	end
end

function DataService.Release(player)
	DataService.Save(player)
	profiles[player] = nil
end

function DataService.Start()
	game:BindToClose(function()
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function() DataService.Save(player); pending -= 1 end)
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do task.wait() end
	end)
	task.spawn(function()
		while true do
			task.wait(90)
			for player in pairs(profiles) do task.spawn(DataService.Save, player) end
		end
	end)
end

return DataService
