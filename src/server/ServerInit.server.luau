-- ServerInit: boots every service (Init -> Start), routes UI actions, spawns players as animals
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Net = require(RS.Modules.Net)
Players.CharacterAutoLoads = false
Net.Folder() -- create all remotes before anything else

local ORDER = { "DataService", "WeatherService", "MorphService", "StationService", "AlphaZoneService", "ProgressionService",
	"InventoryService", "RollService", "AbilityService", "AltarService", "TotemService", "ForgeService", "LeaderboardService", "MonetizationService", "AdminService" }
local S = { Actions = {} }
for _, name in ipairs(ORDER) do S[name] = require(script.Parent.Services:WaitForChild(name)) end
for _, name in ipairs(ORDER) do if S[name].Init then S[name].Init(S) end end
for _, name in ipairs(ORDER) do if S[name].Start then task.spawn(S[name].Start) end end

local lastAction = {} -- [player] = { [action] = os.clock() }
local ACTION_COOLDOWN = { Equip = 0.25, Buy = 0.25, Forge = 0.2, Sacrifice = 0.2, CraftTotem = 0.2 }
local DEFAULT_ACTION_CD = 0.08

Net.Get("Action").OnServerEvent:Connect(function(player, action, ...)
	if typeof(action) ~= "string" then return end
	local handler = S.Actions[action]
	if not handler or not S.DataService.Get(player) then return end
	local now = os.clock()
	local pcd = lastAction[player]
	if not pcd then pcd = {}; lastAction[player] = pcd end
	local cd = ACTION_COOLDOWN[action] or DEFAULT_ACTION_CD
	if pcd[action] and (now - pcd[action]) < cd then return end -- silently drop remote spam
	pcd[action] = now
	local ok, err = pcall(handler, player, ...)
	if not ok then warn("[Action " .. action .. "] " .. tostring(err)) end
end)

local function onPlayer(player)
	local loaded = S.DataService.Load(player)
	if not loaded or not player.Parent then return end
	S.ProgressionService.CheckRanks(player)
	S.MorphService.Spawn(player, false)
	S.DataService.Sync(player)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p)
	lastAction[p] = nil
	S.DataService.Release(p)
end)

-- Studio-only test hook (never exists on live servers)
if game:GetService("RunService"):IsStudio() then
	local hook = Instance.new("BindableFunction"); hook.Name = "DevTestHook"
	hook.OnInvoke = function(action, a, b, c)
		local p = a and Players:FindFirstChild(a)
		if action == "Weather" then S.WeatherService.Force(a); return "ok"
		elseif action == "Give" then
			local data = S.DataService.Get(p)
			local item = S.DataService.NewItem(data, { Animal = b, Tier = c and c.Tier or 1, Mutation = c and c.Mutation or "Normal" })
			table.insert(data.Inventory, item); S.ProgressionService.AddIndex(data, item); S.DataService.Sync(p); return item.Id
		elseif action == "Coins" then local data = S.DataService.Get(p); data.Coins += b; S.DataService.Sync(p); return data.Coins
		elseif action == "Materials" then local data = S.DataService.Get(p); for k in pairs(data.Materials) do data.Materials[k] += b end; S.DataService.Sync(p); return "ok"
		elseif action == "Rank" then local data = S.DataService.Get(p); data.Rank = b; S.DataService.Sync(p); return "ok"
		elseif action == "PreviewTierQuiet" then return nil
		elseif action == "PreviewTier" then
			-- b = tier index 1..28 ; c = true to also fire the server announcement
			local AD = require(game:GetService("ReplicatedStorage").Modules.AnimalData)
			local Net = require(game:GetService("ReplicatedStorage").Modules.Net)
			local tier = AD.Tiers[math.clamp(b, 1, AD.TierCount)]
			local muts = { [13] = "Prismatic", [16] = "Abyssal", [20] = "Astral", [24] = "ChronoShifted", [27] = "Sovereign", [28] = "Singularity" }
			local mut = "Normal"; for k, v in pairs(muts) do if b >= k and AD.Mutations[v].Rank > AD.Mutations[mut].Rank then mut = v end end
			local item = { Id = "preview", Animal = b >= AD.TierCount and AD.UnattainableCreature or AD.PickCreature(Random.new(), {}), Tier = b, Mutation = mut }
			local rarity = AD.ItemRarity(item)
			local r = { Item = item, Name = "[Preview] " .. AD.ItemName(item), Rarity = rarity, Tier = tier.Name, TierIndex = b, Mutation = mut, Status = "Kept", Coins = 0, NewIndex = false, Luck = 1, Bonus = false, Preview = true }
			Net.Get("RollResult"):FireClient(p, { Results = { r }, BestIndex = 1, Multi = false })
			if c then
				local root = p.Character and p.Character.PrimaryPart
				Net.Get("Jackpot"):FireAllClients({ UserId = p.UserId, Player = p.DisplayName, Name = r.Name, Rarity = rarity, Position = root and root.Position or Vector3.zero, Animal = item.Animal, TierColor = tier.Color, TierIndex = b, Tier = tier.Name })
				S.WeatherService.Spectacle(tier.Color, b >= AD.TierCount and 12 or 7, b >= AD.TierCount)
			end
			return tier.Name .. " " .. AD.FormatRarity(rarity)
		elseif action == "Elixir" then local data = S.DataService.Get(p); data.ElixirArmed = true; return "armed"
		elseif action == "SetStat" then local data = S.DataService.Get(p); data.Stats[b] = c; S.DataService.Sync(p); return "ok"
		elseif action == "ClearPasses" then local data = S.DataService.Get(p); data.StudioPasses = {}; data.LuckBoostUntil = 0; game:GetService("ReplicatedStorage"):SetAttribute("ServerLuckUntil", 0); S.DataService.Sync(p); return "ok"
		elseif action == "Luck" then return game:GetService("ReplicatedStorage") and p:GetAttribute("LuckBreakdown")
		elseif action == "Data" then return game:GetService("HttpService"):JSONEncode(S.DataService.Get(p))
		elseif action == "Sandbox" then S.DataService.SetCanSave(p, not b); return b and "sandboxed (no saves)" or "saving on"
		elseif action == "Purge" then
			-- b = { item ids to delete }, c = { Coins = n to subtract, DropIndex = animal to forget }
			local AD = require(game:GetService("ReplicatedStorage").Modules.AnimalData)
			local data = S.DataService.Get(p)
			local kill, removed = {}, 0
			for _, id in ipairs(b or {}) do kill[id] = true end
			for _, list in ipairs({ data.Inventory, data.Vault }) do
				for i = #list, 1, -1 do if kill[list[i].Id] then table.remove(list, i); removed += 1 end end
			end
			if c and c.Coins then data.Coins = math.max(0, data.Coins - c.Coins) end
			if c and c.DropIndex then
				for k in pairs(data.Index) do if k == c.DropIndex or k:sub(1, #c.DropIndex + 1) == c.DropIndex .. "|" then data.Index[k] = nil end end
			end
			data.Stats.RarestPull, data.Stats.RarestName = 0, ""
			for _, list in ipairs({ data.Inventory, data.Vault }) do
				for _, it in ipairs(list) do
					local r = AD.ItemRarity(it)
					if r > data.Stats.RarestPull then data.Stats.RarestPull = r; data.Stats.RarestName = AD.ItemName(it) end
				end
			end
			if not S.DataService.FindItem(data, data.Equipped) then data.Equipped = data.Inventory[1] and data.Inventory[1].Id or ""; S.MorphService.Spawn(p, false) end
			S.DataService.Sync(p); return removed
		end
	end
	hook.Parent = game:GetService("ServerStorage")
end

-- Studio-only preview command: type "/tier 17" in chat (never created on live servers)
if game:GetService("RunService"):IsStudio() then
	task.spawn(function()
		local TCS = game:GetService("TextChatService")
		local cmd = Instance.new("TextChatCommand"); cmd.Name = "PreviewTierCommand"; cmd.PrimaryAlias = "/tier"; cmd.Parent = TCS
		cmd.Triggered:Connect(function(source, text)
			local p = game:GetService("Players"):GetPlayerByUserId(source.UserId)
			local n = tonumber(text:match("(%d+)"))
			local hook = game:GetService("ServerStorage"):FindFirstChild("DevTestHook")
			if p and n and hook then hook:Invoke("PreviewTier", p.Name, math.clamp(n, 1, 28), n >= 20) end
		end)
	end)
end
