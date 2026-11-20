-- MonetizationService: gamepasses + developer products (idempotent ProcessReceipt), paid luck multipliers.
-- Placeholder ids (0) can be test-granted from the Shop ONLY inside Studio; live servers never allow that.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local Config = require(RS.Modules.Config)
local M = Config.Monetization

local Mon = {}
local S
local owned = {} -- [player] = { passKey = true }

function Mon.Init(services) S = services end
local function now() return os.time() end

function Mon.HasPass(player, key)
	if owned[player] and owned[player][key] then return true end
	local data = S.DataService.Get(player)
	return RunService:IsStudio() and data and data.StudioPasses and data.StudioPasses[key] == true or false
end

function Mon.OwnedPasses(player)
	local out = {}
	for _, key in ipairs(M.PassOrder) do out[key] = Mon.HasPass(player, key) end
	return out
end

function Mon.LuckMultipliers(player)
	local data = S.DataService.Get(player)
	local mult = {}
	if Mon.HasPass(player, "LuckPass") then mult.LuckPass = M.Passes.LuckPass.LuckMult end
	if data and (data.LuckBoostUntil or 0) > now() then mult.LuckBoost = M.Products.LuckBoost15.LuckMult end
	if (RS:GetAttribute("ServerLuckUntil") or 0) > workspace:GetServerTimeNow() then mult.ServerLuck = M.Products.ServerLuck.LuckMult end
	return mult
end

function Mon.SpeedMult(player)
	return Mon.HasPass(player, "SwiftRolls") and M.Passes.SwiftRolls.SpeedMult or 1
end

local function grantProduct(player, key)
	local prod = M.Products[key]; local data = S.DataService.Get(player)
	if not prod or not data then return false end
	if prod.Server then
		local untilT = math.max(workspace:GetServerTimeNow(), RS:GetAttribute("ServerLuckUntil") or 0) + prod.Minutes * 60
		RS:SetAttribute("ServerLuckUntil", untilT)
		RS:SetAttribute("ServerLuckBy", player.DisplayName)
		for _, p in ipairs(Players:GetPlayers()) do
			S.DataService.Notify(p, "Banner", { Text = "🌍 " .. player.DisplayName .. " activated SERVER LUCK x2 for " .. prod.Minutes .. " min!", Color = Color3.fromRGB(120, 255, 200) })
		end
	else
		data.LuckBoostUntil = math.max(now(), data.LuckBoostUntil or 0) + prod.Minutes * 60
		S.DataService.Notify(player, "Banner", { Text = prod.Icon .. " LUCK x2 ACTIVE for " .. prod.Minutes .. " min!", Color = Color3.fromRGB(255, 220, 90) })
	end
	S.DataService.Sync(player)
	return true
end

local function grantPass(player, key)
	owned[player] = owned[player] or {}
	owned[player][key] = true
	S.DataService.Notify(player, "Banner", { Text = M.Passes[key].Icon .. " " .. M.Passes[key].Display:upper() .. " UNLOCKED!", Color = Color3.fromRGB(255, 220, 90) })
	if key == "VIPAdmin" then player:SetAttribute("IsVIPAdmin", true) end
	S.DataService.Sync(player)
end

function Mon.Start()
	local function loadPasses(player)
		owned[player] = {}
		for key, pass in pairs(M.Passes) do
			if pass.Id > 0 then
				local ok, has = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id) end)
				if ok and has then owned[player][key] = true end
			end
		end
	end
	Players.PlayerAdded:Connect(loadPasses)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(loadPasses, p) end
	Players.PlayerRemoving:Connect(function(p) owned[p] = nil end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then return end
		for key, pass in pairs(M.Passes) do if pass.Id == passId and pass.Id > 0 then grantPass(player, key) end end
	end)
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local data = player and S.DataService.Get(player)
		if not data then return Enum.ProductPurchaseDecision.NotProcessedYet end
		if data.Purchases[info.PurchaseId] then return Enum.ProductPurchaseDecision.PurchaseGranted end
		for key, prod in pairs(M.Products) do
			if prod.Id > 0 and prod.Id == info.ProductId then
				local ok, granted = pcall(grantProduct, player, key)
				if not ok or not granted then return Enum.ProductPurchaseDecision.NotProcessedYet end
				data.Purchases[info.PurchaseId] = true
				task.spawn(S.DataService.Save, player)
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	S.Actions.Buy = function(player, kind, key)
		if typeof(key) ~= "string" then return end
		local item = (kind == "Pass" and M.Passes[key]) or (kind == "Product" and M.Products[key])
		if not item then return end
		if item.Id > 0 then
			if kind == "Pass" then MarketplaceService:PromptGamePassPurchase(player, item.Id) else MarketplaceService:PromptProductPurchase(player, item.Id) end
		elseif RunService:IsStudio() then
			if kind == "Pass" then
				local data = S.DataService.Get(player); data.StudioPasses[key] = true
				grantPass(player, key)
			else grantProduct(player, key) end
			S.DataService.Toast(player, "[Studio test] granted " .. item.Display .. " (placeholder id)", Color3.fromRGB(170, 210, 255))
		else
			S.DataService.Toast(player, item.Display .. " is coming soon!", Color3.fromRGB(255, 200, 120))
		end
	end
end

return Mon
