-- StationService: station prompts (Altar / Totem / Forge / World2Portal) + procedural World 2 Astral Expanse Island
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local Config = require(RS.Modules.Config)

local StationService = {}
local S
local anchors = {}
local C = Color3.fromRGB

function StationService.Init(services) S = services end

function StationService.Near(player, station)
	local root = player.Character and player.Character.PrimaryPart
	local a = anchors[station]
	return root ~= nil and a ~= nil and (root.Position - a).Magnitude <= Config.StationRange
end

local function buildWorld2AndPortals()
	if workspace:FindFirstChild("World2") then return end
	local SS = game:GetService("ServerStorage")
	local assetLib = SS:FindFirstChild("AssetLibrary")

	local function spawnProp(parent, libName, cf, scale, neonCol)
		local tpl = assetLib and assetLib:FindFirstChild(libName)
		if not tpl then return nil end
		local clone = tpl:Clone()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				if neonCol then
					d.Material = Enum.Material.Neon
					d.Color = neonCol
					if d:IsA("MeshPart") then d.TextureID = "" end
				end
			end
		end
		if scale and scale ~= 1 then pcall(function() clone:ScaleTo(clone:GetScale() * scale) end) end
		clone:PivotTo(cf)
		clone.Parent = parent
		return clone
	end

	-- 1) WORLD 1 COSMIC PORTAL GATEWAY (North-East Sanctuary Plaza)
	local portalModel = Instance.new("Model"); portalModel.Name = "World2PortalGateway"
	local pPos = Vector3.new(82, 12, -82)
	local base = Instance.new("Part"); base.Name = "Pedestal"; base.Shape = Enum.PartType.Cylinder
	base.Anchored = true; base.Material = Enum.Material.SmoothPlastic; base.Color = C(24, 28, 52)
	base.Size = Vector3.new(2, 24, 24); base.CFrame = CFrame.new(pPos - Vector3.new(0, 9.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	base.Parent = portalModel

	-- Flanking 3D Greek Pillars & Glowing Crystal Clusters around the Portal Gateway
	spawnProp(portalModel, "Pillar", CFrame.new(pPos + Vector3.new(-9, -2, -5)), 0.85)
	spawnProp(portalModel, "Pillar", CFrame.new(pPos + Vector3.new(9, -2, 5)), 0.85)
	spawnProp(portalModel, "CrystalBlue", CFrame.new(pPos + Vector3.new(-10.5, -6.5, -2)), 2.2, C(34, 235, 255))
	spawnProp(portalModel, "CrystalBlue", CFrame.new(pPos + Vector3.new(10.5, -6.5, 2)), 2.2, C(210, 100, 255))
	spawnProp(portalModel, "Quartz", CFrame.new(pPos + Vector3.new(0, 11.5, 0)), 1.6, C(255, 210, 60))

	local ring = Instance.new("Part"); ring.Name = "OuroborosRing"; ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true; ring.CanCollide = false; ring.Material = Enum.Material.Neon; ring.Color = C(255, 205, 60)
	ring.Size = Vector3.new(1.5, 19, 19); ring.CFrame = CFrame.new(pPos) * CFrame.Angles(0, math.rad(45), 0)
	ring.Parent = portalModel

	local vortex = Instance.new("Part"); vortex.Name = "Vortex"; vortex.Shape = Enum.PartType.Cylinder
	vortex.Anchored = true; vortex.CanCollide = false; vortex.Material = Enum.Material.ForceField; vortex.Color = C(34, 235, 255)
	vortex.Transparency = 0.15; vortex.Size = Vector3.new(0.8, 16.5, 16.5); vortex.CFrame = ring.CFrame
	vortex.Parent = portalModel

	local pl = Instance.new("PointLight"); pl.Color = C(34, 235, 255); pl.Range = 36; pl.Brightness = 3.5; pl.Parent = vortex
	local em = Instance.new("ParticleEmitter"); em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	em.Color = ColorSequence.new(C(34, 235, 255), C(210, 110, 255)); em.LightEmission = 1; em.Rate = 38
	em.Size = NumberSequence.new(1.1, 0); em.Lifetime = NumberRange.new(1.2, 2.4); em.Speed = NumberRange.new(3, 8); em.SpreadAngle = Vector2.new(180, 180)
	em.Parent = vortex

	-- Sacred Sigil Texture on Portal Vortex & Pedestal
	if Config.VFXTextures then
		for _, face in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
			local sg = Instance.new("SurfaceGui"); sg.Face = face; sg.LightInfluence = 0; sg.Brightness = 3; sg.Parent = vortex
			local im = Instance.new("ImageLabel"); im.BackgroundTransparency = 1; im.Size = UDim2.fromScale(1, 1); im.Image = Config.VFXTextures.SacredSigil; im.ImageColor3 = C(34, 235, 255); im.Parent = sg
		end
	end

	-- Billboard overhead sign
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromOffset(320, 74); bb.StudsOffset = Vector3.new(0, 13, 0); bb.AlwaysOnTop = false; bb.MaxDistance = 160; bb.Parent = vortex
	local tl = Instance.new("TextLabel"); tl.BackgroundTransparency = 1; tl.Size = UDim2.fromScale(1, 1); tl.Font = Enum.Font.FredokaOne; tl.TextScaled = true; tl.RichText = true
	tl.Text = "🌌 WORLD 2: ASTRAL EXPANSE\n<font color='#FFD166' size='16'>Requires Rebirth 10  •  +200% Base Luck</font>"
	tl.TextColor3 = C(34, 235, 255); tl.Parent = bb
	local st = Instance.new("UIStroke"); st.Thickness = 2.5; st.Color = C(8, 10, 20); st.Parent = tl

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter World 2 (Rebirth 10)"
	prompt.ObjectText = "Cosmic Ouroboros Portal"
	prompt.MaxActivationDistance = 22
	prompt.HoldDuration = 0.25
	prompt.Parent = vortex
	prompt.Triggered:Connect(function(player)
		if S.Actions and S.Actions.TeleportWorld2 then S.Actions.TeleportWorld2(player) end
	end)
	portalModel.Parent = workspace.Hub

	-- 2) WORLD 2: THE ASTRAL EXPANSE (Floating Cosmic Island in the Sky with 3D Temple Pillars, Crystals & Trees)
	local w2 = Instance.new("Model"); w2.Name = "World2"
	local w2Center = Vector3.new(0, 520, -680)

	local island = Instance.new("Part"); island.Name = "AstralPlaza"; island.Shape = Enum.PartType.Cylinder
	island.Anchored = true; island.Material = Enum.Material.Glass; island.Color = C(18, 22, 54); island.Transparency = 0.08
	island.Size = Vector3.new(6, 175, 175); island.CFrame = CFrame.new(w2Center) * CFrame.Angles(0, 0, math.rad(90))
	island.Parent = w2

	local innerRing = Instance.new("Part"); innerRing.Name = "AstralCoreRing"; innerRing.Shape = Enum.PartType.Cylinder
	innerRing.Anchored = true; innerRing.Material = Enum.Material.Neon; innerRing.Color = C(34, 235, 255)
	innerRing.Size = Vector3.new(6.3, 62, 62); innerRing.CFrame = CFrame.new(w2Center) * CFrame.Angles(0, 0, math.rad(90))
	innerRing.Parent = w2

	-- Giant Sacred Sigil on World 2 Floor
	if Config.VFXTextures then
		local sigPlate = Instance.new("Part"); sigPlate.Name = "AstralFloorSigil"; sigPlate.Anchored = true; sigPlate.CanCollide = false; sigPlate.Transparency = 1
		sigPlate.Size = Vector3.new(95, 0.2, 95); sigPlate.CFrame = CFrame.new(w2Center + Vector3.new(0, 3.25, 0)); sigPlate.Parent = w2
		local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Top; sg.LightInfluence = 0; sg.Brightness = 3.5; sg.Parent = sigPlate
		local im = Instance.new("ImageLabel"); im.BackgroundTransparency = 1; im.Size = UDim2.fromScale(1, 1); im.Image = Config.VFXTextures.SacredSigil; im.ImageColor3 = C(34, 235, 255); im.Parent = sg
	end

	local w2Spawn = Instance.new("Part"); w2Spawn.Name = "World2Spawn"; w2Spawn.Anchored = true; w2Spawn.CanCollide = false; w2Spawn.Transparency = 1
	w2Spawn.Size = Vector3.new(8, 1, 8); w2Spawn.CFrame = CFrame.new(w2Center + Vector3.new(0, 5, 45))
	w2Spawn.Parent = w2

	-- 8 Real 3D Greek Pillars, Crystal Clusters & Floating Quartz around World 2 Island
	for i = 1, 8 do
		local ang = (i - 1) / 8 * math.pi * 2
		local rad = 74
		local mPos = w2Center + Vector3.new(math.cos(ang) * rad, 13, math.sin(ang) * rad)
		spawnProp(w2, "Pillar", CFrame.new(mPos), 1.05)
		spawnProp(w2, "CrystalBlue", CFrame.new(mPos + Vector3.new(0, -7, 0)) * CFrame.Angles(0, ang, 0), 2.5, (i % 2 == 0) and C(210, 100, 255) or C(34, 235, 255))
		local qPos = mPos + Vector3.new(0, 16, 0)
		local q = spawnProp(w2, "Quartz", CFrame.new(qPos), 1.8, (i % 2 == 0) and C(34, 235, 255) or C(255, 205, 60))
		if q and q.PrimaryPart then
			q.PrimaryPart:SetAttribute("BasePos", qPos)
			CS:AddTag(q.PrimaryPart, "Floater")
		end
	end

	-- Return Portal back to World 1
	local ret = Instance.new("Part"); ret.Name = "ReturnPortal"; ret.Shape = Enum.PartType.Ball
	ret.Anchored = true; ret.CanCollide = false; ret.Material = Enum.Material.Neon; ret.Color = C(255, 205, 60)
	ret.Size = Vector3.new(10, 10, 10); ret.Position = w2Center + Vector3.new(0, 8, 72)
	ret.Parent = w2
	local rbb = Instance.new("BillboardGui"); rbb.Size = UDim2.fromOffset(240, 50); rbb.StudsOffset = Vector3.new(0, 8, 0); rbb.Parent = ret
	local rtl = Instance.new("TextLabel"); rtl.BackgroundTransparency = 1; rtl.Size = UDim2.fromScale(1, 1); rtl.Font = Enum.Font.FredokaOne; rtl.TextScaled = true
	rtl.Text = "🌲 RETURN TO WORLD 1"; rtl.TextColor3 = C(255, 220, 90); rtl.Parent = rbb
	local rpr = Instance.new("ProximityPrompt"); rpr.ActionText = "Return to Sanctuary"; rpr.ObjectText = "World 1 Portal"; rpr.MaxActivationDistance = 20; rpr.Parent = ret
	rpr.Triggered:Connect(function(player)
		if player.Character and player.Character.PrimaryPart then
			local sp = workspace.Hub.SpawnPoint:GetAttribute("SpawnCFrame") or CFrame.new(0, 5, 90)
			player.Character:PivotTo(sp + Vector3.new(0, 4, 0))
			player:SetAttribute("InWorld2", false)
			S.DataService.Toast(player, "🌲 Returned to World 1: Forest Sanctuary", C(120, 255, 170))
		end
	end)

	w2.PrimaryPart = w2Spawn
	w2.Parent = workspace
end

function StationService.Start()
	pcall(buildWorld2AndPortals)
	for _, pr in ipairs(workspace.Hub:GetDescendants()) do
		if pr:IsA("ProximityPrompt") and pr:GetAttribute("Station") then
			local station = pr:GetAttribute("Station")
			anchors[station] = pr.Parent.Position
			pr.Triggered:Connect(function(player)
				S.DataService.Notify(player, "OpenStation", station)
			end)
		end
	end
end

return StationService
