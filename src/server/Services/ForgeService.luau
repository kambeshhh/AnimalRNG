-- ForgeService: risk a duplicate + Coins/Materials to mutate an animal. Failure never destroys the target.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Modules.Config)
local AnimalData = require(RS.Modules.AnimalData)

local Forge = {}
local S
local rng = Random.new()

function Forge.Init(services) S = services end

function Forge.Start()
	S.Actions.Forge = function(player, targetId, mutation)
		if not S.StationService.Near(player, "Forge") then return end
		local cfg = typeof(mutation) == "string" and Config.Forge[mutation]; if not cfg then return end
		local data = S.DataService.Get(player)
		local target = typeof(targetId) == "string" and S.DataService.FindItem(data, targetId); if not target then return end
		local cur = AnimalData.Mutations[target.Mutation or "Normal"]
		if cur.Rank >= AnimalData.Mutations[mutation].Rank then S.DataService.Toast(player, "Already " .. cur.Display .. " — pick a higher mutation."); return end
		local dup
		for _, it in ipairs(data.Inventory) do
			if it.Id ~= target.Id and it.Animal == target.Animal and not it.Locked and it.Id ~= data.Equipped then
				if not dup or AnimalData.ItemRarity(it) < AnimalData.ItemRarity(dup) then dup = it end
			end
		end
		if not dup then S.DataService.Toast(player, "You need a duplicate " .. AnimalData.Animals[target.Animal].Display .. " (unlocked, unequipped)."); return end
		if data.Coins < cfg.Coins then S.DataService.Toast(player, "Need " .. AnimalData.Comma(cfg.Coins) .. " Coins."); return end
		for m, n in pairs(cfg.Materials) do
			if (data.Materials[m] or 0) < n then S.DataService.Toast(player, "Need " .. n .. " " .. Config.Materials[m].Display .. "."); return end
		end
		data.Coins -= cfg.Coins
		for m, n in pairs(cfg.Materials) do data.Materials[m] -= n end
		S.DataService.RemoveItem(data, dup.Id)
		local success = rng:NextNumber() < cfg.Chance
		if success then
			target.Mutation = mutation
			data.Stats.Forges += 1
			S.ProgressionService.AddIndex(data, target)
			local rarity = AnimalData.ItemRarity(target)
			if rarity > data.Stats.RarestPull then data.Stats.RarestPull = rarity; data.Stats.RarestName = AnimalData.ItemName(target) end
			if data.Equipped == target.Id then S.MorphService.Spawn(player, true) end
			S.ProgressionService.CheckRanks(player)
		end
		S.DataService.Notify(player, "ForgeResult", { Success = success, Name = AnimalData.ItemName(target), Rarity = AnimalData.ItemRarity(target), Mutation = mutation })
		S.DataService.Sync(player)
	end
end

return Forge
