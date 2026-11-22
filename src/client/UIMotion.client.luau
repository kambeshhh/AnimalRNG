-- UIMotion: cosmetic HUD motion (entrance, glow, light sweeps, coin pop). Reads the HUD, never changes game state.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("Modules"):WaitForChild("Config"))
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("RNGHud", 30); if not gui then return end
local function tw(o, p, t, s, d) local x = TweenService:Create(o, TweenInfo.new(t, s or Enum.EasingStyle.Quint, d or Enum.EasingDirection.Out), p); x:Play(); return x end
local function gradOn(stroke, name, seq)
	if not stroke then return end
	local g = stroke:FindFirstChild(name) or Instance.new("UIGradient"); g.Name = name; g.Color = seq; g:SetAttribute("ThemeSkip", true); g.Parent = stroke
	stroke.Color = Color3.new(1, 1, 1); return g
end
local C = Color3.fromRGB
local CYAN, GOLD, MAG, LINE = C(40, 210, 255), C(255, 200, 40), C(255, 79, 216), C(8, 10, 20)
local SWEEP = ColorSequence.new({ ColorSequenceKeypoint.new(0, LINE), ColorSequenceKeypoint.new(0.38, LINE), ColorSequenceKeypoint.new(0.5, CYAN), ColorSequenceKeypoint.new(0.62, LINE), ColorSequenceKeypoint.new(1, LINE) })
local GRAIL = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 213, 74)), ColorSequenceKeypoint.new(0.5, CYAN), ColorSequenceKeypoint.new(1, MAG) })

-- 1) Entrance: slide pieces in from their edges
local dock, bar, wallet, top, ability = gui.RollDock, gui.IconBar, gui.Wallet, gui.TopCenter, gui.AbilityButton
for _, e in { { dock, UDim2.fromOffset(0, 220) }, { bar, UDim2.fromOffset(-140, 0) }, { wallet, UDim2.fromOffset(0, -140) }, { top, UDim2.fromOffset(0, -160) }, { ability, UDim2.fromOffset(200, 0) } } do
	local o, off = e[1], e[2]
	local home = o.Position; o.Position = home + off
	task.delay(0.15, function() tw(o, { Position = home }, 0.7, Enum.EasingStyle.Back) end)
end

-- 2) Subtle selection sweeps (only on active IconBar SelectRing & JackpotBanner; main HUD frames stay crisp matte slate)
local sweeps = {}
local function addSweep(stroke, speed, seq) local g = gradOn(stroke, "Sweep", seq or SWEEP); if g then table.insert(sweeps, { g = g, s = speed }) end end
local jb = gui:FindFirstChild("JackpotBanner"); if jb then addSweep(jb:FindFirstChild("Stroke"), 120, GRAIL) end
local ring = ability:FindFirstChild("Ring"); local ringGrad = ring and ring:FindFirstChildOfClass("UIGradient")
local dots = {}
for _, b in bar:GetChildren() do
	if b:IsA("GuiButton") then
		if b:FindFirstChild("SelectRing") then addSweep(b.SelectRing, 160, ColorSequence.new(Color3.new(1, 1, 1), GOLD)) end
		local dot = b:FindFirstChild("Dot")
		if dot and dot:IsA("GuiObject") then
			local dsc = dot:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", dot)
			table.insert(dots, dsc)
		end
	end
end

-- 3) Live 3D Spinning Die inside the ROLL button + periodic shine sweep
local roll, multi = dock.RollButton, dock.MultiButton
local diePart3D
pcall(function()
	local oldVP = roll:FindFirstChild("RollDieVP"); if oldVP then oldVP:Destroy() end
	local vp = Instance.new("ViewportFrame"); vp.Name = "RollDieVP"
	vp.Size = UDim2.fromOffset(42, 42); vp.Position = UDim2.new(0, 8, 0.5, -21)
	vp.BackgroundTransparency = 1; vp.ZIndex = roll.ZIndex + 3
	vp.Ambient = C(200, 220, 255); vp.LightColor = C(255, 255, 255); vp.LightDirection = Vector3.new(-1, -1, -1)
	local cam = Instance.new("Camera"); cam.FieldOfView = 35; cam.CFrame = CFrame.lookAt(Vector3.new(0, 1.4, 3.8), Vector3.zero); cam.Parent = vp
	vp.CurrentCamera = cam
	local dp = Instance.new("Part"); dp.Size = Vector3.new(1.55, 1.55, 1.55); dp.Material = Enum.Material.Neon; dp.Color = C(255, 235, 120)
	local bc = Instance.new("SelectionBox"); bc.Adornee = dp; bc.Color3 = C(255, 255, 255); bc.LineThickness = 0.06; bc.SurfaceTransparency = 0.75; bc.SurfaceColor3 = CYAN; bc.Parent = dp
	dp.Parent = vp; vp.Parent = roll
	diePart3D = dp
	local function updateDieColor()
		local dk = player:GetAttribute("EquippedDie") or "Wooden"
		local cfg = Config.Dice and Config.Dice.Types and Config.Dice.Types[dk]
		if cfg and diePart3D then
			diePart3D.Color = cfg.Color
			bc.Color3 = cfg.Accent or Color3.new(1, 1, 1)
		end
	end
	player:GetAttributeChangedSignal("EquippedDie"):Connect(updateDieColor)
	updateDieColor()
end)

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

-- 5) Ambient Celestial Biome Soundscape (soft harmonic pad chord loop using our custom StarburstChord WAV slowed into an ethereal pad)
task.spawn(function()
	local ambGroup = SoundService:FindFirstChild("AnimalRNG_AmbientGroup") or Instance.new("SoundGroup")
	ambGroup.Name = "AnimalRNG_AmbientGroup"; ambGroup.Volume = 0.22; ambGroup.Parent = SoundService
	if not ambGroup:FindFirstChildOfClass("ReverbSoundEffect") then
		local rev = Instance.new("ReverbSoundEffect"); rev.DecayTime = 4.5; rev.Density = 1; rev.Diffusion = 1; rev.DryLevel = -6; rev.WetLevel = 0; rev.Parent = ambGroup
		local eq = Instance.new("EqualizerSoundEffect"); eq.LowGain = 3; eq.MidGain = -4; eq.HighGain = -8; eq.Parent = ambGroup
	end
	local padNotes = { 0.45, 0.5, 0.6, 0.53 }
	local idx = 1
	while gui.Parent do
		local s = Instance.new("Sound")
		s.Name = "AmbientCelestialPad"
		s.SoundId = Config.Sounds.Reveal -- AnimalRNG_StarburstChord_SFX
		s.Volume = 0.28
		s.PlaybackSpeed = padNotes[idx]
		s.SoundGroup = ambGroup
		s.Parent = SoundService
		s:Play()
		s.Ended:Connect(function() s:Destroy() end)
		task.delay(8, function() if s.Parent then s:Destroy() end end)
		idx = (idx % #padNotes) + 1
		task.wait(5.5)
	end
end)

-- 6) Per-frame: rotate sweeps, spin 3D die on RollButton, pulse notification dots
local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	for _, s in sweeps do s.g.Rotation = (s.g.Rotation + dt * s.s) % 360 end
	if ringGrad then ringGrad.Rotation = (ringGrad.Rotation + dt * 90) % 360 end
	local k = (math.sin(t * 2.4) + 1) / 2
	if roll:FindFirstChild("Gloss") then roll.Gloss.BackgroundTransparency = 0.62 + (1 - k) * 0.25 end
	if diePart3D then
		diePart3D.CFrame = CFrame.Angles(t * 1.6, t * 2.2, math.sin(t * 1.4) * 0.5)
	end
	local dotPulse = 1 + math.sin(t * 5.5) * 0.16
	for _, dsc in dots do dsc.Scale = dotPulse end
end)
