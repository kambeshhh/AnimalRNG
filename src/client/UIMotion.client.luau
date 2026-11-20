-- UIMotion: cosmetic HUD motion (entrance, glow, light sweeps, coin pop). Reads the HUD, never changes game state.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("RNGHud", 30); if not gui then return end
local function tw(o, p, t, s, d) local x = TweenService:Create(o, TweenInfo.new(t, s or Enum.EasingStyle.Quint, d or Enum.EasingDirection.Out), p); x:Play(); return x end
local function gradOn(stroke, name, seq)
	if not stroke then return end
	local g = stroke:FindFirstChild(name) or Instance.new("UIGradient"); g.Name = name; g.Color = seq; g:SetAttribute("ThemeSkip", true); g.Parent = stroke
	stroke.Color = Color3.new(1, 1, 1); return g
end
local C = Color3.fromRGB
local CYAN, GOLD, MAG, LINE = C(40, 210, 255), C(255, 200, 40), C(255, 79, 216), C(8, 10, 20)
local SWEEP = ColorSequence.new({ ColorSequenceKeypoint.new(0, LINE), ColorSequenceKeypoint.new(0.42, LINE), ColorSequenceKeypoint.new(0.5, CYAN), ColorSequenceKeypoint.new(0.58, LINE), ColorSequenceKeypoint.new(1, LINE) })
local GRAIL = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 213, 74)), ColorSequenceKeypoint.new(0.5, CYAN), ColorSequenceKeypoint.new(1, MAG) })

-- 1) Entrance: slide pieces in from their edges
local dock, bar, wallet, top, ability = gui.RollDock, gui.IconBar, gui.Wallet, gui.TopCenter, gui.AbilityButton
for _, e in { { dock, UDim2.fromOffset(0, 220) }, { bar, UDim2.fromOffset(-140, 0) }, { wallet, UDim2.fromOffset(0, -140) }, { top, UDim2.fromOffset(0, -160) }, { ability, UDim2.fromOffset(200, 0) } } do
	local o, off = e[1], e[2]
	local home = o.Position; o.Position = home + off
	task.delay(0.15, function() tw(o, { Position = home }, 0.7, Enum.EasingStyle.Back) end)
end

-- 2) Animated borders
local sweeps = {}
local function addSweep(stroke, speed, seq) local g = gradOn(stroke, "Sweep", seq or SWEEP); if g then table.insert(sweeps, { g = g, s = speed }) end end
addSweep(dock.Bar:FindFirstChild("Stroke"), 70)
addSweep(gui.TopCenter.WeatherPill:FindFirstChild("Stroke"), 55)
addSweep(wallet:FindFirstChild("Stroke"), 45)
local jb = gui:FindFirstChild("JackpotBanner"); if jb then addSweep(jb:FindFirstChild("Stroke"), 120, GRAIL) end
local ring = ability:FindFirstChild("Ring"); local ringGrad = ring and ring:FindFirstChildOfClass("UIGradient")
for _, b in bar:GetChildren() do
	if b:IsA("GuiButton") and b:FindFirstChild("SelectRing") then addSweep(b.SelectRing, 160, ColorSequence.new(Color3.new(1, 1, 1), GOLD)) end
end

-- 3) Roll / 5x breathing glow + periodic shine sweep
local roll, multi = dock.RollButton, dock.MultiButton
local function shine(btn)
	local s = btn:FindFirstChild("ShineSweep")
	if not s then
		s = Instance.new("Frame"); s.Name = "ShineSweep"; s.BackgroundColor3 = Color3.new(1, 1, 1); s.BorderSizePixel = 0; s.Size = UDim2.new(0.22, 0, 1.6, 0)
		s.AnchorPoint = Vector2.new(0.5, 0.5); s.Rotation = 18; s.ZIndex = btn.ZIndex + 2; s.BackgroundTransparency = 0.25
		local g = Instance.new("UIGradient"); g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) }); g.Parent = s
		s.Parent = btn; btn.ClipsDescendants = true
	end
	s.Position = UDim2.fromScale(-0.3, 0.5); tw(s, { Position = UDim2.fromScale(1.3, 0.5) }, 0.9, Enum.EasingStyle.Sine)
end
task.spawn(function() while gui.Parent do task.wait(3.2); shine(roll); task.wait(0.25); shine(multi) end end)

-- 4) Coin pop when the balance changes
local coins = wallet:FindFirstChild("Coins")
if coins then
	local sc = coins:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", coins)
	coins:GetPropertyChangedSignal("Text"):Connect(function() sc.Scale = 1.18; tw(sc, { Scale = 1 }, 0.35, Enum.EasingStyle.Back) end)
end

-- 5) Per-frame: rotate sweeps, breathe glows
local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	for _, s in sweeps do s.g.Rotation = (s.g.Rotation + dt * s.s) % 360 end
	if ringGrad then ringGrad.Rotation = (ringGrad.Rotation + dt * 90) % 360 end
	local k = (math.sin(t * 2.4) + 1) / 2
	if roll:FindFirstChild("Gloss") then roll.Gloss.BackgroundTransparency = 0.62 + (1 - k) * 0.25 end
	-- outlines stay solid (chunky style)
end)
