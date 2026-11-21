-- UIUtil: juicy button feedback, toasts, banners, floating text, sounds, glass cards
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Modules.Config)
local Theme = require(RS.Modules.UITheme)

local UI = {}
local player = Players.LocalPlayer
UI.Gui = player:WaitForChild("PlayerGui"):WaitForChild("RNGHud", 30)
local C = Color3.fromRGB
UI.Colors = Config.UI
UI.Theme = Theme
if UI.Gui then Theme.ApplyTree(UI.Gui); Theme.Watch(UI.Gui) end

function UI.Tween(obj, props, t, style) local tw = TweenService:Create(obj, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quad), props); tw:Play(); return tw end

-- Studio-grade DSP SoundGroups (UI + Cutscene)
local uiGroup = SoundService:FindFirstChild("AnimalRNG_UIGroup") or Instance.new("SoundGroup")
uiGroup.Name = "AnimalRNG_UIGroup"; uiGroup.Volume = 1; uiGroup.Parent = SoundService

local cutGroup = SoundService:FindFirstChild("AnimalRNG_CutsceneGroup") or Instance.new("SoundGroup")
cutGroup.Name = "AnimalRNG_CutsceneGroup"; cutGroup.Volume = 1.05; cutGroup.Parent = SoundService
if not cutGroup:FindFirstChildOfClass("ReverbSoundEffect") then
	local rev = Instance.new("ReverbSoundEffect"); rev.DecayTime = 1.65; rev.Density = 0.85; rev.Diffusion = 0.9; rev.DryLevel = 0; rev.WetLevel = -7; rev.Parent = cutGroup
	local eq = Instance.new("EqualizerSoundEffect"); eq.LowGain = 4.5; eq.MidGain = 0.5; eq.HighGain = 3.0; eq.Parent = cutGroup
	local comp = Instance.new("CompressorSoundEffect"); comp.Threshold = -8; comp.Ratio = 3; comp.Attack = 0.01; comp.Release = 0.15; comp.Parent = cutGroup
end
UI.CutsceneSoundGroup = cutGroup
UI.UISoundGroup = uiGroup

function UI.Sound(name, volume, pitch)
	local id = Config.Sounds[name]; if not id then return end
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume or 0.5; s.PlaybackSpeed = pitch or 1
	s.SoundGroup = (name == "Bass" or name == "Reveal" or name == "Rise" or name == "Hello" or name == "Low" or name == "Sweep") and cutGroup or uiGroup
	s.Parent = SoundService
	s:Play(); s.Ended:Connect(function() s:Destroy() end)
	task.delay(6, function() if s.Parent then s:Destroy() end end)
end

function UI.Juice(btn)
	if btn:GetAttribute("Juiced") then return end
	btn:SetAttribute("Juiced", true)
	local sc = btn:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", btn)
	local baseRot = btn.Rotation
	local isIcon = btn.Parent and btn.Parent.Name == "IconBar"
	btn.MouseEnter:Connect(function()
		UI.Tween(sc, { Scale = isIcon and 1.12 or 1.08 }, 0.15, Enum.EasingStyle.Back)
		if isIcon then UI.Tween(btn, { Rotation = baseRot - 5 }, 0.14, Enum.EasingStyle.Back) end
		UI.Sound("Tick", 0.25, 1.32)
	end)
	btn.MouseLeave:Connect(function()
		UI.Tween(sc, { Scale = 1 }, 0.15)
		if isIcon then UI.Tween(btn, { Rotation = baseRot }, 0.15, Enum.EasingStyle.Back) end
	end)
	btn.MouseButton1Down:Connect(function()
		UI.Tween(sc, { Scale = 0.9 }, 0.05)
		if isIcon then UI.Tween(btn, { Rotation = baseRot + 4 }, 0.05) end
	end)
	btn.MouseButton1Up:Connect(function()
		UI.Tween(sc, { Scale = isIcon and 1.12 or 1.08 }, 0.13, Enum.EasingStyle.Back)
		if isIcon then UI.Tween(btn, { Rotation = baseRot }, 0.13, Enum.EasingStyle.Back) end
	end)
	btn.Activated:Connect(function() UI.Sound("Click", 0.52, 1.04) end)
end

function UI.JuiceAll(root)
	for _, d in ipairs(root:GetDescendants()) do if d:IsA("GuiButton") and d:GetAttribute("Juicy") then UI.Juice(d) end end
end

UI.Display = Enum.Font.FredokaOne -- remapped to Fredoka/Montserrat Black by UITheme
function UI.Glass(f, radius, colA, colB)
	f.BackgroundColor3 = Color3.new(1, 1, 1); f.BackgroundTransparency = 0.04; f.BorderSizePixel = 0
	local fill = Instance.new("UIGradient"); fill.Name = "Fill"; fill.Rotation = 90
	fill.Color = Theme.GlassFill; fill.Parent = f
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, math.max(radius or 14, 10)); c.Parent = f
	local s = Instance.new("UIStroke"); s.Name = "Stroke"; s.Thickness = 3; s.Transparency = 0; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Color = colA and Color3.new(1, 1, 1) or Theme.Colors.BorderInner; s.Parent = f
	if colA then local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(colA, colB or colA); g.Rotation = 35; g.Parent = s end
	return f
end

function UI.FoilShimmer(card, color)
	card.ClipsDescendants = true
	local sh = Instance.new("Frame"); sh.Name = "FoilGleam"; sh.BackgroundColor3 = color or Color3.new(1, 1, 1)
	sh.BorderSizePixel = 0; sh.Size = UDim2.new(0.35, 0, 1.8, 0); sh.AnchorPoint = Vector2.new(0.5, 0.5)
	sh.Position = UDim2.fromScale(-0.4, 0.5); sh.Rotation = 24; sh.BackgroundTransparency = 0.35; sh.ZIndex = card.ZIndex + 3
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = sh; sh.Parent = card
	task.spawn(function()
		task.wait(math.random() * 2.5)
		while sh.Parent and card.Parent do
			sh.Position = UDim2.fromScale(-0.4, 0.5)
			UI.Tween(sh, { Position = UDim2.fromScale(1.4, 0.5) }, 1.15, Enum.EasingStyle.Sine)
			task.wait(3.2 + math.random() * 1.5)
		end
	end)
end

function UI.Label(parent, text, size, pos, tsize, color, font, props)
	local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Text = text; l.Size = size; l.Position = pos or UDim2.new()
	l.TextSize = tsize or 16; l.TextColor3 = color or Config.UI.Text; l.Font = font or Enum.Font.GothamBold; l.RichText = true; l.TextWrapped = true
	if props then for k, v in pairs(props) do l[k] = v end end
	l.Parent = parent
	return l
end

function UI.Button(parent, text, size, color, onClick, props)
	local b = Instance.new("TextButton"); b.Text = text; b.Size = size; b.BackgroundColor3 = color or Theme.Colors.CardHi; b.AutoButtonColor = false
	b.Font = Enum.Font.GothamBlack; b.TextSize = 16; b.TextColor3 = Config.UI.Text; b.TextWrapped = true; b.RichText = true
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = b
	local s = Instance.new("UIStroke"); s.Thickness = 3; s.Transparency = 0; s.Color = Theme.Colors.Outline; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = b
	local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(165, 172, 190)); g.Rotation = 90; g.Parent = b
	b.FontFace = Theme.Fonts.Black; b.TextSize = 16
	local ts = Instance.new("UIStroke"); ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; ts.Thickness = 2; ts.Color = Theme.Colors.Outline; ts.Transparency = 0; ts.Parent = b
	if props then for k, v in pairs(props) do b[k] = v end end
	b.Parent = parent
	UI.Juice(b)
	if onClick then b.Activated:Connect(onClick) end
	return b
end

function UI.Toast(text, color)
	local holder = UI.Gui.Toasts
	local items = {}
	for _, c in ipairs(holder:GetChildren()) do if c:IsA("TextLabel") then table.insert(items, c) end end
	if #items >= 4 then items[1]:Destroy() end
	local l = UI.Label(holder, text, UDim2.fromOffset(500, 38), nil, 18, color or Config.UI.Text, Enum.Font.FredokaOne, { LayoutOrder = math.floor(os.clock() * 100) })
	UI.Glass(l, 10)
	l.BackgroundTransparency = 1; l.TextTransparency = 1
	UI.Tween(l, { BackgroundTransparency = 0.2, TextTransparency = 0 }, 0.2)
	task.delay(3.2, function()
		if l.Parent then UI.Tween(l, { BackgroundTransparency = 1, TextTransparency = 1 }, 0.4); task.delay(0.45, function() l:Destroy() end) end
	end)
end

function UI.Banner(text, color, duration)
	local b = UI.Gui.TopCenter.EventBanner
	b.Text.Text = text; b.Text.TextColor3 = color or Config.UI.Gold
	b.Visible = true; b.Size = UDim2.fromOffset(600, 48)
	UI.Tween(b, { Size = UDim2.fromOffset(560, 40) }, 0.35, Enum.EasingStyle.Back)
	local token = os.clock(); b:SetAttribute("Token", token)
	task.delay(duration or 4, function() if b:GetAttribute("Token") == token then b.Visible = false end end)
end

function UI.Float(text, color)
	local char = player.Character
	local head = char and char:FindFirstChild("Head"); if not head then return end
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromOffset(200, 40); bb.AlwaysOnTop = true; bb.StudsOffset = Vector3.new(0, 3, 0); bb.Adornee = head
	local t = UI.Label(bb, text, UDim2.fromScale(1, 1), nil, 22, color, Enum.Font.GothamBlack, { TextScaled = true })
	local s = Instance.new("UIStroke"); s.Thickness = 2; s.Parent = t
	bb.Parent = UI.Gui
	UI.Tween(bb, { StudsOffset = Vector3.new(0, 6, 0) }, 1)
	UI.Tween(t, { TextTransparency = 1 }, 1)
	task.delay(1.05, function() bb:Destroy() end)
end

function UI.Clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
	end
end

return UI
