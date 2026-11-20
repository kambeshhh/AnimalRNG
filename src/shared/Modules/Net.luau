-- Net : single source of truth for every remote. Server creates them, clients wait for them.
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local Net = {}
Net.Events = {
	"RequestRoll",   -- client -> server (quickRoll: boolean)
	"RollResult",    -- server -> client
	"Jackpot",       -- server -> all clients (sky beam + banner)
	"Action",        -- client -> server (actionName, ...) inventory / stations / potions / gifts
	"Sync",          -- server -> client (full player snapshot)
	"Notify",        -- server -> client (kind, payload)
	"UseAbility",    -- client -> server
	"AbilityFX",     -- server -> all clients
	"Knockback",     -- server -> victim client
	"SocialFX",      -- server -> all clients (VIP admin cosmetic effects)
}
Net.Functions = {
	"Admin",         -- client -> server request/response (dev + VIP admin panels)
}

local folder
function Net.Folder()
	if folder then return folder end
	if RunService:IsServer() then
		folder = RS:FindFirstChild("Remotes") or Instance.new("Folder")
		folder.Name = "Remotes"; folder.Parent = RS
		for _, n in ipairs(Net.Events) do
			if not folder:FindFirstChild(n) then local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = folder end
		end
		for _, n in ipairs(Net.Functions) do
			if not folder:FindFirstChild(n) then local r = Instance.new("RemoteFunction"); r.Name = n; r.Parent = folder end
		end
	else
		folder = RS:WaitForChild("Remotes")
	end
	return folder
end

function Net.Get(name: string): RemoteEvent
	assert(table.find(Net.Events, name), "Unknown remote: " .. name)
	function Net.GetFunction(name: string): RemoteFunction
	assert(table.find(Net.Functions, name), "Unknown remote function: " .. name)
	return Net.Folder():WaitForChild(name)
end

return Net.Folder():WaitForChild(name)
end

return Net
