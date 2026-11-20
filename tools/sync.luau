--!strict
-- Animal RNG Cloud Sync Tool for Roblox Studio
-- Paste into Studio Command Bar:
-- loadstring(game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/kambeshhh/AnimalRNG/main/tools/sync.luau?nocache=" .. tostring(os.time())))()

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")

local BASE_URL = "https://raw.githubusercontent.com/kambeshhh/AnimalRNG/main/"

local FILES = {
	-- Shared Modules
	{ path = "src/shared/Modules/Config.luau", parent = ReplicatedStorage, folder = "Modules", name = "Config", kind = "ModuleScript" },
	{ path = "src/shared/Modules/AnimalData.luau", parent = ReplicatedStorage, folder = "Modules", name = "AnimalData", kind = "ModuleScript" },
	{ path = "src/shared/Modules/Net.luau", parent = ReplicatedStorage, folder = "Modules", name = "Net", kind = "ModuleScript" },
	{ path = "src/shared/Modules/NumberFormat.luau", parent = ReplicatedStorage, folder = "Modules", name = "NumberFormat", kind = "ModuleScript" },
	{ path = "src/shared/Modules/UITheme.luau", parent = ReplicatedStorage, folder = "Modules", name = "UITheme", kind = "ModuleScript" },

	-- Server Services & ServerInit
	{ path = "src/server/ServerInit.server.luau", parent = ServerScriptService, folder = nil, name = "ServerInit", kind = "Script" },
	{ path = "src/server/Services/RollService.luau", parent = ServerScriptService, folder = "Services", name = "RollService", kind = "ModuleScript" },
	{ path = "src/server/Services/DataService.luau", parent = ServerScriptService, folder = "Services", name = "DataService", kind = "ModuleScript" },
	{ path = "src/server/Services/MorphService.luau", parent = ServerScriptService, folder = "Services", name = "MorphService", kind = "ModuleScript" },
	{ path = "src/server/Services/ProgressionService.luau", parent = ServerScriptService, folder = "Services", name = "ProgressionService", kind = "ModuleScript" },
	{ path = "src/server/Services/InventoryService.luau", parent = ServerScriptService, folder = "Services", name = "InventoryService", kind = "ModuleScript" },
	{ path = "src/server/Services/AdminService.luau", parent = ServerScriptService, folder = "Services", name = "AdminService", kind = "ModuleScript" },
	{ path = "src/server/Services/MonetizationService.luau", parent = ServerScriptService, folder = "Services", name = "MonetizationService", kind = "ModuleScript" },
	{ path = "src/server/Services/LeaderboardService.luau", parent = ServerScriptService, folder = "Services", name = "LeaderboardService", kind = "ModuleScript" },
	{ path = "src/server/Services/WeatherService.luau", parent = ServerScriptService, folder = "Services", name = "WeatherService", kind = "ModuleScript" },
	{ path = "src/server/Services/AltarService.luau", parent = ServerScriptService, folder = "Services", name = "AltarService", kind = "ModuleScript" },
	{ path = "src/server/Services/ForgeService.luau", parent = ServerScriptService, folder = "Services", name = "ForgeService", kind = "ModuleScript" },
	{ path = "src/server/Services/TotemService.luau", parent = ServerScriptService, folder = "Services", name = "TotemService", kind = "ModuleScript" },
	{ path = "src/server/Services/AlphaZoneService.luau", parent = ServerScriptService, folder = "Services", name = "AlphaZoneService", kind = "ModuleScript" },
	{ path = "src/server/Services/StationService.luau", parent = ServerScriptService, folder = "Services", name = "StationService", kind = "ModuleScript" },
	{ path = "src/server/Services/AbilityService.luau", parent = ServerScriptService, folder = "Services", name = "AbilityService", kind = "ModuleScript" },

	-- Client Scripts & Controllers
	{ path = "src/client/AltarAnimator.client.luau", parent = StarterPlayerScripts, folder = nil, name = "AltarAnimator", kind = "LocalScript" },
	{ path = "src/client/UIMotion.client.luau", parent = StarterPlayerScripts, folder = nil, name = "UIMotion", kind = "LocalScript" },
	{ path = "src/client/Controllers/ClientInit.client.luau", parent = StarterPlayerScripts, folder = "Controllers", name = "ClientInit", kind = "LocalScript" },
	{ path = "src/client/Controllers/UIController.luau", parent = StarterPlayerScripts, folder = "Controllers", name = "UIController", kind = "ModuleScript" },
	{ path = "src/client/Controllers/CutsceneController.luau", parent = StarterPlayerScripts, folder = "Controllers", name = "CutsceneController", kind = "ModuleScript" },
	{ path = "src/client/Controllers/AnimationController.luau", parent = StarterPlayerScripts, folder = "Controllers", name = "AnimationController", kind = "ModuleScript" },
	{ path = "src/client/Controllers/RollController.luau", parent = StarterPlayerScripts, folder = "Controllers", name = "RollController", kind = "ModuleScript" },
	{ path = "src/client/Controllers/AbilityController.luau", parent = StarterPlayerScripts, folder = "Controllers", name = "AbilityController", kind = "ModuleScript" },
	{ path = "src/client/Controllers/ClientState.luau", parent = StarterPlayerScripts, folder = "Controllers", name = "ClientState", kind = "ModuleScript" },
	{ path = "src/client/Controllers/UIUtil.luau", parent = StarterPlayerScripts, folder = "Controllers", name = "UIUtil", kind = "ModuleScript" },
}

print("==================================================")
print("🚀 [Animal RNG] Starting Direct Studio Sync...")
print("==================================================")

local successCount = 0
local failCount = 0

for _, item in ipairs(FILES) do
	local targetFolder = item.parent
	if item.folder then
		local foundFolder = targetFolder:FindFirstChild(item.folder)
		if not foundFolder then
			foundFolder = Instance.new("Folder")
			foundFolder.Name = item.folder
			foundFolder.Parent = targetFolder
		end
		targetFolder = foundFolder
	end

	local ok, code = pcall(function()
		local url = BASE_URL .. item.path .. "?v=" .. tostring(os.time())
		return HttpService:GetAsync(url, true)
	end)

	if ok and code and #code > 0 then
		local existing = targetFolder:FindFirstChild(item.name)
		local scriptInstance = existing

		if existing and existing.ClassName ~= item.kind then
			existing:Destroy()
			scriptInstance = nil
		end

		if not scriptInstance then
			scriptInstance = Instance.new(item.kind)
			scriptInstance.Name = item.name
			scriptInstance.Parent = targetFolder
		end

		(scriptInstance :: any).Source = code
		successCount += 1
		print(string.format("  ✓ [%s] %s (%d bytes)", item.kind, item.name, #code))
	else
		failCount += 1
		warn(string.format("  ✗ Failed to fetch %s: %s", item.path, tostring(code)))
	end
end

print("==================================================")
if failCount == 0 then
	print(string.format("🎉 [Animal RNG] SUCCESS! Synced all %d scripts directly from GitHub!", successCount))
	print("▶ You do NOT need Rojo anymore! Simply press PLAY (F5) to test!")
else
	warn(string.format("⚠️ Synced %d scripts, but %d failed.", successCount, failCount))
end
print("==================================================")
