-- TotemService: craft permanent Totems from animals + biome materials; equip into 1-2 slots
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Modules.Config)
local AnimalData = require(RS.Modules.AnimalData)

local Totem = {}
local S

function Totem.Init(services) S = services end
function Totem.Slots(player)
	local data = S.DataService.Get(player)
	return Config.TotemSlots.Base + ((data and data.Rank >= Config.TotemSlots.BonusRank) and 1 or 0)
end

-- pick the cheapest matching animals (unlocked, unequipped, prefer Normal & non-TITAN)
local function pickAnimals(data, animal, n)
	local list = {}
	for _, it in ipairs(data.Inventory) do
		if it.Animal == animal and not it.Locked and it.Id ~= data.Equipped then table.insert(list, it) end
	end
	table.sort(list, function(a, b) return AnimalData.ItemRarity(a) < AnimalData.ItemRarity(b) end)
	if #list < n then return nil end
	local out = {}
	for i = 1, n do out[i] = list[i] end
	return out
end

function Totem.Start()
	local A = S.Actions
	A.CraftTotem = function(player, id)
		if not S.StationService.Near(player, "Totem") then return end
		local cfg = typeof(id) == "string" and Config.Totems[id]; if not cfg then return end
		local data = S.DataService.Get(player)
		if data.Coins < (cfg.Cost.Coins or 0) then S.DataService.Toast(player, "Not enough Coins."); return end
		for m, n in pairs(cfg.Cost.Materials or {}) do
			if (data.Materials[m] or 0) < n then S.DataService.Toast(player, "Need " .. n .. " " .. Config.Materials[m].Display .. " (spawn during weather events)."); return end
		end
		local consume = {}
		for animal, n in pairs(cfg.Cost.Animals or {}) do
			local picks = pickAnimals(data, animal, n)
			if not picks then S.DataService.Toast(player, "Need " .. n .. "x unlocked " .. AnimalData.Animals[animal].Display .. "."); return end
			for _, it in ipairs(picks) do table.insert(consume, it.Id) end
		end
		data.Coins -= (cfg.Cost.Coins or 0)
		for m, n in pairs(cfg.Cost.Materials or {}) do data.Materials[m] -= n end
		for _, iid in ipairs(consume) do S.DataService.RemoveItem(data, iid) end
		table.insert(data.Totems, id)
		data.Stats.Crafts += 1
		if #data.EquippedTotems < Totem.Slots(player) then table.insert(data.EquippedTotems, id) end
		S.DataService.Notify(player, "Banner", { Text = "CRAFTED " .. cfg.Display:upper() .. "!", Color = Color3.fromRGB(120, 255, 180) })
		S.ProgressionService.CheckRanks(player)
		S.DataService.Sync(player)
	end
	A.ToggleTotem = function(player, id)
		local data = S.DataService.Get(player)
		if typeof(id) ~= "string" or not Config.Totems[id] then return end
		local at = table.find(data.EquippedTotems, id)
		if at then table.remove(data.EquippedTotems, at)
		else
			local owned, equipped = 0, 0
			for _, t in ipairs(data.Totems) do if t == id then owned += 1 end end
			for _, t in ipairs(data.EquippedTotems) do if t == id then equipped += 1 end end
			if owned <= equipped then return end
			if #data.EquippedTotems >= Totem.Slots(player) then S.DataService.Toast(player, "All Totem slots are full."); return end
			table.insert(data.EquippedTotems, id)
		end
		S.DataService.Sync(player)
	end
end

return Totem
