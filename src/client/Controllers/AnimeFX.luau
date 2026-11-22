-- AnimeFX (V6): Cinematic anime SFX & 3D VFX engine built 100% on verified built-in Roblox Studio
-- sounds (Config.AnimeSounds), built-in particle textures (Config.BuiltinTextures), and native 3D primitives.
-- Inspired by The Strongest Battlegrounds, Jujutsu Shenanigans, and Sol's RNG.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local Config = require(RS.Modules.Config)

local AnimeFX = {}
local player = Players.LocalPlayer
local C = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local TEX = Config.BuiltinTextures
local SND = Config.AnimeSounds

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, C(255, 85, 110)),
	ColorSequenceKeypoint.new(0.25, C(255, 220, 80)),
	ColorSequenceKeypoint.new(0.5, C(80, 255, 175)),
	ColorSequenceKeypoint.new(0.75, C(85, 175, 255)),
	ColorSequenceKeypoint.new(1, C(225, 105, 255)),
})

local function tw(o, props, t, style, dir)
	local tween = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

------------------------------------------------------------------ DSP Audio Group
local animeGroup = SoundService:FindFirstChild("AnimalRNG_AnimeSFX")
if not animeGroup then
	animeGroup = Instance.new("SoundGroup")
	animeGroup.Name = "AnimalRNG_AnimeSFX"
	animeGroup.Volume = 1.0
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = 5.5; eq.MidGain = 1.0; eq.HighGain = 3.0; eq.Parent = animeGroup
	local rev = Instance.new("ReverbSoundEffect")
	rev.DecayTime = 1.45; rev.Density = 0.85; rev.Diffusion = 0.9; rev.DryLevel = 0; rev.WetLevel = -9; rev.Parent = animeGroup
	local comp = Instance.new("CompressorSoundEffect")
	comp.Threshold = -9; comp.Ratio = 3.5; comp.Attack = 0.008; comp.Release = 0.14; comp.Parent = animeGroup
	animeGroup.Parent = SoundService
end

local function playLayer(key, vol, pitch, opts)
	local id = SND[key]
	if not id then return nil end
	opts = opts or {}
	local s = Instance.new("Sound")
	s.Name = "AnimeSFX_" .. key
	s.SoundId = id
	s.Volume = math.clamp(vol or 0.65, 0, 1.15)
	s.PlaybackSpeed = pitch or 1
	s.SoundGroup = animeGroup
	if opts.distort and opts.distort > 0 then
		local d = Instance.new("DistortionSoundEffect")
		d.Level = math.clamp(opts.distort, 0, 0.85)
		d.Parent = s
	end
	if opts.lowBoost then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = opts.lowBoost; eq.MidGain = -2; eq.HighGain = 0; eq.Parent = s
	end
	if opts.timePos then s.TimePosition = opts.timePos end
	s.Parent = SoundService
	s:Play()
	if opts.endPitch and opts.sweepTime then
		tw(s, { PlaybackSpeed = opts.endPitch }, opts.sweepTime, Enum.EasingStyle.Expo, Enum.EasingDirection.Out)
	end
	if opts.fadeAfter and opts.fadeDur then
		task.delay(opts.fadeAfter, function()
			if s.Parent then tw(s, { Volume = 0 }, opts.fadeDur) end
		end)
	end
	s.Ended:Once(function() if s.Parent then s:Destroy() end end)
	Debris:AddItem(s, (opts.maxLife or 4.5))
	return s
end

-- Multi-layered built-in Roblox anime sound presets
function AnimeFX.SFX(preset, scale)
	local g = scale or 1
	if preset == "BlackFlash" then
		-- Iconic anime Black Flash: sharp distorted snap + electric crack + deep sub drop
		playLayer("Hit",     0.85 * g, 1.45, { distort = 0.45 })
		playLayer("Glass",   0.55 * g, 1.65)
		playLayer("Thunder", 0.72 * g, 1.35, { fadeAfter = 0.6, fadeDur = 0.6 })
		playLayer("Bass",    0.95 * g, 0.62, { endPitch = 0.28, sweepTime = 0.55, lowBoost = 7, distort = 0.25 })
	elseif preset == "SuperCrit" then
		playLayer("Hit",     0.95 * g, 1.25, { distort = 0.5 })
		playLayer("Glass",   0.75 * g, 1.4)
		playLayer("Thunder", 0.85 * g, 1.05)
		playLayer("Stinger", 0.70 * g, 1.15)
		playLayer("Bass",    1.00 * g, 0.52, { endPitch = 0.24, sweepTime = 0.75, lowBoost = 8, distort = 0.3 })
	elseif preset == "Breakthrough" then
		-- Ceiling shatter + sword unsheath + ascending chime
		playLayer("Glass",    0.78 * g, 1.22)
		playLayer("Unsheath", 0.72 * g, 1.32)
		playLayer("Boom",     0.65 * g, 0.82, { lowBoost = 5 })
		task.delay(0.08, function()
			playLayer("Stinger", 0.72 * g, 1.18)
			playLayer("Ping",    0.65 * g, 1.52)
		end)
	elseif preset == "DomainDrop" then
		-- Massive Domain Expansion bass drop + thunder + slash
		playLayer("Rumble",  0.85 * g, 0.72, { lowBoost = 6, fadeAfter = 1.6, fadeDur = 1.0 })
		playLayer("Bass",    1.00 * g, 0.95, { endPitch = 0.26, sweepTime = 0.9, lowBoost = 8, distort = 0.35 })
		playLayer("Thunder", 0.82 * g, 0.82)
		playLayer("Slash",   0.62 * g, 0.65)
		task.delay(0.12, function() playLayer("Stinger", 0.68 * g, 0.78) end)
	elseif preset == "AnimeSlash" then
		playLayer("Slash",  0.72 * g, 1.32)
		playLayer("Lunge",  0.58 * g, 1.12)
		playLayer("Whoosh", 0.42 * g, 1.65, { fadeAfter = 0.25, fadeDur = 0.25 })
	elseif preset == "TensionRiser" then
		playLayer("Launch", 0.55 * g, 0.58, { endPitch = 1.65, sweepTime = 1.35, fadeAfter = 1.1, fadeDur = 0.3 })
		playLayer("Wind",   0.45 * g, 1.05, { endPitch = 1.75, sweepTime = 1.35, fadeAfter = 1.1, fadeDur = 0.3 })
	elseif preset == "Heartbeat" then
		playLayer("Bass", 0.82 * g, 0.44, { lowBoost = 7 })
		task.delay(0.16, function() playLayer("Bass", 0.55 * g, 0.38, { lowBoost = 6 }) end)
	elseif preset == "OverdriveRoar" then
		playLayer("Rumble",   0.78 * g, 0.95, { fadeAfter = 1.1, fadeDur = 0.7 })
		playLayer("Thunder",  0.78 * g, 1.18)
		playLayer("Unsheath", 0.68 * g, 0.92)
		playLayer("Stinger",  0.72 * g, 1.08)
		playLayer("Bass",     0.90 * g, 0.75, { endPitch = 0.35, sweepTime = 0.6, lowBoost = 6 })
	elseif preset == "CraterImpact" then
		playLayer("Boom",   0.75 * g, 0.72, { lowBoost = 6, distort = 0.2 })
		playLayer("Land",   0.72 * g, 0.65)
		playLayer("Rumble", 0.55 * g, 0.85, { fadeAfter = 0.6, fadeDur = 0.5 })
	elseif preset == "BountyClear" then
		playLayer("Ping",     0.55 * g, 1.25)
		playLayer("Unsheath", 0.45 * g, 1.45)
		task.delay(0.09, function() playLayer("Ping", 0.62 * g, 1.58) end)
	end
end

------------------------------------------------------------------ 3D Ground Crater Boulders + Magma Fissures
-- Inspired by The Strongest Battlegrounds: raycasts real ground color/material and erupts a ring of tilted boulders.
function AnimeFX.Crater(pos, radius, count, accentCol, holdTime)
	radius = radius or 10
	count = math.clamp(count or 12, 6, 20)
	holdTime = holdTime or 1.4
	accentCol = accentCol or C(255, 165, 60)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ignore, p.Character) end end
	params.FilterDescendantsInstances = ignore

	local res = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -18, 0), params)
	local groundY = res and res.Position.Y or (pos.Y - 2.6)
	local groundMat = (res and res.Instance and res.Instance:IsA("BasePart")) and res.Instance.Material or Enum.Material.Slate
	local groundCol = (res and res.Instance and res.Instance:IsA("BasePart")) and res.Instance.Color or C(58, 62, 74)
	local center = Vector3.new(pos.X, groundY, pos.Z)

	local folder = Instance.new("Folder")
	folder.Name = "AnimeCraterFX"
	folder.Parent = workspace

	-- Radial dust & spark burst from center using built-in Roblox textures
	local dustPart = Instance.new("Part")
	dustPart.Anchored = true; dustPart.CanCollide = false; dustPart.CanQuery = false; dustPart.CanTouch = false
	dustPart.Transparency = 1; dustPart.Size = Vector3.new(radius * 0.8, 0.5, radius * 0.8)
	dustPart.Position = center + Vector3.new(0, 0.4, 0)
	dustPart.Parent = folder

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = TEX.Smoke
	dust.Color = ColorSequence.new(groundCol:Lerp(WHITE, 0.25), groundCol:Lerp(BLACK, 0.35))
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 1) })
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(0.5, 5.5), NumberSequenceKeypoint.new(1, 7.5) })
	dust.Speed = NumberRange.new(radius * 1.1, radius * 2.2)
	dust.SpreadAngle = Vector2.new(82, 82)
	dust.Lifetime = NumberRange.new(0.55, 1.05)
	dust.Drag = 4
	dust.Rate = 0
	dust.Parent = dustPart
	dust:Emit(math.min(32, count * 2))

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = TEX.FireSpark
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(accentCol, WHITE)
	sparks.Size = NumberSequence.new(0.7, 0)
	sparks.Speed = NumberRange.new(radius * 1.4, radius * 2.8)
	sparks.SpreadAngle = Vector2.new(75, 75)
	sparks.Acceleration = Vector3.new(0, -32, 0)
	sparks.Lifetime = NumberRange.new(0.4, 0.85)
	sparks.Rate = 0
	sparks.Parent = dustPart
	sparks:Emit(math.min(40, count * 3))

	-- Ring of tilted 3D boulders + glowing ground fissures
	for i = 1, count do
		local ang = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.22
		local r = radius * (0.82 + math.random() * 0.34)
		local p = Vector3.new(center.X + math.cos(ang) * r, groundY, center.Z + math.sin(ang) * r)
		local sz = Vector3.new(1.6 + math.random() * 1.8, 1.1 + math.random() * 1.4, 1.8 + math.random() * 2.2) * (radius / 10)
		local rock = Instance.new("Part")
		rock.Anchored = true; rock.CanCollide = false; rock.CanQuery = false; rock.CanTouch = false; rock.CastShadow = true
		rock.Material = groundMat
		rock.Color = groundCol:Lerp(BLACK, math.random() * 0.25)
		rock.Size = sz
		local targetCF = CFrame.lookAt(p + Vector3.new(0, sz.Y * 0.22, 0), center + Vector3.new(0, 1.8, 0))
			* CFrame.Angles(math.rad(math.random(22, 46)), math.rad(math.random(-18, 18)), math.rad(math.random(-14, 14)))
		rock.CFrame = targetCF - Vector3.new(0, sz.Y * 1.4, 0)
		rock.Parent = folder
		tw(rock, { CFrame = targetCF }, 0.14 + math.random() * 0.08, Enum.EasingStyle.Back)
		task.delay(holdTime + math.random() * 0.35, function()
			if rock.Parent then
				tw(rock, { CFrame = targetCF - Vector3.new(0, sz.Y * 1.6, 0), Transparency = 1 }, 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)

		-- Neon energy fissure radiating outward every other boulder
		if i % 2 == 0 then
			local crack = Instance.new("Part")
			crack.Anchored = true; crack.CanCollide = false; crack.CanQuery = false; crack.CanTouch = false; crack.CastShadow = false
			crack.Material = Enum.Material.Neon
			crack.Color = accentCol
			local len = radius * (0.75 + math.random() * 0.45)
			crack.Size = Vector3.new(0.26, 0.12, 0.5)
			local dirVec = Vector3.new(math.cos(ang), 0, math.sin(ang))
			crack.CFrame = CFrame.lookAt(center + dirVec * (len * 0.5) + Vector3.new(0, 0.08, 0), center + dirVec * (len + 2) + Vector3.new(0, 0.08, 0))
			crack.Parent = folder
			tw(crack, { Size = Vector3.new(0.32, 0.14, len) }, 0.16, Enum.EasingStyle.Quart)
			task.delay(holdTime * 0.75, function()
				if crack.Parent then tw(crack, { Transparency = 1, Size = Vector3.new(0.05, 0.05, len) }, 0.5) end
			end)
		end
	end

	Debris:AddItem(folder, holdTime + 1.2)
	return folder
end

------------------------------------------------------------------ Procedural 3D Jagged Anime Lightning
-- Multi-segment Attachment + Beam chain that jitters every frame; supports "Black Flash" dual-beam (dark core + bright outline).
function AnimeFX.LightningBolt(p0, p1, color, opts)
	opts = opts or {}
	local segs = opts.segments or 6
	local jitter = opts.jitter or 1.6
	local dur = opts.duration or 0.26
	local width = opts.width or 0.65
	local blackFlash = opts.blackFlash == true
	color = color or C(110, 210, 255)

	local holder = Instance.new("Part")
	holder.Name = "AnimeLightningBolt"
	holder.Anchored = true; holder.CanCollide = false; holder.CanQuery = false; holder.CanTouch = false
	holder.Transparency = 1; holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Position = (p0 + p1) * 0.5
	holder.Parent = workspace

	local atts = {}
	for i = 0, segs do
		local a = Instance.new("Attachment")
		a.Parent = holder
		atts[i + 1] = a
	end

	local beams = {}
	local function makeBeam(a0, a1, col, w, emit)
		local b = Instance.new("Beam")
		b.Attachment0 = a0; b.Attachment1 = a1
		b.Color = ColorSequence.new(col)
		b.LightEmission = emit
		b.FaceCamera = true
		b.Width0 = w; b.Width1 = w * 0.85
		b.Transparency = NumberSequence.new(0.05)
		b.Parent = holder
		table.insert(beams, { beam = b, baseW = w })
	end

	for i = 1, segs do
		makeBeam(atts[i], atts[i + 1], color, width, 1)
		if blackFlash then
			makeBeam(atts[i], atts[i + 1], C(10, 6, 14), width * 0.52, 0)
		end
	end

	local function refreshPoints()
		local dir = p1 - p0
		local len = dir.Magnitude
		if len < 0.01 then return end
		local cf = CFrame.lookAt(p0, p1)
		local right, up = cf.RightVector, cf.UpVector
		for i = 0, segs do
			local frac = i / segs
			local base = p0:Lerp(p1, frac)
			if i > 0 and i < segs then
				local env = math.sin(frac * math.pi)
				base += right * ((math.random() - 0.5) * 2 * jitter * env) + up * ((math.random() - 0.5) * 2 * jitter * env)
			end
			atts[i + 1].WorldPosition = base
		end
	end
	refreshPoints()

	local t0 = os.clock()
	local lastSnap = t0
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - t0
		if el >= dur or not holder.Parent then
			if conn then conn:Disconnect() end
			if holder.Parent then holder:Destroy() end
			return
		end
		if os.clock() - lastSnap >= 0.045 then
			lastSnap = os.clock()
			refreshPoints()
		end
		local alpha = el / dur
		for _, entry in ipairs(beams) do
			entry.beam.Transparency = NumberSequence.new(math.clamp(alpha * 1.15, 0, 1))
			entry.beam.Width0 = entry.baseW * (1 - alpha * 0.65)
			entry.beam.Width1 = entry.baseW * 0.8 * (1 - alpha * 0.65)
		end
	end)
	return holder
end

function AnimeFX.LightningBurst(center, radius, bolts, color, blackFlash, duration)
	radius = radius or 12
	bolts = math.clamp(bolts or 6, 2, 12)
	for i = 1, bolts do
		local theta = (i / bolts) * math.pi * 2 + math.random() * 0.5
		local elev = (math.random() - 0.25) * radius * 0.7
		local target = center + Vector3.new(math.cos(theta) * radius, elev, math.sin(theta) * radius)
		AnimeFX.LightningBolt(center, target, color, {
			segments = 6,
			jitter = radius * 0.16,
			duration = (duration or 0.28) + math.random() * 0.14,
			width = blackFlash and 0.9 or 0.65,
			blackFlash = blackFlash,
		})
	end
end

------------------------------------------------------------------ 3D Anime Energy Slash Waves
-- Expanding tilted 3D neon rings + built-in shockwave particles that cut through space at anime angles.
function AnimeFX.SlashWaves(center, color, count, radius)
	count = math.clamp(count or 3, 1, 6)
	radius = radius or 18
	for i = 1, count do
		task.delay((i - 1) * 0.06, function()
			local ring = Instance.new("Part")
			ring.Name = "AnimeSlashWave"
			ring.Anchored = true; ring.CanCollide = false; ring.CanQuery = false; ring.CanTouch = false; ring.CastShadow = false
			ring.Shape = Enum.PartType.Cylinder
			ring.Material = Enum.Material.Neon
			ring.Color = (i % 2 == 0) and color:Lerp(WHITE, 0.55) or color
			ring.Transparency = 0.12
			ring.Size = Vector3.new(0.22, 3, 3)
			local tilt = CFrame.Angles(math.rad(math.random(-55, 55)), math.rad(math.random(0, 180)), math.rad(90 + math.random(-35, 35)))
			ring.CFrame = CFrame.new(center) * tilt
			ring.Parent = workspace

			tw(ring, {
				Size = Vector3.new(0.08, radius * 2, radius * 2),
				Transparency = 1,
				CFrame = ring.CFrame * CFrame.Angles(0, math.rad(50), 0),
			}, 0.42 + i * 0.05, Enum.EasingStyle.Quart)
			Debris:AddItem(ring, 0.65)
		end)
	end
end

------------------------------------------------------------------ 3D Domain Expansion Energy Sphere
function AnimeFX.DomainSphere(J, center, color, maxRadius, duration, rainbow)
	maxRadius = maxRadius or 38
	duration = duration or 1.4

	local dome = Instance.new("Part")
	dome.Name = "AnimeDomainSphere"
	dome.Shape = Enum.PartType.Ball
	dome.Anchored = true; dome.CanCollide = false; dome.CanQuery = false; dome.CanTouch = false; dome.CastShadow = false
	dome.Material = Enum.Material.ForceField
	dome.Color = color
	dome.Transparency = 0.25
	dome.Size = Vector3.new(2, 2, 2)
	dome.Position = center
	dome.Parent = workspace
	if J then J:add(dome) else Debris:AddItem(dome, duration + 0.5) end

	local core = Instance.new("Part")
	core.Name = "AnimeDomainCore"
	core.Shape = Enum.PartType.Ball
	core.Anchored = true; core.CanCollide = false; core.CanQuery = false; core.CanTouch = false; core.CastShadow = false
	core.Material = Enum.Material.Neon
	core.Color = color:Lerp(WHITE, 0.4)
	core.Transparency = 0.45
	core.Size = Vector3.new(1.5, 1.5, 1.5)
	core.Position = center
	core.Parent = workspace
	if J then J:add(core) else Debris:AddItem(core, duration + 0.5) end

	local vortex = Instance.new("ParticleEmitter")
	vortex.Texture = TEX.Vortex
	vortex.LightEmission = 1
	vortex.Color = rainbow and RAINBOW or ColorSequence.new(color, WHITE)
	vortex.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(0.5, maxRadius * 0.42), NumberSequenceKeypoint.new(1, 0) })
	vortex.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	vortex.RotSpeed = NumberRange.new(140, 220)
	vortex.Lifetime = NumberRange.new(0.5, 0.85)
	vortex.Speed = NumberRange.new(0.5, 2)
	vortex.Rate = 0
	vortex.Parent = dome
	vortex:Emit(8)

	tw(dome, { Size = Vector3.new(maxRadius * 2, maxRadius * 2, maxRadius * 2), Transparency = 0.78 }, duration * 0.45, Enum.EasingStyle.Expo)
	tw(core, { Size = Vector3.new(maxRadius * 1.15, maxRadius * 1.15, maxRadius * 1.15), Transparency = 1 }, duration * 0.4, Enum.EasingStyle.Quart)

	if rainbow and J then
		local h = 0
		J:conn(RunService.RenderStepped:Connect(function(dt)
			if not dome.Parent then return end
			h = (h + dt * 0.45) % 1
			dome.Color = Color3.fromHSV(h, 0.75, 1)
		end))
	end

	task.delay(duration * 0.55, function()
		if dome.Parent then
			tw(dome, { Transparency = 1, Size = Vector3.new(maxRadius * 2.4, maxRadius * 2.4, maxRadius * 2.4) }, duration * 0.45)
		end
	end)
	return dome
end

------------------------------------------------------------------ Manga B&W Silhouette Impact Frame
-- Temporarily snaps world Lighting to high-contrast monochrome + pure white/black character silhouette Highlight.
function AnimeFX.MangaImpactFrame(J, accentColor, flashFrame)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "AnimeMangaImpactCC"
	cc.Saturation = -1
	cc.Contrast = 2.6
	cc.Brightness = -0.32
	cc.TintColor = WHITE
	cc.Parent = Lighting
	if J then J:add(cc) else Debris:AddItem(cc, 0.45) end

	local char = player.Character
	local hl
	if char then
		hl = Instance.new("Highlight")
		hl.Name = "AnimeImpactSilhouette"
		hl.FillColor = WHITE
		hl.FillTransparency = 0
		hl.OutlineColor = BLACK
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = char
		if J then J:add(hl) else Debris:AddItem(hl, 0.25) end
	end

	if flashFrame then
		flashFrame.BackgroundColor3 = BLACK
		flashFrame.BackgroundTransparency = 0.65
	end

	-- Frame 2 (55ms later): inverted white-hot flash + black silhouette
	task.delay(0.055, function()
		if J and J.dead then return end
		if cc.Parent then
			cc.Brightness = 0.45
			cc.Contrast = 3.0
		end
		if hl and hl.Parent then
			hl.FillColor = BLACK
			hl.OutlineColor = WHITE
		end
		if flashFrame then
			flashFrame.BackgroundColor3 = WHITE
			flashFrame.BackgroundTransparency = 0.15
		end
	end)

	-- Frame 3 (110ms later): chromatic anime burst back to full vivid color
	task.delay(0.115, function()
		if hl and hl.Parent then hl:Destroy() end
		if cc.Parent then
			cc.Saturation = 0.55
			cc.Contrast = 0.4
			cc.Brightness = 0.1
			cc.TintColor = WHITE:Lerp(accentColor or WHITE, 0.28)
			tw(cc, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = WHITE }, 0.35)
			Debris:AddItem(cc, 0.38)
		end
		if flashFrame then
			flashFrame.BackgroundColor3 = accentColor or WHITE
			flashFrame.BackgroundTransparency = 0.2
			tw(flashFrame, { BackgroundTransparency = 1 }, 0.42)
		end
	end)
end

------------------------------------------------------------------ Screen-Space Anime Speedlines
function AnimeFX.Speedlines(J, parent, color, duration, count)
	if not parent then return end
	count = math.clamp(count or 28, 12, 40)
	duration = duration or 1.0
	color = color or WHITE

	local holder = Instance.new("Frame")
	holder.Name = "AnimeSpeedlines"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ClipsDescendants = true
	holder.ZIndex = 2
	holder.Parent = parent
	if J then J:add(holder) else Debris:AddItem(holder, duration + 0.3) end

	local lines = {}
	for i = 1, count do
		local ang = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.08
		local deg = math.deg(ang)
		local ln = Instance.new("Frame")
		ln.AnchorPoint = Vector2.new(0.5, 0.5)
		ln.BorderSizePixel = 0
		ln.BackgroundColor3 = (i % 3 == 0) and WHITE or color
		ln.BackgroundTransparency = 0.18 + math.random() * 0.35
		local thickness = math.random(2, 5)
		local len = math.random(220, 420)
		ln.Size = UDim2.fromOffset(len, thickness)
		ln.Rotation = deg
		local dist = 0.48 + math.random() * 0.16
		ln.Position = UDim2.fromScale(0.5 + math.cos(ang) * dist, 0.5 + math.sin(ang) * dist)
		local grad = Instance.new("UIGradient")
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 0.1),
			NumberSequenceKeypoint.new(1, 0),
		})
		grad.Parent = ln
		ln.Parent = holder
		table.insert(lines, { frame = ln, ang = ang, baseDist = dist, baseLen = len, thick = thickness })
	end

	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - t0
		if el >= duration or not holder.Parent or (J and J.dead) then
			if conn then conn:Disconnect() end
			if holder.Parent then holder:Destroy() end
			return
		end
		local fade = (el > duration * 0.72) and ((el - duration * 0.72) / (duration * 0.28)) or 0
		for _, item in ipairs(lines) do
			local jitterDist = item.baseDist + (math.random() - 0.5) * 0.06
			item.frame.Position = UDim2.fromScale(0.5 + math.cos(item.ang) * jitterDist, 0.5 + math.sin(item.ang) * jitterDist)
			item.frame.BackgroundTransparency = math.clamp(0.2 + fade * 0.8 + math.random() * 0.18, 0, 1)
		end
	end)
	if J then J:conn(conn) end
	return holder
end

------------------------------------------------------------------ Overdrive 3D Character Aura (20s Fever Mode)
local overdriveCleanup
function AnimeFX.StartOverdriveAura(duration)
	if overdriveCleanup then overdriveCleanup() end
	duration = duration or Config.Overdrive.Duration
	local char = player.Character
	local root = char and char.PrimaryPart
	if not root then return end

	local items = {}
	local dead = false
	local function cleanup()
		if dead then return end
		dead = true
		for _, inst in ipairs(items) do if inst and inst.Parent then inst:Destroy() end end
		table.clear(items)
		overdriveCleanup = nil
	end
	overdriveCleanup = cleanup

	-- Blazing anime aura emitters on the character root
	local fire = Instance.new("ParticleEmitter")
	fire.Name = "OverdriveFlames"
	fire.Texture = TEX.FireSpark
	fire.LightEmission = 1
	fire.Color = ColorSequence.new(C(255, 190, 55), C(255, 65, 95))
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.6, 1.3), NumberSequenceKeypoint.new(1, 0) })
	fire.Rate = 42
	fire.Speed = NumberRange.new(6, 14)
	fire.SpreadAngle = Vector2.new(45, 45)
	fire.Lifetime = NumberRange.new(0.4, 0.8)
	fire.Parent = root
	table.insert(items, fire)

	local glow = Instance.new("ParticleEmitter")
	glow.Name = "OverdriveGlow"
	glow.Texture = TEX.Glow
	glow.LightEmission = 1
	glow.Color = ColorSequence.new(C(255, 215, 90), C(255, 75, 125))
	glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3.2), NumberSequenceKeypoint.new(1, 5.5) })
	glow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	glow.Rate = 10
	glow.Speed = NumberRange.new(1, 3)
	glow.Lifetime = NumberRange.new(0.45, 0.7)
	glow.Parent = root
	table.insert(items, glow)

	local hl = Instance.new("Highlight")
	hl.Name = "OverdriveHighlight"
	hl.FillColor = C(255, 140, 45)
	hl.FillTransparency = 0.72
	hl.OutlineColor = C(255, 225, 95)
	hl.OutlineTransparency = 0.05
	hl.Parent = char
	table.insert(items, hl)

	-- Opening burst: Domain roar + Crater + Lightning Burst + Slash Waves
	AnimeFX.SFX("OverdriveRoar", 1)
	AnimeFX.Crater(root.Position, 11, 12, C(255, 155, 50), 1.3)
	AnimeFX.LightningBurst(root.Position, 11, 6, C(255, 200, 65), true, 0.32)
	AnimeFX.SlashWaves(root.Position, C(255, 130, 50), 3, 16)

	-- Periodic Conqueror's lightning arcs crackling around the character while Overdrive is active
	task.spawn(function()
		local tEnd = os.clock() + duration
		while not dead and os.clock() < tEnd do
			task.wait(0.55 + math.random() * 0.45)
			if dead then break end
			local r = player.Character and player.Character.PrimaryPart
			if r then
				local p0 = r.Position + Vector3.new(math.random(-4, 4), math.random(-2, 4), math.random(-4, 4))
				local p1 = r.Position + Vector3.new(math.random(-6, 6), math.random(-1, 5), math.random(-6, 6))
				AnimeFX.LightningBolt(p0, p1, C(255, 195, 65), { segments = 5, jitter = 1.2, duration = 0.2, width = 0.45, blackFlash = true })
			end
		end
		cleanup()
	end)
end

return AnimeFX
