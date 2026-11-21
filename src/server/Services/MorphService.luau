-- MorphService: turns players into their equipped animal (with mutation VFX + scale), overhead tags, Elixir aura
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local AnimalData = require(RS.Modules.AnimalData)
local Config = require(RS.Modules.Config)

local MorphService = {}
local S
local Templates = RS:WaitForChild("Animals")
local C = Color3.fromRGB

function MorphService.Init(services) S = services end

local function emitter(parent, col, rate, size, speed, tex)
	local e = Instance.new("ParticleEmitter")
	e.Texture = tex or "rbxasset://textures/particles/sparkles_main.dds"; e.LightEmission = 1
	e.Color = ColorSequence.new(col); e.Rate = rate; e.Size = NumberSequence.new(size, 0)
	e.Speed = NumberRange.new(speed, speed * 2); e.SpreadAngle = Vector2.new(180, 180); e.Lifetime = NumberRange.new(0.5, 1.2)
	e.Parent = parent
	return e
end

local RAINBOW = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 90, 90)), ColorSequenceKeypoint.new(0.25, C(255, 220, 80)),
	ColorSequenceKeypoint.new(0.5, C(90, 255, 160)), ColorSequenceKeypoint.new(0.75, C(90, 160, 255)), ColorSequenceKeypoint.new(1, C(230, 110, 255)) })

local function glow(model, fill, outline, ft)
	local h = Instance.new("Highlight"); h.Name = "MutationGlow"; h.FillColor = fill; h.FillTransparency = ft or 0.75
	h.OutlineColor = outline or fill; h.DepthMode = Enum.HighlightDepthMode.Occluded; h.Parent = model
	return h
end
local function light(parent, col, range, br)
	local l = Instance.new("PointLight"); l.Color = col; l.Range = range; l.Brightness = br; l.Parent = parent
end
local function skyBeam(root, col, height, width)
	local a0 = Instance.new("Attachment"); a0.Name = "BeamBase"; a0.Parent = root
	local a1 = Instance.new("Attachment"); a1.Name = "BeamTop"; a1.Position = Vector3.new(0, height, 0); a1.Parent = root
	local beam = Instance.new("Beam"); beam.Name = "MutationBeam"; beam.Attachment0 = a0; beam.Attachment1 = a1
	beam.Color = typeof(col) == "ColorSequence" and col or ColorSequence.new(col); beam.LightEmission = 1; beam.FaceCamera = true
	beam.Width0 = width; beam.Width1 = 0.2; beam.Transparency = NumberSequence.new(0.3, 1); beam.Parent = root
end

-- visual overrides per mutation (8 tiers; Normal = untouched)
local MUTATION_FX = {
	Gilded = function(model, mesh, root)
		glow(model, C(255, 205, 80), C(255, 230, 140), 0.78)
		emitter(mesh, C(255, 220, 120), 10, 0.5, 2).Name = "GildedSparkle"
	end,
	Prismatic = function(model, mesh, root)
		glow(model, C(150, 230, 255), C(255, 160, 240), 0.8)
		local e = emitter(mesh, C(255, 255, 255), 22, 0.6, 3); e.Name = "PrismaticSparkle"; e.Color = RAINBOW
		light(mesh, C(200, 220, 255), 12, 1.5)
	end,
	Abyssal = function(model, mesh, root)
		glow(model, C(20, 14, 60), C(110, 90, 255), 0.45)
		local mist = emitter(mesh, C(60, 40, 150), 14, 1.6, 1); mist.Name = "AbyssalMist"; mist.LightEmission = 0.3
		light(mesh, C(110, 80, 255), 14, 2)
	end,
	Astral = function(model, mesh, root)
		glow(model, C(170, 200, 255), C(230, 240, 255), 0.7)
		local st = emitter(mesh, C(220, 230, 255), 26, 0.45, 1.5); st.Name = "AstralStars"; st.Lifetime = NumberRange.new(1, 2)
		light(mesh, C(170, 200, 255), 16, 2.2)
	end,
	ChronoShifted = function(model, mesh, root)
		glow(model, C(90, 255, 210), C(200, 255, 240), 0.72)
		mesh.Transparency = 0.12
		local sw = emitter(mesh, C(120, 255, 220), 30, 0.7, 4); sw.Name = "ChronoSwirl"
		sw.RotSpeed = NumberRange.new(-360, 360); sw.Rotation = NumberRange.new(0, 360); sw.Lifetime = NumberRange.new(0.3, 0.7)
		light(mesh, C(90, 255, 210), 16, 2.4)
	end,
	Sovereign = function(model, mesh, root)
		mesh.TextureID = ""; mesh.Color = C(255, 200, 80); mesh.Material = Enum.Material.Foil
		glow(model, C(255, 230, 150), C(255, 245, 200), 0.82)
		emitter(mesh, C(255, 225, 130), 34, 0.8, 3).Name = "SovereignAura"
		skyBeam(root, C(255, 225, 140), 32, 2.5)
		light(mesh, C(255, 220, 140), 20, 3)
	end,
	Singularity = function(model, mesh, root)
		mesh.TextureID = ""; mesh.Color = C(10, 8, 18); mesh.Material = Enum.Material.SmoothPlastic
		glow(model, C(255, 255, 255), C(255, 255, 255), 0.92)
		local e = emitter(mesh, C(255, 255, 255), 45, 1.1, 5); e.Name = "SingularityAura"; e.Color = RAINBOW
		local d = emitter(mesh, C(30, 10, 60), 20, 2, 0.5); d.Name = "SingularityVoid"; d.LightEmission = 0
		skyBeam(root, RAINBOW, 45, 3)
		light(mesh, C(255, 245, 255), 24, 3.5)
	end,
}

-- Ouroboros: 2.75x scale, rainbow sky beam, orbiting halo (attachments rotated client-side by AnimationController)
local function applyShowcase(model, scale)
	model:ScaleTo(model:GetScale() * scale)
	local root, mesh = model.PrimaryPart, model:FindFirstChild("AnimalMesh")
	local height = mesh and (mesh.Size.Y * 0.55) or 6
	local radius = mesh and (math.max(mesh.Size.X, mesh.Size.Z) * 0.75) or 8
	local halo = Instance.new("Folder"); halo.Name = "ShowcaseHalo"; halo.Parent = root
	local atts = {}
	for i = 1, 8 do
		local att = Instance.new("Attachment"); att.Name = "Halo" .. i
		local ang = (i - 1) / 8 * math.pi * 2
		att.Position = Vector3.new(math.cos(ang) * radius, height - root.Size.Y / 2, math.sin(ang) * radius)
		att:SetAttribute("Angle", ang); att.Parent = root
		local e = emitter(att, C(255, 255, 255), 12, 0.9, 0.6); e.Color = RAINBOW
		atts[i] = att
	end
	for i = 1, 8 do
		local beam = Instance.new("Beam"); beam.Attachment0 = atts[i]; beam.Attachment1 = atts[i % 8 + 1]
		beam.Color = RAINBOW; beam.LightEmission = 1; beam.FaceCamera = true; beam.Width0 = 0.6; beam.Width1 = 0.6
		beam.Transparency = NumberSequence.new(0.25); beam.Parent = halo
	end
	skyBeam(root, RAINBOW, 60, 4)
	light(root, C(255, 240, 200), 30, 3)
	model:SetAttribute("Showcase", true); model:SetAttribute("HaloRadius", radius); model:SetAttribute("HaloHeight", height - root.Size.Y / 2)
end

-- Sol's RNG-style Sacred Floor Sigil & Orbiting Energy Spheres for Tier 8+ (Exalted -> Unattainable)
local function applyTierSigil(model, item)
	local tierIdx = AnimalData.ItemTierIndex(item)
	if tierIdx < 8 then return end
	local root, mesh = model.PrimaryPart, model:FindFirstChild("AnimalMesh")
	if not root then return end
	local tier = AnimalData.Tiers[tierIdx]
	local col = tier.Color
	local rainbow = tierIdx >= 25 or item.Mutation == "Prismatic" or item.Mutation == "Singularity"
	local seq = rainbow and RAINBOW or ColorSequence.new(col, col:Lerp(Color3.new(1, 1, 1), 0.55))
	local floorY = -(root.Size.Y / 2) - ((model:FindFirstChildOfClass("Humanoid") and model:FindFirstChildOfClass("Humanoid").HipHeight or 2)) + 0.15
	local baseRadius = math.clamp((mesh and math.max(mesh.Size.X, mesh.Size.Z) or 6) * 0.65, 4.5, 16)
	local ringCount = (tierIdx >= 25 and 3) or (tierIdx >= 16 and 2) or 1
	local sigilFolder = Instance.new("Folder"); sigilFolder.Name = "SacredSigil"; sigilFolder.Parent = root

	for r = 1, ringCount do
		local rad = baseRadius * (0.7 + r * 0.35)
		local nodes = 6 + r * 2
		local ringAtts = {}
		for i = 1, nodes do
			local a = (i - 1) / nodes * math.pi * 2
			local att = Instance.new("Attachment"); att.Name = string.format("Sigil_%d_%d", r, i)
			att.Position = Vector3.new(math.cos(a) * rad, floorY, math.sin(a) * rad)
			att:SetAttribute("SigilRing", r)
			att:SetAttribute("SigilAngle", a)
			att:SetAttribute("SigilRadius", rad)
			att:SetAttribute("SigilY", floorY)
			att:SetAttribute("SigilSpeed", (r % 2 == 1 and 1 or -1) * (0.55 + r * 0.2))
			att.Parent = root
			if i % 2 == 1 then
				local sp = emitter(att, col, 4 + r * 2, 0.38, 1.2)
				sp.Color = seq
			end
			ringAtts[i] = att
		end
		-- Outer polygon ring beams
		for i = 1, nodes do
			local bm = Instance.new("Beam")
			bm.Name = "SigilRingBeam"
			bm.Attachment0 = ringAtts[i]
			bm.Attachment1 = ringAtts[i % nodes + 1]
			bm.Color = seq
			bm.LightEmission = 1
			bm.FaceCamera = false
			bm.Width0 = 0.35 + r * 0.08
			bm.Width1 = 0.35 + r * 0.08
			bm.Transparency = NumberSequence.new(0.15)
			bm.Parent = sigilFolder
		end
		-- Sacred geometry inner star chords for Tier 13+
		if tierIdx >= 13 and r == ringCount then
			local step = math.max(2, math.floor(nodes / 3))
			for i = 1, nodes do
				local bm = Instance.new("Beam")
				bm.Name = "SigilStarChord"
				bm.Attachment0 = ringAtts[i]
				bm.Attachment1 = ringAtts[(i + step - 1) % nodes + 1]
				bm.Color = seq
				bm.LightEmission = 1
				bm.Width0 = 0.22
				bm.Width1 = 0.22
				bm.Transparency = NumberSequence.new(0.32)
				bm.Parent = sigilFolder
			end
		end
	end

	-- Custom-rendered 512x512 Sacred Geometry Magic Circle & Arcane Rune Floor Plates (Uploaded via Open Cloud)
	if Config.VFXTextures then
		local plateAtt = Instance.new("Attachment"); plateAtt.Name = "SigilPlateAtt"; plateAtt.Position = Vector3.new(0, floorY + 0.05, 0); plateAtt.Parent = root
		local plate = Instance.new("Part"); plate.Name = "SigilPlate"; plate.Transparency = 1
		plate.Anchored = false; plate.CanCollide = false; plate.CanQuery = false; plate.CanTouch = false; plate.Massless = true
		local plateDia = baseRadius * (1.5 + ringCount * 0.45)
		plate.Size = Vector3.new(plateDia, 0.1, plateDia)
		plate.CFrame = root.CFrame * CFrame.new(0, floorY + 0.05, 0)
		local wc = Instance.new("WeldConstraint"); wc.Part0 = root; wc.Part1 = plate; wc.Parent = plate
		local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Top; sg.LightInfluence = 0; sg.Brightness = 3.2
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize; sg.CanvasSize = Vector2.new(512, 512); sg.Parent = plate
		local img1 = Instance.new("ImageLabel"); img1.Name = "OuterSigil"; img1.BackgroundTransparency = 1
		img1.Size = UDim2.fromScale(1, 1); img1.AnchorPoint = Vector2.new(0.5, 0.5); img1.Position = UDim2.fromScale(0.5, 0.5)
		img1.Image = Config.VFXTextures.SacredSigil; img1.ImageColor3 = col; img1.ImageTransparency = 0.1; img1.Parent = sg
		if tierIdx >= 13 then
			local img2 = Instance.new("ImageLabel"); img2.Name = "InnerRune"; img2.BackgroundTransparency = 1
			img2.Size = UDim2.fromScale(0.76, 0.76); img2.AnchorPoint = Vector2.new(0.5, 0.5); img2.Position = UDim2.fromScale(0.5, 0.5)
			img2.Image = Config.VFXTextures.ArcaneRune; img2.ImageColor3 = col:Lerp(Color3.new(1, 1, 1), 0.45); img2.ImageTransparency = 0.12; img2.Parent = sg
		end
		if tierIdx >= 20 then
			local img3 = Instance.new("ImageLabel"); img3.Name = "CoreStar"; img3.BackgroundTransparency = 1
			img3.Size = UDim2.fromScale(0.52, 0.52); img3.AnchorPoint = Vector2.new(0.5, 0.5); img3.Position = UDim2.fromScale(0.5, 0.5)
			img3.Image = Config.VFXTextures.Starburst; img3.ImageColor3 = Color3.new(1, 1, 1); img3.ImageTransparency = 0.18; img3.Parent = sg
		end
		plate.Parent = sigilFolder
	end

	model:SetAttribute("HasSigil", true)
end

local function applyMutation(model, item)
	local cfg = AnimalData.Animals[item.Animal]
	local tierIdx = AnimalData.ItemTierIndex(item)
	local scale = (cfg and cfg.ShowcaseScale) or (tierIdx >= 28 and 2.5) or (tierIdx >= 25 and 1.85) or nil
	if scale then applyShowcase(model, scale) end
	applyTierSigil(model, item)
	local mesh, root = model:FindFirstChild("AnimalMesh"), model.PrimaryPart
	local fx = MUTATION_FX[item.Mutation or "Normal"]
	if fx and mesh then fx(model, mesh, root) end
end

local function chip(parent, name, text, textColor, bg, stroke, height, order, font)
	local f = Instance.new("Frame"); f.Name = name; f.LayoutOrder = order; f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.new(0, 0, height, 0); f.BackgroundColor3 = bg or Color3.new(0, 0, 0); f.BackgroundTransparency = bg and 0.2 or 1
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f
	if stroke then local st = Instance.new("UIStroke"); st.Color = stroke; st.Thickness = 1.5; st.Transparency = 0.15; st.Parent = f end
	local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10); pad.Parent = f
	local l = Instance.new("TextLabel"); l.Name = "Label"; l.BackgroundTransparency = 1; l.AutomaticSize = Enum.AutomaticSize.X; l.Size = UDim2.fromScale(0, 1)
	l.Font = font or Enum.Font.GothamBold; l.TextScaled = true; l.RichText = true; l.Text = text; l.TextColor3 = textColor; l.Parent = f
	local ts = Instance.new("UITextSizeConstraint"); ts.MaxTextSize = 40; ts.Parent = l
	f.Parent = parent
	return f
end

local function fullTitle(player)
	local t = player:GetAttribute("Title") or ""
	local reb = player:GetAttribute("Rebirth") or 0
	if reb > 0 then
		local rTag = "🔱 Rebirth " .. reb
		return t ~= "" and (t .. "  •  " .. rTag) or rTag
	end
	return t
end

-- Overhead tag: [crown chip] / name / [tier chip]. Sized in studs so it shrinks with distance and never stacks on top of other tags.
local function makeTag(player, model, item)
	local head = model:FindFirstChild("Head"); if not head then return end
	local mesh = model:FindFirstChild("AnimalMesh")
	local topY = mesh and (mesh.Position.Y + mesh.Size.Y / 2) or (head.Position.Y + 1)
	local tag = Instance.new("BillboardGui"); tag.Name = "Tag"; tag.LightInfluence = 0; tag.MaxDistance = 70; tag.AlwaysOnTop = false
	tag.Size = UDim2.fromScale(7, 2.5); tag.SizeOffset = Vector2.new(0, 0.5)
	tag.StudsOffsetWorldSpace = Vector3.new(0, topY - head.Position.Y + 0.6, 0)
	local list = Instance.new("UIListLayout"); list.HorizontalAlignment = Enum.HorizontalAlignment.Center; list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder; list.Padding = UDim.new(0.04, 0); list.Parent = tag
	local title = fullTitle(player)
	local crown = chip(tag, "Title", title, C(40, 26, 6), C(255, 205, 90), C(255, 240, 180), 0.24, 1, Enum.Font.GothamBlack)
	crown.Visible = title ~= ""
	local name = chip(tag, "PlayerName", player.DisplayName, C(255, 255, 255), nil, nil, 0.3, 2, Enum.Font.GothamBlack)
	local ns = Instance.new("UIStroke"); ns.Thickness = 2; ns.Color = C(10, 12, 25); ns.Parent = name.Label
	local rarity = AnimalData.ItemRarity(item)
	local tier = AnimalData.TierFor(item)
	chip(tag, "AnimalLine", string.format("%s  <font color='#C8D2EB'>%s</font>", AnimalData.ItemName(item), AnimalData.FormatRarityShort(rarity)), tier.Color, C(15, 23, 42), tier.Color, 0.24, 3)
	tag.Parent = head
end

function MorphService.RefreshTitle(player)
	local char = player.Character
	local tag = char and char:FindFirstChild("Head") and char.Head:FindFirstChild("Tag")
	if tag and tag:FindFirstChild("Title") then
		local t = fullTitle(player)
		tag.Title.Label.Text = t; tag.Title.Visible = t ~= ""
	end
end

-- Slime RNG x Anime Dice: Spawn 3D active companion models inside char.Companions so AnimationController can bounce & follow smoothly
function MorphService.RefreshPack(player)
	local char = player.Character
	local root = char and char.PrimaryPart
	local data = S.DataService.Get(player)
	if not char or not root or not data then return end
	local old = char:FindFirstChild("Companions")
	if old then old:Destroy() end
	if not data.Pack or #data.Pack == 0 then return end
	local folder = Instance.new("Folder"); folder.Name = "Companions"; folder.Parent = char
	local offsets = {
		Vector3.new(-6.2, 0, 3.8),
		Vector3.new(6.2, 0, 3.8),
		Vector3.new(0, 0, 7.2),
	}
	for idx, itemId in ipairs(data.Pack) do
		if idx > Config.Pack.MaxCompanions then break end
		local it = S.DataService.FindItem(data, itemId)
		if it and it.Id ~= data.Equipped then
			local tpl = Templates:FindFirstChild(AnimalData.TemplateName(it.Animal)) or Templates:FindFirstChild("MeadowRabbit")
			if tpl then
				local comp = tpl:Clone()
				comp.Name = "Companion_" .. idx
				for _, d in ipairs(comp:GetDescendants()) do
					if d:IsA("Humanoid") or d:IsA("LuaSourceContainer") or d:IsA("WeldConstraint") then
						d:Destroy()
					elseif d:IsA("BasePart") then
						d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.Massless = true
					end
				end
				pcall(function() comp:ScaleTo(comp:GetScale() * 0.48) end)
				local mesh = comp:FindFirstChild("AnimalMesh")
				local fx = MUTATION_FX[it.Mutation or "Normal"]
				if fx and mesh and comp.PrimaryPart then pcall(fx, comp, mesh, comp.PrimaryPart) end
				local tier = AnimalData.TierFor(it)
				local cps = math.floor(Config.CompanionCPS(AnimalData.ItemRarity(it)) * S.DataService.CoinMult(data))
				if mesh then
					local bb = Instance.new("BillboardGui"); bb.Name = "PackTag"; bb.Size = UDim2.fromScale(4.5, 1.1); bb.MaxDistance = 45; bb.LightInfluence = 0
					bb.StudsOffsetWorldSpace = Vector3.new(0, mesh.Size.Y * 0.65 + 0.5, 0); bb.Parent = mesh
					local lbl = Instance.new("TextLabel"); lbl.BackgroundTransparency = 1; lbl.Size = UDim2.fromScale(1, 1); lbl.Font = Enum.Font.FredokaOne; lbl.TextScaled = true; lbl.RichText = true
					lbl.Text = string.format("%s\n<font color='#78FFAA'>+%s/s</font>", AnimalData.ItemName(it), AnimalData.FormatRarityShort(cps):gsub("^1 in ", ""))
					lbl.TextColor3 = tier.Color; lbl.Parent = bb
					local st = Instance.new("UIStroke"); st.Thickness = 1.8; st.Color = C(8, 10, 20); st.Parent = lbl
				end
				local off = offsets[idx] or Vector3.new((idx - 2) * 5, 0, 5)
				comp:SetAttribute("OffsetX", off.X)
				comp:SetAttribute("OffsetZ", off.Z)
				comp:SetAttribute("Phase", idx * 1.35)
				comp:PivotTo(root.CFrame * CFrame.new(off))
				comp.Parent = folder
			end
		end
	end
end

function MorphService.RefreshRelics(player)
	local char = player.Character
	local root = char and char.PrimaryPart
	local data = S.DataService.Get(player)
	if not char or not root or not data then return end
	local old = char:FindFirstChild("EquippedRelics3D")
	if old then old:Destroy() end
	local eq = data.EquippedRelics
	if not eq or not next(eq) then return end
	local folder = Instance.new("Folder"); folder.Name = "EquippedRelics3D"; folder.Parent = char
	local SS = game:GetService("ServerStorage")
	local assetLib = SS:FindFirstChild("AssetLibrary")
	local idx = 0
	for _, rKey in ipairs(Config.Relics and Config.Relics.Order or {}) do
		if eq[rKey] then
			idx += 1
			local cfg = Config.Relics.Types[rKey]
			if cfg then
				local p
				local tplModel = assetLib and cfg.MeshTemplate and assetLib:FindFirstChild(cfg.MeshTemplate)
				local tplMesh = tplModel and tplModel:FindFirstChildWhichIsA("MeshPart", true)
				if tplMesh then
					p = tplMesh:Clone()
					local maxSide = math.max(p.Size.X, p.Size.Y, p.Size.Z, 0.01)
					local targetSide = (cfg.Slot == "Halo" and 2.2) or (cfg.Slot == "Back" and 2.5) or 1.85
					p.Size = p.Size * (targetSide / maxSide)
					p.TextureID = ""
				else
					p = Instance.new("Part")
					p.Size = (cfg.Slot == "Halo" and Vector3.new(2.2, 0.45, 2.2)) or (cfg.Slot == "Back" and Vector3.new(1.8, 1.8, 1.8)) or Vector3.new(1.25, 1.25, 1.25)
					p.Shape = (cfg.Slot == "Back" and Enum.PartType.Ball) or Enum.PartType.Block
				end
				p.Name = "Relic_" .. rKey
				p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true
				p.Material = Enum.Material.Neon
				p.Color = cfg.Color
				local h = Instance.new("Highlight"); h.FillColor = cfg.Color; h.FillTransparency = 0.35; h.OutlineColor = Color3.new(1, 1, 1); h.Parent = p
				local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0.6, 0); a0.Parent = p
				local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -0.6, 0); a1.Parent = p
				local tr = Instance.new("Trail"); tr.Attachment0 = a0; tr.Attachment1 = a1; tr.Lifetime = 0.4
				tr.LightEmission = 1; tr.Color = cfg.Rainbow and RAINBOW or ColorSequence.new(cfg.Color, Color3.new(1, 1, 1))
				tr.Transparency = NumberSequence.new(0.1, 1); tr.WidthScale = NumberSequence.new(1, 0); tr.Parent = p
				local em = emitter(p, cfg.Color, 16, 0.55, 2.2)
				if cfg.Rainbow then em.Color = RAINBOW end
				light(p, cfg.Color, 12, 2.2)
				p:SetAttribute("RelicIndex", idx)
				p:SetAttribute("RelicSlot", cfg.Slot)
				p.CFrame = root.CFrame * CFrame.new(3.5, 2, 0)
				p.Parent = folder
			end
		end
	end
end

function MorphService.SetElixirAura(player, on)
	local char = player.Character
	local root = char and char.PrimaryPart
	if not root then return end
	local old = root:FindFirstChild("ElixirAura")
	if old then old:Destroy() end
	local oldH = char:FindFirstChild("ElixirHighlight"); if oldH then oldH:Destroy() end
	if on then
		local f = Instance.new("Folder"); f.Name = "ElixirAura"; f.Parent = root
		local e = emitter(root, C(255, 215, 90), 60, 1.4, 4); e.Parent = f
		local l = Instance.new("PointLight"); l.Color = C(255, 210, 100); l.Range = 26; l.Brightness = 4; l.Parent = f
		local h = Instance.new("Highlight"); h.Name = "ElixirHighlight"; h.FillColor = C(255, 210, 90); h.FillTransparency = 0.55; h.OutlineColor = C(255, 240, 170); h.Parent = char
	end
end

function MorphService.EquippedItem(player)
	local data = S.DataService.Get(player)
	if not data then return nil end
	return S.DataService.FindItem(data, data.Equipped) or data.Inventory[1]
end

local function rootOffset(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	return (hum and hum.HipHeight or 2) + model.PrimaryPart.Size.Y / 2
end

function MorphService.Spawn(player, keepPosition)
	if not player.Parent then return end
	local item = MorphService.EquippedItem(player); if not item then return end
	local template = Templates:FindFirstChild(AnimalData.TemplateName(item.Animal)) or Templates.MeadowRabbit
	local model = template:Clone()
	applyMutation(model, item)
	model.Name = player.Name
	local cfg = AnimalData.Animals[item.Animal]
	local hum = model:FindFirstChildOfClass("Humanoid")
	local showcase = cfg.ShowcaseScale ~= nil or (item.Tier or 1) >= 25
	hum.WalkSpeed = cfg.WalkSpeed
	hum.UseJumpPower = true; hum.JumpPower = showcase and 75 or 55
	model:SetAttribute("Animal", item.Animal); model:SetAttribute("Titan", showcase); model:SetAttribute("Mutation", item.Mutation); model:SetAttribute("Tier", item.Tier)
	model:SetAttribute("Ability", cfg.Ability); model:SetAttribute("ItemName", AnimalData.ItemName(item))
	local old = player.Character
	local cf
	if keepPosition and old and old.PrimaryPart then
		cf = old:GetPivot() + Vector3.new(0, rootOffset(model) - rootOffset(old) + 0.3, 0)
	else
		local spawn = workspace.Hub.SpawnPoint:GetAttribute("SpawnCFrame")
		cf = spawn + Vector3.new(math.random(-6, 6), rootOffset(model), math.random(-4, 4))
	end
	model:PivotTo(cf)
	model.Parent = workspace
	player.Character = model
	if old and old ~= model then old:Destroy() end
	pcall(function() model.PrimaryPart:SetNetworkOwner(player) end)
	makeTag(player, model, item)
	MorphService.RefreshPack(player)
	MorphService.RefreshRelics(player)
	local data = S.DataService.Get(player)
	if data and data.ElixirArmed then MorphService.SetElixirAura(player, true) end
	hum.Died:Connect(function()
		task.wait(2.5)
		if player.Parent and player.Character == model then MorphService.Spawn(player, false) end
	end)
	return model
end

function MorphService.Start()
	Players.PlayerAdded:Connect(function(p)
		p:GetAttributeChangedSignal("Title"):Connect(function() MorphService.RefreshTitle(p) end)
		p:GetAttributeChangedSignal("Rebirth"):Connect(function() MorphService.RefreshTitle(p) end)
	end)
	-- fall safety: anyone dropping into the ocean returns to spawn
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, p in ipairs(Players:GetPlayers()) do
				local r = p.Character and p.Character.PrimaryPart
				if r and r.Position.Y < -20 then
					local spawn = workspace.Hub.SpawnPoint:GetAttribute("SpawnCFrame")
					p.Character:PivotTo(spawn + Vector3.new(0, 3, 0)); r.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
end

return MorphService
