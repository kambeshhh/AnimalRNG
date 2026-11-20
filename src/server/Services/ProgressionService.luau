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
	S.Actions.ClaimGift = function(player, i)
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
end

return Prog
