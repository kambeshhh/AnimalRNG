-- AbilityController: E / mobile button, movement abilities (owner), FX for everyone, knockback
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Config = require(RS.Modules.Config)
local Net = require(RS.Modules.Net)
local UI = require(script.Parent.UIUtil)

local Ab = {}
local player = Players.LocalPlayer
local C = Color3.fromRGB
local dashUntil, dashDir = 0, Vector3.zero
local knockUntil, knockVel = 0, Vector3.zero
local COLORS = { Dash = C(255, 255, 255), Blink = C(255, 235, 80), FrostPulse = C(140, 220, 255), Slam = C(255, 120, 40), Beam = C(255, 170, 60) }

local function burst(pos, col, n)
	local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.Transparency = 1; p.Position = pos; p.Parent = workspace
	local e = Instance.new("ParticleEmitter"); e.Texture = "rbxasset://textures/particles/sparkles_main.dds"; e.Color = ColorSequence.new(col); e.LightEmission = 1
	e.Speed = NumberRange.new(14, 28); e.SpreadAngle = Vector2.new(180, 180); e.Lifetime = NumberRange.new(0.3, 0.6); e.Size = NumberSequence.new(1, 0); e.Rate = 0; e.Parent = p
	e:Emit(n or 30); Debris:AddItem(p, 1)
end
local function ring(pos, col, radius)
	local r = Instance.new("Part"); r.Anchored = true; r.CanCollide = false; r.CanQuery = false; r.Shape = Enum.PartType.Cylinder; r.Material = Enum.Material.Neon; r.Color = col
	r.Size = Vector3.new(0.5, 2, 2); r.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)); r.Parent = workspace
	UI.Tween(r, { Size = Vector3.new(0.5, radius * 2, radius * 2), Transparency = 1 }, 0.5)
	Debris:AddItem(r, 0.6)
end
local function beamFX(origin, look, range, width, col)
	local b = Instance.new("Part"); b.Anchored = true; b.CanCollide = false; b.CanQuery = false; b.Material = Enum.Material.Neon; b.Color = col; b.Transparency = 0.1
	b.Size = Vector3.new(width * 0.3, width * 0.3, range); b.CFrame = CFrame.lookAt(origin + look * range / 2 + Vector3.new(0, 2, 0), origin + look * range + Vector3.new(0, 2, 0)); b.Parent = workspace
	local l = Instance.new("PointLight"); l.Color = col; l.Range = 30; l.Brightness = 5; l.Parent = b
	UI.Tween(b, { Size = Vector3.new(width, width, range), Transparency = 1 }, 0.45)
	Debris:AddItem(b, 0.5)
end

local function myRoot() local c = player.Character; return c and c.PrimaryPart, c end

function Ab.Use()
	local _, char = myRoot(); if not char then return end
	if workspace:GetServerTimeNow() < (char:GetAttribute("AbilityReadyAt") or 0) - 0.05 then return end
	Net.Get("UseAbility"):FireServer()
end

function Ab.Start()
	UIS.InputBegan:Connect(function(input, gp)
		if not gp and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX) then Ab.Use() end
	end)
	UI.Gui.AbilityButton.Activated:Connect(Ab.Use)
	Net.Get("AbilityFX").OnClientEvent:Connect(function(who, ability, origin, look, scale)
		local col = COLORS[ability] or Color3.new(1, 1, 1)
		scale = scale or 1
		if ability == "Slam" then ring(origin - Vector3.new(0, 2, 0), col, Config.Abilities.Slam.Radius * scale); burst(origin, col, 50); UI.Sound("Bass", 0.6, 0.8)
		elseif ability == "FrostPulse" then ring(origin, col, Config.Abilities.FrostPulse.Radius * scale); burst(origin, col, 40)
		elseif ability == "Beam" then beamFX(origin, look, Config.Abilities.Beam.Range * scale, Config.Abilities.Beam.Width * scale, col); burst(origin, col, 40)
		else burst(origin, col, 24) end
		if who ~= player then return end
		local root, char = myRoot(); if not root then return end
		if ability == "Dash" then
			dashUntil = os.clock() + 0.25; dashDir = look
		elseif ability == "Blink" then
			local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = { char }
			local dist = Config.Abilities.Blink.Distance
			local hit = workspace:Raycast(root.Position, look * dist, params)
			local travel = hit and math.max(0, (hit.Position - root.Position).Magnitude - 3) or dist
			char:PivotTo(char:GetPivot() + look * travel)
			burst(root.Position, col, 30)
		elseif ability == "Beam" then
			local glow = Instance.new("PointLight"); glow.Color = col; glow.Range = 24; glow.Brightness = 6; glow.Parent = root
			Debris:AddItem(glow, 1.2)
		end
		UI.Sound("Whoosh", 0.6, 1)
		if ability == "Dash" or ability == "Blink" then UI.Sound("Chime", 0.4, 1.3) end
		if ability == "Slam" or ability == "Beam" or ability == "FrostPulse" then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				local t0, k = os.clock(), (ability == "Slam" and 0.9 or 0.6) * (scale or 1)
				local conn; conn = RunService.RenderStepped:Connect(function()
					local t = os.clock() - t0
					if t > 0.35 or not hum.Parent then hum.CameraOffset = Vector3.zero; conn:Disconnect(); return end
					local a = k * (1 - t / 0.35)
					hum.CameraOffset = Vector3.new(math.random(-100, 100) / 100 * a, math.random(-100, 100) / 100 * a, 0)
				end)
			end
		end
	end)
	Net.Get("Knockback").OnClientEvent:Connect(function(vel)
		knockUntil = os.clock() + 0.18; knockVel = vel
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum:ChangeState(Enum.HumanoidStateType.Freefall) end
		UI.Float("KNOCKED!", C(255, 120, 120))
	end)
	RunService.Stepped:Connect(function()
		local root = myRoot(); if not root then return end
		if os.clock() < dashUntil then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = dashDir * Config.Abilities.Dash.Speed + Vector3.new(0, math.max(v.Y, 0), 0)
		end
		if os.clock() < knockUntil then root.AssemblyLinearVelocity = knockVel end
	end)
	RunService.RenderStepped:Connect(function()
		local _, char = myRoot()
		local btn = UI.Gui.AbilityButton
		local ability = char and char:GetAttribute("Ability")
		local cfg = ability and Config.Abilities[ability]
		btn.AbilityName.Text = cfg and cfg.Display or "Ability"
		local left = char and ((char:GetAttribute("AbilityReadyAt") or 0) - workspace:GetServerTimeNow()) or 0
		if cfg and left > 0 then
			btn.CooldownFill.Size = UDim2.fromScale(1, math.clamp(left / cfg.Cooldown, 0, 1)); btn.CooldownText.Text = tostring(math.ceil(left)); btn.Key.Visible = false
		else
			btn.CooldownFill.Size = UDim2.fromScale(1, 0); btn.CooldownText.Text = ""; btn.Key.Visible = true
		end
	end)
end

return Ab
