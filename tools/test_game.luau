--!strict
-- Animal RNG Automated In-Studio Diagnostic Test Suite
-- Paste into Studio Command Bar while in Play mode or Edit mode:
-- loadstring(game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/kambeshhh/AnimalRNG/main/tools/test_game.luau?v=" .. os.time()))()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config") :: ModuleScript) :: any
local AnimalData = require(Modules:WaitForChild("AnimalData") :: ModuleScript) :: any
local NumberFormat = require(Modules:WaitForChild("NumberFormat") :: ModuleScript) :: any

print("==================================================")
print("🧪 [Animal RNG] Starting Diagnostic Test Suite...")
print("==================================================")

local passed = 0
local failed = 0

local function assertTest(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print("  ✅ [PASS] " .. name)
	else
		failed += 1
		warn("  ❌ [FAIL] " .. name .. " — " .. (detail or "Assertion failed"))
	end
end

-- Test 1: Ladder Rarity Integrity (Tier 1 to Tier 28)
local ladderCount = #Config.RarityLadder
assertTest("28-Tier Rarity Ladder", ladderCount == 28, "Expected 28 tiers, got " .. tostring(ladderCount))

-- Test 2: Tier 28 Unattainable Odds
local tier28 = Config.RarityLadder[28]
assertTest("Tier 28 is Unattainable at 1 in 1Qa", tier28 and tier28.Tier == 28 and tier28.Odds == 1e15, "Tier 28 odds mismatch")

-- Test 3: Ouroboros Exclusivity (Must ONLY be in Tier 28)
local ouroborosInLowerTiers = false
for i = 1, 27 do
	local tier = Config.RarityLadder[i]
	if tier and tier.Pool then
		for _, creature in ipairs(tier.Pool) do
			if creature == "Ouroboros" then
				ouroborosInLowerTiers = true
				break
			end
		end
	end
end
assertTest("Ouroboros Excluded from Tiers 1-27", not ouroborosInLowerTiers, "Ouroboros was found in lower tiers!")

-- Test 4: 8 Mutations Defined
local mutationCount = 0
for _ in pairs(Config.Mutations) do
	mutationCount += 1
end
assertTest("8 Mutation Types", mutationCount == 8, "Expected 8 mutations, got " .. tostring(mutationCount))

-- Test 5: NumberFormat.Odds and NumberFormat.Comma
local formatted1Qa = NumberFormat.Odds(1e15)
local formatted1Sx = NumberFormat.Odds(1e21)
assertTest("NumberFormat 1Qa Compact", formatted1Qa:find("1 in 1Qa") ~= nil, "Got: " .. formatted1Qa)
assertTest("NumberFormat 1Sx Singularity", formatted1Sx:find("1 in 1Sx") ~= nil, "Got: " .. formatted1Sx)

-- Test 6: 8-Tier 3D Dice Ladder
local diceCount = #Config.Dice
assertTest("8-Tier 3D Dice Config", diceCount == 8, "Expected 8 dice, got " .. tostring(diceCount))

-- Test 7: Rebirth Config
assertTest("Rebirth Luck & Coin Multipliers", Config.Rebirth.LuckBase == 1.35 and Config.Rebirth.CoinBase == 1.50, "Rebirth math mismatch")

-- Test 8: Active Companion Pack
assertTest("Pack Limits (3 Companions)", Config.Pack.MaxActive == 3 and Config.Pack.TickInterval == 2, "Pack settings mismatch")

-- Test 9: Promo Codes Config
local ouroCode = Config.Codes["OUROBOROS"]
local slimeCode = Config.Codes["SLIMEDICE"]
assertTest("Promo Codes Active", ouroCode ~= nil and slimeCode ~= nil, "Codes missing")

print("==================================================")
if failed == 0 then
	print(string.format("🎉 ALL %d DIAGNOSTIC TESTS PASSED! Game systems are 100%% operational!", passed))
else
	warn(string.format("⚠️ Completed with %d passed, %d failed.", passed, failed))
end
print("==================================================")
