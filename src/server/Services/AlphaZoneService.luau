-- AlphaZoneService: King-of-the-Hill circle. Inside = +100% luck, 2x roll speed, and you can be knocked out.
local Players = game:GetService("Players")
local AlphaZone = {}
local S
local inside = {}

function AlphaZone.Init(services) S = services end
function AlphaZone.IsInside(p) return inside[p] == true end

function AlphaZone.Start()
	local vol = workspace.Hub.AlphaZone.ZoneVolume
	local center, radius, floorY = vol.Position, vol:GetAttribute("Radius"), vol:GetAttribute("FloorY")
	Players.PlayerRemoving:Connect(function(p) inside[p] = nil end)
	local acc = 0
	while true do
		local dt = task.wait(0.2)
		acc += dt
		for _, p in ipairs(Players:GetPlayers()) do
			local root = p.Character and p.Character.PrimaryPart
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			local now = false
			if root and hum and hum.Health > 0 then
				local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
				now = flat <= radius and root.Position.Y > floorY - 2 and root.Position.Y < floorY + 40
			end
			if now ~= (inside[p] == true) then inside[p] = now; p:SetAttribute("InAlpha", now) end
			local data = S.DataService.Get(p)
			if now and data then data.Stats.AlphaTime += dt end
		end
		if acc >= 5 then
			acc = 0
			for _, p in ipairs(Players:GetPlayers()) do if inside[p] then S.ProgressionService.CheckRanks(p) end end
		end
	end
end

return AlphaZone
