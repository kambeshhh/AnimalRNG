-- AltarAnimator: spins the altar rings and bobs the crystal (client-only, cosmetic)
local RunService = game:GetService("RunService")
local fx = workspace:WaitForChild("Hub"):WaitForChild("AltarFX", 30); if not fx then return end
local crystal, inner, outer, floor = fx:WaitForChild("Crystal"), fx:WaitForChild("RingInner"), fx:WaitForChild("RingOuter"), fx:WaitForChild("FloorRing")
local c0, i0, o0, f0 = crystal:GetPivot(), inner:GetPivot(), outer:GetPivot(), floor:GetPivot()
local light = crystal.Core:FindFirstChildOfClass("PointLight")
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
