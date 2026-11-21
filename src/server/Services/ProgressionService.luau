-- ProgressionService: Hunter Ranks (1-10), Collection Index, Playtime Gifts
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Modules.Config)
local AnimalData = require(RS.Modules.AnimalData)

local Prog = {}
local S

function Prog.Init(services) S = services end

local function statValue(data, stat)
	if stat == "IndexCount" then return S.DataService.IndexCount(data) end
	return data.Stats[stat] or 0
end

local function grant(player, data, reward)
	if not reward then return end
	if reward.Coins then data.Coins += reward.Coins end
	if reward.Potion then data.Potions[reward.Potion] = (data.Potions[reward.Potion] or 0) + (reward.Amount or 1) end
	if reward.Materials then for k, v in pairs(reward.Materials) do data.Materials[k] = (data.Materials[k] or 0) + v end end
end

function Prog.CheckRanks(player)
	local data = S.DataService.Get(player); if not data then return end
	local ranked = false
	while Config.Ranks[data.Rank + 1] do
		local nextRank = Config.Ranks[data.Rank + 1]
		if statValue(data, nextRank.Req.Stat) < nextRank.Req.Value then break end
		data.Rank += 1; ranked = true
		grant(player, data, nextRank.Reward)
		S.DataService.Notify(player, "Banner", { Text = string.format("HUNTER RANK %d: %s%s", data.Rank, nextRank.Name, nextRank.Unlock and ("  •  Unlocked " .. nextRank.Unlock) or ""), Color = Config.UI.Gold })
	end
	if ranked then S.DataService.Sync(player) end
end

function Prog.AddIndex(data, item)
	local new = {}
	for _, key in ipairs(AnimalData.IndexKeys(item)) do
		if not data.Index[key] then data.Index[key] = true; table.insert(new, key) end
	end
	return new
end

function Prog.Start()
	local A = S.Actions
	A.ClaimGift = function(player, i)
		if typeof(i) ~= "number" then return end
		local data, session = S.DataService.Get(player), S.DataService.Session(player)
		local gift = Config.PlaytimeGifts[i]
		if not gift or session.Gifts[i] then return end
		local minutes = (workspace:GetServerTimeNow() - session.Start) / 60
		if minutes < gift.Minutes then return end
		session.Gifts[i] = true
		grant(player, data, gift.Reward)
		S.DataService.Toast(player, "Playtime gift claimed!", Color3.fromRGB(120, 255, 170))
		S.DataService.Sync(player)
	end

	-- Anime Dice: 8-tier 3D Dice Ladder purchase & equip
	A.BuyDie = function(player, dieKey)
		if typeof(dieKey) ~= "string" then return end
		local cfg = Config.Dice.Types[dieKey]; if not cfg then return end
		local data = S.DataService.Get(player); if not data then return end
		data.Dice = data.Dice or { Wooden = true }
		if data.Dice[dieKey] then
			data.EquippedDie = dieKey
			S.DataService.Toast(player, string.format("🎲 Equipped %s (x%s Luck)!", cfg.Display, tostring(cfg.Luck)), cfg.Color)
			S.DataService.Sync(player)
			return
		end
		if data.Coins < (cfg.Coins or 0) then
			S.DataService.Toast(player, "Need " .. AnimalData.Comma(cfg.Coins) .. " Coins for " .. cfg.Display .. "."); return
		end
		for mat, req in pairs(cfg.Materials or {}) do
			if (data.Materials[mat] or 0) < req then
				S.DataService.Toast(player, "Need " .. req .. " " .. Config.Materials[mat].Display .. " for " .. cfg.Display .. "."); return
			end
		end
		data.Coins -= (cfg.Coins or 0)
		for mat, req in pairs(cfg.Materials or {}) do data.Materials[mat] -= req end
		data.Dice[dieKey] = true
		data.EquippedDie = dieKey
		S.DataService.Notify(player, "Banner", { Text = string.format("🎲 UNLOCKED & EQUIPPED %s (x%s LUCK)!", cfg.Display:upper(), tostring(cfg.Luck)), Color = cfg.Color })
		S.DataService.Notify(player, "PowerUpFX", { Kind = "Die", Color = cfg.Color })
		S.DataService.Sync(player)
	end

	A.EquipDie = function(player, dieKey)
		if typeof(dieKey) ~= "string" or not Config.Dice.Types[dieKey] then return end
		local data = S.DataService.Get(player)
		if not data or not (data.Dice and data.Dice[dieKey]) then return end
		data.EquippedDie = dieKey
		local cfg = Config.Dice.Types[dieKey]
		S.DataService.Toast(player, string.format("🎲 Equipped %s (x%s Luck)!", cfg.Display, tostring(cfg.Luck)), cfg.Color)
		S.DataService.Sync(player)
	end

	-- Sol's RNG x Anime Dice: 3D Wearable Relics & Gauntlets
	A.CraftRelic = function(player, relicKey)
		if typeof(relicKey) ~= "string" then return end
		local cfg = Config.Relics and Config.Relics.Types[relicKey]; if not cfg then return end
		local data = S.DataService.Get(player); if not data then return end
		data.Relics = data.Relics or {}
		data.EquippedRelics = data.EquippedRelics or {}
		if data.Relics[relicKey] then
			data.EquippedRelics[relicKey] = not data.EquippedRelics[relicKey] or nil
			if S.MorphService and S.MorphService.RefreshRelics then S.MorphService.RefreshRelics(player) end
			S.DataService.Toast(player, string.format("%s %s %s!", cfg.Icon, cfg.Display, data.EquippedRelics[relicKey] and "EQUIPPED" or "UNEQUIPPED"), cfg.Color)
			S.DataService.Sync(player)
			return
		end
		if data.Coins < (cfg.Coins or 0) then
			S.DataService.Toast(player, "Need " .. AnimalData.Comma(cfg.Coins) .. " Coins for " .. cfg.Display .. "."); return
		end
		for mat, req in pairs(cfg.Materials or {}) do
			if (data.Materials[mat] or 0) < req then
				S.DataService.Toast(player, "Need " .. req .. " " .. Config.Materials[mat].Display .. " for " .. cfg.Display .. "."); return
			end
		end
		data.Coins -= (cfg.Coins or 0)
		for mat, req in pairs(cfg.Materials or {}) do data.Materials[mat] -= req end
		data.Relics[relicKey] = true
		data.EquippedRelics[relicKey] = true
		data.Stats.Crafts = (data.Stats.Crafts or 0) + 1
		if S.MorphService and S.MorphService.RefreshRelics then S.MorphService.RefreshRelics(player) end
		S.DataService.Notify(player, "Banner", { Text = string.format("%s FORGED & EQUIPPED %s (+%d%% LUCK)!", cfg.Icon, cfg.Display:upper(), math.floor(cfg.Luck * 100)), Color = cfg.Color })
		S.DataService.Notify(player, "PowerUpFX", { Kind = "Die", Color = cfg.Color })
		S.DataService.Sync(player)
	end

	-- Slime RNG: Essence Rebirth (spends Coins & Essence, resets Coins only; keeps ALL Animals, Index, Dice, Totems, Skills & Passes)
	A.Rebirth = function(player)
		local data = S.DataService.Get(player); if not data then return end
		local cur = data.Rebirth or 0
		local coinCost, essenceCost = Config.RebirthCost(cur)
		if (data.Coins or 0) < coinCost then
			S.DataService.Toast(player, "Need " .. AnimalData.Comma(coinCost) .. " Coins to Rebirth!"); return
		end
		if (data.Essence or 0) < essenceCost then
			S.DataService.Toast(player, "Need " .. AnimalData.Comma(essenceCost) .. " ✨ Essence to Rebirth (Sacrifice duplicates at the Altar!)."); return
		end
		data.Coins = 0
		data.Essence -= essenceCost
		data.Rebirth = cur + 1
		data.Stats.Rebirths = data.Rebirth
		local luckM = Config.RebirthLuckMult(data.Rebirth)
		local coinM = Config.RebirthCoinMult(data.Rebirth)

		-- World 2 Unlock Check on Rebirth 10!
		if data.Rebirth == Config.Rebirth.World2RebirthRequired then
			data.World2Unlocked = true
			for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
				S.DataService.Notify(p, "Banner", {
					Text = string.format("🌌 %s HAS UNLOCKED THE WORLD 2 COSMIC PORTAL (REBIRTH 10)! 🌌", player.DisplayName:upper()),
					Color = Color3.fromRGB(0, 240, 255),
				})
			end
		end

		for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
			S.DataService.Notify(p, "Banner", {
				Text = string.format("🔱 %s REACHED REBIRTH %d! (Permanent x%.2f Luck & x%.2f Coins)", player.DisplayName:upper(), data.Rebirth, luckM, coinM),
				Color = Color3.fromRGB(210, 140, 255),
			})
		end
		S.DataService.Notify(player, "PowerUpFX", { Kind = "Rebirth", Level = data.Rebirth, Color = Color3.fromRGB(210, 140, 255) })
		if S.MorphService and S.MorphService.RefreshTitle then S.MorphService.RefreshTitle(player) end
		S.DataService.Sync(player)
	end

	A.TeleportWorld2 = function(player)
		local data = S.DataService.Get(player); if not data then return end
		if (data.Rebirth or 0) < Config.Rebirth.World2RebirthRequired then
			S.DataService.Toast(player, string.format("🔒 World 2 Portal requires Rebirth %d! (You have Rebirth %d)", Config.Rebirth.World2RebirthRequired, data.Rebirth or 0))
			return
		end
		local w2Spawn = workspace:FindFirstChild("World2Spawn", true) or workspace:FindFirstChild("World2", true)
		if w2Spawn and player.Character and player.Character.PrimaryPart then
			local cf = w2Spawn:IsA("BasePart") and w2Spawn.CFrame or w2Spawn:GetPivot()
			player.Character:PivotTo(cf + Vector3.new(0, 4, 0))
			S.DataService.Toast(player, "🌌 Welcome to World 2: The Astral Expanse!", Color3.fromRGB(0, 240, 255))
			S.DataService.Notify(player, "PowerUpFX", { Kind = "Die", Color = Color3.fromRGB(0, 240, 255) })
		else
			S.DataService.Toast(player, "🌌 World 2 Portal Active! Stepped through into World 2!", Color3.fromRGB(0, 240, 255))
		end
	end

	-- Slime RNG: Branching Coin Skill Tree
	A.BuySkill = function(player, skillKey)
		if typeof(skillKey) ~= "string" then return end
		local node = Config.Skills.Nodes[skillKey]; if not node then return end
		local data = S.DataService.Get(player); if not data then return end
		data.Skills = data.Skills or {}
		local cur = data.Skills[skillKey] or 0
		if cur >= node.Max then
			S.DataService.Toast(player, node.Display .. " is already MAX level!"); return
		end
		local cost = Config.SkillCost(skillKey, cur)
		if data.Coins < cost then
			S.DataService.Toast(player, "Need " .. AnimalData.Comma(cost) .. " Coins to upgrade " .. node.Display .. "."); return
		end
		data.Coins -= cost
		data.Skills[skillKey] = cur + 1
		S.DataService.Toast(player, string.format("%s %s upgraded to Lv.%d/%d!", node.Icon, node.Display, cur + 1, node.Max), Color3.fromRGB(120, 255, 170))
		S.DataService.Notify(player, "PowerUpFX", { Kind = "Skill", Color = Color3.fromRGB(120, 255, 170) })
		S.DataService.Sync(player)
	end

	-- Promo Codes & Lucky Spins
	A.RedeemCode = function(player, rawCode)
		if typeof(rawCode) ~= "string" then return end
		local code = rawCode:upper():gsub("%s+", "")
		if code == "" then return end
		local data = S.DataService.Get(player); if not data then return end
		data.RedeemedCodes = data.RedeemedCodes or {}
		if data.RedeemedCodes[code] then
			S.DataService.Toast(player, "Code '" .. code .. "' was already redeemed!", Color3.fromRGB(255, 160, 120)); return
		end
		local reward = Config.Codes[code]
		if not reward then
			S.DataService.Toast(player, "Invalid or expired code: '" .. code .. "'", Color3.fromRGB(255, 110, 110)); return
		end
		data.RedeemedCodes[code] = true
		grant(player, data, reward)
		if reward.Essence then data.Essence = (data.Essence or 0) + reward.Essence end
		if reward.Spins then data.LuckySpins = (data.LuckySpins or 0) + reward.Spins end
		S.DataService.Notify(player, "Banner", { Text = "🎁 CODE '" .. code .. "' REDEEMED: " .. reward.Desc, Color = Color3.fromRGB(80, 225, 255) })
		S.DataService.Notify(player, "PowerUpFX", { Kind = "Code", Color = Color3.fromRGB(80, 225, 255) })
		S.DataService.Sync(player)
	end

	A.ArmLuckySpin = function(player)
		local data = S.DataService.Get(player); if not data then return end
		if data.LuckySpinArmed then
			S.DataService.Toast(player, "🎰 Lucky Spin is already armed for your next roll!", Config.UI.Gold); return
		end
		if (data.LuckySpins or 0) <= 0 then
			S.DataService.Toast(player, "No Lucky Spins left — redeem codes or claim playtime gifts!", Config.UI.Muted); return
		end
		data.LuckySpins -= 1
		data.LuckySpinArmed = true
		S.DataService.Toast(player, "🎰 LUCKY SPIN ARMED! Next roll gets +2,500% Luck!", Config.UI.Gold)
		S.DataService.Notify(player, "PowerUpFX", { Kind = "LuckySpin", Color = Config.UI.Gold })
		S.DataService.Sync(player)
	end
end

return Prog
