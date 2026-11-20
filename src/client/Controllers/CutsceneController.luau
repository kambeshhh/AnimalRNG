-- CutsceneController v3 — modular 28-tier reveal engine.
-- Every effect is registered on a Janitor; finish / abort / respawn always restores camera FOV + offset,
-- destroys ColorCorrection, Blur, Sounds, BillboardGuis, rings, ghosts and pillars. No Scriptable camera is ever used.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Config = require(RS.Modules.Config)
local AnimalData = require(RS.Modules.AnimalData)
local Net = require(RS.Modules.Net)
local UI = require(script.Parent.UIUtil)
local State = require(script.Parent.ClientState)

local Cut = {}
local player = Players.LocalPlayer
local C = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local TOP = AnimalData.TierCount
local ABORT = "__cutscene_abort"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local RAINBOW = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 90, 90)), ColorSequenceKeypoint.new(0.25, C(255, 220, 80)),
	ColorSequenceKeypoint.new(0.5, C(90, 255, 160)), ColorSequenceKeypoint.new(0.75, C(90, 160, 255)), ColorSequenceKeypoint.new(1, C(230, 110, 255)) })

------------------------------------------------------------------ PROFILES (tier groups → identity)
-- Build = anticipation seconds, Hold = reveal hold. Hit/Tail/BuildSfx = { sound, volume, pitch }.
local PROFILES = {
	{ From = 1,  To = 3,  Name = "Quick" },
	{ From = 4,  To = 6,  Name = "Spark",   Build = 0.2, Hold = 0.9, Vignette = 0.35, Flash = 0.4, Rings = 1, Card = "quick",
		BuildSfx = { "Swish", 0.5, 1.15 }, Hit = { { "Bass", 0.5, 1.3 }, { "Pop", 0.4, 1.2 } } },
	{ From = 7,  To = 9,  Name = "Pulse",   Build = 0.45, Hold = 1.2, Vignette = 0.55, Flash = 0.5, Rings = 1, Shock = 28, Shake = 0.35, Ghost = true, Card = "star",
		BuildSfx = { "Swish", 0.55, 0.95 }, Hit = { { "Bass", 0.7, 0.85 } }, Tail = { { "Chime", 0.5, 1 }, { "Reveal", 0.4, 1.1 } } },
	{ From = 10, To = 12, Name = "Rift",    Build = 1.0, Hold = 1.25, Vignette = 0.6, Flash = 0.55, Rings = 2, Rift = true, Zoom = 10, Shock = 34, Shake = 0.5, Riser = 1, Ghost = true, Tag = true, Card = "star",
		Hit = { { "Bass", 0.75, 0.75 }, { "Pop", 0.4, 0.9 } }, Tail = { { "Chime", 0.5, 0.9 } } },
	{ From = 13, To = 15, Name = "Cosmic",  Build = 1.4, Hold = 1.6, Vignette = 0.65, Flash = 0.6, Rings = 2, Rift = true, Zoom = 12, Stars = 8, Shock = 40, Shake = 0.9, Riser = 1, Ghost = true, Tag = true, Card = "star",
		Grade = { Contrast = 0.25, Saturation = 0.25, Tint = 0.18 }, Hit = { { "Bass", 0.8, 0.6 } }, Tail = { { "Chime", 0.5, 0.85 }, { "Reveal", 0.4, 0.9 } } },
	{ From = 16, To = 19, Name = "Eternal", Build = 1.6, Hold = 1.9, Vignette = 0.7, Flash = 0.7, Rings = 3, Rift = true, Zoom = 14, Stars = 10, Shock = 46, Shake = 1.1, Riser = 2, Burst = 120, Bursts = 1, Ghost = true, Tag = true, Card = "star",
		Grade = { Contrast = 0.4, Saturation = 0.35, Tint = 0.2 }, Hit = { { "Bass", 0.85, 0.55 }, { "Bass", 0.45, 0.8 } }, Tail = { { "Reveal", 0.5, 0.8 }, { "Chime", 0.45, 0.85 } } },
	{ From = 20, To = 24, Name = "Pillar",  Build = 1.9, Hold = 2.3, Vignette = 0.75, Flash = 0.75, Rings = 3, Rift = true, Zoom = 16, Stars = 12, Shock = 55, Shake = 1.3, Riser = 2, Burst = 140, Bursts = 2, Pillar = true, Blur = 6, Ghost = true, Tag = true, Card = "star",
		Grade = { Contrast = 0.45, Saturation = 0.3, Brightness = -0.05, Tint = 0.25 }, Hit = { { "Bass", 0.85, 0.5 }, { "Reveal", 0.45, 0.7 } }, Tail = { { "Chime", 0.45, 0.8 } } },
	{ From = 25, To = 27, Name = "Climax",  Build = 2.2, Hold = 2.6, Vignette = 0.82, Flash = 0.85, Rings = 4, Rift = true, Zoom = 18, Stars = 14, Shock = 70, Shake = 1.5, Riser = 3, Burst = 180, Bursts = 3, Pillar = true, Blur = 8, Ghost = true, Tag = true, Card = "star",
		Grade = { Contrast = 0.55, Saturation = 0.4, Brightness = -0.06, Tint = 0.28 }, Hit = { { "Bass", 0.8, 0.45 }, { "Bass", 0.5, 0.6 }, { "Low", 0.55, 0.75 } }, Tail = { { "Reveal", 0.45, 0.65 } } },
	{ From = 28, To = 28, Name = "Unattainable" },
}
Cut.Profiles = PROFILES
local function profileFor(idx) for _, P in ipairs(PROFILES) do if idx >= P.From and idx <= P.To then return P end end return PROFILES[1] end

------------------------------------------------------------------ Janitor
local Janitor = {}; Janitor.__index = Janitor
function Janitor.new() return setmetatable({ items = {}, conns = {}, sounds = {}, dead = false }, Janitor) end
function Janitor:add(x) table.insert(self.items, x); return x end
function Janitor:conn(c) table.insert(self.conns, c); return c end
function Janitor:wait(t)
	local t0 = os.clock()
	repeat
		if self.dead then error(ABORT, 0) end
		task.wait()
	until os.clock() - t0 >= t
	if self.dead then error(ABORT, 0) end
end
function Janitor:clean()
	if self.cleaned then return end
	self.cleaned = true; self.dead = true
	for _, c in ipairs(self.conns) do c:Disconnect() end
	for i = #self.items, 1, -1 do
		local x = self.items[i]
		if typeof(x) == "Instance" then x:Destroy() elseif type(x) == "function" then pcall(x) end
	end
	table.clear(self.items); table.clear(self.conns); table.clear(self.sounds)
end

local active
function Cut.Abort() if active then active:clean(); active = nil end end
function Cut.IsActive() return active ~= nil end

------------------------------------------------------------------ primitives
local fx -- CutsceneFX ScreenGui (built in Start)
local function tw(o, props, t, style, dir)
	local tween = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props); tween:Play(); return tween
end
local function settings() return (State.Data and State.Data.Settings) or { CutsceneMin = Config.Cutscene.Default, ReduceOthersFX = false } end
local function minTier()
	local m = settings().CutsceneMin or Config.Cutscene.Default
	if m > TOP then m = AnimalData.TierIndex(m) end
	return m
end
local function tierColor(idx) return AnimalData.Tiers[math.clamp(idx, 1, TOP)].Color end
local function rootPart() return player.Character and player.Character.PrimaryPart end

local function sfx(J, name, vol, pitch)
	local id = Config.Sounds[name]; if not id then return end
	local s = Instance.new("Sound"); s.Name = "CutsceneSFX"; s.SoundId = id; s.Volume = math.min(vol or 0.6, 0.85); s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService; s:Play()
	s.Ended:Once(function() s:Destroy() end)
	if J then J:add(s); table.insert(J.sounds, s) else Debris:AddItem(s, 6) end
	return s
end

-- one damped shake driver per cutscene (latest request wins; CameraOffset only — never takes the camera)
local function shake(J, amp, dur)
	if not amp or amp <= 0 then return end
	J.shakeAmp, J.shakeDur, J.shakeT0 = amp, dur, os.clock()
	if J.shakeConn then return end
	J.shakeConn = J:conn(RunService.RenderStepped:Connect(function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid"); if not hum then return end
		local t = os.clock() - J.shakeT0
		if t >= J.shakeDur then hum.CameraOffset = Vector3.zero; return end
		local k = J.shakeAmp * math.exp(-4 * t / J.shakeDur)
		local n = os.clock() * 28
		hum.CameraOffset = Vector3.new(math.noise(n, 0.3) * 2 * k, math.noise(0.7, n) * 2 * k, 0)
	end))
end

local function vignette(J, strength, t) tw(fx.Vignette, { GroupTransparency = 1 - strength }, t) end
local function flash(alpha, color)
	if not alpha or alpha <= 0 then return end
	fx.Flash.BackgroundColor3 = color or WHITE; fx.Flash.BackgroundTransparency = 1 - alpha
	tw(fx.Flash, { BackgroundTransparency = 1 }, 0.45)
end

local function ring(J, color, size, t, thick)
	local f = Instance.new("Frame"); f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = UDim2.fromScale(0.5, 0.5); f.Size = UDim2.fromOffset(30, 30); f.BackgroundTransparency = 1
	Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
	local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = thick or 5; s.Parent = f
	f.Parent = fx.Center; J:add(f)
	tw(f, { Size = UDim2.fromOffset(size, size) }, t, Enum.EasingStyle.Quart); tw(s, { Transparency = 1, Thickness = 1 }, t)
	Debris:AddItem(f, t + 0.05)
end

local function rift(J, color, t, rainbow)
	for i, spec in ipairs({ { 640, 140, 1 }, { 520, 90, -1.6 } }) do
		local f = Instance.new("Frame"); f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = UDim2.fromScale(0.5, 0.5); f.Size = UDim2.fromOffset(spec[1], spec[1]); f.BackgroundTransparency = 1
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		local s = Instance.new("UIStroke"); s.Color = WHITE; s.Thickness = 4 - i; s.Transparency = 1; s.Parent = f
		local g = Instance.new("UIGradient"); g.Color = rainbow and RAINBOW or ColorSequence.new(color, color:Lerp(WHITE, 0.6))
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 0) }); g.Parent = s
		f.Parent = fx.Center; J:add(f)
		tw(s, { Transparency = 0 }, t * 0.4)
		tw(f, { Size = UDim2.fromOffset(spec[2], spec[2]) }, t, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		J:conn(RunService.RenderStepped:Connect(function(dt) f.Rotation += dt * 140 * spec[3] end))
		J.rift = J.rift or {}; table.insert(J.rift, { f, s })
	end
end
local function riftCollapse(J)
	for _, p in ipairs(J.rift or {}) do tw(p[1], { Size = UDim2.fromOffset(900, 900) }, 0.35); tw(p[2], { Transparency = 1 }, 0.35) end
end

local function stars(J, n, color, rainbow)
	local labels, t0 = {}, os.clock()
	for i = 1, n do
		local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.AnchorPoint = Vector2.new(0.5, 0.5); l.Size = UDim2.fromOffset(28, 28)
		l.Text = "✦"; l.Font = Enum.Font.FredokaOne; l.TextScaled = true; l.TextTransparency = 1
		l.TextColor3 = rainbow and Color3.fromHSV(i / n, 0.6, 1) or color:Lerp(WHITE, (i % 3) * 0.25)
		l.Parent = fx.Center; J:add(l); labels[i] = l
		tw(l, { TextTransparency = 0 }, 0.5)
	end
	J.stars = labels
	J:conn(RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for i, l in ipairs(labels) do
			local a = t * (0.8 + (i % 3) * 0.25) + i / n * math.pi * 2
			local r = 150 + math.sin(t * 2 + i) * 30 + (i % 2) * 60
			l.Position = UDim2.new(0.5, math.cos(a) * r, 0.5, math.sin(a) * r * 0.6)
			l.Rotation = t * 90
		end
	end))
end

local function grade(J, g, color, t)
	local cc = J.cc
	if not cc then cc = Instance.new("ColorCorrectionEffect"); cc.Name = "CutsceneGrade"; cc.Parent = Lighting; J.cc = J:add(cc) end
	tw(cc, { Contrast = g.Contrast or 0, Saturation = g.Saturation or 0, Brightness = g.Brightness or 0, TintColor = WHITE:Lerp(color, g.Tint or 0) }, t)
end
local function blur(J, size, t)
	local b = J.blur
	if not b then b = Instance.new("BlurEffect"); b.Name = "CutsceneBlur"; b.Size = 0; b.Parent = Lighting; J.blur = J:add(b) end
	tw(b, { Size = size }, t)
end
local function zoom(J, deg, t, back)
	local cam = workspace.CurrentCamera
	J.baseFov = J.baseFov or cam.FieldOfView
	tw(cam, { FieldOfView = back and J.baseFov or (J.baseFov - deg) }, t, back and Enum.EasingStyle.Back or Enum.EasingStyle.Quad, back and Enum.EasingDirection.Out or Enum.EasingDirection.In)
end

local function burstAt(J, pos, color, count, speed)
	local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1; p.Size = Vector3.one; p.Position = pos; p.Parent = workspace
	local e = Instance.new("ParticleEmitter"); e.Texture = SPARK; e.LightEmission = 1; e.Color = typeof(color) == "ColorSequence" and color or ColorSequence.new(color)
	e.Speed = NumberRange.new(speed, speed * 2); e.SpreadAngle = Vector2.new(180, 180); e.Lifetime = NumberRange.new(0.5, 1.1); e.Size = NumberSequence.new(1.4, 0); e.Rate = 0; e.Parent = p
	e:Emit(count); J:add(p); Debris:AddItem(p, 2)
end
local function shockwave(J, pos, color, radius, t)
	local r = Instance.new("Part"); r.Anchored = true; r.CanCollide = false; r.CanQuery = false; r.CanTouch = false; r.CastShadow = false
	r.Shape = Enum.PartType.Cylinder; r.Material = Enum.Material.Neon; r.Color = color; r.Size = Vector3.new(0.3, 4, 4)
	r.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)); r.Parent = workspace; J:add(r)
	tw(r, { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 }, t or 0.9); Debris:AddItem(r, (t or 0.9) + 0.1)
end
local function makePillar(pos, color, rainbow)
	local p = Instance.new("Part"); p.Name = "JackpotPillar"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Shape = Enum.PartType.Cylinder; p.Material = Enum.Material.Neon; p.Color = color; p.Transparency = 0.25
	p.Size = Vector3.new(600, 1, 1); p.CFrame = CFrame.new(pos + Vector3.new(0, 300, 0)) * CFrame.Angles(0, 0, math.rad(90)); p.Parent = workspace
	local l = Instance.new("PointLight"); l.Color = color; l.Range = 45; l.Brightness = 3; l.Parent = p
	tw(p, { Size = Vector3.new(600, 12, 12) }, 0.5, Enum.EasingStyle.Back)
	local conn
	if rainbow then local h = 0; conn = RunService.RenderStepped:Connect(function(dt) h = (h + dt * 0.4) % 1; p.Color = Color3.fromHSV(h, 0.6, 1); l.Color = p.Color end) end
	return p, conn
end
-- self-cleaning pillar (other players' announcements)
function Cut.SkyPillar(pos, color, duration, rainbow)
	local p, conn = makePillar(pos, color, rainbow)
	task.delay(duration or 6, function()
		tw(p, { Size = Vector3.new(600, 0.3, 0.3), Transparency = 1 }, 0.8)
		task.delay(0.85, function() if conn then conn:Disconnect() end; p:Destroy() end)
	end)
end

local function ghost(J, r, dur)
	local root = rootPart()
	local tpl = r.Item and RS.Animals:FindFirstChild(AnimalData.TemplateName(r.Item.Animal))
	if not root or not tpl then return end
	local g = tpl:Clone()
	for _, d in ipairs(g:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false
		elseif d:IsA("Humanoid") or d:IsA("LuaSourceContainer") then d:Destroy() end
	end
	local sc = AnimalData.Animals[r.Item.Animal] and AnimalData.Animals[r.Item.Animal].ShowcaseScale
	if sc then pcall(function() g:ScaleTo(sc) end) end
	local h = Instance.new("Highlight"); h.FillColor = tierColor(r.TierIndex); h.FillTransparency = 0.35; h.OutlineColor = WHITE; h.Parent = g
	local start = root.Position + Vector3.new(0, 60, 0)
	g:PivotTo(CFrame.new(start)); g.Parent = workspace; J:add(g)
	local t0 = os.clock()
	J:conn(RunService.RenderStepped:Connect(function()
		if not g.Parent or not root.Parent then return end
		local a = math.min(1, (os.clock() - t0) / dur)
		local e = 1 - (1 - a) ^ 3
		g:PivotTo(CFrame.new(start:Lerp(root.Position + Vector3.new(0, 4, 0), e)) * CFrame.Angles(0, a * math.pi * 4, 0))
		if a >= 1 then h.FillTransparency += 0.04; h.OutlineTransparency += 0.04; if h.FillTransparency >= 1 then g.Parent = nil end end
	end))
end

local function tag(J, r, color)
	local root = rootPart(); if not root then return end
	local bb = Instance.new("BillboardGui"); bb.Name = "CutsceneTag"; bb.Adornee = root; bb.Size = UDim2.fromOffset(380, 56)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 11, 0); bb.AlwaysOnTop = true; bb.LightInfluence = 0; bb.MaxDistance = 250
	local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 1); l.FontFace = UI.Theme.Fonts.Black; l.TextScaled = true
	l.Text = "// " .. r.Tier:upper() .. " //"; l.TextColor3 = color; l.TextTransparency = 1; l.Parent = bb
	local s = Instance.new("UIStroke"); s.Thickness = 2.5; s.Color = C(10, 8, 20); s.Parent = l
	bb.Parent = player:WaitForChild("PlayerGui"); J:add(bb)
	tw(l, { TextTransparency = 0 }, 0.4)
end

-- Anime Dice: Physical 3D Dice Throw & Shatter Reveal (1 die or 5 dice arc in front of player)
local function buildDiePart(dieCfg, tierCol)
	local p = Instance.new("Part")
	p.Name = "ThrownDie3D"
	p.Size = Vector3.new(2.3, 2.3, 2.3)
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = dieCfg.Mat or Enum.Material.Neon
	p.Color = dieCfg.Color
	local hl = Instance.new("Highlight")
	hl.FillColor = dieCfg.Color; hl.FillTransparency = 0.35; hl.OutlineColor = tierCol or dieCfg.Accent or WHITE; hl.OutlineTransparency = 0
	hl.Parent = p
	local pl = Instance.new("PointLight")
	pl.Color = tierCol or dieCfg.Color; pl.Range = 16; pl.Brightness = 2.8; pl.Parent = p
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 1.1, 0); a0.Parent = p
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -1.1, 0); a1.Parent = p
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0; tr.Attachment1 = a1
	tr.Color = dieCfg.Rainbow and RAINBOW or ColorSequence.new(dieCfg.Color, tierCol or dieCfg.Accent or WHITE)
	tr.LightEmission = 1; tr.Lifetime = 0.28; tr.WidthScale = NumberSequence.new(1, 0)
	tr.Transparency = NumberSequence.new(0.15, 1); tr.Parent = p
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = SPARK; sp.LightEmission = 1
	sp.Color = dieCfg.Rainbow and RAINBOW or ColorSequence.new(dieCfg.Color, tierCol or WHITE)
	sp.Rate = 32; sp.Size = NumberSequence.new(0.45, 0); sp.Speed = NumberRange.new(2, 6); sp.Lifetime = NumberRange.new(0.25, 0.5)
	sp.SpreadAngle = Vector2.new(180, 180); sp.Parent = p
	-- Glowing pips on faces
	for _, normal in ipairs(Enum.NormalId:GetEnumItems()) do
		local sg = Instance.new("SurfaceGui"); sg.Face = normal; sg.LightInfluence = 0; sg.AlwaysOnTop = false; sg.Parent = p
		local lbl = Instance.new("TextLabel"); lbl.BackgroundTransparency = 1; lbl.Size = UDim2.fromScale(1, 1)
		lbl.Font = Enum.Font.FredokaOne; lbl.TextScaled = true; lbl.Text = "✦"; lbl.TextColor3 = dieCfg.Accent or WHITE; lbl.Parent = sg
	end
	p.Parent = workspace
	return p
end

local function throwDice3D(batch)
	local root = rootPart()
	if not root then return end
	local dieKey = batch.Die or (State.Data and State.Data.EquippedDie) or "Wooden"
	local dieCfg = Config.Dice.Types[dieKey] or Config.Dice.Types.Wooden
	local count = batch.Multi and #batch.Results or 1
	local quick = batch.Results[1] and batch.Results[1].Quick
	local dur = quick and 0.34 or 0.56
	local J = Janitor.new()
	local dice = {}
	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector
	local startBase = root.Position + Vector3.new(0, 3.2, 0) + look * 2.5

	sfx(nil, "Whoosh", 0.55, quick and 1.3 or 1.08)
	sfx(nil, "Tick", 0.4, 1.4)

	for i = 1, count do
		local r = batch.Results[i]
		local tCol = tierColor(r and r.TierIndex or 1)
		local dPart = J:add(buildDiePart(dieCfg, tCol))
		local spread = (count == 1) and 0 or ((i - (count + 1) / 2) * 3.4)
		local targetPos = root.Position + look * (10.5 + math.abs(spread) * 0.25) + right * spread - Vector3.new(0, 1.2, 0)
		dice[i] = {
			part = dPart,
			p0 = startBase + right * (spread * 0.25),
			p1 = targetPos,
			col = tCol,
			tierIdx = r and r.TierIndex or 1,
			best = (i == batch.BestIndex),
			rx = math.random(10, 18) * (i % 2 == 0 and 1 or -1),
			ry = math.random(12, 20),
			rz = math.random(8, 16),
		}
	end

	local t0 = os.clock()
	local bounced = false
	while true do
		local elapsed = os.clock() - t0
		local a = math.min(1, elapsed / dur)
		-- 2-hop parabolic arc: main throw (0..0.72) + bounce hop (0.72..1.0)
		local hopY
		if a < 0.72 then
			local u = a / 0.72
			hopY = math.sin(u * math.pi) * 6.5
		else
			if not bounced then
				bounced = true
				sfx(nil, "Swish", 0.45, 1.35)
				sfx(nil, "Tick", 0.45, 1.65)
				for _, d in ipairs(dice) do
					shockwave(J, d.p1 - Vector3.new(0, 0.8, 0), d.col, d.best and 6.5 or 4.2, 0.32)
				end
			end
			local u = (a - 0.72) / 0.28
			hopY = math.sin(u * math.pi) * 2.4
		end
		for _, d in ipairs(dice) do
			local pos = d.p0:Lerp(d.p1, a) + Vector3.new(0, hopY, 0)
			d.part.CFrame = CFrame.new(pos) * CFrame.Angles(elapsed * d.rx, elapsed * d.ry, elapsed * d.rz)
		end
		if a >= 1 then break end
		task.wait()
	end

	-- Shatter burst on impact
	local bestD = dice[batch.BestIndex or 1] or dice[1]
	local shatterPitch = math.clamp(0.85 + (bestD.tierIdx or 1) * 0.035, 0.85, 1.75)
	sfx(nil, "Chime", 0.55, shatterPitch)
	sfx(nil, "Pop", 0.5, shatterPitch * 0.95)
	for _, d in ipairs(dice) do
		burstAt(J, d.p1, (d.tierIdx >= 25 or dieCfg.Rainbow) and RAINBOW or d.col, d.best and 42 or 20, d.best and 22 or 14)
		shockwave(J, d.p1 - Vector3.new(0, 0.8, 0), d.col, d.best and 14 or 8, 0.48)
		d.part.Transparency = 1
	end
	task.delay(0.55, function() J:clean() end)
end

-- World Power-Up VFX & multi-harmonic SFX for Rebirth, Dice Unlock, Skill Upgrade & Code Redemption
function Cut.PowerUpFX(payload)
	local col = (payload and payload.Color) or Config.UI.Gold
	local kind = (payload and payload.Kind) or "Skill"
	local J = Janitor.new()
	local root = rootPart()
	if kind == "Rebirth" then
		flash(0.55, col)
		sfx(nil, "Bass", 0.8, 0.65)
		sfx(nil, "Reveal", 0.65, 0.9)
		sfx(nil, "Hello", 0.6, 1.05)
		task.delay(0.15, function() sfx(nil, "Chime", 0.6, 1.35) end)
		ring(J, col, 680, 0.75, 7)
		ring(J, WHITE, 520, 0.55, 5)
		if root then
			Cut.SkyPillar(root.Position, col, 4.5, true)
			burstAt(J, root.Position, RAINBOW, 110, 26)
			shockwave(J, root.Position - Vector3.new(0, 2.5, 0), col, 44, 0.9)
		end
	elseif kind == "Die" or kind == "LuckySpin" then
		flash(0.32, col)
		sfx(nil, "Reveal", 0.55, 1.15)
		sfx(nil, "Chime", 0.55, 1.4)
		ring(J, col, 460, 0.5, 5)
		if root then
			burstAt(J, root.Position, col, 65, 20)
			shockwave(J, root.Position - Vector3.new(0, 2.5, 0), col, 26, 0.65)
		end
	else
		sfx(nil, "Chime", 0.5, 1.25)
		sfx(nil, "Pop", 0.45, 1.3)
		if root then
			burstAt(J, root.Position, col, 35, 15)
			shockwave(J, root.Position - Vector3.new(0, 2.5, 0), col, 16, 0.45)
		end
	end
	task.delay(1.5, function() J:clean() end)
end

------------------------------------------------------------------ cards
local function oddsLine(r)
	local dieCfg = r.Die and Config.Dice.Types[r.Die]
	local dieTag = (dieCfg and r.Die ~= "Wooden") and ("  •  " .. dieCfg.Icon .. " " .. dieCfg.Display) or ""
	return string.format("%s  •  %s%s%s%s%s%s", AnimalData.FormatRarity(r.Rarity), r.Tier, dieTag,
		r.Elixir and "  •  ELIXIR" or "",
		r.LuckySpin and "  •  <font color='#28D2FF'>🎰 LUCKY SPIN</font>" or "",
		r.Bonus and "  •  <font color='#FFD166'>★ BONUS</font>" or "",
		r.NewIndex and "  •  <font color='#78FFAA'>NEW!</font>" or "")
end

-- Tiers 1–3 (and anything below the player's cutscene threshold): instant card, no takeover
local function quickCard(r)
	local box = UI.Gui.RollReveal
	local col = tierColor(r.TierIndex)
	local grad = box.Stroke:FindFirstChildOfClass("UIGradient"); if grad then grad.Color = ColorSequence.new(col, col:Lerp(WHITE, 0.4)) end
	box.Visible = true
	box.AnimalName.Text = r.Name; box.AnimalName.TextColor3 = col
	if box:FindFirstChild("AccentBar") then box.AccentBar.BackgroundColor3 = col end
	box.Odds.Text = oddsLine(r)
	local sc = box:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", box)
	sc.Scale = 0.8; tw(sc, { Scale = 1 }, 0.18, Enum.EasingStyle.Back)
	sfx(nil, r.TierIndex <= 1 and "Tick" or "Pop", 0.45, 0.95 + math.min(0.6, r.TierIndex * 0.05))
	local token = os.clock(); box:SetAttribute("Token", token)
	task.delay(r.Quick and 0.75 or 1.2, function() if box:GetAttribute("Token") == token then box.Visible = false end end)
end

local function starOpen(J, r, col, rainbow, buildT)
	local st = UI.Gui.StarReveal
	J:add(function() st.Visible = false end)
	st.Visible = true; st.BackgroundTransparency = 1
	st.Tier.Text = "// " .. r.Tier:upper() .. " //"; st.Tier.TextColor3 = col; st.AnimalName.Text = ""; st.Odds.Text = ""
	st.Emblem.Grad.Color = rainbow and RAINBOW or ColorSequence.new(col:Lerp(WHITE, 0.5), col)
	tw(st, { BackgroundTransparency = 0.28 }, 0.3)
	st.Emblem.Size = UDim2.fromOffset(30, 30); st.Emblem.Rotation = 0
	tw(st.Emblem, { Size = UDim2.fromOffset(235, 235) }, math.max(0.3, buildT), Enum.EasingStyle.Back)
	-- Sol's RNG counter-rotating 8-point secondary star overlay + beat pulses
	local pulseRing = Instance.new("Frame"); pulseRing.AnchorPoint = Vector2.new(0.5, 0.5); pulseRing.Position = UDim2.fromScale(0.5, 0.5)
	pulseRing.Size = UDim2.fromOffset(90, 90); pulseRing.BackgroundTransparency = 1; pulseRing.Rotation = 45; pulseRing.Parent = st; J:add(pulseRing)
	local ps = Instance.new("UIStroke"); ps.Color = col; ps.Thickness = 3; ps.Transparency = 0.2; ps.Parent = pulseRing
	local t0 = os.clock()
	J:conn(RunService.RenderStepped:Connect(function(dt)
		st.Emblem.Rotation += dt * 175
		pulseRing.Rotation -= dt * 120
		local beat = 1 + math.sin((os.clock() - t0) * 14) * 0.12
		pulseRing.Size = UDim2.fromOffset(180 * beat, 180 * beat)
	end))
end
local function starReveal(r, col)
	local st = UI.Gui.StarReveal
	st.AnimalName.Text = r.Name; st.AnimalName.TextColor3 = col
	st.Odds.Text = oddsLine(r)
	local sc = st.AnimalName:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", st.AnimalName)
	sc.Scale = 1.3; tw(sc, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
end
local function quickInside(J, r, col)
	local box = UI.Gui.RollReveal
	J:add(function() box.Visible = false end)
	local grad = box.Stroke:FindFirstChildOfClass("UIGradient"); if grad then grad.Color = ColorSequence.new(col, col:Lerp(WHITE, 0.4)) end
	box.Visible = true; if box:FindFirstChild("AccentBar") then box.AccentBar.BackgroundColor3 = col end; box.AnimalName.Text = r.Name; box.AnimalName.TextColor3 = col; box.Odds.Text = oddsLine(r)
	local sc = box:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", box)
	sc.Scale = 0.6; tw(sc, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
end

------------------------------------------------------------------ generic profile runner (tiers 4–27)
local function outro(J, t)
	tw(fx.Vignette, { GroupTransparency = 1 }, t)
	if J.cc then tw(J.cc, { Contrast = 0, Saturation = 0, Brightness = 0, TintColor = WHITE }, t) end
	if J.blur then tw(J.blur, { Size = 0 }, t) end
	for _, l in ipairs(J.stars or {}) do tw(l, { TextTransparency = 1 }, t) end
	for _, s in ipairs(J.sounds) do if s.Parent then tw(s, { Volume = 0 }, t) end end
	if J.pillar then tw(J.pillar, { Size = Vector3.new(600, 0.3, 0.3), Transparency = 1 }, t) end
	tw(UI.Gui.StarReveal, { BackgroundTransparency = 1 }, t)
end

local function runProfile(r, P, J)
	local col = tierColor(r.TierIndex)
	local rainbow = r.TierIndex >= 25
	-- 1) ANTICIPATION
	if P.Vignette then vignette(J, P.Vignette, math.max(0.15, P.Build)) end
	if P.Grade then grade(J, P.Grade, col, P.Build) end
	if P.Blur then blur(J, P.Blur, P.Build) end
	if P.Zoom then zoom(J, P.Zoom, P.Build) end
	if P.Rift then rift(J, col, P.Build, rainbow) end
	if P.Stars then stars(J, P.Stars, col, rainbow) end
	if P.Tag then tag(J, r, col) end
	if P.Card == "star" then starOpen(J, r, col, rainbow, P.Build) end
	if P.Ghost then ghost(J, r, math.max(0.6, P.Build + 0.1)) end
	if P.BuildSfx then sfx(J, P.BuildSfx[1], P.BuildSfx[2], P.BuildSfx[3]) end
	for i = 1, P.Riser or 0 do
		task.delay((i - 1) * P.Build / P.Riser, function() if not J.dead then sfx(J, "Rise", 0.65, 0.7 + i * 0.18) end end)
	end
	if P.Build >= 1 then shake(J, (P.Shake or 0) * 0.2, P.Build) end
	J:wait(P.Build)
	-- 2) IMPACT
	flash(P.Flash, col:Lerp(WHITE, 0.5))
	riftCollapse(J)
	for i = 1, P.Rings or 0 do
		task.delay((i - 1) * 0.12, function() if not J.dead then ring(J, i % 2 == 0 and WHITE or col, 520 + i * 180, 0.55 + i * 0.1, 7 - i) end end)
	end
	for _, h in ipairs(P.Hit or {}) do sfx(J, h[1], h[2], h[3]) end
	shake(J, P.Shake, 0.45 + (P.Shake or 0) * 0.4)
	if P.Zoom then zoom(J, 0, 0.45, true) end
	if P.Blur then blur(J, 0, 0.2) end
	if P.Grade and J.cc then
		J.cc.Brightness = (P.Grade.Brightness or 0) + 0.18
		tw(J.cc, { Brightness = P.Grade.Brightness or 0 }, 0.5)
	end
	local root = rootPart()
	if root then
		local pos = root.Position
		if P.Shock then shockwave(J, pos - Vector3.new(0, 2.5, 0), col, P.Shock, 0.9) end
		for i = 1, P.Bursts or 0 do
			task.delay((i - 1) * 0.25, function() if not J.dead and root.Parent then burstAt(J, root.Position, rainbow and RAINBOW or col, P.Burst, 22 + i * 6) end end)
		end
		if P.Pillar then local pl, conn = makePillar(pos, col, rainbow); J.pillar = J:add(pl); if conn then J:conn(conn) end end
	end
	-- 3) REVEAL
	if P.Card == "star" then starReveal(r, col) else quickInside(J, r, col) end
	task.delay(0.25, function() if not J.dead then for _, t in ipairs(P.Tail or {}) do sfx(J, t[1], t[2], t[3]) end end end)
	J:wait(P.Hold)
	outro(J, 0.35)
	J:wait(0.35)
end

------------------------------------------------------------------ tier 28: Unattainable (double fake-out)
local function unattainable(r, J)
	local un = UI.Gui.Unattainable
	local title, sub = un.Title, un.Sub
	local basePos = title.Position
	J:add(function()
		un.Visible = false; un.BackgroundTransparency = 1; un.Flash.BackgroundTransparency = 1
		for _, n in { "GrailLineTop", "GrailLineBottom" } do local ln = un:FindFirstChild(n); if ln then ln.Visible = false end end
		title.Text = "UNATTAINABLE"; title.TextColor3 = WHITE; title.Rainbow.Enabled = true; title.Position = basePos; title.TextTransparency = 1; sub.TextTransparency = 1
	end)
	un.Visible = true; un.BackgroundTransparency = 1; title.TextTransparency = 1; sub.TextTransparency = 1; un.Flash.BackgroundTransparency = 1
	-- A) blackout + heartbeat
	vignette(J, 1, 1.2); blur(J, 10, 1.4); zoom(J, 18, 3.4)
	grade(J, { Contrast = 0.5, Saturation = -0.6, Brightness = -0.1 }, WHITE, 1.4)
	tw(un, { BackgroundTransparency = 0.3 }, 1.2)
	rift(J, WHITE, 1.6, true); stars(J, 16, WHITE, true); tag(J, r, WHITE)
	for i = 1, 3 do sfx(J, "Low", 0.65, 0.55 + i * 0.1); shake(J, 0.2 * i, 0.35); J:wait(0.42) end
	sfx(J, "Rise", 0.7, 0.8)
	J:wait(0.25)
	-- B) FAKE-OUT: appears to resolve as Primordial
	local fake = AnimalData.Tiers[TOP - 1]
	flash(0.55, fake.Color); ring(J, fake.Color, 700, 0.6, 6); riftCollapse(J)
	sfx(J, "Bass", 0.7, 0.8); shake(J, 0.7, 0.5)
	title.Rainbow.Enabled = false; title.TextColor3 = fake.Color; title.Text = fake.Name:upper(); title.TextTransparency = 0
	sub.Text = "..."; sub.TextTransparency = 0.2
	J:wait(0.75)
	-- C) glitch + second build
	sfx(J, "Rise", 0.75, 1.1); sfx(J, "Low", 0.5, 0.45)
	tw(un, { BackgroundTransparency = 0.04 }, 0.6)
	grade(J, { Contrast = 0.7, Saturation = -1, Brightness = -0.15 }, WHITE, 0.6)
	local g0 = os.clock()
	local glitch = J:conn(RunService.RenderStepped:Connect(function()
		local t = os.clock() - g0
		title.Position = basePos + UDim2.fromOffset(math.random(-14, 14) * t, math.random(-6, 6) * t)
		title.TextTransparency = math.random() < 0.25 + t * 0.5 and 1 or 0
		if math.random() < 0.2 then title.Text = (math.random() < 0.5) and fake.Name:upper() or "UNATTAINABLE" end
	end))
	shake(J, 0.5, 0.9)
	J:wait(0.9)
	glitch:Disconnect(); title.Position = basePos; title.TextTransparency = 1; sub.TextTransparency = 1
	J:wait(0.25)
	-- D) TRUE CLIMAX
	un.Flash.BackgroundTransparency = 0; tw(un.Flash, { BackgroundTransparency = 1 }, 1.4)
	title.Text = "UNATTAINABLE"; title.TextColor3 = WHITE; title.Rainbow.Enabled = true; title.TextTransparency = 0
	for _, n in { "GrailLineTop", "GrailLineBottom" } do local ln = un:FindFirstChild(n); if ln then ln.Visible = true; ln.BackgroundTransparency = 1; tw(ln, { BackgroundTransparency = 0 }, 0.6) end end
	title.Rainbow.Offset = Vector2.new(-1, 0); tw(title.Rainbow, { Offset = Vector2.new(1, 0) }, 4, Enum.EasingStyle.Linear)
	sub.Text = r.Name .. "  •  " .. AnimalData.FormatRarity(r.Rarity); tw(sub, { TextTransparency = 0 }, 0.6)
	sfx(J, "Bass", 0.85, 0.5); sfx(J, "Reveal", 0.5, 0.7); sfx(J, "Low", 0.45, 0.5)
	task.delay(0.18, function() if not J.dead then sfx(J, "Bass", 0.55, 0.72) end end)
	shake(J, 2, 1.4); zoom(J, 0, 0.6, true); blur(J, 0, 0.25)
	for i = 1, 4 do task.delay((i - 1) * 0.14, function() if not J.dead then ring(J, Color3.fromHSV(i / 4, 0.6, 1), 700 + i * 220, 0.8, 8 - i) end end) end
	local h = 0
	J:conn(RunService.RenderStepped:Connect(function(dt) h = (h + dt * 0.25) % 1; if J.cc then J.cc.TintColor = Color3.fromHSV(h, 0.25, 1) end end))
	grade(J, { Contrast = 0.35, Saturation = 0.5, Brightness = 0.05 }, WHITE, 0.4)
	local root = rootPart()
	if root then
		local pos = root.Position
		for i = 0, 2 do
			task.delay(i * 0.35, function()
				if J.dead or not root.Parent then return end
				burstAt(J, root.Position, RAINBOW, 160, 30 + i * 10)
				shockwave(J, root.Position - Vector3.new(0, 2.5, 0), Color3.fromHSV(i / 3, 0.7, 1), 90, 1.4)
			end)
		end
		local pl, conn = makePillar(pos, WHITE, true); J.pillar = J:add(pl); J:conn(conn)
		ghost(J, r, 2.2)
	end
	J:wait(2.3)
	tw(un, { BackgroundTransparency = 0.8 }, 0.8)
	J:wait(1.3)
	outro(J, 0.7); tw(title, { TextTransparency = 1 }, 0.7); tw(sub, { TextTransparency = 1 }, 0.7)
	J:wait(0.7)
end

------------------------------------------------------------------ runner + dispatch
local function run(fn, r)
	Cut.Abort()
	local J = Janitor.new(); active = J
	J:add(function()
		local cam = workspace.CurrentCamera
		if J.baseFov then cam.FieldOfView = J.baseFov end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid"); if hum then hum.CameraOffset = Vector3.zero end
		fx.Vignette.GroupTransparency = 1; fx.Flash.BackgroundTransparency = 1
	end)
	local ok, err = pcall(fn, r, J)
	if not ok and err ~= ABORT then warn("[Cutscene] " .. tostring(err)) end
	J:clean()
	if active == J then active = nil end
end

local function playOne(r)
	r.TierIndex = r.TierIndex or AnimalData.TierIndex(r.Rarity)
	local idx = r.TierIndex
	if idx >= TOP then run(unattainable, r)
	elseif idx <= 3 or idx < minTier() then quickCard(r)
	else local P = profileFor(idx); run(function(rr, J) runProfile(rr, P, J) end, r) end
end
Cut.PlayOne = playOne

-- Studio-only client preview (server hook / "/tier N" chat command use the real remotes instead)
function Cut.Preview(idx)
	if not RunService:IsStudio() then return end
	local t = AnimalData.Tiers[math.clamp(idx, 1, TOP)]
	playOne({ Name = "[Preview] " .. t.Name, Rarity = t.Min, Tier = t.Name, TierIndex = idx, Item = { Animal = "SolarEclipseDragon" }, Preview = true })
end

------------------------------------------------------------------ 5x strip
local function multiStrip(batch)
	local mr = UI.Gui.MultiReveal
	UI.Clear(mr)
	mr.Visible = true
	for i, r in ipairs(batch.Results) do
		local best = i == batch.BestIndex
		local col = tierColor(r.TierIndex or AnimalData.TierIndex(r.Rarity))
		local f = Instance.new("Frame"); f.LayoutOrder = i; f.Size = UDim2.fromOffset(best and 136 or 112, best and 116 or 96); f.ZIndex = 20
		UI.Glass(f, 14, col, col:Lerp(WHITE, 0.4))
		f.Fill.Color = ColorSequence.new(col:Lerp(C(20, 22, 48), best and 0.4 or 0.7), C(12, 14, 30)); f.Stroke.Thickness = best and 3.5 or 1.6
		local n = UI.Label(f, r.Name, UDim2.new(1, -12, 0, best and 52 or 44), UDim2.fromOffset(6, 8), 15, WHITE, UI.Display, { TextScaled = true, ZIndex = 21 })
		local cap = Instance.new("UITextSizeConstraint"); cap.MaxTextSize = best and 20 or 16; cap.Parent = n
		UI.Label(f, AnimalData.FormatRarityShort(r.Rarity), UDim2.new(1, -12, 0, 16), UDim2.new(0, 6, 1, -40), 12, C(210, 210, 235), Enum.Font.GothamBold, { ZIndex = 21 })
		UI.Label(f, (best and "★ BEST  " or "") .. r.Tier:upper() .. (r.Bonus and "  ★" or ""), UDim2.new(1, -12, 0, 16), UDim2.new(0, 6, 1, -22), 11, col, UI.Display, { ZIndex = 21 })
		local sc = Instance.new("UIScale"); sc.Scale = 0.2; sc.Parent = f
		f.Parent = mr
		task.delay(i * 0.07, function() tw(sc, { Scale = 1 }, 0.25, Enum.EasingStyle.Back); sfx(nil, "Tick", 0.4, 0.9 + i * 0.08) end)
	end
	local token = os.clock(); mr:SetAttribute("Token", token)
	task.delay(1.9, function() if mr:GetAttribute("Token") == token then mr.Visible = false; UI.Clear(mr) end end)
end

function Cut.PlayBatch(batch)
	State.CutsceneBusy = true
	local ok, err = pcall(function()
		for _, r in ipairs(batch.Results) do r.TierIndex = r.TierIndex or AnimalData.TierIndex(r.Rarity) end
		pcall(throwDice3D, batch)
		if batch.Multi then
			multiStrip(batch)
			local best = batch.Results[batch.BestIndex]
			if best.TierIndex >= TOP or (best.TierIndex >= 4 and best.TierIndex >= minTier()) then task.wait(0.9); playOne(best)
			else task.wait(0.6) end
		else
			playOne(batch.Results[1])
		end
	end)
	if not ok then warn("[Cutscene] " .. tostring(err)) end
	State.CutsceneBusy = false
	local vaulted, sold, coins = 0, 0, 0
	for _, r in ipairs(batch.Results) do
		if r.Status == "Vault" then vaulted += 1 elseif r.Status == "Sold" then sold += 1; coins += r.Coins end
		if r.Bonus then sfx(nil, "Hello", 0.5, 1.1) end
	end
	if vaulted > 0 then UI.Toast(string.format("Inventory full — %d rare pull%s saved to your Vault 📦", vaulted, vaulted == 1 and "" or "s"), Config.UI.Gold) end
	if sold > 0 then UI.Toast(string.format("Inventory full — auto-sold %d common%s for %s Coins", sold, sold == 1 and "" or "s", AnimalData.Comma(coins)), Config.UI.Muted) end
end

------------------------------------------------------------------ setup + server announcements
local function buildFX()
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("CutsceneFX"); if old then old:Destroy() end
	fx = Instance.new("ScreenGui"); fx.Name = "CutsceneFX"; fx.IgnoreGuiInset = true; fx.ResetOnSpawn = false; fx.DisplayOrder = -5
	local v = Instance.new("CanvasGroup"); v.Name = "Vignette"; v.Size = UDim2.fromScale(1, 1); v.BackgroundTransparency = 1; v.GroupTransparency = 1; v.Parent = fx
	for _, e in ipairs({ { UDim2.new(1, 0, 0.38, 0), UDim2.fromScale(0, 0), 90 }, { UDim2.new(1, 0, 0.38, 0), UDim2.fromScale(0, 0.62), 270 },
		{ UDim2.new(0.3, 0, 1, 0), UDim2.fromScale(0, 0), 0 }, { UDim2.new(0.3, 0, 1, 0), UDim2.fromScale(0.7, 0), 180 } }) do
		local f = Instance.new("Frame"); f.Size = e[1]; f.Position = e[2]; f.BackgroundColor3 = C(4, 2, 12); f.BorderSizePixel = 0; f.Parent = v
		local g = Instance.new("UIGradient"); g.Rotation = e[3]; g.Transparency = NumberSequence.new(0, 1); g.Parent = f
	end
	local fl = Instance.new("Frame"); fl.Name = "Flash"; fl.Size = UDim2.fromScale(1, 1); fl.BackgroundColor3 = WHITE; fl.BackgroundTransparency = 1; fl.BorderSizePixel = 0; fl.Parent = fx
	local ce = Instance.new("Frame"); ce.Name = "Center"; ce.Size = UDim2.fromScale(1, 1); ce.BackgroundTransparency = 1; ce.ClipsDescendants = true; ce.Parent = fx
	fx.Parent = pg
end

function Cut.Start()
	buildFX()
	-- long exact odds must shrink, never overflow
	for _, lbl in ipairs({ UI.Gui.StarReveal.Odds, UI.Gui.JackpotBanner.Text, UI.Gui.RollReveal.Odds }) do
		lbl.TextScaled = true; lbl.RichText = true
		if not lbl:FindFirstChildOfClass("UITextSizeConstraint") then local c = Instance.new("UITextSizeConstraint"); c.MaxTextSize = 20; c.Parent = lbl end
	end
	player.CharacterRemoving:Connect(Cut.Abort)
	-- VIP Admin cosmetic effects (server rate-limited). Heavy effects respect "Reduce other players' VFX"; shouts always show.
	Net.Get("SocialFX").OnClientEvent:Connect(function(fxp)
		local mine = fxp.UserId == player.UserId
		local reduce = (not mine) and settings().ReduceOthersFX
		if fxp.Kind == "Shout" then
			UI.Banner("📣 " .. fxp.Player .. ": " .. tostring(fxp.Text), C(140, 190, 255), 6); sfx(nil, "Chime", 0.5, 1); return
		end
		if fxp.Kind == "Confetti" then UI.Banner("🎊 " .. fxp.Player .. " threw confetti!", C(255, 140, 220), 4) end
		if reduce then return end
		local J = Janitor.new()
		if fxp.Kind == "Fireworks" then
			for i = 0, 4 do
				task.delay(i * 0.35, function()
					local pos = fxp.Position + Vector3.new(math.random(-12, 12), 28 + math.random(0, 14), math.random(-12, 12))
					burstAt(J, pos, Color3.fromHSV(math.random(), 0.7, 1), 90, 26); sfx(J, "Pop", 0.5, 0.7 + math.random() * 0.5)
				end)
			end
			task.delay(4, function() J:clean() end)
		elseif fxp.Kind == "Confetti" then
			local cam = workspace.CurrentCamera
			local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1; p.Size = Vector3.new(60, 1, 60); p.Parent = workspace; J:add(p)
			local e = Instance.new("ParticleEmitter"); e.Texture = SPARK; e.Color = RAINBOW; e.LightEmission = 0.6; e.Rate = 160; e.Speed = NumberRange.new(2, 6)
			e.Acceleration = Vector3.new(0, -12, 0); e.Lifetime = NumberRange.new(2.5, 3.5); e.Size = NumberSequence.new(0.5); e.RotSpeed = NumberRange.new(-200, 200)
			e.Shape = Enum.ParticleEmitterShape.Box; e.Parent = p
			J:conn(RunService.RenderStepped:Connect(function() p.Position = cam.CFrame.Position + Vector3.new(0, 22, 0) end))
			sfx(J, "Pop", 0.6, 1.2)
			task.delay(4, function() e.Enabled = false end)
			task.delay(8, function() J:clean() end)
		elseif fxp.Kind == "Spotlight" then
			local plr = Players:GetPlayerByUserId(fxp.UserId)
			local root = plr and plr.Character and plr.Character.PrimaryPart
			if root then
				local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, -2, 0); a0.Parent = root; J:add(a0)
				local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, 70, 0); a1.Parent = root; J:add(a1)
				local b = Instance.new("Beam"); b.Attachment0 = a0; b.Attachment1 = a1; b.Color = ColorSequence.new(C(255, 240, 200)); b.LightEmission = 1
				b.Width0 = 9; b.Width1 = 3; b.FaceCamera = true; b.Transparency = NumberSequence.new(0.35, 1); b.Parent = root; J:add(b)
				local l = Instance.new("SpotLight"); l.Face = Enum.NormalId.Bottom; l.Angle = 40; l.Range = 60; l.Brightness = 6; l.Color = C(255, 240, 200); l.Parent = root; J:add(l)
				sfx(J, "Reveal", 0.4, 1.1)
			end
			task.delay(10, function() J:clean() end)
		end
	end)
	Net.Get("Jackpot").OnClientEvent:Connect(function(j)
		local mine = j.UserId == player.UserId
		local reduce = (not mine) and settings().ReduceOthersFX
		local top = (j.TierIndex or 0) >= TOP
		if not mine and not reduce then
			Cut.SkyPillar(j.Position, j.TierColor, top and 12 or 7, (j.TierIndex or 0) >= 25)
			sfx(nil, "Bass", top and 0.7 or 0.5, top and 0.55 or 0.8)
			if top then flash(0.5, WHITE); sfx(nil, "Reveal", 0.4, 0.7) end
		end
		local jb = UI.Gui.JackpotBanner
		jb.Text.Text = string.format("%s %s ROLLED %s (%s)!", top and "🌈" or "✦", j.Player:upper(), j.Name:upper(), AnimalData.FormatRarity(j.Rarity))
		jb.Text.TextColor3 = j.TierColor
		jb.Visible = true
		local sc = jb:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", jb)
		sc.Scale = 0.6; tw(sc, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
		local token = os.clock(); jb:SetAttribute("Token", token)
		task.delay(top and 12 or 7, function() if jb:GetAttribute("Token") == token then jb.Visible = false end end)
	end)
end

return Cut
