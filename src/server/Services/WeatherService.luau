-- WeatherService: Sunny / Blizzard / Volcanic Eruption / Solar Eclipse cycle with smooth lighting + material pickups
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Config = require(RS.Modules.Config)

local Weather = {}
local S
local C = Color3.fromRGB
local current = "Sunny"
local rng = Random.new()

local PRESETS = {
	Sunny    = { L = { ClockTime = 18.55, Brightness = 2.4, Ambient = C(64, 58, 92), OutdoorAmbient = C(118, 106, 150) },
		A = { Density = 0.3, Color = C(196, 150, 190), Decay = C(52, 40, 96), Haze = 1.6 }, CC = { TintColor = C(255, 236, 240), Saturation = 0.08, Brightness = 0 } },
	Blizzard = { L = { ClockTime = 13, Brightness = 2.2, Ambient = C(120, 135, 160), OutdoorAmbient = C(170, 185, 210) },
		A = { Density = 0.5, Color = C(225, 238, 255), Decay = C(170, 195, 235), Haze = 2.6 }, CC = { TintColor = C(225, 240, 255), Saturation = -0.05, Brightness = 0.04 } },
	Volcanic = { L = { ClockTime = 17.7, Brightness = 2.4, Ambient = C(120, 70, 60), OutdoorAmbient = C(170, 110, 90) },
		A = { Density = 0.42, Color = C(255, 150, 100), Decay = C(130, 40, 20), Haze = 2 }, CC = { TintColor = C(255, 214, 190), Saturation = 0.3, Brightness = 0 } },
	Eclipse  = { L = { ClockTime = 20.6, Brightness = 1.2, Ambient = C(80, 50, 120), OutdoorAmbient = C(100, 70, 150) },
		A = { Density = 0.36, Color = C(130, 90, 190), Decay = C(40, 20, 70), Haze = 1.6 }, CC = { TintColor = C(205, 175, 255), Saturation = 0.15, Brightness = -0.03 } },
}

function Weather.Init(services) S = services end
function Weather.Current() return current end
-- weather boosts: configured per-animal boosts + every registered creature whose Biome matches the current weather (x3)
function Weather.Boosts()
	local AD = require(game:GetService("ReplicatedStorage").Modules.AnimalData)
	local out = {}
	for k, v in pairs(Config.Weather.Types[current].Boost or {}) do out[k] = v end
	for name, a in pairs(AD.Animals) do
		if a.Biome == current and not a.Exclusive then out[name] = math.max(out[name] or 1, 3) end
	end
	return out
end

local function tween(obj, props, t) TweenService:Create(obj, TweenInfo.new(t or 5, Enum.EasingStyle.Sine), props):Play() end

local function applyLook(name, t)
	local p = PRESETS[name]
	tween(Lighting, p.L, t)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere"); if atm then tween(atm, p.A, t) end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect"); if cc then tween(cc, p.CC, t) end
	local fx = workspace.Hub.WeatherFX
	fx.Snow.FX.Enabled = name == "Blizzard"
	fx.Ash.FX.Enabled = name == "Volcanic"
	fx.Stardust.FX.Enabled = name == "Eclipse"
	for _, part in ipairs(fx.EclipseRing:GetChildren()) do
		tween(part, { Transparency = (name == "Eclipse") and (part.Name == "Disc" and 0 or 0.1) or 1 }, t)
	end
end

-- server-wide lighting/atmosphere shift for top-tier pulls; always tweens back to the current weather preset
function Weather.Spectacle(color, duration, heavy)
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if cc then tween(cc, { TintColor = heavy and Color3.fromRGB(120, 110, 150) or color:Lerp(Color3.new(1, 1, 1), 0.45), Contrast = 0.35, Brightness = heavy and -0.08 or 0.04 }, 0.8) end
	if atm then tween(atm, { Color = heavy and Color3.fromRGB(30, 20, 50) or color:Lerp(Color3.new(0, 0, 0), 0.3), Density = heavy and 0.5 or 0.38 }, 1) end
	tween(Lighting, { Brightness = heavy and 0.9 or 2.8 }, 1)
	task.delay(duration or 7, function()
		local p = PRESETS[current]
		if cc then tween(cc, { TintColor = p.CC.TintColor, Contrast = 0.22, Brightness = p.CC.Brightness }, 2) end
		if atm then tween(atm, p.A, 2) end
		tween(Lighting, { Brightness = p.L.Brightness }, 2)
	end)
end

-- brief server-wide sky tint (jackpots)
function Weather.Flash(color, duration)
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect"); if not cc then return end
	tween(cc, { TintColor = color:Lerp(Color3.new(1, 1, 1), 0.35), Brightness = 0.08 }, 0.6)
	task.delay(duration or 6, function() tween(cc, PRESETS[current].CC, 2) end)
end

local function clearPickups() workspace.Pickups:ClearAllChildren() end

local function spawnPickup()
	local mat = Config.Weather.Types[current].Material
	if not mat or #workspace.Pickups:GetChildren() >= Config.Weather.MaxPickups then return end
	for _ = 1, 8 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(40, 175)
		local origin = Vector3.new(math.cos(a) * r, 120, math.sin(a) * r)
		local hit = workspace:Raycast(origin, Vector3.new(0, -200, 0))
		if hit and hit.Instance:IsA("Terrain") and hit.Material ~= Enum.Material.Water then
			local info = Config.Materials[mat]
			local p = Instance.new("Part"); p.Name = mat; p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(2.2, 2.2, 2.2)
			p.Anchored = true; p.CanCollide = false; p.Material = Enum.Material.Neon; p.Color = info.Color
			p.Position = hit.Position + Vector3.new(0, 2.5, 0); p:SetAttribute("BasePos", p.Position); p:SetAttribute("Material", mat)
			local l = Instance.new("PointLight"); l.Color = info.Color; l.Range = 10; l.Brightness = 2; l.Parent = p
			local e = Instance.new("ParticleEmitter"); e.Texture = "rbxasset://textures/particles/sparkles_main.dds"; e.Color = ColorSequence.new(info.Color)
			e.LightEmission = 1; e.Rate = 8; e.Size = NumberSequence.new(0.5, 0); e.Speed = NumberRange.new(1, 3); e.SpreadAngle = Vector2.new(180, 180); e.Parent = p
			game:GetService("CollectionService"):AddTag(p, "Pickup")
			local taken = false
			p.Touched:Connect(function(hitPart)
				if taken then return end
				local model = hitPart:FindFirstAncestorOfClass("Model")
				local plr = model and Players:GetPlayerFromCharacter(model)
				local data = plr and S.DataService.Get(plr)
				if not data then return end
				taken = true
				local amount = (model:GetAttribute("Titan") and 2) or 1
				data.Materials[mat] = (data.Materials[mat] or 0) + amount
				S.DataService.Notify(plr, "Float", { Text = "+" .. amount .. " " .. info.Display, Color = info.Color })
				S.DataService.Sync(plr)
				p:Destroy()
			end)
			p.Parent = workspace.Pickups
			return
		end
	end
end

local function setWeather(name)
	current = name
	local dur = RS:GetAttribute("WeatherDurationOverride") or rng:NextInteger(Config.Weather.MinDuration, Config.Weather.MaxDuration)
	RS:SetAttribute("Weather", name)
	RS:SetAttribute("WeatherEndsAt", workspace:GetServerTimeNow() + dur)
	applyLook(name, 5)
	clearPickups()
	if name ~= "Sunny" then
		for _, p in ipairs(Players:GetPlayers()) do
			S.DataService.Notify(p, "Banner", { Text = Config.Weather.Types[name].Icon .. " " .. Config.Weather.Types[name].Display:upper() .. " HAS BEGUN!", Color = PRESETS[name].A.Color })
		end
	end
	return dur
end

local function nextWeather()
	if current ~= "Eclipse" and rng:NextNumber() < Config.Weather.EclipseChance then return "Eclipse" end
	local options = {}
	for _, n in ipairs(Config.Weather.Order) do if n ~= current then table.insert(options, n) end end
	return options[rng:NextInteger(1, #options)]
end

function Weather.Start()
	applyLook("Sunny", 0.1)
	local dur = setWeather("Sunny")
	local endsAt = os.clock() + dur
	local nextPickup = os.clock() + 5
	while true do
		task.wait(1)
		if os.clock() >= endsAt then endsAt = os.clock() + setWeather(nextWeather()) end
		if os.clock() >= nextPickup then nextPickup = os.clock() + Config.Weather.PickupInterval; spawnPickup() end
	end
end

-- Studio/admin helper: force a weather
function Weather.Force(name) if PRESETS[name] then setWeather(name) end end

return Weather
