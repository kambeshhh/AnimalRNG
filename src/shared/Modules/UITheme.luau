-- UITheme v2 "chunky": navy panels, thick black outlines, rounded stroked text, saturated buttons.
-- Used by UIUtil at runtime and safe to require in Edit (no player dependencies).
local C = Color3.fromRGB
local T = {}

T.Colors = {
	Obsidian = C(10, 12, 24), Panel = C(20, 26, 48), Card = C(30, 40, 72), CardHi = C(44, 60, 102),
	Outline = C(6, 8, 18), BorderInner = C(12, 16, 32), BorderStrong = C(80, 110, 175),
	Text = C(255, 255, 255), TextSecondary = C(210, 222, 248), TextMuted = C(148, 162, 198),
	Cyan = C(34, 235, 255), Gold = C(255, 210, 45), Magenta = C(255, 65, 220), Vip = C(190, 115, 255),
	Green = C(65, 235, 95), Success = C(65, 235, 95), Warn = C(255, 178, 36), Danger = C(245, 50, 65),
}
local K = T.Colors

local FRED = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
local MONT = "rbxasset://fonts/families/Montserrat.json"
T.Fonts = { Black = FRED, Bold = FRED, SemiBold = FRED, Medium = Font.new(MONT, Enum.FontWeight.Bold), Input = Font.new(MONT, Enum.FontWeight.SemiBold) }

T.GlassFill = ColorSequence.new({
	ColorSequenceKeypoint.new(0, C(48, 64, 112)),
	ColorSequenceKeypoint.new(0.5, C(28, 38, 70)),
	ColorSequenceKeypoint.new(1, C(16, 22, 44)),
})
T.TileFill = ColorSequence.new(C(66, 86, 138), C(34, 46, 82))
T.GrailGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, C(255, 218, 70)), ColorSequenceKeypoint.new(0.5, K.Cyan), ColorSequenceKeypoint.new(1, K.Magenta),
})

local function close(a, b) return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.06 end
T.BgRemap = {
	{ C(7, 8, 12), K.Obsidian }, { C(14, 17, 25), K.Panel }, { C(21, 26, 38), K.Card }, { C(28, 35, 51), K.CardHi },
	{ C(40, 50, 74), K.CardHi }, { C(24, 30, 44), C(44, 52, 78) }, { C(44, 56, 84), C(60, 78, 120) }, { C(59, 71, 102), K.CardHi },
	{ C(9, 12, 26), K.Obsidian }, { C(12, 15, 32), K.Panel }, { C(15, 23, 42), K.Panel }, { C(20, 16, 44), K.Obsidian },
	{ C(30, 41, 69), K.CardHi }, { C(24, 28, 58), K.Card }, { C(44, 62, 108), C(60, 78, 120) }, { C(52, 60, 88), K.CardHi },
	{ C(20, 20, 60), K.Obsidian }, { C(60, 90, 170), K.CardHi }, { C(60, 66, 110), K.CardHi }, { C(60, 64, 90), K.CardHi },
	{ C(80, 86, 120), C(60, 78, 120) }, { C(50, 56, 92), K.CardHi }, { C(80, 90, 130), C(60, 78, 120) }, { C(90, 100, 160), C(70, 90, 140) },
	{ C(40, 46, 64), C(44, 52, 78) }, { C(22, 31, 56), K.Card }, { C(12, 16, 34), K.Panel }, { C(14, 16, 34), K.Panel },
}
local OLD_GLASS = { C(24, 28, 58), C(26, 30, 62), C(21, 26, 38) }
local OLD_TEXT = { { C(235, 240, 255), K.Text }, { C(244, 246, 251), K.Text }, { C(150, 160, 190), K.TextSecondary }, { C(154, 163, 184), K.TextSecondary }, { C(94, 103, 128), K.TextMuted } }

local function textStroke(d)
	local s = d:FindFirstChildOfClass("UIStroke")
	if s and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then return end
	if not s then s = Instance.new("UIStroke"); s.Name = "TextStroke"; s.Parent = d end
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; s.Color = K.Outline; s.Transparency = 0
	s.Thickness = (d.TextSize >= 22 and 2.5) or (d.TextSize >= 15 and 2) or 1.5
	-- dark text (e.g. on bright pills) reads better without an outline
	local c = d.TextColor3
	if (0.299 * c.R + 0.587 * c.G + 0.114 * c.B) < 0.3 then s.Transparency = 1 end
end

function T.Apply(d)
	if d:GetAttribute("ThemeSkip") then return end
	if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
		local c = d.BackgroundColor3
		for _, pair in T.BgRemap do if close(c, pair[1]) then d.BackgroundColor3 = pair[2]; break end end
	end
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		d.FontFace = FRED
		for _, p in OLD_TEXT do if close(d.TextColor3, p[1]) then d.TextColor3 = p[2]; break end end
		if d.Text ~= "" or d:IsA("TextLabel") then textStroke(d) end
	elseif d:IsA("TextBox") then
		d.FontFace = T.Fonts.Input
	elseif d:IsA("UIGradient") then
		if d.Name == "Fill" then
			local c0 = d.Color.Keypoints[1].Value
			for _, g in OLD_GLASS do if close(c0, g) then d.Color = T.GlassFill; break end end
		end
	elseif d:IsA("UIStroke") then
		if d.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			d.Color = K.Outline; d.Transparency = 0; d.Thickness = math.max(d.Thickness, 1.5)
			local p = d.Parent
			if p and (p:IsA("TextLabel") or p:IsA("TextButton")) then local c = p.TextColor3; if (0.299 * c.R + 0.587 * c.G + 0.114 * c.B) < 0.3 then d.Transparency = 1 end end
		elseif (d.Name == "Stroke" or d.Name == "Inner") and (close(d.Color, C(42, 50, 71)) or close(d.Color, Color3.new(1, 1, 1))) and not d:FindFirstChildWhichIsA("UIGradient") then
			d.Color = K.Outline; d.Thickness = 3; d.Transparency = 0
		end
	elseif d:IsA("UICorner") then
		if d.CornerRadius.Scale == 0 and d.CornerRadius.Offset >= 8 and d.CornerRadius.Offset < 14 then d.CornerRadius = UDim.new(0, 12) end
	end
end

function T.ApplyTree(root) T.Apply(root); for _, d in root:GetDescendants() do T.Apply(d) end end
function T.Watch(root)
	return root.DescendantAdded:Connect(function(d) task.defer(function() if d.Parent then T.Apply(d) end end) end)
end
return T
