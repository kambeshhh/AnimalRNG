-- AnimationController: procedural bone animation for every animal (legs, tail, wings), floating props, pickups, TITAN footsteps
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CS = game:GetService("CollectionService")

local Anim = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local cache = setmetatable({}, { __mode = "k" })
local nextStep = 0

local function rig(model)
	if cache[model] then return cache[model] end
	local r = { legs = {}, wings = {} }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Bone") then
			if d:GetAttribute("Phase") ~= nil then table.insert(r.legs, d)
			elseif d:GetAttribute("Wag") then r.tail = d
			elseif d:GetAttribute("Flap") then table.insert(r.wings, d)
			elseif d.Name == "Root" then r.root = d end
		end
	end
	cache[model] = r
	return r
end

local function fitCamera(char)
	local mesh = char:WaitForChild("AnimalMesh", 5)
	if not mesh then return end
	local size = math.max(mesh.Size.X, mesh.Size.Y, mesh.Size.Z)
	player.CameraMaxZoomDistance = math.max(60, size * 5)
	player.CameraMinZoomDistance = math.clamp(size * 1.1, 0.5, 40)
	task.delay(0.1, function() player.CameraMinZoomDistance = math.clamp(size * 0.6, 0.5, 20) end)
end

function Anim.Start()
	player.CharacterAdded:Connect(fitCamera)
	if player.Character then task.spawn(fitCamera, player.Character) end
	RunService.Stepped:Connect(function(t)
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p.Character
			local root = c and c.PrimaryPart
			if root then
				local r = rig(c)
				local v = root.AssemblyLinearVelocity
				local spd = Vector3.new(v.X, 0, v.Z).Magnitude
				local hum = c:FindFirstChildOfClass("Humanoid")
				local air = hum and hum.FloorMaterial == Enum.Material.Air
				local amp = math.clamp(spd / 24, 0, 1) * 0.85
				local freq = 7 + math.min(spd, 120) * 0.14
				for _, b in ipairs(r.legs) do
					local ph = b:GetAttribute("Phase")
					b.Transform = air and CFrame.Angles(ph == 0 and -0.5 or 0.5, 0, 0) or CFrame.Angles(math.sin(t * freq + ph * math.pi) * amp, 0, 0)
				end
				if r.tail then r.tail.Transform = CFrame.Angles(0, 0, math.sin(t * freq * 0.5) * (0.15 + 0.25 * amp)) end
				for _, w in ipairs(r.wings) do
					local beat = air and 9 or (3.5 + amp * 6)
					w.Transform = CFrame.Angles(math.sin(t * beat) * (air and 0.55 or 0.12 + amp * 0.3), 0, 0)
				end
				if c:GetAttribute("Showcase") then
					if r.root then
						r.root.Transform = CFrame.new(0, math.sin(t * 1.8) * 0.45, 0) * CFrame.Angles(0, t * 1.1, math.sin(t * 1.4) * 0.08)
					end
				elseif r.root then
					r.root.Transform = air and CFrame.new() or CFrame.new(0, math.abs(math.sin(t * freq)) * 0.12 * amp, 0)
				end
				-- TITAN footsteps: subtle camera shake for the local player
				if p == player and c:GetAttribute("Titan") and spd > 6 and not air and hum then
					if t > nextStep then
						nextStep = t + 0.38
						hum.CameraOffset = Vector3.new(math.random(-10, 10) / 60, math.random(-10, 10) / 40, 0)
						task.delay(0.08, function() if hum.Parent then hum.CameraOffset = Vector3.zero end end)
					end
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, p in ipairs(CS:GetTagged("Floater")) do
			local base = p:GetAttribute("BasePos")
			if base then p.CFrame = CFrame.new(base + Vector3.new(0, math.sin(t * 1.6 + base.X) * 0.6, 0)) * CFrame.Angles(0, t * 0.6, 0) end
		end
		for _, p in ipairs(CS:GetTagged("Spinner")) do
			local base = p:GetAttribute("BaseCFrame")
			if base then p.CFrame = base * CFrame.Angles(t * 1.2, 0, 0) end
		end
		for _, p in ipairs(CS:GetTagged("Pickup")) do
			local base = p:GetAttribute("BasePos")
			if base then p.CFrame = CFrame.new(base + Vector3.new(0, math.sin(t * 3) * 0.4, 0)) * CFrame.Angles(0, t * 2, 0) end
		end
	end)
end

-- Showcase halo + Sol's RNG Sacred Floor Sigils + Slime RNG / Anime Dice Bouncy 3D Companion Pack
task.spawn(function()
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local compCF = setmetatable({}, { __mode = "k" })
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local alpha = math.clamp(dt * 8.5, 0.05, 0.45)
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p.Character
			local root = c and c.PrimaryPart
			if root then
				if c:GetAttribute("Showcase") or c:GetAttribute("HasSigil") then
					local r, h = c:GetAttribute("HaloRadius") or 8, c:GetAttribute("HaloHeight") or 4
					for _, att in ipairs(root:GetChildren()) do
						if att:IsA("Attachment") then
							local base = att:GetAttribute("Angle")
							if base then
								local a = base + t * 0.9
								att.Position = Vector3.new(math.cos(a) * r, h + math.sin(t * 2 + base * 2) * 0.8, math.sin(a) * r)
							else
								local sAng = att:GetAttribute("SigilAngle")
								if sAng then
									local sRad = att:GetAttribute("SigilRadius") or 6
									local sY = att:GetAttribute("SigilY") or -2.5
									local sSpd = att:GetAttribute("SigilSpeed") or 0.7
									local a = sAng + t * sSpd
									att.Position = Vector3.new(math.cos(a) * sRad, sY + math.sin(t * 2.5 + sAng) * 0.12, math.sin(a) * sRad)
								end
							end
						end
					end
				end
				-- Slime RNG x Anime Dice: Bouncy 3D Companion Pack following in V-formation
				local pack = c:FindFirstChild("Companions")
				if pack then
					for _, comp in ipairs(pack:GetChildren()) do
						if comp:IsA("Model") then
							local ox = comp:GetAttribute("OffsetX") or -5.5
							local oz = comp:GetAttribute("OffsetZ") or 4
							local ph = comp:GetAttribute("Phase") or 0
							local bounce = math.abs(math.sin(t * 4.4 + ph)) * 1.15
							local sway = math.sin(t * 2.2 + ph) * 0.08
							local targetCF = root.CFrame * CFrame.new(ox, bounce - 0.5, oz) * CFrame.Angles(0, sway, math.sin(t * 4.4 + ph) * 0.06)
							local cur = compCF[comp]
							local nextCF = cur and cur:Lerp(targetCF, alpha) or targetCF
							compCF[comp] = nextCF
							comp:PivotTo(nextCF)
						end
					end
				end
				-- Sol's RNG x Anime Dice: 3D Wearable Relics & Gauntlets orbiting the character
				local relics = c:FindFirstChild("EquippedRelics3D")
				if relics then
					local items = relics:GetChildren()
					local n = #items
					for i, rel in ipairs(items) do
						if rel:IsA("BasePart") then
							local slot = rel:GetAttribute("RelicSlot")
							local ang = t * 1.85 + (i - 1) / math.max(1, n) * math.pi * 2
							local rad = (slot == "Halo" and 0.1) or 4.2
							local h = (slot == "Halo" and 5.2) or (1.5 + math.sin(t * 3 + i) * 0.9)
							local offset = Vector3.new(math.cos(ang) * rad, h, math.sin(ang) * rad)
							rel.CFrame = CFrame.new(root.Position + offset) * CFrame.Angles(t * 2.2, t * 1.7, t * 0.9)
						end
					end
				end
			end
		end
	end)
end)

return Anim
