--!strict
-- Animal RNG : every tunable number lives here
local C = Color3.fromRGB
local Config = {}

Config.DataStoreName = "AnimalRNG_v1"
Config.StartingCoins = 0

Config.Roll = {
	BaseCooldown = 2.4,        -- seconds between rolls
	AlphaSpeedMult = 2,        -- Alpha Zone doubles roll speed
	QuickRollSpeedMult = 1.35, -- Quick Roll (Hunter Rank 3+)
	QuickRollRank = 3,
	StarThreshold = 1000,      -- 1 in 1,000+ : star reveal
	JackpotThreshold = 10000,  -- 1 in 10,000+ : sky-beam cutscene + server flex
	ExoticThreshold = 1e6,     -- 1 in 1M+     : extended jackpot
	UnattainableThreshold = 1e15, -- 1 in 1Qa+ : full spectacle, server blackout
	AnnounceTier = 20,         -- tier 20+ (Omniscient): server-wide pillar + banner
	ToastTier = 7,             -- tier 7+ (Mythical): other players get a toast
	MultiCount = 5,            -- 5x Roll
	MultiCooldownMult = 2.6,   -- 5 rolls for 2.6x the time of one (F2P speed-up)
	MultiRollRank = 2,         -- unlocked at Hunter Rank 2 (or the 5x Roll pass)
	BonusEvery = 10,           -- every 10th roll is a Bonus Roll
	BonusLuckMult = 2,         -- ...with x2 total luck
	VaultSize = 25,            -- rare pulls never auto-sell: they wait here
}

Config.Cutscene = {
	Options = { 4, 7, 10, 13, 20 }, -- player setting: minimum TIER for full cutscenes (Unattainable always plays)
	Default = 4,
}

-- Paid boosts multiply on top of the F2P (additive) luck. Capped so free progression stays meaningful.
-- Ids of 0 are placeholders: in Studio the Shop test-grants them; on live servers they show "coming soon".
Config.Monetization = {
	PaidLuckCap = 4,
	Passes = {
		LuckPass   = { Display = "Lucky Paws",   Icon = "🍀", Id = 0, Robux = 299, LuckMult = 1.5,  RandomModifier = true, Desc = "Permanent x1.5 Paid Luck multiplier (divides tier odds denominators; capped at x4 total paid luck)" },
		SwiftRolls = { Display = "Swift Rolls",  Icon = "⚡", Id = 0, Robux = 199, SpeedMult = 1.25, Desc = "Permanent +25% roll speed & unlocks Fast Roll immediately (no odds change)" },
		MultiRoll  = { Display = "5x Roll Pass", Icon = "🎰", Id = 0, Robux = 149, Desc = "Unlock 5x Roll immediately (no odds change)" },
		VIPAdmin   = { Display = "VIP Admin",    Icon = "👑", Id = 0, Robux = 10000, Desc = "Fireworks, confetti, spotlight & server shouts (cosmetic only; no odds change)" },
	},
	PassOrder = { "LuckPass", "SwiftRolls", "MultiRoll", "VIPAdmin" },
	Products = {
		LuckBoost15 = { Display = "Luck x2 · 15 min", Icon = "🌟", Id = 0, Robux = 49,  LuckMult = 2, Minutes = 15, RandomModifier = true, Desc = "x2 Paid Luck multiplier for 15 min (divides tier odds denominators; live odds update while active)" },
		LuckBoost60 = { Display = "Luck x2 · 60 min", Icon = "💫", Id = 0, Robux = 149, LuckMult = 2, Minutes = 60, RandomModifier = true, Desc = "x2 Paid Luck multiplier for 60 min (divides tier odds denominators; live odds update while active)" },
		ServerLuck  = { Display = "SERVER Luck x2 · 10 min", Icon = "🌍", Id = 0, Robux = 199, LuckMult = 2, Minutes = 10, Server = true, RandomModifier = true, Desc = "x2 Paid Luck multiplier for every player in the server for 10 min (live odds update while active)" },
		InfiniteLuckSurge = { Display = "+1x Luck Surge", Icon = "⚡", Id = 0, Robux = 99, LuckAdd = 1.0, Infinite = true, RandomModifier = true, Desc = "+1x Permanent Luck Surge! Stacks infinitely with every purchase for uncapped luck!" },
	},
	ProductOrder = { "LuckBoost15", "LuckBoost60", "ServerLuck", "InfiniteLuckSurge" },
}

Config.Luck = {
	AlphaZone = 1.0,           -- +100%
	IndexPerEntry = 0.02,      -- +2% per Collection Index entry
	StreakPer100 = 0.02,       -- +2% per 100 unlucky rolls without Epic+ (free, unsellable)
	StreakCap = 0.50,          -- stacks up to +50%
	StreakResetTier = 5,       -- Tier 5 (Epic) or better
	Weather = { Sunny = 0, Blizzard = 0.25, Volcanic = 0.25, Eclipse = 0.5, Starfall = 1.0, BloodEclipse = 0.75, Aurora = 0.5 },
	MutationLuckExponent = 0.5,-- mutations scale with sqrt(luck)
}

Config.Inventory = {
	StartSlots = 8,
	SlotCosts = { 250, 750, 2500, 8000, 25000, 80000, 250000, 800000 },
}
function Config.SellValue(rarity: number): number
	return math.max(1, math.floor(rarity ^ 0.6))
end

Config.Materials = {
	FrostCore   = { Display = "Frost Core",   Icon = "❄️", Color = C(140, 220, 255) },
	MagmaHeart  = { Display = "Magma Heart",  Icon = "🔥", Color = C(255, 120, 50) },
	EclipseDust = { Display = "Eclipse Dust", Icon = "🌑", Color = C(190, 120, 255) },
}
Config.MaterialOrder = { "FrostCore", "MagmaHeart", "EclipseDust" }

Config.Weather = {
	MinDuration = 480, MaxDuration = 600, -- 8-10 minutes
	EclipseChance = 0.15,
	PickupInterval = 12, MaxPickups = 14,
	Order = { "Sunny", "Blizzard", "Volcanic", "Starfall", "BloodEclipse", "Aurora" },
	Types = {
		Sunny        = { Display = "Starlit Twilight",  Icon = "🌙", Boost = {},                         Material = nil },
		Blizzard     = { Display = "Blizzard",          Icon = "❄️", Boost = { FrostbiteWolf = 3 },      Material = "FrostCore" },
		Volcanic     = { Display = "Volcanic Eruption", Icon = "🌋", Boost = { MagmaGrizzly = 3 },       Material = "MagmaHeart" },
		Eclipse      = { Display = "Solar Eclipse",     Icon = "🌑", Boost = { SolarEclipseDragon = 5 }, Material = "EclipseDust" },
		Starfall     = { Display = "Cosmic Starfall",   Icon = "🌠", Boost = { VoidStag = 4, CelestialUnicorn = 4 }, Material = "EclipseDust" },
		BloodEclipse = { Display = "Blood Eclipse",     Icon = "🩸", Boost = { LavaSalamander = 4, Phoenix = 4 },    Material = "MagmaHeart" },
		Aurora       = { Display = "Aurora Borealis",   Icon = "🌈", Boost = { FrostDrake = 4, GiantPanda = 3 },     Material = "FrostCore" },
	},
}

-- Custom-rendered VFX Textures uploaded to Roblox Open Cloud + Real 3D AssetLibrary MeshIds
Config.VFXTextures = {
	SacredSigil = "rbxthumb://type=Asset&id=84970895257055&w=420&h=420", -- 512x512 Sacred Geometry Outer Magic Circle
	Starburst   = "rbxthumb://type=Asset&id=107753862044886&w=420&h=420", -- 512x512 Sol's RNG 8-Pointed Sharp Starburst
	ArcaneRune  = "rbxthumb://type=Asset&id=131937264384749&w=420&h=420", -- 512x512 Inner Arcane Hexagram & Rune Ring
	Shockwave   = "rbxthumb://type=Asset&id=106947964792162&w=420&h=420", -- 512x512 Radial Impact Shockwave Ring
}

-- Sol's RNG x Anime Dice: 3D Wearable Relics & Gauntlets (orbit around player character with real 3D meshes, glowing beams & trails)
Config.Relics = {
	Order = { "SolarGauntlet", "FrostTalisman", "ChronoCrown", "SingularityCore" },
	Types = {
		SolarGauntlet   = { Display = "Solar Strike Gauntlet", Slot = "RightArm", Icon = "🥊", Luck = 1.5, Speed = 0.20, Coins = 50000,    Materials = { MagmaHeart = 5 }, Color = C(255, 140, 40), MeshTemplate = "Quartz", Desc = "+150% Luck & +20% Roll Speed (3D Flaming Solar Crystal)" },
		FrostTalisman   = { Display = "Subzero Talisman",      Slot = "LeftArm",  Icon = "💠", Luck = 3.0, Speed = 0.25, Coins = 250000,   Materials = { FrostCore = 8 }, Color = C(80, 225, 255), MeshTemplate = "CrystalBlue", Desc = "+300% Luck & +25% Roll Speed (3D Cryo Crystal Cluster)" },
		ChronoCrown     = { Display = "Chrono-Shift Halo",     Slot = "Halo",     Icon = "⏳", Luck = 8.0, Speed = 0.35, Coins = 2000000,  Materials = { FrostCore = 12, MagmaHeart = 12 }, Color = C(70, 255, 190), MeshTemplate = "Lantern", Desc = "+800% Luck & +35% Roll Speed (3D Temporal Sanctum Halo)" },
		SingularityCore = { Display = "Ouroboros Void Core",   Slot = "Back",     Icon = "🕳️", Luck = 25.0, Speed = 0.50, Coins = 15000000, Materials = { EclipseDust = 20, FrostCore = 15, MagmaHeart = 15 }, Color = C(210, 90, 255), Rainbow = true, MeshTemplate = "Totem", Desc = "+2,500% Luck & +50% Roll Speed (3D Singularity Relic)" },
	},
}

Config.Totems = {
	LuckTotem = { Display = "Luck Totem", Luck = 0.25, Speed = 0, Icon = "🍀",
		Cost = { Coins = 300, Animals = { RedFox = 2 }, Materials = { FrostCore = 4 } } },
	SpeedTotem = { Display = "Swift Totem", Luck = 0, Speed = 0.25, Icon = "💨",
		Cost = { Coins = 300, Animals = { MeadowRabbit = 4 }, Materials = { MagmaHeart = 4 } } },
	EclipseTotem = { Display = "Eclipse Totem", Luck = 1.0, Speed = 0.1, Icon = "🌘",
		Cost = { Coins = 5000, Animals = { VoltCheetah = 1 }, Materials = { EclipseDust = 8, FrostCore = 4, MagmaHeart = 4 } } },
}
Config.TotemOrder = { "LuckTotem", "SpeedTotem", "EclipseTotem" }
Config.TotemSlots = { Base = 1, BonusRank = 6 }

Config.Potions = {
	Lucky  = { Display = "Lucky Potion",   Icon = "🧪", Luck = 1.0, Duration = 300, CoinCost = 750 },
	Elixir = { Display = "Eclipse Elixir", Icon = "🌟", Luck = 500, EssenceCost = 5000, RankRequired = 5 },
}

-- Forge upgrades a creature to a higher mutation (needs a duplicate of the same creature). Top 3 mutations are roll-only.
Config.Forge = {
	Order = { "Gilded", "Prismatic", "Abyssal", "Astral", "ChronoShifted" },
	Gilded        = { Chance = 0.50, Coins = 500,     Materials = {} },
	Prismatic     = { Chance = 0.25, Coins = 2500,    Materials = { FrostCore = 3, MagmaHeart = 3 } },
	Abyssal       = { Chance = 0.10, Coins = 10000,   Materials = { EclipseDust = 6 } },
	Astral        = { Chance = 0.04, Coins = 50000,   Materials = { FrostCore = 10, MagmaHeart = 10, EclipseDust = 10 } },
	ChronoShifted = { Chance = 0.01, Coins = 250000,  Materials = { FrostCore = 25, MagmaHeart = 25, EclipseDust = 25 } },
}

-- Admin access. Owners/devs by UserId (the place owner is always included). VIP Admin = gamepass "VIPAdmin".
Config.Admin = {
	DevUserIds = { 5101838508 },
	DevGroup = nil,            -- e.g. { Id = 1234567, MinRank = 250 }
	AllowStudioTesters = true, -- anyone in a Studio playtest is a dev (never true on live servers)
	VIP = {
		Fireworks = { Cooldown = 15 },
		Confetti  = { Cooldown = 60, ServerCooldown = 20 },
		Spotlight = { Cooldown = 30 },
		Shout     = { Cooldown = 120, ServerCooldown = 15, MaxLength = 80 },
	},
}

Config.StationRange = 26

Config.Abilities = {
	Dash       = { Display = "Quick Dash",      Cooldown = 3, Speed = 120 },
	Blink      = { Display = "Lightning Blink", Cooldown = 4, Distance = 28 },
	FrostPulse = { Display = "Frost Pulse",     Cooldown = 6, Radius = 16, Force = 95 },
	Slam       = { Display = "Ground Slam",     Cooldown = 6, Radius = 20, Force = 115 },
	Beam       = { Display = "Solar Beam",      Cooldown = 8, Range = 46, Width = 9, Force = 145 },
}

Config.Ranks = {
	{ Name = "Cub",          Req = nil },
	{ Name = "Tracker",      Req = { Stat = "Rolls", Value = 25 },        Reward = { Coins = 100 }, Text = "Roll 25 times" },
	{ Name = "Scout",        Req = { Stat = "Rolls", Value = 100 },       Reward = { Coins = 300 }, Text = "Roll 100 times", Unlock = "Quick Roll" },
	{ Name = "Ranger",       Req = { Stat = "AlphaTime", Value = 60 },    Reward = { Coins = 500 }, Text = "Hold the Alpha Zone for 60s" },
	{ Name = "Stalker",      Req = { Stat = "RarestPull", Value = 500 },  Reward = { Coins = 800 }, Text = "Roll a 1 in 500+ animal", Unlock = "Eclipse Elixir recipe" },
	{ Name = "Totem Keeper", Req = { Stat = "Crafts", Value = 1 },        Reward = { Coins = 1000 }, Text = "Craft a Totem", Unlock = "2nd Totem slot" },
	{ Name = "Hunter",       Req = { Stat = "Rolls", Value = 1000 },      Reward = { Coins = 2500 }, Text = "Roll 1,000 times" },
	{ Name = "Forgemaster",  Req = { Stat = "Forges", Value = 1 },        Reward = { Coins = 4000 }, Text = "Forge a mutation" },
	{ Name = "Collector",    Req = { Stat = "IndexCount", Value = 8 },    Reward = { Coins = 6000 }, Text = "Discover 8 Index entries" },
	{ Name = "Apex Hunter",  Req = { Stat = "RarestPull", Value = 10000 },Reward = { Coins = 15000 }, Text = "Roll a 1 in 10,000+ animal" },
}

Config.PlaytimeGifts = {
	{ Minutes = 3,  Reward = { Coins = 100 } },
	{ Minutes = 7,  Reward = { Potion = "Lucky", Amount = 1 } },
	{ Minutes = 15, Reward = { Materials = { FrostCore = 3, MagmaHeart = 3 } } },
	{ Minutes = 30, Reward = { Coins = 2500 } },
	{ Minutes = 60, Reward = { Potion = "Elixir", Amount = 1 } },
}

Config.LeaderboardRefresh = 60

-- Anime Dice: 8-tier 3D Dice Ladder (each die physically throws in 3D with custom color, material & trail)
Config.Dice = {
	Order = { "Wooden", "Amber", "Frost", "Magma", "Storm", "Astral", "Chrono", "Void" },
	Types = {
		Wooden = { Display = "Wooden Die", Rarity = "Common",    Icon = "🎲", Luck = 1,    Coins = 0,          Materials = {}, Color = C(196, 154, 108), Accent = C(240, 205, 160), Mat = Enum.Material.Wood },
		Amber  = { Display = "Amber Die",  Rarity = "Uncommon",  Icon = "🟠", Luck = 1.5,  Coins = 2500,       Materials = {}, Color = C(255, 174, 52),  Accent = C(255, 225, 120), Mat = Enum.Material.Glass },
		Frost  = { Display = "Frost Die",  Rarity = "Rare",      Icon = "❄️", Luck = 2.8,  Coins = 25000,      Materials = { FrostCore = 4 }, Color = C(92, 225, 255), Accent = C(210, 248, 255), Mat = Enum.Material.Ice },
		Magma  = { Display = "Magma Die",  Rarity = "Epic",      Icon = "🔥", Luck = 5.5,  Coins = 250000,     Materials = { MagmaHeart = 6 }, Color = C(255, 94, 54), Accent = C(255, 200, 90), Mat = Enum.Material.CrackedLava },
		Storm  = { Display = "Storm Die",  Rarity = "Legendary", Icon = "⚡", Luck = 12,   Coins = 2500000,    Materials = { FrostCore = 8, MagmaHeart = 8 }, Color = C(255, 224, 71), Accent = C(140, 230, 255), Mat = Enum.Material.Neon },
		Astral = { Display = "Astral Die", Rarity = "Mythical",  Icon = "🌌", Luck = 28,   Coins = 25000000,   Materials = { EclipseDust = 10 }, Color = C(169, 146, 255), Accent = C(230, 215, 255), Mat = Enum.Material.ForceField },
		Chrono = { Display = "Chrono Die", Rarity = "Cosmic",    Icon = "⏳", Luck = 65,   Coins = 250000000,  Materials = { FrostCore = 18, MagmaHeart = 18, EclipseDust = 18 }, Color = C(71, 255, 209), Accent = C(210, 255, 245), Mat = Enum.Material.Foil },
		Void   = { Display = "Void Die",   Rarity = "Godly",     Icon = "🕳️", Luck = 150,  Coins = 1500000000, Materials = { EclipseDust = 40, FrostCore = 25, MagmaHeart = 25 }, Color = C(255, 79, 216), Accent = C(40, 210, 255), Mat = Enum.Material.Neon, Rainbow = true },
	},
}

-- Slime RNG: Essence Rebirth (resets Coins only; keeps ALL Animals, Index, Dice, Totems, Skills & Passes)
Config.Rebirth = {
	BaseCoins   = 500000,     -- Rebirth 1 costs 500K Coins
	BaseEssence = 250,        -- Rebirth 1 costs 250 Essence
	CostGrowth  = 1.75,       -- Smooth 1.75x scaling (each tier is progressively harder, but not too grindy)
	LuckBase    = 1.30,       -- compounding x1.30 (+30%) Luck per Rebirth
	CoinBase    = 1.45,       -- compounding x1.45 (+45%) Coin Income per Rebirth
	World2RebirthRequired = 10, -- 🌌 Rebirth 10 unlocks the World 2 Cosmic Portal!
}
function Config.RebirthCost(level: number): (number, number)
	local coins = math.floor(Config.Rebirth.BaseCoins * (Config.Rebirth.CostGrowth ^ level) + 0.5)
	local essence = math.floor(Config.Rebirth.BaseEssence * (Config.Rebirth.CostGrowth ^ level) + 0.5)
	return coins, essence
end
function Config.RebirthLuckMult(level: number): number
	if level <= 0 then return 1 end
	return math.floor((Config.Rebirth.LuckBase ^ level) * 100 + 0.5) / 100
end
function Config.RebirthCoinMult(level: number): number
	if level <= 0 then return 1 end
	return math.floor((Config.Rebirth.CoinBase ^ level) * 100 + 0.5) / 100
end

-- Slime RNG: Branching Coin Skill Tree
Config.Skills = {
	Order = { "CoinYield", "RollSpeed", "SuperLuck", "OfflineCap", "BonusCycle" },
	Nodes = {
		CoinYield  = { Display = "Coin Yield",         Icon = "💰", Max = 10, BaseCost = 500,    CostMult = 3.2, Step = 0.35, Desc = "+35% Passive & Sell Coins per level" },
		RollSpeed  = { Display = "Hyper Roll Speed",   Icon = "⚡", Max = 5,  BaseCost = 2000,   CostMult = 4.5, Step = 0.10, Desc = "+10% Roll Speed & faster Dice throw per level" },
		SuperLuck  = { Display = "Super Luck Core",    Icon = "🍀", Max = 10, BaseCost = 1500,   CostMult = 3.5, Step = 0.15, Desc = "+15% Base Additive Luck per level" },
		OfflineCap = { Display = "Offline Sanctuary",  Icon = "💤", Max = 5,  BaseCost = 5000,   CostMult = 4.0, Step = 0.15, Desc = "+15% Offline Pack Coin rate (up to 12h away)" },
		BonusCycle = { Display = "Bonus Roll Mastery", Icon = "🔥", Max = 4,  BaseCost = 25000,  CostMult = 6.0, Step = 1,    Desc = "Reduces 2x Bonus Roll cycle by 1 roll per level (10 -> 6)" },
	},
}
function Config.SkillCost(key: string, currentLevel: number): number
	local n = Config.Skills.Nodes[key]
	if not n then return 0 end
	return math.floor(n.BaseCost * (n.CostMult ^ currentLevel) + 0.5)
end

-- Slime RNG x Anime Dice: Active Companion Pack (top 3 companions follow player in 3D & generate passive Coins/sec)
Config.Pack = {
	MaxCompanions = 3,
	TickInterval = 2,         -- awards passive Coins every 2 seconds
	OfflineMaxHours = 12,
	BaseOfflineEfficiency = 0.25,
}
function Config.CompanionCPS(rarity: number): number
	return math.max(1, math.floor((rarity ^ 0.42) * 1.5))
end

-- Promo Codes & Lucky Spins (Lucky Spin = supercharged +2,500% Luck roll token)
Config.LuckySpinBoost = 25    -- +2,500% additive Luck on next roll
Config.Codes = {
	RELEASE   = { Spins = 2, Coins = 2500,   Materials = { FrostCore = 3, MagmaHeart = 3 }, Desc = "2 Lucky Spins, 2,500 Coins & 6 Biome Cores" },
	ANIMALRNG = { Spins = 3, Essence = 1500, Potion = "Lucky", Amount = 2,                  Desc = "3 Lucky Spins, 1,500 Essence & 2 Lucky Potions" },
	OUROBOROS = { Spins = 5, Potion = "Elixir", Amount = 1,                                 Desc = "5 Lucky Spins & 1 Eclipse Elixir (+50,000% Luck)" },
	SLIMEDICE = { Spins = 3, Coins = 25000,  Materials = { EclipseDust = 5 },               Desc = "3 Lucky Spins, 25,000 Coins & 5 Eclipse Dust" },
	UPDATE1   = { Spins = 2, Essence = 2500, Coins = 10000,                                 Desc = "2 Lucky Spins, 2,500 Essence & 10,000 Coins" },
}

-- 100% Built-In Roblox Studio Engine Sounds (zero external rbxassetid upload/permission errors)
Config.Sounds = {
	Tick   = "rbxasset://sounds/clickfast.wav",
	Click  = "rbxasset://sounds/button.wav",
	Pop    = "rbxasset://sounds/snap.wav",
	Sweep  = "rbxasset://sounds/Launching rocket.wav",
	Reveal = "rbxasset://sounds/electronicpingshort.wav",
	Bass   = "rbxasset://sounds/bass.wav",
	Roar   = "rbxasset://sounds/collide.wav",
	Whoosh = "rbxasset://sounds/Rocket whoosh 01.wav",
	Fail   = "rbxasset://sounds/splat.wav",
	Rise   = "rbxasset://sounds/Launching rocket.wav",
	Swish  = "rbxasset://sounds/swordslash.wav",
	Chime  = "rbxasset://sounds/electronicpingshort.wav",
	Hello  = "rbxasset://sounds/unsheath.wav",
	Low    = "rbxasset://sounds/bass.wav",
}

-- Built-in Roblox sounds (ship with the client: zero upload/permission failures). Every id here was verified
-- with ContentProvider:PreloadAsync on a live server (AssetFetchStatus.Success). Layered + DSP'd by AnimeFX.
Config.AnimeSounds = {
	Slash    = "rbxasset://sounds/swordslash.wav",
	Lunge    = "rbxasset://sounds/swordlunge.wav",
	Unsheath = "rbxasset://sounds/unsheath.wav",
	Ping     = "rbxasset://sounds/electronicpingshort.wav",
	Boom     = "rbxasset://sounds/collide.wav",
	Shot     = "rbxasset://sounds/Rocket shot.wav",
	Whoosh   = "rbxasset://sounds/Rocket whoosh 01.wav",
	Launch   = "rbxasset://sounds/Launching rocket.wav",
	Glass    = "rbxasset://sounds/glassbreak.wav",
	Hit      = "rbxasset://sounds/hit.wav",
	Snap     = "rbxasset://sounds/snap.wav",
	Click    = "rbxasset://sounds/clickfast.wav",
	Land     = "rbxasset://sounds/action_jump_land.mp3",
	Wind     = "rbxasset://sounds/action_falling.mp3",
	Splash   = "rbxasset://sounds/impact_water.mp3",
	Bass     = "rbxasset://sounds/bass.wav",
	Thunder  = "rbxasset://sounds/Rocket shot.wav",
	Rumble   = "rbxasset://sounds/collide.wav",
	Stinger  = "rbxasset://sounds/unsheath.wav",
}

-- Built-in particle textures (verified on a live server)
Config.BuiltinTextures = {
	Spark     = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke     = "rbxasset://textures/particles/smoke_main.dds",
	Fire      = "rbxasset://textures/particles/fire_main.dds",
	FireSpark = "rbxasset://textures/particles/fire_sparks_main.dds",
	Core      = "rbxasset://textures/particles/explosion01_core_main.dds",
	Shock     = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Implode   = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	Dust      = "rbxasset://textures/particles/explosion01_smoke_main.dds",
	Glow      = "rbxasset://textures/particles/forcefield_glow_main.dds",
	Vortex    = "rbxasset://textures/particles/forcefield_vortex_main.dds",
}

------------------------------------------------------------------ V6 "Hype" systems (active gameplay layer)
-- ANIME OVERDRIVE: every roll charges the gauge; at 100% the player unleashes 20s of x2 luck & +50% roll speed.
Config.Overdrive = {
	Max = 100,
	PerRoll = 4,          -- every roll
	PerEpic = 10,         -- Tier 5 (Epic)+ pull
	PerBonus = 6,         -- Bonus Roll
	PerCrit = 8,          -- Critical Roll
	Duration = 20,        -- seconds
	LuckMult = 2,         -- x2 total luck (free, outside the paid cap)
	SpeedMult = 1.5,      -- +50% roll speed
	CritBonus = 0.06,     -- +6% crit chance while active
	BreakthroughBonus = 0.03,
}

-- CRITICAL ROLL ("Black Flash"): any throw can crit for x2.5 luck on that roll; 1 in 8 crits is a SUPER crit (x5).
Config.Crit = { Base = 0.04, PerDie = 0.006, Mult = 2.5, SuperChance = 0.125, SuperMult = 5 }

-- BREAKTHROUGH: a landed pull can shatter its ceiling and climb +1 tier (never into the Tier 27/28 finale).
Config.Breakthrough = { Chance = 0.02, MaxFromTier = 26, EssenceMult = 0.5 }

-- BIOME RESONANCE: pulls of the current weather's featured creatures pay +50% bonus coins.
Config.Resonance = { CoinBonus = 0.5 }

-- HUNTER BOUNTIES: 3 live short-term goals; finishing one auto-pays and rolls a fresh bounty in that slot.
Config.Bounties = {
	Slots = 3,
	ScaleMult = { 1, 2, 3.5 }, -- reward multiplier by target size
	Pool = {
		{ Id = "Roll",     Stat = "Rolls",         Targets = { 30, 75, 150 }, Text = "Roll %d times",                     Reward = { Coins = 600, Essence = 40 } },
		{ Id = "Epic",     Stat = "Epic",          Targets = { 3, 8, 15 },    Text = "Pull %d Epic+ (T5+) creatures",     Reward = { Essence = 120, LuckySpins = 1 } },
		{ Id = "Mythic",   Stat = "Mythic",        Targets = { 1, 2, 4 },     Text = "Pull %d Mythical+ (T7+) creatures", Reward = { LuckySpins = 2, Essence = 200 } },
		{ Id = "Crit",     Stat = "Crits",         Targets = { 3, 7, 14 },    Text = "Land %d Critical Rolls",            Reward = { Potion = "Lucky", Amount = 1, Coins = 400 } },
		{ Id = "Break",    Stat = "Breakthroughs", Targets = { 1, 2, 4 },     Text = "Trigger %d Breakthroughs",          Reward = { LuckySpins = 2, Materials = { EclipseDust = 2 } } },
		{ Id = "Overdrive",Stat = "Overdrives",    Targets = { 1, 2, 3 },     Text = "Unleash Overdrive %d time(s)",      Reward = { Essence = 250, Materials = { FrostCore = 2, MagmaHeart = 2 } } },
		{ Id = "Index",    Stat = "NewIndex",      Targets = { 2, 5, 10 },    Text = "Discover %d new Index entries",     Reward = { Coins = 1500, LuckySpins = 1 } },
		{ Id = "Resonate", Stat = "Resonance",     Targets = { 2, 5, 10 },    Text = "Pull %d Biome-Resonant creatures",  Reward = { Materials = { FrostCore = 2, MagmaHeart = 2, EclipseDust = 1 }, Coins = 800 } },
	},
}

Config.UI = {
	Slate = C(14, 17, 25), Glass = 0.2, Text = C(244, 246, 251), Muted = C(154, 163, 184),
	Accent = C(34, 227, 255), Gold = C(255, 200, 61),
}

return Config
