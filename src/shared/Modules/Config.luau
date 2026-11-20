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
	},
	ProductOrder = { "LuckBoost15", "LuckBoost60", "ServerLuck" },
}

Config.Luck = {
	AlphaZone = 1.0,           -- +100%
	IndexPerEntry = 0.02,      -- +2% per Collection Index entry
	StreakPer100 = 0.02,       -- +2% per 100 unlucky rolls without Epic+ (free, unsellable)
	StreakCap = 0.50,          -- stacks up to +50%
	StreakResetTier = 5,       -- Tier 5 (Epic) or better
	Weather = { Sunny = 0, Blizzard = 0.25, Volcanic = 0.25, Eclipse = 0.5 },
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
	MinDuration = 600, MaxDuration = 720, -- 10-12 minutes
	EclipseChance = 0.15,
	PickupInterval = 15, MaxPickups = 12,
	Order = { "Sunny", "Blizzard", "Volcanic" },
	Types = {
		Sunny    = { Display = "Starlit Twilight", Icon = "🌙", Boost = {},                         Material = nil },
		Blizzard = { Display = "Blizzard",         Icon = "❄️", Boost = { FrostbiteWolf = 3 },      Material = "FrostCore" },
		Volcanic = { Display = "Volcanic Eruption",Icon = "🌋", Boost = { MagmaGrizzly = 3 },       Material = "MagmaHeart" },
		Eclipse  = { Display = "Solar Eclipse",    Icon = "🌑", Boost = { SolarEclipseDragon = 5 }, Material = "EclipseDust" },
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

-- Built-in engine sounds (always available, no uploads needed). Swap for your own asset ids here.
Config.Sounds = {
	Tick   = "rbxassetid://15675032796", -- Roblox_UI_Small_Click
	Click  = "rbxassetid://15675059323", -- Roblox_UI_Bright_Click
	Pop    = "rbxassetid://15675055424", -- Roblox_UI_Cute_Pop
	Sweep  = "rbxassetid://15675046931", -- Roblox_UI_Sweep (build-up)
	Reveal = "rbxassetid://15675043410", -- Roblox_UI_Tonal_Stinger
	Bass   = "rbxassetid://9038652624",  -- APM: Big Hair Rock - Hit 3
	Roar   = "rbxassetid://9038652624",
	Whoosh = "rbxassetid://15674975792", -- Roblox_UI_Whoosh_03
	Fail   = "rbxassetid://15675075163", -- Roblox_UI_Delete
	Rise   = "rbxassetid://15675028888", -- Roblox_UI_Whoosh_02 (tension riser)
	Swish  = "rbxassetid://15675024286", -- Roblox_UI_Whoosh_01
	Chime  = "rbxassetid://15675085146", -- Roblox_UI_Indicator
	Hello  = "rbxassetid://15675016548", -- Roblox_UI_Piano_Hello (bonus roll)
	Low    = "rbxassetid://15675062723", -- Roblox_UI_Whistle_Low (Unattainable build-up)
}

Config.UI = {
	Slate = C(14, 17, 25), Glass = 0.2, Text = C(244, 246, 251), Muted = C(154, 163, 184),
	Accent = C(34, 227, 255), Gold = C(255, 200, 61),
}

return Config
