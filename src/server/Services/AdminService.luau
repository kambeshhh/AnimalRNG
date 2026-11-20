-- AdminService: two server-gated panels over one RemoteFunction ("Admin").
--   Dev/Owner panel: Config.Admin.DevUserIds, the place owner, optional group rank (and any Studio tester).
--   VIP Admin panel: gamepass "VIPAdmin" (server-verified) → cosmetic, rate-limited social effects only.
-- Every request is re-authorised and every argument validated on the server. Nothing trusts the client.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Config = require(RS.Modules.Config)
local AnimalData = require(RS.Modules.AnimalData)
local Net = require(RS.Modules.Net)

local Admin = {}
local S
local cooldowns = {}  -- [player] = { [action] = os.clock() }
local serverCd = {}   -- [action] = os.clock()

function Admin.Init(services) S = services end

function Admin.IsDev(player)
	local A = Config.Admin
	if table.find(A.DevUserIds, player.UserId) then return true end
	if game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId then return true end
	if A.DevGroup then
		local ok, rank = pcall(player.GetRankInGroup, player, A.DevGroup.Id)
		if ok and rank >= A.DevGroup.MinRank then return true end
	end
	return A.AllowStudioTesters and RunService:IsStudio() or false
end

function Admin.IsVIP(player)
	return Admin.IsDev(player) or S.MonetizationService.HasPass(player, "VIPAdmin")
end

local function refresh(player)
	player:SetAttribute("IsDevAdmin", Admin.IsDev(player))
	player:SetAttribute("IsVIPAdmin", Admin.IsVIP(player))
end

local function num(x, lo, hi) -- finite number clamp, rejects NaN / inf / non-numbers
	if typeof(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then return nil end
	return math.clamp(x, lo, hi)
end
local function target(name, fallback)
	if typeof(name) ~= "string" or name == "" then return fallback end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == name:lower() or p.DisplayName:lower() == name:lower() then return p end
	end
end
local function log(player, msg) print(string.format("[Admin] %s (%d): %s", player.Name, player.UserId, msg)) end

------------------------------------------------------------------ DEV actions
local DEV = {}
DEV.Inspect = function(player, args)
	local p = target(args.Target, player); if not p then return false, "Player not found" end
	local d = S.DataService.Get(p); if not d then return false, "No data loaded" end
	local best
	for _, it in ipairs(d.Inventory) do if not best or AnimalData.ItemRarity(it) > AnimalData.ItemRarity(best) then best = it end end
	local luck = S.RollService.GetLuck(p)
	return true, string.format("%s  •  Coins %s  •  Rank %d  •  Rolls %s  •  Luck x%.2f\nInventory %d/%d  •  Vault %d  •  Index %d\nBest: %s (%s)  •  Rarest ever: %s",
		p.DisplayName, AnimalData.Comma(d.Coins), d.Rank, AnimalData.Comma(d.Stats.Rolls), luck, #d.Inventory, d.Slots, #d.Vault, S.DataService.IndexCount(d),
		best and AnimalData.ItemName(best) or "-", best and AnimalData.FormatRarity(AnimalData.ItemRarity(best)) or "-", d.Stats.RarestName ~= "" and d.Stats.RarestName or "-")
end
local function validateCombo(args)
	local animal = args.Animal
	if typeof(animal) ~= "string" or not AnimalData.Animals[animal] then return nil, "Unknown creature" end
	local tier = num(args.Tier, 1, AnimalData.TierCount); if not tier then return nil, "Bad tier" end
	tier = math.floor(tier)
	local mutation = typeof(args.Mutation) == "string" and AnimalData.Mutations[args.Mutation] and args.Mutation or "Normal"
	-- strict Unattainable exclusivity, even for admins
	if animal == AnimalData.UnattainableCreature then tier = AnimalData.TierCount
	elseif tier >= AnimalData.TierCount then return nil, "Tier 28 is Ouroboros-only" end
	return { Animal = animal, Tier = tier, Mutation = mutation }
end
DEV.Grant = function(player, args)
	local p = target(args.Target, player); if not p then return false, "Player not found" end
	local combo, err = validateCombo(args); if not combo then return false, err end
	local d = S.DataService.Get(p)
	local item = S.DataService.NewItem(d, combo)
	if #d.Inventory < d.Slots then table.insert(d.Inventory, item) else table.insert(d.Vault, item) end
	S.ProgressionService.AddIndex(d, item)
	local r = AnimalData.ItemRarity(item)
	if r > d.Stats.RarestPull then d.Stats.RarestPull = r; d.Stats.RarestName = AnimalData.ItemName(item) end
	S.DataService.Sync(p)
	S.DataService.Toast(p, "🎁 Admin granted you " .. AnimalData.ItemName(item) .. " (" .. AnimalData.TierFor(item).Name .. ")", Config.UI.Gold)
	log(player, "Grant " .. AnimalData.ItemName(item) .. " T" .. item.Tier .. " → " .. p.Name)
	return true, "Granted " .. AnimalData.ItemName(item) .. " • " .. AnimalData.TierFor(item).Name .. " • " .. AnimalData.FormatRarity(r) .. " → " .. p.DisplayName
end
DEV.TestRoll = function(player, args)
	local p = target(args.Target, player); if not p then return false, "Player not found" end
	local force
	if args.Tier ~= nil then
		local combo, err = validateCombo({ Animal = args.Animal or (num(args.Tier, 1, 28) == 28 and AnimalData.UnattainableCreature or AnimalData.Common), Tier = args.Tier, Mutation = args.Mutation })
		if not combo then return false, err end
		force = { Tier = combo.Tier, Mutation = combo.Mutation, Animal = args.Animal and combo.Animal or nil }
	end
	local count = args.Count == Config.Roll.MultiCount and Config.Roll.MultiCount or 1
	local res = S.RollService.Execute(p, false, count, force)
	log(player, "TestRoll x" .. count .. " for " .. p.Name .. (force and (" forced T" .. force.Tier .. " " .. force.Mutation) or ""))
	return true, res and ("Rolled: " .. res[1].Name .. " (" .. res[1].Tier .. ")") or "Rolled"
end
DEV.ServerLuck = function(player, args)
	local mult = num(args.Mult, 1, 100); local minutes = num(args.Minutes, 1, 180)
	if not mult or not minutes then return false, "Bad values" end
	RS:SetAttribute("EventLuckMult", mult)
	RS:SetAttribute("EventLuckUntil", workspace:GetServerTimeNow() + minutes * 60)
	for _, p in ipairs(Players:GetPlayers()) do
		S.DataService.Notify(p, "Banner", { Text = string.format("🌟 SERVER EVENT: LUCK x%s for %d min!", AnimalData.Comma(mult), minutes), Color = Color3.fromRGB(255, 220, 90) })
	end
	log(player, "ServerLuck x" .. mult .. " " .. minutes .. "m")
	return true, string.format("Server luck x%s for %d min", AnimalData.Comma(mult), minutes)
end
DEV.ClearLuck = function(player)
	RS:SetAttribute("EventLuckUntil", 0); RS:SetAttribute("ServerLuckUntil", 0)
	log(player, "ClearLuck")
	return true, "Server luck events cleared"
end
DEV.Weather = function(player, args)
	if typeof(args.Name) ~= "string" or not Config.Weather.Types[args.Name] then return false, "Unknown weather" end
	S.WeatherService.Force(args.Name)
	log(player, "Weather " .. args.Name)
	return true, "Weather → " .. args.Name
end
DEV.Coins = function(player, args)
	local p = target(args.Target, player); if not p then return false, "Player not found" end
	local amt = num(args.Amount, -1e15, 1e15); if not amt then return false, "Bad amount" end
	local d = S.DataService.Get(p); d.Coins = math.max(0, d.Coins + math.floor(amt)); S.DataService.Sync(p)
	log(player, "Coins " .. amt .. " → " .. p.Name)
	return true, p.DisplayName .. " now has " .. AnimalData.Comma(d.Coins) .. " Coins"
end

------------------------------------------------------------------ VIP actions (cosmetic only)
local function social(kind, player, extra)
	local root = player.Character and player.Character.PrimaryPart
	local payload = { Kind = kind, UserId = player.UserId, Player = player.DisplayName, Position = root and root.Position or Vector3.zero }
	for k, v in pairs(extra or {}) do payload[k] = v end
	Net.Get("SocialFX"):FireAllClients(payload)
end
local VIP = {}
VIP.Fireworks = function(player) social("Fireworks", player); return true, "🎆 Fireworks!" end
VIP.Confetti = function(player) social("Confetti", player); return true, "🎊 Confetti for everyone!" end
VIP.Spotlight = function(player) social("Spotlight", player); return true, "🔦 Spotlight on you!" end
VIP.Shout = function(player, args)
	local text = typeof(args.Text) == "string" and args.Text:sub(1, Config.Admin.VIP.Shout.MaxLength) or ""
	text = text:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if #text < 2 then return false, "Type a message first" end
	local ok, res = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then return false, "Message couldn't be filtered — try again" end
	social("Shout", player, { Text = res })
	return true, "📣 Shout sent"
end

local lastInvoke = {} -- [player] = os.clock() of last Admin RemoteFunction call
local ADMIN_RATE_LIMIT = 0.1

------------------------------------------------------------------ dispatch
local function handle(player, kind, action, args)
	local now = os.clock()
	if lastInvoke[player] and (now - lastInvoke[player]) < ADMIN_RATE_LIMIT then
		return { Ok = false, Msg = "Too fast — slow down" }
	end
	lastInvoke[player] = now
	args = typeof(args) == "table" and args or {}
	if typeof(action) ~= "string" then return { Ok = false, Msg = "Bad request" } end
	if kind == "Dev" then
		if not Admin.IsDev(player) then log(player, "DENIED dev " .. action); return { Ok = false, Msg = "Not authorised" } end
		local fn = DEV[action]; if not fn then return { Ok = false, Msg = "Unknown action" } end
		local ok, okv, msg = pcall(fn, player, args)
		if not ok then warn("[Admin] " .. tostring(okv)); return { Ok = false, Msg = "Server error" } end
		return { Ok = okv, Msg = msg }
	elseif kind == "VIP" then
		if not Admin.IsVIP(player) then return { Ok = false, Msg = "VIP Admin pass required" } end
		local fn, cfg = VIP[action], Config.Admin.VIP[action]
		if not fn or not cfg then return { Ok = false, Msg = "Unknown action" } end
		cooldowns[player] = cooldowns[player] or {}
		local left = (cooldowns[player][action] or -1e9) + cfg.Cooldown - now
		if left > 0 then return { Ok = false, Msg = string.format("Cooldown: %ds", math.ceil(left)), Cooldown = left } end
		if cfg.ServerCooldown and (serverCd[action] or -1e9) + cfg.ServerCooldown > now then return { Ok = false, Msg = "Someone just used that — try in a few seconds" } end
		local ok, okv, msg = pcall(fn, player, args)
		if not ok then warn("[Admin] " .. tostring(okv)); return { Ok = false, Msg = "Server error" } end
		if okv then cooldowns[player][action] = now; serverCd[action] = now end
		return { Ok = okv, Msg = msg, Cooldown = okv and cfg.Cooldown or nil }
	elseif kind == "Meta" and action == "Catalog" then
		return { Ok = true, Animals = AnimalData.Order, Mutations = AnimalData.MutationOrder, Tiers = AnimalData.TierCount, Weathers = (function()
			local w = {}; for k in pairs(Config.Weather.Types) do table.insert(w, k) end; table.sort(w); return w end)() }
	end
	return { Ok = false, Msg = "Bad request" }
end

function Admin.Start()
	Net.GetFunction("Admin").OnServerInvoke = handle
	Players.PlayerAdded:Connect(function(p) task.defer(refresh, p) end)
	for _, p in ipairs(Players:GetPlayers()) do task.defer(refresh, p) end
	Players.PlayerRemoving:Connect(function(p) cooldowns[p] = nil; lastInvoke[p] = nil end)
	task.spawn(function() while true do task.wait(10); for _, p in ipairs(Players:GetPlayers()) do refresh(p) end end end)
end

return Admin
