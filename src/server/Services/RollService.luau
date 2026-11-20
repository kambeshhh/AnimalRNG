-- RollService: server-authoritative rolls (1x / 5x / auto / fast), bonus rolls, centralized luck.
--   Roll = independent Tier (1-28) × Creature (group-weighted, Ouroboros only at Tier 28) × Mutation (8)
--   Luck = (1 + Rank + Totems + AlphaZone + Potion + Weather + Index [+ Elixir]) × min(Paid, cap) × ServerEvent × BonusRoll
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(RS.Modules.Config)
local AnimalData = require(RS.Modules.AnimalData)
local Net = require(RS.Modules.Net)

local Roll = {}
local S
local rng = Random.new()
local nextAllowed = {} -- [player] = os.clock() when the next roll is allowed

function Roll.Init(services) S = services end

function Roll.EventMult()
	if (RS:GetAttribute("EventLuckUntil") or 0) > workspace:GetServerTimeNow() then return RS:GetAttribute("EventLuckMult") or 1 end
	return 1
end

-- total, additive parts, paid multipliers, paid total (after cap), event multiplier
function Roll.GetLuck(player)
	local data = S.DataService.Get(player)
	if not data then return 1, {}, {}, 1, 1 end
	local streakStacks = math.max(data.Stats.StreakStacks or 0, (data.Stats.UnluckyStreak or 0) // 100)
	local streakBonus = math.min(streakStacks * (Config.Luck.StreakPer100 or 0.02), Config.Luck.StreakCap or 0.5)
	local skillLuck = ((data.Skills and data.Skills.SuperLuck) or 0) * Config.Skills.Nodes.SuperLuck.Step
	local dieCfg = Config.Dice.Types[data.EquippedDie or "Wooden"] or Config.Dice.Types.Wooden
	local dieBonus = math.max(0, (dieCfg.Luck or 1) - 1)
	local add = { Base = 1, Rank = (data.Rank - 1) * 0.05, Streak = streakBonus, Skills = skillLuck, Die = dieBonus, Totems = 0, AlphaZone = 0, Potion = 0, Weather = 0, Index = 0 }
	for _, id in ipairs(data.EquippedTotems) do local t = Config.Totems[id]; if t then add.Totems += t.Luck end end
	if player:GetAttribute("InAlpha") then add.AlphaZone = Config.Luck.AlphaZone end
	if (data.LuckyUntil or 0) > os.time() then add.Potion = Config.Potions.Lucky.Luck end
	add.Weather = Config.Luck.Weather[S.WeatherService.Current()] or 0
	add.Index = S.DataService.IndexCount(data) * Config.Luck.IndexPerEntry
	local mult = S.MonetizationService.LuckMultipliers(player)
	local additive = 0
	for _, v in pairs(add) do additive += v end
	local rebirthMult = Config.RebirthLuckMult(data.Rebirth or 0)
	local paid = 1
	for _, v in pairs(mult) do paid *= v end
	paid = math.min(paid, Config.Monetization.PaidLuckCap)
	local event = Roll.EventMult()
	return additive * rebirthMult * paid * event, add, mult, paid, event, rebirthMult
end

function Roll.CanQuick(player)
	local data = S.DataService.Get(player)
	return data and (data.Rank >= Config.Roll.QuickRollRank or S.MonetizationService.HasPass(player, "SwiftRolls")) or false
end

function Roll.BonusEvery(data)
	local red = (data and data.Skills and data.Skills.BonusCycle or 0) * Config.Skills.Nodes.BonusCycle.Step
	return math.max(5, Config.Roll.BonusEvery - red)
end

function Roll.GetCooldown(player, quick, multi)
	local data = S.DataService.Get(player)
	local speed = 1
	if player:GetAttribute("InAlpha") then speed *= Config.Roll.AlphaSpeedMult end
	if data then
		local ts = 0
		for _, id in ipairs(data.EquippedTotems) do local t = Config.Totems[id]; if t then ts += t.Speed end end
		local skillSpd = ((data.Skills and data.Skills.RollSpeed) or 0) * Config.Skills.Nodes.RollSpeed.Step
		speed *= 1 + ts + skillSpd
		if quick and Roll.CanQuick(player) then speed *= Config.Roll.QuickRollSpeedMult end
		speed *= S.MonetizationService.SpeedMult(player)
	end
	return Config.Roll.BaseCooldown / speed * (multi and Config.Roll.MultiCooldownMult or 1)
end

function Roll.CanMulti(player)
	local data = S.DataService.Get(player)
	return data and (data.Rank >= Config.Roll.MultiRollRank or S.MonetizationService.HasPass(player, "MultiRoll")) or false
end

-- one roll through the full pipeline. force = { Tier, Mutation, Animal } for admin/test rolls
local function doRoll(player, data, luck, extra, force)
	local cycle = Roll.BonusEvery(data)
	data.Stats.BonusCounter = (data.Stats.BonusCounter or 0) + 1
	local bonus = data.Stats.BonusCounter >= cycle
	if bonus then data.Stats.BonusCounter = 0 end
	local rollLuck = luck * (bonus and Config.Roll.BonusLuckMult or 1) + (extra or 0)
	local roll = AnimalData.Roll(rollLuck, S.WeatherService.Boosts(), rng, Config.Luck.MutationLuckExponent, force)
	data.Stats.Rolls += 1
	-- Free Streak Luck: every 100 rolls without Epic (Tier 5) or better grants permanent +2% luck, capped at +50%
	if (roll.Tier or 1) >= (Config.Luck.StreakResetTier or 5) then
		data.Stats.UnluckyStreak = 0
	else
		data.Stats.UnluckyStreak = (data.Stats.UnluckyStreak or 0) + 1
		if data.Stats.UnluckyStreak % 100 == 0 then
			local maxStacks = math.floor(((Config.Luck.StreakCap or 0.5) / (Config.Luck.StreakPer100 or 0.02)) + 0.5)
			data.Stats.StreakStacks = math.min(maxStacks, (data.Stats.StreakStacks or 0) + 1)
		end
	end
	local newIndex = S.ProgressionService.AddIndex(data, roll)
	local status, item, coins = S.DataService.AddRolled(player, roll)
	local rarity = AnimalData.ItemRarity(item)
	if rarity > data.Stats.RarestPull then data.Stats.RarestPull = rarity; data.Stats.RarestName = AnimalData.ItemName(item) end
	local tier = AnimalData.TierFor(item)
	return { Item = item, Name = AnimalData.ItemName(item), Rarity = rarity, Tier = tier.Name, TierIndex = item.Tier,
		Mutation = item.Mutation, Status = status, Coins = coins, NewIndex = #newIndex > 0, Luck = rollLuck, Bonus = bonus,
		Die = data.EquippedDie or "Wooden" }
end

local function announce(player, best)
	local root = player.Character and player.Character.PrimaryPart
	local tier = AnimalData.TierFor(best.Item)
	local idx = best.TierIndex
	if idx >= Config.Roll.AnnounceTier then
		Net.Get("Jackpot"):FireAllClients({ UserId = player.UserId, Player = player.DisplayName, Name = best.Name, Rarity = best.Rarity,
			Position = root and root.Position or Vector3.zero, Animal = best.Item.Animal, TierColor = tier.Color, TierIndex = idx, Tier = tier.Name })
		S.WeatherService.Spectacle(tier.Color, idx >= AnimalData.TierCount and 12 or 7, idx >= AnimalData.TierCount)
	elseif idx >= Config.Roll.ToastTier then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then S.DataService.Toast(p, string.format("%s rolled %s (%s) — %s", player.DisplayName, best.Name, AnimalData.FormatRarity(best.Rarity), tier.Name), tier.Color) end
		end
	end
end

local function better(a, b) -- higher tier wins, then rarer combined odds
	if a.TierIndex ~= b.TierIndex then return a.TierIndex > b.TierIndex end
	return a.Rarity > b.Rarity
end

-- shared by the RequestRoll remote and the admin panel. force applies to the FIRST roll only.
function Roll.Execute(player, quick, count, force)
	local data = S.DataService.Get(player); if not data then return end
	local multi = count == Config.Roll.MultiCount
	local luck = Roll.GetLuck(player)
	local results, best = {}, nil
	for i = 1, multi and Config.Roll.MultiCount or 1 do
		local extra = 0
		local usedLuckySpin = false
		if i == 1 and not force then
			if data.ElixirArmed then
				extra += Config.Potions.Elixir.Luck
				data.ElixirArmed = false
				S.MorphService.SetElixirAura(player, false)
			end
			if data.LuckySpinArmed then
				extra += (Config.LuckySpinBoost or 25) * math.max(1, luck)
				data.LuckySpinArmed = false
				usedLuckySpin = true
			end
		end
		local r = doRoll(player, data, luck, extra, i == 1 and force or nil)
		r.Elixir = extra >= Config.Potions.Elixir.Luck
		r.LuckySpin = usedLuckySpin
		r.Quick = quick
		table.insert(results, r)
		if not best or better(r, best) then best = r end
	end
	S.ProgressionService.CheckRanks(player)
	S.DataService.Sync(player)
	Net.Get("RollResult"):FireClient(player, { Results = results, BestIndex = table.find(results, best), Multi = multi, Die = data.EquippedDie or "Wooden" })
	announce(player, best)
	return results
end

local function onRoll(player, quick, count)
	local data = S.DataService.Get(player); if not data then return end
	if typeof(count) ~= "number" then count = 1 end
	quick = quick == true and Roll.CanQuick(player)
	local multi = count == Config.Roll.MultiCount
	if multi and not Roll.CanMulti(player) then
		S.DataService.Toast(player, "5x Roll unlocks at Hunter Rank " .. Config.Roll.MultiRollRank .. " (or the 5x Roll Pass)."); return
	end
	local now = os.clock()
	if nextAllowed[player] and now < nextAllowed[player] - 0.15 then return end -- debounce (server-side cooldown)
	nextAllowed[player] = now + Roll.GetCooldown(player, quick, multi)
	Roll.Execute(player, quick, multi and Config.Roll.MultiCount or 1)
end

function Roll.Start()
	Net.Get("RequestRoll").OnServerEvent:Connect(onRoll)
	Players.PlayerRemoving:Connect(function(p) nextAllowed[p] = nil end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, p in ipairs(Players:GetPlayers()) do
				local data = S.DataService.Get(p)
				if data then
					local luck, add, mult, paid, event, rebirthMult = Roll.GetLuck(p)
					local cycle = Roll.BonusEvery(data)
					p:SetAttribute("Luck", luck)
					p:SetAttribute("LuckBreakdown", HttpService:JSONEncode({ Add = add, Mult = mult, PaidTotal = paid, Event = event, RebirthMult = rebirthMult, Total = luck }))
					p:SetAttribute("RollCooldown", Roll.GetCooldown(p, false))
					p:SetAttribute("RollCooldownQuick", Roll.GetCooldown(p, true))
					p:SetAttribute("RollCooldownMulti", Roll.GetCooldown(p, false, true))
					p:SetAttribute("CanQuick", Roll.CanQuick(p))
					p:SetAttribute("CanMulti", Roll.CanMulti(p))
					p:SetAttribute("BonusEvery", cycle)
					p:SetAttribute("BonusIn", math.max(1, cycle - (data.Stats.BonusCounter or 0)))
				end
			end
		end
	end)
end

return Roll
