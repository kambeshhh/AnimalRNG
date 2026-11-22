-- HypeService (V6): the active gameplay layer on top of passive rolling.
--   • ANIME OVERDRIVE gauge (charged by rolls; unleash for 20s of x2 luck / +50% roll speed)
--   • CRITICAL ROLLS ("Black Flash", x2.5 / SUPER x5 luck on a single throw)
--   • BREAKTHROUGH (+1 tier climb on landing) and BIOME RESONANCE (+50% coin bonus for weather-featured creatures)
--   • HUNTER BOUNTIES (3 auto-refreshing short-term goals that pay Lucky Spins, Essence, Potions & Biome Cores)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Modules.Config)
local AnimalData = require(RS.Modules.AnimalData)

local Hype = {}
local S
local rng = Random.new()

function Hype.Init(services) S = services end

------------------------------------------------------------------ Overdrive
function Hype.OverdriveActive(player)
	return (player:GetAttribute("OverdriveUntil") or 0) > workspace:GetServerTimeNow()
end

function Hype.ChargeOverdrive(player, data, r)
	if Hype.OverdriveActive(player) then return end
	local O = Config.Overdrive
	local gain = O.PerRoll
	if (r.TierIndex or 1) >= 5 then gain += O.PerEpic end
	if r.Bonus then gain += O.PerBonus end
	if r.Crit then gain += O.PerCrit end
	data.Overdrive = math.min(O.Max, (data.Overdrive or 0) + gain)
	player:SetAttribute("Overdrive", data.Overdrive)
end

function Hype.Activate(player)
	local data = S.DataService.Get(player); if not data then return false end
	if Hype.OverdriveActive(player) or (data.Overdrive or 0) < Config.Overdrive.Max then return false end
	data.Overdrive = 0
	data.Stats.Overdrives = (data.Stats.Overdrives or 0) + 1
	player:SetAttribute("Overdrive", 0)
	player:SetAttribute("OverdriveUntil", workspace:GetServerTimeNow() + Config.Overdrive.Duration)
	Hype.Bump(player, data, "Overdrives", 1)
	S.DataService.Notify(player, "Overdrive", { Duration = Config.Overdrive.Duration })
	S.DataService.Sync(player)
	return true
end

------------------------------------------------------------------ Critical Roll
-- returns multiplier, kind ("Crit" | "Super" | nil)
function Hype.RollCrit(player, data)
	local C = Config.Crit
	local dieIdx = table.find(Config.Dice.Order, data.EquippedDie or "Wooden") or 1
	local chance = C.Base + (dieIdx - 1) * C.PerDie + (Hype.OverdriveActive(player) and Config.Overdrive.CritBonus or 0)
	if rng:NextNumber() >= chance then return 1, nil end
	if rng:NextNumber() < C.SuperChance then return C.SuperMult, "Super" end
	return C.Mult, "Crit"
end

------------------------------------------------------------------ Breakthrough (+1 tier) & Resonance
function Hype.TryBreakthrough(player, roll)
	local B = Config.Breakthrough
	if (roll.Tier or 1) > B.MaxFromTier then return false end
	local chance = B.Chance + (Hype.OverdriveActive(player) and Config.Overdrive.BreakthroughBonus or 0)
	if rng:NextNumber() >= chance then return false end
	roll.Tier = math.min(AnimalData.TierCount - 1, roll.Tier + 1)
	return true
end

function Hype.IsResonant(animal)
	local boosts = S.WeatherService.Boosts() or {}
	return (boosts[animal] or 1) > 1
end

------------------------------------------------------------------ Hunter Bounties
local POOL_BY_ID = {}
for _, def in ipairs(Config.Bounties.Pool) do POOL_BY_ID[def.Id] = def end
Hype.PoolById = POOL_BY_ID

local function newBounty(data)
	local taken = {}
	for _, b in ipairs(data.Bounties or {}) do taken[b.Id] = true end
	local choices = {}
	for _, def in ipairs(Config.Bounties.Pool) do if not taken[def.Id] then table.insert(choices, def) end end
	if #choices == 0 then choices = Config.Bounties.Pool end
	local def = choices[rng:NextInteger(1, #choices)]
	local scale = rng:NextInteger(1, #def.Targets)
	return { Id = def.Id, Stat = def.Stat, Target = def.Targets[scale], Progress = 0, Scale = scale }
end

-- fills empty / invalid slots. Returns true if anything changed.
function Hype.Ensure(data)
	data.Bounties = data.Bounties or {}
	local changed = false
	for i = #data.Bounties, 1, -1 do
		local b = data.Bounties[i]
		if type(b) ~= "table" or not POOL_BY_ID[b.Id] then table.remove(data.Bounties, i); changed = true end
	end
	while #data.Bounties < Config.Bounties.Slots do
		table.insert(data.Bounties, newBounty(data)); changed = true
	end
	return changed
end

local function scaledReward(def, scale)
	local m = Config.Bounties.ScaleMult[scale] or 1
	local out = {}
	for k, v in pairs(def.Reward) do
		if type(v) == "number" and k ~= "Amount" then out[k] = math.max(1, math.floor(v * m + 0.5))
		elseif k == "Materials" then
			out.Materials = {}
			for mk, mv in pairs(v) do out.Materials[mk] = math.max(1, math.floor(mv * m + 0.5)) end
		else out[k] = v end
	end
	if out.Potion then out.Amount = math.max(1, math.floor((def.Reward.Amount or 1) * m + 0.5)) end
	return out
end
Hype.ScaledReward = scaledReward

function Hype.RewardText(rew)
	local parts = {}
	if rew.LuckySpins then table.insert(parts, rew.LuckySpins .. " Lucky Spin" .. (rew.LuckySpins == 1 and "" or "s")) end
	if rew.Coins then table.insert(parts, AnimalData.Comma(rew.Coins) .. " Coins") end
	if rew.Essence then table.insert(parts, AnimalData.Comma(rew.Essence) .. " Essence") end
	if rew.Potion then
		local p = Config.Potions[rew.Potion]
		table.insert(parts, (rew.Amount or 1) .. "x " .. (p and p.Display or rew.Potion))
	end
	if rew.Materials then
		for _, mk in ipairs(Config.MaterialOrder) do
			local n = rew.Materials[mk]
			if n then table.insert(parts, n .. " " .. Config.Materials[mk].Display) end
		end
	end
	return table.concat(parts, " · ")
end

local function grant(data, rew)
	if rew.Coins then data.Coins += math.floor(rew.Coins * S.DataService.CoinMult(data)) end
	if rew.Essence then data.Essence = (data.Essence or 0) + rew.Essence end
	if rew.LuckySpins then data.LuckySpins = (data.LuckySpins or 0) + rew.LuckySpins end
	if rew.Potion then data.Potions[rew.Potion] = (data.Potions[rew.Potion] or 0) + (rew.Amount or 1) end
	if rew.Materials then for k, v in pairs(rew.Materials) do data.Materials[k] = (data.Materials[k] or 0) + v end end
end

function Hype.Bump(player, data, stat, n)
	Hype.Ensure(data)
	for i, b in ipairs(data.Bounties) do
		if b.Stat == stat then
			b.Progress = math.min(b.Target, (b.Progress or 0) + (n or 1))
			if b.Progress >= b.Target then
				local def = POOL_BY_ID[b.Id]
				local rew = scaledReward(def, b.Scale or 1)
				grant(data, rew)
				data.Stats.BountiesDone = (data.Stats.BountiesDone or 0) + 1
				S.DataService.Notify(player, "Bounty", { Text = string.format(def.Text, b.Target), Reward = Hype.RewardText(rew) })
				local others = {}
				for j, x in ipairs(data.Bounties) do if j ~= i then table.insert(others, x) end end
				table.insert(others, b) -- don't immediately re-roll the same bounty
				data.Bounties[i] = newBounty({ Bounties = others })
			end
		end
	end
end

-- called once per roll result
function Hype.TrackRoll(player, data, r)
	Hype.Bump(player, data, "Rolls", 1)
	if (r.TierIndex or 1) >= 5 then Hype.Bump(player, data, "Epic", 1) end
	if (r.TierIndex or 1) >= 7 then Hype.Bump(player, data, "Mythic", 1) end
	if r.Crit then Hype.Bump(player, data, "Crits", 1) end
	if r.Breakthrough then Hype.Bump(player, data, "Breakthroughs", 1) end
	if r.NewIndex then Hype.Bump(player, data, "NewIndex", 1) end
	if r.Resonance then Hype.Bump(player, data, "Resonance", 1) end
end

function Hype.Start()
	S.Actions.ActivateOverdrive = function(player) Hype.Activate(player) end
	-- keep attributes + bounty slots live (cheap; RollService already pushes luck/cooldowns on the same cadence)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, p in ipairs(Players:GetPlayers()) do
				local data = S.DataService.Get(p)
				if data then
					if p:GetAttribute("Overdrive") ~= (data.Overdrive or 0) then p:SetAttribute("Overdrive", data.Overdrive or 0) end
					if Hype.Ensure(data) then S.DataService.Sync(p) end
				end
			end
		end
	end)
end

return Hype
