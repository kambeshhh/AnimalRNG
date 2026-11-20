--!nocheck
-- Run in Studio (Edit, command bar / execute_luau) after inserting an uploaded creature model as
-- ServerStorage.Import_<Name>. Turns it into a ReplicatedStorage.Animals template built on the RedFox shell
-- (HumanoidRootPart + Humanoid + hidden Head + skinned AnimalMesh). The registry in AnimalData picks it
-- up automatically; the model attributes below override AnimalData's META defaults.
local RS, SS = game.ReplicatedStorage, game.ServerStorage
local base = RS.Animals.RedFox

-- name = { Group, longest side (studs), Display, Ability, WalkSpeed, Color, Biome? }
local SPEC = {
	-- WildBoar = { "Starter", 6.2, "Wild Boar", "Dash", 28, Color3.fromRGB(170, 120, 90) },
}
-- typical sizes: Starter 6.2 · Apex 7.2 · Mythical 8.6 · Cosmic 11 · Unattainable 8
local PHASE = { Leg_FL = 0, Leg_BR = 0, Leg_FR = 1, Leg_BL = 1, Arm_L = 1, Arm_R = 0 }

local function bone(mesh, n)
	for _, b in ipairs(mesh:GetDescendants()) do if b:IsA("Bone") and b.Name == n then return b end end
end

for name, s in pairs(SPEC) do
	local src = SS:FindFirstChild("Import_" .. name)
	if not src then warn(name .. ": missing Import_" .. name); continue end
	for _, n in ipairs({ "PackageLink", "InitialPoses", "AnimationController" }) do local o = src:FindFirstChild(n, true); if o then o:Destroy() end end
	for _, d in ipairs(src:GetDescendants()) do if d:IsA("LuaSourceContainer") then d:Destroy() end end -- imports must be script-free
	local mesh = src:FindFirstChildWhichIsA("MeshPart", true)
	src:ScaleTo(src:GetScale() * (s[2] / math.max(mesh.Size.X, mesh.Size.Y, mesh.Size.Z)))

	local old = RS.Animals:FindFirstChild(name); if old then old:Destroy() end
	local tpl = base:Clone(); tpl.Name = name
	tpl.AnimalMesh:Destroy()
	local root, hum = tpl.HumanoidRootPart, tpl:FindFirstChildOfClass("Humanoid")

	-- face -Z (Roblox forward); flip if the Head bone ended up behind the Root bone
	local function orient(dir) mesh.CFrame = CFrame.lookAt(Vector3.zero, dir) end
	orient(Vector3.new(0, 0, -1))
	local hb, rb = bone(mesh, "Head"), bone(mesh, "Root")
	if hb and rb and hb.WorldPosition.Z > rb.WorldPosition.Z then orient(Vector3.new(0, 0, 1)) end

	-- hidden collider + hip height so the mesh stands on the ground
	local sz = mesh.Size
	local rootSize = Vector3.new(math.clamp(sz.X * 0.4, 1.6, 5), math.clamp(sz.Y * 0.32, 1.4, 4.5), math.clamp(sz.Z * 0.5, 1.8, 7))
	root.Size = rootSize
	hum.HipHeight = math.max(0.6, sz.Y * 0.5 - rootSize.Y / 2 - 0.05)
	root.CFrame = CFrame.new(0, hum.HipHeight + rootSize.Y / 2, 0)
	mesh.CFrame = (mesh.CFrame - mesh.CFrame.Position) + Vector3.new(0, sz.Y / 2, 0)
	tpl.Head.CFrame = CFrame.new(0, sz.Y * 0.8, -sz.Z * 0.3)

	mesh.Name = "AnimalMesh"
	mesh.Anchored = false; mesh.CanCollide = false; mesh.CanTouch = false; mesh.CanQuery = false; mesh.Massless = true
	for _, wc in ipairs(mesh:GetChildren()) do if wc:IsA("WeldConstraint") then wc:Destroy() end end
	mesh.Parent = tpl
	local weld = Instance.new("WeldConstraint"); weld.Part0 = root; weld.Part1 = mesh; weld.Parent = mesh

	-- procedural animation tags read by AnimationController
	for _, b in ipairs(mesh:GetDescendants()) do
		if b:IsA("Bone") then
			if PHASE[b.Name] ~= nil then b:SetAttribute("Phase", PHASE[b.Name]) end
			if b.Name == "Tail1" then b:SetAttribute("Wag", true) end
			if b.Name == "Wing_L" or b.Name == "Wing_R" then b:SetAttribute("Flap", true) end
		end
	end

	tpl:SetAttribute("Group", s[1]); tpl:SetAttribute("Weight", 1)
	tpl:SetAttribute("Display", s[3]); tpl:SetAttribute("Ability", s[4]); tpl:SetAttribute("WalkSpeed", s[5]); tpl:SetAttribute("Color", s[6])
	if s[7] then tpl:SetAttribute("Biome", s[7]) end
	tpl.PrimaryPart = root
	tpl.Parent = RS.Animals
	src:Destroy()
	print("built", name)
end
