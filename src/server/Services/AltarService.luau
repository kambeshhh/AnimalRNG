-- AltarService: sacrifice animals into Essence, brew Lucky Potions + the Eclipse Elixir, drink potions
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Modules.Config)
local AnimalData = require(RS.Modules.AnimalData)

local Altar = {}
local S

function Altar.Init(services) S = services end

function Altar.Start()
	local A = S.Actions
	A.Sacrifice = function(player, ids)
		if not S.StationService.Near(player, "Altar") then return end
		local data = S.DataService.Get(player)
		if typeof(ids) ~= "table" then return end
		local gained, n = 0, 0
		for _, id in ipairs(ids) do
			local item = typeof(id) == "string" and S.DataService.FindItem(data, id)
			if item and not item.Locked and item.Id ~= data.Equipped then
				gained += AnimalData.ItemRarity(item); n += 1
				S.DataService.RemoveItem(data, item.Id)
			end
		end
		if n == 0 then S.DataService.Toast(player, "Select unlocked, unequipped animals to sacrifice."); return end
		data.Essence += gained; data.Stats.Sacrifices += n
		S.DataService.Toast(player, string.format("Sacrificed %d animal%s: +%s Essence", n, n == 1 and "" or "s", AnimalData.Comma(gained)), Color3.fromRGB(200, 140, 255))
		S.DataService.Sync(player)
	end
	A.BrewLucky = function(player)
		if not S.StationService.Near(player, "Altar") then return end
		local data = S.DataService.Get(player); local cost = Config.Potions.Lucky.CoinCost
		if data.Coins < cost then S.DataService.Toast(player, "Need " .. cost .. " Coins."); return end
		data.Coins -= cost; data.Potions.Lucky += 1
		S.DataService.Toast(player, "Brewed a Lucky Potion!", Color3.fromRGB(120, 255, 170)); S.DataService.Sync(player)
	end
	A.BrewElixir = function(player)
		if not S.StationService.Near(player, "Altar") then return end
		local data = S.DataService.Get(player); local cfg = Config.Potions.Elixir
		if data.Rank < cfg.RankRequired then S.DataService.Toast(player, "Eclipse Elixir unlocks at Hunter Rank " .. cfg.RankRequired .. "."); return end
		if data.Essence < cfg.EssenceCost then S.DataService.Toast(player, "Need " .. AnimalData.Comma(cfg.EssenceCost) .. " Essence."); return end
		data.Essence -= cfg.EssenceCost; data.Potions.Elixir += 1
		S.DataService.Notify(player, "Banner", { Text = "ECLIPSE ELIXIR BREWED!", Color = Config.UI.Gold }); S.DataService.Sync(player)
	end
	A.DrinkPotion = function(player, kind)
		local data = S.DataService.Get(player)
		if (data.Potions[kind] or 0) <= 0 then return end
		if kind == "Lucky" then
			data.Potions.Lucky -= 1
			data.LuckyUntil = math.max(os.time(), data.LuckyUntil or 0) + Config.Potions.Lucky.Duration
			S.DataService.Toast(player, "+100% Luck for 5 minutes!", Color3.fromRGB(120, 255, 170))
		elseif kind == "Elixir" then
			if data.ElixirArmed then S.DataService.Toast(player, "Your Eclipse Elixir is already active!"); return end
			data.Potions.Elixir -= 1; data.ElixirArmed = true
			S.MorphService.SetElixirAura(player, true)
			for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
				S.DataService.Notify(p, "Banner", { Text = player.DisplayName .. " drank an ECLIPSE ELIXIR! (+50,000% Luck next roll)", Color = Config.UI.Gold })
			end
		else return end
		S.DataService.Sync(player)
	end
end

return Altar
