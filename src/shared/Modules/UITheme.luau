-- UITheme v5 "Hand-Crafted Studio Mix":
-- Fuses Sol's RNG Eon 1 & Fisch (matte charcoal-slate surfaces, crisp 1.5px hairline borders, clean Sarpanch/Montserrat/Fredoka hierarchy)
-- with PETS GO! (tactile solid-bevel Roll buttons, high-contrast badges, zero rainbow-gradient AI slop).
local C = Color3.fromRGB
local T = {}

T.Colors = {
	Obsidian = C(11, 13, 18),     -- Deep matte charcoal
	Panel    = C(16, 18, 25),     -- Sol's RNG / Fisch matte dark slate panel
	Card     = C(22, 25, 34),     -- Clean dark card surface
	CardHi   = C(30, 34, 46),     -- Elevated card / button surface
	Outline  = C(8, 9, 13),       -- Crisp dark ink outline
	BorderInner  = C(48, 54, 72), -- Subtle 1.5px slate hairline border
	BorderStrong = C(95, 108, 140),
	Text          = C(244, 246, 252),
	TextSecondary = C(195, 204, 224),
	TextMuted     = C(132, 142, 168),
	Cyan    = C(78, 205, 245),
	Gold    = C(246, 208, 78),
	Magenta = C(236, 105, 195),
	Vip     = C(184, 132, 248),
	Green   = C(62, 218, 132),
	Success = C(62, 218, 132),
	Warn    = C(245, 172, 56),
	Danger  = C(235, 72, 88),
}
local K = T.Colors

local MONT = "rbxasset://fonts/families/Montserrat.json"
local function safeFont(enumItem, weight)
	local ok, f = pcall(function()
		local base = Font.fromEnum(enumItem)
		return weight and Font.new(base.Family, weight) or base
	end)
	return (ok and f) or Font.new(MONT, weight or Enum.FontWeight.Black)
end
local FRED = safeFont(Enum.Font.FredokaOne, nil)
local SARP = safeFont(Enum.Font.Sarpanch, Enum.FontWeight.ExtraBold)
local MONO = safeFont(Enum.Font.RobotoMono, Enum.FontWeight.Bold)

T.Fonts = {
	Black    = Font.new(MONT, Enum.FontWeight.Black),
	Bold     = Font.new(MONT, Enum.FontWeight.Bold),
	SemiBold = Font.new(MONT, Enum.FontWeight.SemiBold),
	Medium   = Font.new(MONT, Enum.FontWeight.Medium),
	Input    = Font.new(MONT, Enum.FontWeight.SemiBold),
	Display  = SARP,
	Mono     = MONO,
	Rounded  = FRED,
}

-- Subtle matte slate vertical sheen (no rainbow/neon overload)
T.GlassFill = ColorSequence.new({
	ColorSequenceKeypoint.new(0, C(26, 30, 42)),
	ColorSequenceKeypoint.new(1, C(15, 17, 24)),
})
T.TileFill = ColorSequence.new(C(32, 37, 52), C(19, 22, 31))
T.GrailGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, C(110, 125, 165)),
	ColorSequenceKeypoint.new(0.5, C(210, 220, 245)),
	ColorSequenceKeypoint.new(1, C(85, 98, 132)),
})

local function close(a, b) return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.06 end
T.BgRemap = {
	{ C(7, 8, 12), K.Obsidian }, { C(14, 17, 25), K.Panel }, { C(21, 26, 38), K.Card }, { C(28, 35, 51), K.CardHi },
	{ C(40, 50, 74), K.CardHi }, { C(24, 30, 44), K.Card }, { C(44, 56, 84), K.CardHi }, { C(59, 71, 102), K.CardHi },
	{ C(9, 12, 26), K.Obsidian }, { C(12, 15, 32), K.Panel }, { C(15, 23, 42), K.Panel }, { C(20, 16, 44), K.Obsidian },
	{ C(30, 41, 69), K.CardHi }, { C(24, 28, 58), K.Card }, { C(44, 62, 108), K.CardHi }, { C(52, 60, 88), K.CardHi },
	{ C(20, 20, 60), K.Obsidian }, { C(60, 90, 170), K.CardHi }, { C(60, 66, 110), K.CardHi }, { C(60, 64, 90), K.CardHi },
	{ C(80, 86, 120), K.CardHi }, { C(50, 56, 92), K.CardHi }, { C(80, 90, 130), K.CardHi }, { C(90, 100, 160), K.CardHi },
	{ C(40, 46, 64), K.Card }, { C(22, 31, 56), K.Card }, { C(12, 16, 34), K.Panel }, { C(14, 16, 34), K.Panel },
}
local OLD_GLASS = { C(24, 28, 58), C(26, 30, 62), C(21, 26, 38), C(48, 64, 112), C(34, 46, 92) }
local OLD_TEXT = {
	{ C(235, 240, 255), K.Text }, { C(244, 246, 251), K.Text },
	{ C(150, 160, 190), K.TextSecondary }, { C(154, 163, 184), K.TextSecondary }, { C(94, 103, 128), K.TextMuted },
}

local function textStroke(d)
	local s = d:FindFirstChildOfClass("UIStroke")
	if s and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then return end
	if d.TextTransparency >= 0.95 then
		if s and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then s.Transparency = 1 end
		return
	end
	if not s then s = Instance.new("UIStroke"); s.Name = "TextStroke"; s.Parent = d end
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; s.Color = K.Outline
	s.Transparency = math.max(d.TextTransparency, 0.25)
	s.Thickness = (d.TextSize >= 22 and 2) or (d.TextSize >= 15 and 1.4) or 1
	local c = d.TextColor3
	if (0.299 * c.R + 0.587 * c.G + 0.114 * c.B) < 0.35 then s.Transparency = 1 end
end

function T.Apply(d)
	if d:GetAttribute("ThemeSkip") then return end
	if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
		local c = d.BackgroundColor3
		for _, pair in T.BgRemap do if close(c, pair[1]) then d.BackgroundColor3 = pair[2]; break end end
	end

	-- 1) Top-Right Telemetry Wallet (Clean matte slate + crisp 1.5px border)
	if d.Name == "Wallet" and d:IsA("Frame") then
		d.Size = UDim2.fromOffset(316, 82)
		d.BackgroundColor3 = K.Panel; d.BackgroundTransparency = 0.08
		local fill = d:FindFirstChild("Fill")
		if fill and fill:IsA("UIGradient") then fill.Color = T.GlassFill end
		local st = d:FindFirstChild("Stroke") or d:FindFirstChildOfClass("UIStroke")
		if st then
			local sg = st:FindFirstChildOfClass("UIGradient"); if sg then sg:Destroy() end
			st.Color = K.BorderInner; st.Thickness = 1.5; st.Transparency = 0.15
		end
		local coins = d:FindFirstChild("Coins")
		if coins and coins:IsA("TextLabel") then coins.TextScaled = true; coins.TextColor3 = K.Gold; coins.FontFace = T.Fonts.Black end
		local mats = d:FindFirstChild("Materials")
		if mats then
			for _, m in ipairs(mats:GetChildren()) do
				if m:IsA("TextLabel") then
					m.AutomaticSize = Enum.AutomaticSize.X
					m.BackgroundColor3 = K.Card; m.BackgroundTransparency = 0.1
					m.FontFace = T.Fonts.Bold
					if not m:FindFirstChildOfClass("UICorner") then
						local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 6); mc.Parent = m
					end
					if not m:FindFirstChildOfClass("UIPadding") then
						local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 7); pad.PaddingRight = UDim.new(0, 7); pad.Parent = m
					end
				end
			end
		end

	-- 2) Top-Center Biome Pill (Fisch x Sol's RNG clean slate badge)
	elseif d.Name == "WeatherPill" and d:IsA("Frame") then
		d.BackgroundColor3 = K.Panel; d.BackgroundTransparency = 0.08
		local st = d:FindFirstChild("Stroke") or d:FindFirstChildOfClass("UIStroke")
		if st then
			local sg = st:FindFirstChildOfClass("UIGradient"); if sg then sg:Destroy() end
			st.Color = K.BorderInner; st.Thickness = 1.5; st.Transparency = 0.15
		end

	-- 3) Bottom Floating Roll Dock (Sol's RNG x PETS GO! tactile buttons, subtle slate container)
	elseif d.Name == "RollDock" and d:IsA("Frame") then
		local bar = d:FindFirstChild("Bar")
		if bar and bar:IsA("Frame") then
			bar.BackgroundTransparency = 0.12
			bar.BackgroundColor3 = K.Panel
			local fill = bar:FindFirstChild("Fill")
			if fill and fill:IsA("UIGradient") then fill.Color = T.GlassFill end
			local st = bar:FindFirstChild("Stroke") or bar:FindFirstChildOfClass("UIStroke")
			if st then
				local sg = st:FindFirstChildOfClass("UIGradient"); if sg then sg:Destroy() end
				st.Transparency = 0.2; st.Thickness = 1.5; st.Color = K.BorderInner
			end
		end
		local rb = d:FindFirstChild("RollButton")
		if rb and rb:IsA("GuiButton") then
			rb.BackgroundColor3 = Color3.new(1, 1, 1)
			local fg = rb:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", rb)
			fg.Rotation = 90
			fg.Color = ColorSequence.new(C(58, 228, 138), C(34, 178, 102))
			local gl = rb:FindFirstChild("Glow")
			if gl and gl:IsA("UIStroke") then gl.Color = C(14, 18, 26); gl.Thickness = 2.5; gl.Transparency = 0 end
		end
		local mb = d:FindFirstChild("MultiButton")
		if mb and mb:IsA("GuiButton") then
			mb.BackgroundColor3 = Color3.new(1, 1, 1)
			local fg = mb:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", mb)
			fg.Rotation = 90
			fg.Color = ColorSequence.new(C(250, 208, 74), C(222, 152, 38))
			local st = mb:FindFirstChildOfClass("UIStroke")
			if st then st.Color = C(14, 18, 26); st.Thickness = 2.5; st.Transparency = 0 end
		end
		local chips = d:FindFirstChild("Chips")
		if chips then
			for _, ch in ipairs(chips:GetChildren()) do
				if ch:IsA("GuiObject") then
					ch.BackgroundColor3 = K.Panel; ch.BackgroundTransparency = 0.1
					local cst = ch:FindFirstChildOfClass("UIStroke")
					if cst then
						cst.Thickness = 1.5
						cst.Color = K.BorderInner
						cst.Transparency = 0.15
					end
				end
			end
		end

	-- 4) Left IconBar Tiles (Clean matte dark slate squares with subtle 1.5px border)
	elseif d.Parent and d.Parent.Name == "IconBar" and d:IsA("GuiButton") then
		d.BackgroundColor3 = Color3.new(1, 1, 1); d.BackgroundTransparency = 0.06
		local fg = d:FindFirstChild("TileGrad") or d:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", d)
		fg.Name = "TileGrad"; fg.Rotation = 90; fg.Color = T.TileFill
		local st = d:FindFirstChild("Stroke") or d:FindFirstChildOfClass("UIStroke")
		if st and st.Name ~= "SelectRing" then
			st.Color = K.BorderInner; st.Thickness = 1.5; st.Transparency = 0.15
		end
		local cn = d:FindFirstChildOfClass("UICorner")
		if cn then cn.CornerRadius = UDim.new(0, 10) end
		local lbl = d:FindFirstChild("Label")
		if lbl and lbl:IsA("TextLabel") then lbl.TextColor3 = K.TextSecondary; lbl.FontFace = T.Fonts.Bold end

	-- 5) Modal Windows (Sol's RNG x Fisch Matte Dark Charcoal + 1.5px Crisp Slate Border)
	elseif d.Name:match("Panel$") and (d:IsA("CanvasGroup") or d:IsA("Frame")) then
		d.BackgroundColor3 = Color3.new(1, 1, 1); d.BackgroundTransparency = 0.03
		local fill = d:FindFirstChild("Fill") or Instance.new("UIGradient", d)
		fill.Name = "Fill"; fill.Rotation = 90
		fill.Color = ColorSequence.new(C(22, 25, 35), C(13, 15, 21))
		local st = d:FindFirstChild("Stroke")
		if st and st:IsA("UIStroke") then
			local sg = st:FindFirstChild("PanelBorderGrad"); if sg then sg:Destroy() end
			st.Thickness = 1.8; st.Color = C(68, 76, 102); st.Transparency = 0.1
		end
		local cn = d:FindFirstChildOfClass("UICorner")
		if cn then cn.CornerRadius = UDim.new(0, 12) end
		local title = d:FindFirstChild("Title")
		if title and title:IsA("TextLabel") then
			local tg = title:FindFirstChild("TitleGrad"); if tg then tg:Destroy() end
			title.TextColor3 = K.Text; title.FontFace = T.Fonts.Display
		end
		local closeBtn = d:FindFirstChild("Close")
		if closeBtn and closeBtn:IsA("GuiButton") then
			closeBtn.BackgroundColor3 = C(36, 40, 54); closeBtn.TextColor3 = K.Text
			local cst = closeBtn:FindFirstChildOfClass("UIStroke")
			if cst then cst.Color = K.BorderInner; cst.Thickness = 1.5 end
		end
	end

	-- Typography & Stroke Normalization
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		if d.Name == "Title" or d.Name == "Tier" or d.Name == "AnimalName" then
			d.FontFace = T.Fonts.Display
		elseif d.Name == "Timer" or d.Name == "Odds" or d.Name == "Coins" then
			d.FontFace = T.Fonts.Black
		else
			d.FontFace = T.Fonts.Bold
		end
		for _, p in OLD_TEXT do if close(d.TextColor3, p[1]) then d.TextColor3 = p[2]; break end end
		if d.Text ~= "" or d:IsA("TextLabel") then textStroke(d) end
	elseif d:IsA("TextBox") then
		d.FontFace = T.Fonts.Input
	elseif d:IsA("UIGradient") then
		if d.Name == "Fill" and not (d.Parent and d.Parent.Name:match("Panel$")) then
			local c0 = d.Color.Keypoints[1].Value
			for _, g in OLD_GLASS do if close(c0, g) then d.Color = T.GlassFill; break end end
		end
	elseif d:IsA("UIStroke") then
		if d.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			local p = d.Parent
			if p and (p:IsA("TextLabel") or p:IsA("TextButton")) and p.TextTransparency >= 0.95 then
				d.Transparency = 1
			else
				d.Color = K.Outline; d.Transparency = 0.25; d.Thickness = math.min(d.Thickness, 2)
				if p and (p:IsA("TextLabel") or p:IsA("TextButton")) then local c = p.TextColor3; if (0.299 * c.R + 0.587 * c.G + 0.114 * c.B) < 0.35 then d.Transparency = 1 end end
			end
		elseif (d.Name == "Stroke" or d.Name == "Inner") and not d:FindFirstChildWhichIsA("UIGradient") then
			local par = d.Parent
			if not (par and (par.Name:match("Panel$") or (par.Parent and par.Parent.Name == "IconBar") or par.Name == "Bar")) then
				d.Color = K.BorderInner; d.Thickness = 1.5; d.Transparency = 0.15
			end
		end
	elseif d:IsA("UICorner") then
		if d.CornerRadius.Scale == 0 and d.CornerRadius.Offset > 12 then d.CornerRadius = UDim.new(0, 10) end
	end
end

function T.ApplyTree(root) T.Apply(root); for _, d in root:GetDescendants() do T.Apply(d) end end
function T.Watch(root)
	return root.DescendantAdded:Connect(function(d) task.defer(function() if d.Parent then T.Apply(d) end end) end)
end
return T
