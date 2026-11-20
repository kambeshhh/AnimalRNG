--!strict
-- AnimalData v2 — Creature Registry + 28-tier roll + 8 mutations (shared by server and client)
--   Combined odds of an item = CreatureOdds × TierOdds × MutationMult   (exact, integer-rounded)
--   Creatures are registered DYNAMICALLY from ReplicatedStorage.Animals. Per-model attributes override defaults:
--     Group ("Starter" | "Apex" | "Mythical" | "Cosmic" | "Unattainable"), Weight (number), Display, Ability, WalkSpeed, Color (Color3), Biome
local RS = game:GetService("ReplicatedStorage")
local C = Color3.fromRGB
local NF = require(script.Parent:WaitForChild("NumberFormat"))
local AnimalData = {}

------------------------------------------------------------------ groups
AnimalData.Groups = {
	{ Key = "Starter",  Display = "Starter / Normal",         Share = 0.65, Color = C(140, 220, 150) },
	{ Key = "Apex",     Display = "Apex / Elemental",         Share = 0.22, Color = C(110, 190, 255) },
	{ Key = "Mythical", Display = "Mythical & Fantasy",       Share = 0.11, Color = C(220, 120, 255) },
	{ Key = "Cosmic",   Display = "Cosmic & Primordial Gods", Share = 0.02, Color = C(255, 210, 110) },
}
AnimalData.UnattainableCreature = "Ouroboros"

-- defaults for known models (attributes on the model win)
local META = {
	MeadowRabbit       = { "Meadow Rabbit",        "Starter",  "Dash",       26, C(170, 255, 170) },
	RedFox             = { "Red Fox",              "Starter",  "Dash",       28, C(255, 120, 70) },
	RegalLion          = { "Regal Lion",           "Starter",  "Slam",       27, C(255, 200, 110) },
	HoneyBadger        = { "Honey Badger",         "Starter",  "Dash",       27, C(225, 225, 225) },
	BoldTiger          = { "Bold Tiger",           "Starter",  "Dash",       30, C(255, 150, 50) },
	Crocodile          = { "Crocodile",            "Starter",  "Slam",       24, C(120, 170, 100) },
	VoltCheetah        = { "Volt Cheetah",         "Apex",     "Blink",      34, C(255, 230, 60) },
	FrostbiteWolf      = { "Frostbite Wolf",       "Apex",     "FrostPulse", 30, C(140, 220, 255), "Blizzard" },
	MagmaGrizzly       = { "Magma Grizzly",        "Apex",     "Slam",       25, C(255, 110, 40),  "Volcanic" },
	Thunderbird        = { "Thunderbird",          "Apex",     "Blink",      32, C(110, 170, 255) },
	Basilisk           = { "Basilisk",             "Apex",     "FrostPulse", 26, C(90, 150, 170) },
	Wyvern             = { "Wyvern",               "Apex",     "Beam",       30, C(200, 120, 120) },
	SolarEclipseDragon = { "Solar Eclipse Dragon", "Mythical", "Beam",       30, C(255, 150, 60),  "Eclipse" },
	Griffin            = { "Griffin",              "Mythical", "Blink",      32, C(230, 180, 90) },
	Phoenix            = { "Phoenix",              "Mythical", "Beam",       31, C(255, 120, 40),  "Volcanic" },
	Pegasus            = { "Pegasus",              "Mythical", "Dash",       34, C(240, 240, 255) },
	Kitsune            = { "Kitsune",              "Mythical", "Blink",      33, C(255, 190, 120) },
	Cerberus           = { "Cerberus",             "Mythical", "Slam",       29, C(120, 80, 90),   "Volcanic" },
	Minotaur           = { "Minotaur",             "Mythical", "Slam",       26, C(170, 110, 80) },
	Chimera            = { "Chimera",              "Mythical", "Beam",       28, C(210, 160, 90) },
	CelestialUnicorn   = { "Celestial Unicorn",    "Mythical", "Blink",      33, C(150, 140, 255), "Eclipse" },
	Hydra              = { "Hydra",                "Mythical", "FrostPulse", 26, C(80, 170, 110) },
	Leviathan          = { "Leviathan",            "Cosmic",   "FrostPulse", 30, C(70, 140, 255),  "Blizzard" },
	Kraken             = { "Kraken",               "Cosmic",   "Slam",       26, C(60, 110, 140) },
	InfinityPhoenix    = { "Infinity Phoenix",     "Cosmic",   "Beam",       34, C(190, 120, 255), "Eclipse" },
	PrimordialDragon   = { "Primordial Dragon",    "Cosmic",   "Beam",       32, C(255, 80, 60),   "Eclipse" },
	Ouroboros          = { "Ouroboros",            "Unattainable", "Beam",   36, C(255, 225, 150) },
}

local function prettify(name: string): string
	return (name:gsub("(%l)(%u)", "%1 %2"))
end

------------------------------------------------------------------ registry build
AnimalData.Animals = {}
local folder = RS:FindFirstChild("Animals")
local function register(name: string, model: Instance?)
	local m = META[name] or {}
	local function attr(k, def) local v = model and model:GetAttribute(k); if v == nil then return def end; return v end
	AnimalData.Animals[name] = {
		Display = attr("Display", m[1] or prettify(name)),
		Group = attr("Group", m[2] or "Starter"),
		Ability = attr("Ability", m[3] or "Dash"),
		WalkSpeed = attr("WalkSpeed", m[4] or 26),
		Color = attr("Color", m[5] or C(200, 200, 220)),
		Biome = attr("Biome", m[6]),
		Weight = attr("Weight", 1),
		Template = model and name or nil,
	}
end
if folder then for _, model in ipairs(folder:GetChildren()) do if model:IsA("Model") then register(model.Name, model) end end end
-- Ouroboros fallback: until its model is imported, it renders on the dragon mesh
if not AnimalData.Animals.Ouroboros then
	register("Ouroboros", nil)
	AnimalData.Animals.Ouroboros.Template = "SolarEclipseDragon"
	AnimalData.Animals.Ouroboros.Placeholder = true
end
local ouro = AnimalData.Animals.Ouroboros
ouro.Group = "Unattainable"; ouro.Exclusive = true; ouro.ShowcaseScale = 2.75

-- odds per creature: group share (renormalised over non-empty groups) split by weight
AnimalData.GroupMembers = {}
local active = 0
for _, g in ipairs(AnimalData.Groups) do
	local list, total = {}, 0
	for name, a in pairs(AnimalData.Animals) do if a.Group == g.Key then table.insert(list, name); total += a.Weight end end
	table.sort(list)
	AnimalData.GroupMembers[g.Key] = list
	g.Total = total
	if #list > 0 then active += g.Share end
end
for _, g in ipairs(AnimalData.Groups) do
	g.EffectiveShare = (#AnimalData.GroupMembers[g.Key] > 0) and g.Share / active or 0
	for _, name in ipairs(AnimalData.GroupMembers[g.Key]) do
		local a = AnimalData.Animals[name]
		a.Chance = g.EffectiveShare * a.Weight / g.Total
		a.Odds = 1 / a.Chance
		a.Rarity = a.Odds -- legacy field
	end
end
ouro.Chance = 1; ouro.Odds = 1; ouro.Rarity = 1e15

-- display order (Index / admin): Unattainable first, then rarest group → most common
AnimalData.Order = { "Ouroboros" }
for gi = #AnimalData.Groups, 1, -1 do
	for _, name in ipairs(AnimalData.GroupMembers[AnimalData.Groups[gi].Key]) do table.insert(AnimalData.Order, name) end
end
AnimalData.Common = AnimalData.GroupMembers.Starter[1] or "MeadowRabbit"

------------------------------------------------------------------ mutations (8)
AnimalData.Mutations = {
	Normal        = { Display = "Normal",         Mult = 1,       Color = C(200, 205, 220), Rank = 1 },
	Gilded        = { Display = "Gilded",         Mult = 5,       Color = C(255, 200, 70),  Rank = 2 },
	Prismatic     = { Display = "Prismatic",      Mult = 25,      Color = C(130, 230, 255), Rank = 3, Rainbow = true },
	Abyssal       = { Display = "Abyssal",        Mult = 150,     Color = C(70, 60, 200),   Rank = 4 },
	Astral        = { Display = "Astral",         Mult = 1000,    Color = C(170, 200, 255), Rank = 5 },
	ChronoShifted = { Display = "Chrono-Shifted", Mult = 10000,   Color = C(90, 255, 210),  Rank = 6 },
	Sovereign     = { Display = "Sovereign",      Mult = 100000,  Color = C(255, 220, 120), Rank = 7 },
	Singularity   = { Display = "Singularity",    Mult = 1000000, Color = C(240, 240, 255), Rank = 8, Rainbow = true },
}
AnimalData.MutationOrder = { "Normal", "Gilded", "Prismatic", "Abyssal", "Astral", "ChronoShifted", "Sovereign", "Singularity" }
AnimalData.IndexVariants = AnimalData.MutationOrder

AnimalData.Tiers = {
	{ Name = "Common",       Min = 1,       Color = C(200, 205, 220) }, -- 1
	{ Name = "Uncommon",     Min = 4,       Color = C(120, 230, 140) }, -- 2
	{ Name = "Rare",         Min = 15,      Color = C(90, 170, 255) },  -- 3
	{ Name = "Unusual",      Min = 50,      Color = C(80, 225, 210) },  -- 4
	{ Name = "Epic",         Min = 200,     Color = C(180, 100, 255) }, -- 5
	{ Name = "Legendary",    Min = 750,     Color = C(255, 200, 60) },  -- 6
	{ Name = "Mythical",     Min = 2500,    Color = C(255, 80, 150) },  -- 7
	{ Name = "Exalted",      Min = 1e4,     Color = C(255, 140, 70) },  -- 8
	{ Name = "Divine",       Min = 3.5e4,   Color = C(255, 235, 150) }, -- 9
	{ Name = "Sacred",       Min = 1.25e5,  Color = C(170, 255, 230) }, -- 10
	{ Name = "Arcane",       Min = 4.5e5,   Color = C(150, 120, 255) }, -- 11
	{ Name = "Ancient",      Min = 1.6e6,   Color = C(215, 170, 110) }, -- 12
	{ Name = "Ethereal",     Min = 6e6,     Color = C(190, 230, 255) }, -- 13
	{ Name = "Astral",       Min = 2e7,     Color = C(120, 160, 255) }, -- 14
	{ Name = "Galactic",     Min = 7.5e7,   Color = C(200, 110, 255) }, -- 15
	{ Name = "Eternal",      Min = 2.5e8,   Color = C(255, 215, 120) }, -- 16
	{ Name = "Cosmic",       Min = 1e9,     Color = C(110, 90, 255) },  -- 17
	{ Name = "Transcendent", Min = 3.5e9,   Color = C(255, 245, 220) }, -- 18
	{ Name = "Infinite",     Min = 1.25e10, Color = C(90, 255, 200) },  -- 19
	{ Name = "Omniscient",   Min = 4.5e10,  Color = C(255, 255, 140) }, -- 20
	{ Name = "Paradox",      Min = 1.6e11,  Color = C(255, 100, 220) }, -- 21
	{ Name = "Mythos",       Min = 6e11,    Color = C(255, 160, 90) },  -- 22
	{ Name = "Abyssal",      Min = 2e12,    Color = C(70, 110, 200) },  -- 23
	{ Name = "Forbidden",    Min = 7.5e12,  Color = C(220, 40, 70) },   -- 24
	{ Name = "Absolute",     Min = 2.7e13,  Color = C(240, 240, 255) }, -- 25
	{ Name = "Genesis",      Min = 1e14,    Color = C(140, 255, 120) }, -- 26
	{ Name = "Primordial",   Min = 3.5e14,  Color = C(255, 120, 40) },  -- 27
	{ Name = "Unattainable", Min = 1e15,    Color = C(255, 255, 255) }, -- 28
}
AnimalData.TierCount = #AnimalData.Tiers

export type Item = { Id: string, Animal: string, Tier: number, Mutation: string, Locked: boolean? }

------------------------------------------------------------------ item math
local LEGACY = { TITAN = 5, Void = 15, Celestial = 50 }
-- old {Animal, Titan, Color} items → {Animal, Tier, Mutation}; keeps their tier, maps the mutation to the nearest new one
function AnimalData.Migrate(item)
	if item.Tier and item.Mutation then return item end
	local oldBase = ({ MeadowRabbit = 2, RedFox = 12, VoltCheetah = 150, FrostbiteWolf = 800, MagmaGrizzly = 2500, SolarEclipseDragon = 50000, EclipseSovereign = 1e15 })[item.Animal] or 2
	local mult = (item.Titan and 5 or 1) * (LEGACY[item.Color or ""] or 1)
	local mut = "Normal"
	for _, k in ipairs(AnimalData.MutationOrder) do if AnimalData.Mutations[k].Mult <= mult then mut = k end end
	if item.Animal == "EclipseSovereign" then item.Animal = "Ouroboros" end
	item.Tier = item.Animal == "Ouroboros" and AnimalData.TierCount or math.min(AnimalData.TierCount - 1, AnimalData.TierIndex(oldBase * mult))
	item.Mutation = mut
	item.Titan = nil; item.Color = nil
	return item
end

function AnimalData.ItemTierIndex(item): number
	return math.clamp(item.Tier or 1, 1, AnimalData.TierCount)
end

function AnimalData.ItemRarity(item): number
	local a = AnimalData.Animals[item.Animal]
	local m = AnimalData.Mutations[item.Mutation or "Normal"] or AnimalData.Mutations.Normal
	local tier = AnimalData.Tiers[AnimalData.ItemTierIndex(item)]
	local creature = (a and not a.Exclusive) and a.Odds or 1
	return math.floor(creature * tier.Min * m.Mult + 0.5)
end

function AnimalData.MutationPrefix(item): string
	local m = item.Mutation
	if not m or m == "Normal" then return "" end
	return (AnimalData.Mutations[m] and AnimalData.Mutations[m].Display or m)
end

function AnimalData.ItemName(item): string
	local prefix = AnimalData.MutationPrefix(item)
	local a = AnimalData.Animals[item.Animal]
	local name = a and a.Display or item.Animal
	return prefix ~= "" and (prefix .. " " .. name) or name
end

function AnimalData.Comma(n: number): string return NF.Smart(n) end
function AnimalData.FormatRarity(n: number): string return NF.Odds(n) end          -- exact, full commas
function AnimalData.FormatRarityShort(n: number): string return NF.OddsShort(n) end -- compact (cards / HUD / boards)

function AnimalData.TemplateName(animal: string): string
	local a = AnimalData.Animals[animal]
	return (a and a.Template) or animal
end

function AnimalData.TierIndex(rarity: number): number
	local idx = 1
	for i, t in ipairs(AnimalData.Tiers) do if rarity >= t.Min then idx = i end end
	return idx
end

-- accepts an item (its rolled tier) or a raw rarity number
function AnimalData.TierFor(x)
	if type(x) == "table" then return AnimalData.Tiers[AnimalData.ItemTierIndex(x)] end
	return AnimalData.Tiers[AnimalData.TierIndex(x)]
end

------------------------------------------------------------------ the roll
-- P(tier ≥ k) = luck / Tiers[k].Min  (walk rarest → common, first success wins)
function AnimalData.RollTier(luck: number, rng: Random): number
	for k = AnimalData.TierCount, 2, -1 do
		if rng:NextNumber() < luck / AnimalData.Tiers[k].Min then return k end
	end
	return 1
end

function AnimalData.RollMutation(mLuck: number, rng: Random): string
	for i = #AnimalData.MutationOrder, 2, -1 do
		local k = AnimalData.MutationOrder[i]
		local cap = (k == "Gilded") and 0.6 or 0.5
		if rng:NextNumber() < math.min(cap, mLuck / AnimalData.Mutations[k].Mult) then return k end
	end
	return "Normal"
end

-- weighted creature pick (Ouroboros excluded); weather boosts multiply a creature's weight
function AnimalData.PickCreature(rng: Random, boosts: { [string]: number }?): string
	boosts = boosts or {}
	local total = 0
	local pool = {}
	for name, a in pairs(AnimalData.Animals) do
		if not a.Exclusive and a.Chance and a.Chance > 0 then
			local w = a.Chance * (boosts[name] or 1)
			total += w; table.insert(pool, { name, w })
		end
	end
	table.sort(pool, function(x, y) return x[1] < y[1] end)
	local r = rng:NextNumber() * total
	for _, e in ipairs(pool) do r -= e[2]; if r <= 0 then return e[1] end end
	return pool[#pool][1]
end

-- Server-authoritative roll. force = { Tier?, Mutation?, Animal? } (admin/test only)
function AnimalData.Roll(luck: number, boosts: { [string]: number }?, rng: Random, mutationExponent: number?, force: any?)
	force = force or {}
	local tier = force.Tier or AnimalData.RollTier(luck, rng)
	local animal
	if tier >= AnimalData.TierCount then animal = AnimalData.UnattainableCreature
	else
		animal = force.Animal or AnimalData.PickCreature(rng, boosts)
		if animal == AnimalData.UnattainableCreature then animal = AnimalData.PickCreature(rng, boosts) end -- strict exclusivity
	end
	local mutation = force.Mutation or AnimalData.RollMutation(luck ^ (mutationExponent or 0.5), rng)
	return { Animal = animal, Tier = tier, Mutation = mutation }
end

-- Index keys: "Animal" (discovered) and "Animal|Mutation"
function AnimalData.IndexKeys(item): { string }
	local keys = { item.Animal }
	if item.Mutation and item.Mutation ~= "Normal" then table.insert(keys, item.Animal .. "|" .. item.Mutation) end
	return keys
end

return AnimalData
