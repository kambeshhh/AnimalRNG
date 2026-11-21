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

-- Test 1: 28-Tier Ladder Integrity
local tierCount = AnimalData.TierCount or #AnimalData.Tiers
assertTest("28-Tier Rarity Ladder", tierCount == 28, "Expected 28 tiers, got " .. tostring(tierCount))

-- Test 2: Tier 28 Unattainable Odds
local tier28 = AnimalData.Tiers[28]
assertTest("Tier 28 is Unattainable at 1 in 1Qa", tier28 and tier28.Min == 1e15, "Tier 28 odds mismatch")

-- Test 3: Rich Index: All Animals in All Tiers Rollable
local rollRng = Random.new()
local forcedT28Roll = AnimalData.Roll(1e18, {}, rollRng, 0.5, { Tier = 28 })
assertTest("Any Animal Rollable at Tier 28", forcedT28Roll ~= nil and forcedT28Roll.Tier == 28 and forcedT28Roll.Animal ~= nil, "Roll failed")

-- Test 4: 8 Mutations Defined
local mutationCount = #AnimalData.MutationOrder
assertTest("8 Mutation Types", mutationCount == 8, "Expected 8 mutations, got " .. tostring(mutationCount))

-- Test 5: NumberFormat.Odds and NumberFormat.Comma
local formatted1Qa = NumberFormat.Odds(1e15)
local formatted1Sx = NumberFormat.Odds(1e21)
assertTest("NumberFormat 1Qa Compact", formatted1Qa:find("1 in 1Qa") ~= nil, "Got: " .. formatted1Qa)
assertTest("NumberFormat 1Sx Singularity", formatted1Sx:find("1 in 1Sx") ~= nil, "Got: " .. formatted1Sx)

-- Test 6: 8-Tier 3D Dice Ladder
local diceCount = #Config.Dice.Order
assertTest("8-Tier 3D Dice Config", diceCount == 8, "Expected 8 dice, got " .. tostring(diceCount))

-- Test 7: Rebirth Smooth Curve & World 2 Milestone
local coins1, ess1 = Config.RebirthCost(0)
local coins10, ess10 = Config.RebirthCost(9)
assertTest("Rebirth Smooth Curve Scaling", coins1 == 500000 and coins10 > 70000000 and Config.Rebirth.CostGrowth == 1.75, "Rebirth math mismatch")
assertTest("World 2 Unlocks at Rebirth 10", Config.Rebirth.World2RebirthRequired == 10, "World 2 requirement mismatch")

-- Test 8: Infinite P2W Luck Developer Product
local infProduct = Config.Monetization.Products.InfiniteLuckSurge
assertTest("Infinite P2W Luck Product Defined", infProduct ~= nil and infProduct.Infinite == true and infProduct.LuckAdd == 1.0, "Infinite luck product missing")

-- Test 9: Active Companion Pack
assertTest("Pack Limits (3 Companions)", Config.Pack.MaxCompanions == 3 and Config.Pack.TickInterval == 2, "Pack settings mismatch")

-- Test 10: Promo Codes Active
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
