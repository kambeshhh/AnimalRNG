-- AbilityService: E abilities. Movement abilities are applied by the owner client; knockback only hits players inside the Alpha Zone.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Modules.Config)
local Net = require(RS.Modules.Net)

local Ability = {}
local S
local readyAt = {}

function Ability.Init(services) S = services end

local function knock(victim, velocity)
	if not S.AlphaZoneService.IsInside(victim) then return end
	Net.Get("Knockback"):FireClient(victim, velocity)
end

local function onUse(player)
	local char = player.Character
	local root = char and char.PrimaryPart
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end
	local ability = char:GetAttribute("Ability")
	local cfg = Config.Abilities[ability]; if not cfg then return end
	local now = os.clock()
	if (readyAt[player] or 0) > now + 0.1 then return end
	readyAt[player] = now + cfg.Cooldown
	char:SetAttribute("AbilityReadyAt", workspace:GetServerTimeNow() + cfg.Cooldown)
	local titan = char:GetAttribute("Titan") == true
	local scale = titan and 1.5 or 1
	local origin = root.Position
	local look = (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	if ability == "Slam" or ability == "FrostPulse" then
		for _, p in ipairs(Players:GetPlayers()) do
			local r = p ~= player and p.Character and p.Character.PrimaryPart
			if r then
				local d = Vector3.new(r.Position.X - origin.X, 0, r.Position.Z - origin.Z)
				if d.Magnitude <= cfg.Radius * scale and math.abs(r.Position.Y - origin.Y) < 14 then
					local dir = d.Magnitude > 0.1 and d.Unit or look
					knock(p, dir * cfg.Force * scale + Vector3.new(0, 55, 0))
				end
			end
		end
	elseif ability == "Beam" then
		for _, p in ipairs(Players:GetPlayers()) do
			local r = p ~= player and p.Character and p.Character.PrimaryPart
			if r then
				local rel = r.Position - origin
				local along = rel:Dot(look)
				local lateral = (rel - look * along) * Vector3.new(1, 0, 1)
				if along > 0 and along <= cfg.Range * scale and lateral.Magnitude <= cfg.Width / 2 * scale and math.abs(rel.Y) < 14 then
					knock(p, look * cfg.Force * scale + Vector3.new(0, 45, 0))
				end
			end
		end
	end
	Net.Get("AbilityFX"):FireAllClients(player, ability, origin, look, scale)
end

function Ability.Start()
	Net.Get("UseAbility").OnServerEvent:Connect(onUse)
	Players.PlayerRemoving:Connect(function(p) readyAt[p] = nil end)
end

return Ability
