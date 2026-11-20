-- InventoryService: equip, sell, lock, slot upgrades, overflow claim
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Modules.Config)
local AnimalData = require(RS.Modules.AnimalData)

local Inv = {}
local S

function Inv.Init(services) S = services end

local function sellItem(player, data, item)
	if item.Locked or item.Id == data.Equipped then return 0 end
	local coins = math.floor(Config.SellValue(AnimalData.ItemRarity(item)) * S.DataService.CoinMult(data))
	S.DataService.RemoveItem(data, item.Id)
	data.Coins += coins
	return coins
end

function Inv.Start()
	local A = S.Actions
	A.Equip = function(player, id)
		local data = S.DataService.Get(player)
		if typeof(id) ~= "string" or not S.DataService.FindItem(data, id) or data.Equipped == id then return end
		data.Equipped = id
		S.MorphService.Spawn(player, true)
		S.DataService.Sync(player)
	end
	A.Lock = function(player, id)
		local data = S.DataService.Get(player)
		local item = typeof(id) == "string" and S.DataService.FindItem(data, id)
		if item then item.Locked = not item.Locked; S.DataService.Sync(player) end
	end
	A.Sell = function(player, ids)
		local data = S.DataService.Get(player)
		if typeof(ids) == "string" then ids = { ids } end
		if typeof(ids) ~= "table" then return end
		local total, n = 0, 0
		for _, id in ipairs(ids) do
			local item = typeof(id) == "string" and S.DataService.FindItem(data, id)
			if item then local c = sellItem(player, data, item); if c > 0 then total += c; n += 1 end end
		end
		if n > 0 then S.DataService.Toast(player, string.format("Sold %d animal%s for %s Coins", n, n == 1 and "" or "s", AnimalData.Comma(total)), Config.UI.Gold) end
		S.DataService.Sync(player)
	end
	A.BuySlot = function(player)
		local data = S.DataService.Get(player)
		local idx = data.Slots - Config.Inventory.StartSlots + 1
		local cost = Config.Inventory.SlotCosts[idx]
		if not cost then S.DataService.Toast(player, "Inventory is at max size!"); return end
		if data.Coins < cost then S.DataService.Toast(player, "Need " .. AnimalData.Comma(cost) .. " Coins for another slot."); return end
		data.Coins -= cost; data.Slots += 1
		S.DataService.Toast(player, "Inventory upgraded to " .. data.Slots .. " slots!", Color3.fromRGB(120, 255, 170))
		S.DataService.Sync(player)
	end
	local function vaultFind(data, id)
		for i, it in ipairs(data.Vault) do if it.Id == id then return it, i end end
	end
	A.ClaimVault = function(player, id)
		local data = S.DataService.Get(player)
		local item, i = vaultFind(data, id); if not item then return end
		if #data.Inventory >= data.Slots then S.DataService.Toast(player, "Free a slot first (sell, sacrifice or buy a slot)."); return end
		table.remove(data.Vault, i); table.insert(data.Inventory, item)
		S.DataService.Sync(player)
	end
	A.SellVault = function(player, id)
		local data = S.DataService.Get(player)
		local item, i = vaultFind(data, id); if not item then return end
		local coins = math.floor(Config.SellValue(AnimalData.ItemRarity(item)) * S.DataService.CoinMult(data))
		table.remove(data.Vault, i); data.Coins += coins
		S.DataService.Toast(player, "Sold " .. AnimalData.ItemName(item) .. " for " .. AnimalData.Comma(coins) .. " Coins", Config.UI.Gold)
		S.DataService.Sync(player)
	end
	A.SetSetting = function(player, key, value)
		local data = S.DataService.Get(player)
		if key == "CutsceneMin" and typeof(value) == "number" and table.find(Config.Cutscene.Options, value) then data.Settings.CutsceneMin = value
		elseif key == "ReduceOthersFX" and typeof(value) == "boolean" then data.Settings.ReduceOthersFX = value
		else return end
		S.DataService.Sync(player)
	end
	A.SyncRequest = function(player) S.DataService.Sync(player) end
end

return Inv
