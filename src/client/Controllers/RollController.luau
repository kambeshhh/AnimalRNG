-- RollController: ROLL, 5x ROLL, Auto (repeats your last roll type), Fast Roll (server Quick roll), bonus-roll badge, R / T / F hotkeys
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Config = require(RS.Modules.Config)
local Net = require(RS.Modules.Net)
local UI = require(script.Parent.UIUtil)
local State = require(script.Parent.ClientState)
local Cut = require(script.Parent.CutsceneController)

local Roll = {}
local player = Players.LocalPlayer
local lastSent, lastWasMulti = 0, false
local waiting = false
local autoMulti = false
local C = Color3.fromRGB

local function canQuick()
	return player:GetAttribute("CanQuick") == true
		or (State.Data and (State.Data.Rank >= Config.Roll.QuickRollRank or (State.Data.Passes and State.Data.Passes.SwiftRolls)))
		or false
end
local function canMulti() return player:GetAttribute("CanMulti") == true end
local function cooldown(multi)
	if multi then return player:GetAttribute("RollCooldownMulti") or Config.Roll.BaseCooldown * Config.Roll.MultiCooldownMult end
	return (State.Quick and player:GetAttribute("RollCooldownQuick") or player:GetAttribute("RollCooldown")) or Config.Roll.BaseCooldown
end

function Roll.Request(multi)
	if State.CutsceneBusy or waiting then return end
	if multi and not canMulti() then UI.Toast("5x Roll unlocks at Hunter Rank " .. Config.Roll.MultiRollRank .. " — or grab the 5x Roll Pass in the Shop", Config.UI.Muted); return end
	if os.clock() - lastSent < cooldown(lastWasMulti) then return end
	lastSent = os.clock(); lastWasMulti = multi == true; waiting = true
	autoMulti = multi == true
	Net.Get("RequestRoll"):FireServer(State.Quick and canQuick(), multi and Config.Roll.MultiCount or 1)
	task.delay(3, function() waiting = false end)
end

local function setSwitch(btn, on, accent, sub)
	local knob = btn.Track.Knob
	UI.Tween(knob, { Position = on and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, 0.18, Enum.EasingStyle.Back)
	UI.Tween(btn.Track, { BackgroundColor3 = on and accent or C(52, 60, 88) }, 0.18)
	btn.Sub.Text = sub or ""
end

local function refresh()
	local dock = UI.Gui.RollDock
	setSwitch(dock.AutoToggle, State.Auto, C(80, 210, 140), State.Auto and (autoMulti and "5x auto" or "auto") or "")
	if canQuick() then dock.QuickToggle.Label.Text = "⚡ FAST"; setSwitch(dock.QuickToggle, State.Quick, C(255, 180, 60), State.Quick and "+35% · F" or "key F")
	else dock.QuickToggle.Label.Text = "🔒 FAST"; setSwitch(dock.QuickToggle, false, C(255, 180, 60), "Rank " .. Config.Roll.QuickRollRank) end
	dock.MultiButton.Lock.Visible = not canMulti()
end

function Roll.Start()
	local dock = UI.Gui.RollDock
	dock.RollButton.Activated:Connect(function() Roll.Request(false) end)
	dock.MultiButton.Activated:Connect(function() Roll.Request(true) end)
	dock.AutoToggle.Activated:Connect(function() State.Auto = not State.Auto; refresh() end)
	local function toggleFast()
		if not canQuick() then UI.Toast("Fast Roll unlocks at Hunter Rank " .. Config.Roll.QuickRollRank .. " (or the Swift Rolls Pass)", Config.UI.Muted); return end
		State.Quick = not State.Quick; refresh()
		UI.Toast(State.Quick and "⚡ Fast Roll ON — shorter cooldown & reveals" or "Fast Roll OFF", C(255, 180, 60))
	end
	dock.QuickToggle.Activated:Connect(toggleFast)
	State.Changed:Connect(refresh)
	player:GetAttributeChangedSignal("CanMulti"):Connect(refresh)
	player:GetAttributeChangedSignal("CanQuick"):Connect(refresh)
	UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.R then Roll.Request(false)
		elseif input.KeyCode == Enum.KeyCode.T then Roll.Request(true)
		elseif input.KeyCode == Enum.KeyCode.F then toggleFast()
		elseif input.KeyCode == Enum.KeyCode.V then Net.Get("Action"):FireServer("ActivateOverdrive") end
	end)
	-- V6 Anime Overdrive Gauge Bar (clean matte-slate bar right above RollDock; click or press [V] at 100%)
	local odBtn = dock:FindFirstChild("OverdriveBar")
	if not odBtn then
		odBtn = Instance.new("TextButton")
		odBtn.Name = "OverdriveBar"
		odBtn.AnchorPoint = Vector2.new(0.5, 1)
		odBtn.Position = UDim2.new(0.5, 0, 0, -28)
		odBtn.Size = UDim2.fromOffset(310, 24)
		odBtn.BackgroundColor3 = C(16, 18, 25)
		odBtn.BackgroundTransparency = 0.08
		odBtn.BorderSizePixel = 0
		odBtn.AutoButtonColor = false
		odBtn.Text = ""
		Instance.new("UICorner", odBtn).CornerRadius = UDim.new(0, 7)
		local odStroke = Instance.new("UIStroke", odBtn); odStroke.Name = "Stroke"; odStroke.Thickness = 1.5; odStroke.Color = C(58, 66, 92)
		local odFill = Instance.new("Frame", odBtn); odFill.Name = "Fill"; odFill.Size = UDim2.fromScale(0, 1); odFill.BorderSizePixel = 0
		odFill.BackgroundColor3 = C(245, 165, 55)
		Instance.new("UICorner", odFill).CornerRadius = UDim.new(0, 6)
		local odLbl = Instance.new("TextLabel", odBtn); odLbl.Name = "Label"; odLbl.Size = UDim2.fromScale(1, 1); odLbl.BackgroundTransparency = 1
		odLbl.FontFace = UI.Theme.Fonts.Display; odLbl.TextSize = 13; odLbl.TextColor3 = C(244, 246, 252); odLbl.ZIndex = 3
		local odTxtStroke = Instance.new("UIStroke", odLbl); odTxtStroke.Thickness = 1.5; odTxtStroke.Color = C(8, 9, 13)
		odBtn.Parent = dock
		odBtn.Activated:Connect(function() Net.Get("Action"):FireServer("ActivateOverdrive") end)
	end
	Net.Get("RollResult").OnClientEvent:Connect(function(batch)
		waiting = false
		lastSent = os.clock(); lastWasMulti = batch.Multi == true
		task.spawn(Cut.PlayBatch, batch)
	end)
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local fracSingle = lastWasMulti and math.clamp((now - lastSent) / cooldown(true), 0, 1) or math.clamp((now - lastSent) / cooldown(false), 0, 1)
		local ready = fracSingle >= 1
		dock.RollButton.CooldownBar.Fill.Size = UDim2.fromScale(fracSingle, 1)
		dock.MultiButton.CooldownBar.Fill.Size = UDim2.fromScale(fracSingle, 1)
		local sh = dock.RollButton:FindFirstChild("Shimmer")
		if sh then sh.Visible = ready; sh.Position = UDim2.new(-0.5 + ((now % 2.4) / 2.4) * 2, 0, -0.3, 0) end
		local glow = dock.RollButton.Glow
		glow.Thickness = ready and (3 + math.sin(now * 5) * 1.2) or 2
		-- bonus badge: counts down, then lights up on the bonus roll itself
		local bonusIn = player:GetAttribute("BonusIn") or Config.Roll.BonusEvery
		local badge = dock.BonusBadge
		if bonusIn <= 1 then
			badge.Text = "★ NEXT ROLL: BONUS x" .. Config.Roll.BonusLuckMult .. " LUCK ★"
			badge.Size = UDim2.fromOffset(230, 24)
			badge.TextColor3 = C(30, 20, 10); badge.BackgroundColor3 = C(255, 205, 90):Lerp(C(255, 150, 60), (math.sin(now * 6) + 1) / 2)
		else
			badge.Text = "★ Bonus Roll in " .. bonusIn
			badge.Size = UDim2.fromOffset(150, 22)
			badge.TextColor3 = C(255, 220, 120); badge.BackgroundColor3 = C(20, 16, 44)
		end
		-- Overdrive gauge update
		local odUntil = player:GetAttribute("OverdriveUntil") or 0
		local odRem = odUntil - workspace:GetServerTimeNow()
		local odVal = player:GetAttribute("Overdrive") or (State.Data and State.Data.Overdrive) or 0
		local odMax = Config.Overdrive.Max or 100
		if odRem > 0 then
			local frac = math.clamp(odRem / Config.Overdrive.Duration, 0, 1)
			odBtn.Fill.Size = UDim2.fromScale(frac, 1)
			odBtn.Fill.BackgroundColor3 = C(255, 110, 55):Lerp(C(255, 205, 65), (math.sin(now * 10) + 1) / 2)
			odBtn.Stroke.Color = C(255, 200, 75)
			odBtn.Label.Text = string.format("🔥 OVERDRIVE ACTIVE · x2 LUCK · %.1fs", odRem)
		elseif odVal >= odMax then
			local pulse = (math.sin(now * 8) + 1) / 2
			odBtn.Fill.Size = UDim2.fromScale(1, 1)
			odBtn.Fill.BackgroundColor3 = C(235, 72, 88):Lerp(C(255, 190, 55), pulse)
			odBtn.Stroke.Color = C(255, 220, 100)
			odBtn.Label.Text = "⚡ UNLEASH OVERDRIVE [V] (x2 LUCK · +50% SPD)"
		else
			local frac = math.clamp(odVal / odMax, 0, 1)
			odBtn.Fill.Size = UDim2.fromScale(frac, 1)
			odBtn.Fill.BackgroundColor3 = C(78, 165, 245):Lerp(C(245, 172, 56), frac)
			odBtn.Stroke.Color = C(58, 66, 92)
			odBtn.Label.Text = string.format("⚡ OVERDRIVE GAUGE  %d%%  (Roll to charge)", math.floor(frac * 100))
		end
		if State.Auto and ready and not State.CutsceneBusy then Roll.Request(autoMulti and canMulti()) end
	end)
	refresh()
end

return Roll
