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

local function applyMutation(model, item)
	local cfg = AnimalData.Animals[item.Animal]
	if cfg and cfg.ShowcaseScale then applyShowcase(model, cfg.ShowcaseScale) end
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

-- Overhead tag: [crown chip] / name / [tier chip]. Sized in studs so it shrinks with distance and never stacks on top of other tags.
local function makeTag(player, model, item)
	local head = model:FindFirstChild("Head"); if not head then return end
	local mesh = model:FindFirstChild("AnimalMesh")
	local root = model.PrimaryPart
	local topY = mesh and (mesh.Position.Y + mesh.Size.Y / 2) or (head.Position.Y + 1)
	local tag = Instance.new("BillboardGui"); tag.Name = "Tag"; tag.LightInfluence = 0; tag.MaxDistance = 70; tag.AlwaysOnTop = false
	tag.Size = UDim2.fromScale(7, 2.5); tag.SizeOffset = Vector2.new(0, 0.5)
	tag.StudsOffsetWorldSpace = Vector3.new(0, topY - head.Position.Y + 0.6, 0)
	local list = Instance.new("UIListLayout"); list.HorizontalAlignment = Enum.HorizontalAlignment.Center; list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder; list.Padding = UDim.new(0.04, 0); list.Parent = tag
	local title = player:GetAttribute("Title") or ""
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
		local t = player:GetAttribute("Title") or ""
		tag.Title.Label.Text = t; tag.Title.Visible = t ~= ""
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
	local showcase = cfg.ShowcaseScale ~= nil
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
