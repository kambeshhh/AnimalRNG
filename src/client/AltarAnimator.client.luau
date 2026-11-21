-- AltarAnimator: spins the altar rings, bobs the crystal, and spawns procedural Sol's RNG sacred beams & ambient dust
local RunService = game:GetService("RunService")
local C = Color3.fromRGB
local fx = workspace:WaitForChild("Hub"):WaitForChild("AltarFX", 30); if not fx then return end
local crystal, inner, outer, floor = fx:WaitForChild("Crystal"), fx:WaitForChild("RingInner"), fx:WaitForChild("RingOuter"), fx:WaitForChild("FloorRing")
local c0, i0, o0, f0 = crystal:GetPivot(), inner:GetPivot(), outer:GetPivot(), floor:GetPivot()
local light = crystal.Core:FindFirstChildOfClass("PointLight")

-- Spawn procedural Sol's RNG sacred energy ring & ambient fireflies around the central altar
pcall(function()
	local centerPart = crystal:FindFirstChild("Core") or crystal.PrimaryPart
	if centerPart and not centerPart:FindFirstChild("SacredAltarAura") then
		local aura = Instance.new("Folder"); aura.Name = "SacredAltarAura"; aura.Parent = centerPart
		local seq = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C(34, 235, 255)),
			ColorSequenceKeypoint.new(0.5, C(210, 120, 255)),
			ColorSequenceKeypoint.new(1, C(255, 210, 45)),
		})
		local em = Instance.new("ParticleEmitter")
		em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		em.Color = seq; em.LightEmission = 1; em.Rate = 28
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(1, 0) })
		em.Lifetime = NumberRange.new(1.8, 3.5); em.Speed = NumberRange.new(2, 6); em.SpreadAngle = Vector2.new(180, 180)
		em.Parent = aura

		-- Vertical skyward beacon beam from the altar crystal
		local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, -4, 0); a0.Parent = centerPart
		local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, 85, 0); a1.Parent = centerPart
		local bm = Instance.new("Beam"); bm.Attachment0 = a0; bm.Attachment1 = a1
		bm.Color = seq; bm.LightEmission = 1; bm.FaceCamera = true
		bm.Width0 = 3.2; bm.Width1 = 0.2; bm.Transparency = NumberSequence.new(0.35, 1)
		bm.Parent = aura
	end
end)

local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	crystal:PivotTo(CFrame.new(c0.Position + Vector3.new(0, math.sin(t * 1.4) * 0.8, 0)) * CFrame.Angles(0, t * 0.9, 0) * (c0 - c0.Position))
	inner:PivotTo(CFrame.new(i0.Position) * CFrame.Angles(math.rad(18), t * 0.6, math.rad(8)))
	outer:PivotTo(CFrame.new(o0.Position) * CFrame.Angles(math.rad(-12), -t * 0.35, math.rad(-6)))
	floor:PivotTo(CFrame.new(f0.Position) * CFrame.Angles(0, t * 0.08, 0))
	if light then light.Brightness = 2.6 + math.sin(t * 2.2) * 0.8 end
end)

-- Lobby rings tagged SpinFX (attributes: Speed, Tilt in degrees)
local CS = game:GetService("CollectionService")
local spins = {}
local function add(m) if m:IsA("Model") then table.insert(spins, { m = m, p = m:GetPivot().Position, s = m:GetAttribute("Speed") or 0.3, tilt = math.rad(m:GetAttribute("Tilt") or 0) }) end end
for _, m in CS:GetTagged("SpinFX") do add(m) end
CS:GetInstanceAddedSignal("SpinFX"):Connect(add)
local t2 = 0
RunService.RenderStepped:Connect(function(dt)
	t2 += dt
	for _, s in spins do if s.m.Parent then s.m:PivotTo(CFrame.new(s.p) * CFrame.Angles(s.tilt, t2 * s.s, 0)) end end
end)
