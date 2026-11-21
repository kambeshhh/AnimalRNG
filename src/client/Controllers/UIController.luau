-- UIController: HUD (wallet, weather, luck, alpha badge) + every panel (inventory, index, rank, potions, gifts, altar, totem, forge)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(RS.Modules.Config)
local AnimalData = require(RS.Modules.AnimalData)
local Net = require(RS.Modules.Net)
local UI = require(script.Parent.UIUtil)
local State = require(script.Parent.ClientState)
local NF = require(RS.Modules.NumberFormat)
local HttpService = game:GetService("HttpService")

local Ctl = {}
local player = Players.LocalPlayer
local gui = UI.Gui
local C = Color3.fromRGB
local A = Net.Get("Action")
local open = nil
local sel = { Inventory = nil, Altar = {}, Forge = nil }

local function act(...) A:FireServer(...) end
local function comma(n) return AnimalData.Comma(n) end
local function itemRarity(it) return AnimalData.ItemRarity(it) end

----------------------------------------------------------------- generic pieces
local function grid(body, cell)
	UI.Clear(body)
	local g = body:FindFirstChildOfClass("UIGridLayout")
	if not g then g = Instance.new("UIGridLayout"); g.Parent = body end
	local lst = body:FindFirstChildOfClass("UIListLayout"); if lst then lst:Destroy() end
	g.CellSize = cell or UDim2.fromOffset(160, 124); g.CellPadding = UDim2.fromOffset(12, 12); g.SortOrder = Enum.SortOrder.LayoutOrder
end
local function list(body)
	UI.Clear(body)
	local g = body:FindFirstChildOfClass("UIGridLayout"); if g then g:Destroy() end
	local l = body:FindFirstChildOfClass("UIListLayout")
	if not l then l = Instance.new("UIListLayout"); l.Padding = UDim.new(0, 8); l.SortOrder = Enum.SortOrder.LayoutOrder; l.Parent = body end
end
local function footer(panel, buttons)
	local f = panel.Footer
	UI.Clear(f)
	for i, b in ipairs(buttons) do
		local btn = UI.Button(f, b[1], UDim2.fromOffset(b.W or 150, 46), b[2], b[3], { LayoutOrder = i })
		if b.Disabled then btn.BackgroundColor3 = C(40, 46, 64); btn.TextColor3 = Config.UI.Muted end
	end
end
local function itemCard(parent, it, order, opts)
	local r = itemRarity(it)
	local tier = AnimalData.TierFor(it)
	local b = Instance.new("TextButton"); b.Text = ""; b.AutoButtonColor = false; b.LayoutOrder = order; b.ClipsDescendants = true
	UI.Glass(b, 14, tier.Color, tier.Color:Lerp(Color3.new(1, 1, 1), 0.35))
	b.Fill.Color = ColorSequence.new(tier.Color:Lerp(Color3.new(1, 1, 1), 0.12), tier.Color:Lerp(C(14, 18, 32), 0.55))
	b.Stroke.Thickness = opts.selected and 4 or 3; do local sg = b.Stroke:FindFirstChildOfClass("UIGradient"); if sg then sg.Enabled = false end end; b.Stroke.Color = opts.selected and Color3.new(1, 1, 1) or C(8, 10, 20)
	local tierIdx = 1; for i, t in ipairs(AnimalData.Tiers) do if t.Name == tier.Name then tierIdx = i end end
	if tierIdx >= 8 then
		local glowE = Instance.new("ImageLabel"); glowE.Name = "TierGlow"; glowE.BackgroundTransparency = 1; glowE.Image = "rbxasset://textures/ui/LuaApp/graphic/gr-item-selector-glow.png"
		glowE.Size = UDim2.fromScale(1, 1); glowE.ImageColor3 = tier.Color; glowE.ImageTransparency = 0.55; glowE.Parent = b
	end
	local strip = Instance.new("Frame"); strip.Size = UDim2.new(1, 0, 0, 5); strip.BorderSizePixel = 0; strip.BackgroundColor3 = tier.Color; strip.Parent = b
	local nameLbl = UI.Label(b, AnimalData.ItemName(it), UDim2.new(1, -16, 0, 46), UDim2.fromOffset(8, 12), 16, Config.UI.Text, Enum.Font.FredokaOne, { TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	local cap = Instance.new("UITextSizeConstraint"); cap.MaxTextSize = 18; cap.Parent = nameLbl
	UI.Label(b, AnimalData.FormatRarityShort(r), UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 62), 13, Config.UI.Muted, Enum.Font.GothamMedium, { TextXAlignment = Enum.TextXAlignment.Left })
	local pill = UI.Label(b, tier.Name:upper(), UDim2.fromOffset(0, 20), UDim2.new(0, 8, 1, -28), 11, C(14, 14, 30), Enum.Font.FredokaOne, { AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0, BackgroundColor3 = tier.Color })
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(1, 0); pc.Parent = pill
	local pp = Instance.new("UIPadding"); pp.PaddingLeft = UDim.new(0, 8); pp.PaddingRight = UDim.new(0, 8); pp.Parent = pill
	local badges = {}
	if opts.equipped then table.insert(badges, "✅") end
	if it.Locked then table.insert(badges, "🔒") end
	if opts.badge then table.insert(badges, opts.badge) end
	if #badges > 0 then UI.Label(b, table.concat(badges, " "), UDim2.fromOffset(60, 20), UDim2.new(1, -66, 1, -28), 14, Config.UI.Text, nil, { TextXAlignment = Enum.TextXAlignment.Right }) end
	UI.Juice(b)
	if opts.onClick then b.Activated:Connect(opts.onClick) end
	b.Parent = parent
	return b
end
local function sortedInventory(data)
	local items = table.clone(data.Inventory)
	table.sort(items, function(a, b) return itemRarity(a) > itemRarity(b) end)
	return items
end
local function costText(cost, data)
	local parts = {}
	if cost.Coins and cost.Coins > 0 then table.insert(parts, string.format("<font color='#%s'>💰 %s</font>", data.Coins >= cost.Coins and "FFFFFF" or "FF7090", comma(cost.Coins))) end
	for m, n in pairs(cost.Materials or {}) do
		local have = data.Materials[m] or 0
		table.insert(parts, string.format("<font color='#%s'>%s %d/%d</font>", have >= n and "FFFFFF" or "FF7090", Config.Materials[m].Icon, have, n))
	end
	for a, n in pairs(cost.Animals or {}) do
		local have = 0
		for _, it in ipairs(data.Inventory) do if it.Animal == a and not it.Locked and it.Id ~= data.Equipped then have += 1 end end
		table.insert(parts, string.format("<font color='#%s'>%s %d/%d</font>", have >= n and "FFFFFF" or "FF7090", AnimalData.Animals[a].Display, have, n))
	end
	return table.concat(parts, "   ")
end

----------------------------------------------------------------- renderers
local render = {}
render.Inventory = function(p, data)
	local vault = data.Vault or {}
	local pack = data.Pack or {}
	local packCPS = data.PackCPS or 0
	local offlinePending = data.OfflineCoinsPending or 0
	local vid = type(sel.Inventory) == "string" and sel.Inventory:match("^V:(.+)$")
	local vitem; if vid then for _, x in ipairs(vault) do if x.Id == vid then vitem = x end end end
	local it; for _, x in ipairs(data.Inventory) do if x.Id == sel.Inventory then it = x end end
	local inspect = vitem or it
	if inspect then
		local itemCPS = math.floor(Config.CompanionCPS(itemRarity(inspect)) * (data.CoinMult or 1))
		p.Subtitle.Text = string.format("%s%s  •  <font color='#FFD166'>%s</font>  •  %s  •  <font color='#78FFAA'>+%s Coins/s in Pack</font>",
			vitem and "📦 " or "", AnimalData.ItemName(inspect), AnimalData.FormatRarity(itemRarity(inspect)), AnimalData.TierFor(inspect).Name, comma(itemCPS))
	else
		p.Subtitle.Text = string.format("%d / %d slots  •  🐾 Pack %d/%d (<font color='#78FFAA'>+%s Coins/s</font>)  •  📦 Vault %d / %d",
			#data.Inventory, data.Slots, #pack, Config.Pack.MaxCompanions, comma(packCPS), #vault, Config.Roll.VaultSize)
	end
	p.Subtitle.RichText = true
	grid(p.Body)
	for i, x in ipairs(vault) do
		itemCard(p.Body, x, -1000 + i, { badge = "📦", selected = sel.Inventory == "V:" .. x.Id, onClick = function() sel.Inventory = "V:" .. x.Id; Ctl.Render() end })
	end
	for i, x in ipairs(sortedInventory(data)) do
		local inPack = table.find(pack, x.Id) ~= nil
		itemCard(p.Body, x, i, {
			equipped = x.Id == data.Equipped,
			badge = inPack and "🐾" or nil,
			selected = sel.Inventory == x.Id,
			onClick = function() sel.Inventory = x.Id; Ctl.Render() end,
		})
	end
	local slotCost = Config.Inventory.SlotCosts[data.Slots - Config.Inventory.StartSlots + 1]
	local buttons = {}
	table.insert(buttons, { "⚡ Equip Best Pack", C(240, 175, 40), function() act("EquipBest") end, W = 185 })
	if offlinePending > 0 then
		table.insert(buttons, { "💤 Claim +" .. NF.Short(offlinePending) .. "💰", C(60, 200, 110), function() act("ClaimOffline") end, W = 175 })
	end
	if vitem then
		table.insert(buttons, { "Claim to Inv", C(60, 170, 110), function() act("ClaimVault", vitem.Id) end, W = 150 })
		table.insert(buttons, { "Sell (" .. NF.Short(Config.SellValue(itemRarity(vitem))) .. ")", C(200, 90, 70), function() act("SellVault", vitem.Id) end, W = 135 })
	elseif it then
		table.insert(buttons, { "Morph", C(70, 130, 255), function() act("Equip", it.Id) end, W = 110, Disabled = it.Id == data.Equipped })
		if it.Id ~= data.Equipped then
			local inPack = table.find(pack, it.Id) ~= nil
			table.insert(buttons, { inPack and "🐾 Remove" or "🐾 Add Pack", C(130, 90, 220), function() act("TogglePack", it.Id) end, W = 135 })
		end
		table.insert(buttons, { it.Locked and "Unlock" or "Lock", C(90, 90, 130), function() act("Lock", it.Id) end, W = 100 })
		table.insert(buttons, { "Sell (" .. NF.Short(Config.SellValue(itemRarity(it))) .. ")", C(200, 90, 70), function() act("Sell", it.Id) end, W = 130, Disabled = it.Locked or it.Id == data.Equipped })
	end
	table.insert(buttons, { slotCost and ("+1 Slot (" .. NF.Short(slotCost) .. ")") or "Max Slots", C(200, 150, 40), function() act("BuySlot") end, W = 160, Disabled = not slotCost })
	footer(p, buttons)
end

local function row(parent, order, h)
	local f = Instance.new("Frame"); f.Size = UDim2.new(1, -6, 0, h or 70); f.LayoutOrder = order
	UI.Glass(f, 14); f.Parent = parent
	return f
end

local promoInput = ""
render.Shop = function(p, data)
	local ok, lb = pcall(function() return HttpService:JSONDecode(player:GetAttribute("LuckBreakdown") or "{}") end)
	lb = ok and lb or {}
	local restricted = player:GetAttribute("PaidRandomRestricted") == true or (data.PaidRandomRestricted == true)
	local eqDie = data.EquippedDie or "Wooden"
	local dieCfg = Config.Dice.Types[eqDie] or Config.Dice.Types.Wooden
	p.Subtitle.Text = string.format("Total Luck: ×%s   ·   %s %s (×%s)   ·   🔱 Rebirth %d (×%.2f)",
		NF.Luck(lb.Total or 1), dieCfg.Icon, dieCfg.Display, tostring(dieCfg.Luck), data.Rebirth or 0, Config.RebirthLuckMult(data.Rebirth or 0))
	list(p.Body)
	local bd = row(p.Body, 1, 114)
	local names = { Base = "Base", Rank = "Rank", Streak = "Streak", Skills = "Skills", Die = "Die", Totems = "Totems", AlphaZone = "Alpha", Potion = "Potion", Weather = "Weather", Index = "Index" }
	local addParts, multParts = {}, {}
	for _, k in ipairs({ "Base", "Die", "Skills", "Rank", "Streak", "Totems", "AlphaZone", "Potion", "Weather", "Index" }) do
		local v = lb.Add and lb.Add[k] or 0
		if v > 0 then table.insert(addParts, string.format("%s <font color='#78FFAA'>+%s</font>", names[k], NF.Luck(v))) end
	end
	if (lb.RebirthMult or 1) > 1 then table.insert(multParts, string.format("Rebirth <font color='#D69EFF'>x%s</font>", NF.Luck(lb.RebirthMult))) end
	for k, v in pairs(lb.Mult or {}) do table.insert(multParts, string.format("%s <font color='#FFD166'>x%s</font>", k, NF.Luck(v))) end
	local streakCur = (data.Stats and data.Stats.UnluckyStreak or 0) % 100
	local streakPct = math.floor(((lb.Add and lb.Add.Streak or 0) * 100) + 0.5)
	UI.Label(bd, "🍀 LUCK BREAKDOWN  ·  <font color='#78FFAA'>Streak Luck +" .. streakPct .. "% (" .. streakCur .. "/100 to next +2%, max +50%)</font>", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 6), 16, Config.UI.Gold, UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	UI.Label(bd, "Free:  " .. table.concat(addParts, "  ·  "), UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 30), 13, Config.UI.Text, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
	UI.Label(bd, "Multipliers:  " .. (#multParts > 0 and table.concat(multParts, "  ·  ") or "<font color='#9AA0C0'>none active</font>") .. "   ·   <font color='#B4BEDC'>Live effective odds update in Index</font>", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 66), 13, Config.UI.Text, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
	if restricted then
		UI.Label(bd, "ℹ️ Paid probability modifiers are restricted in your region — all luck progression is earnable free via Dice, Rebirth, Skills, Streak Luck & Potions.", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 90), 12, C(255, 210, 120), Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
	else
		UI.Label(bd, "ℹ️ Probability Disclosure: Luck divides tier odds denominators (e.g. at x10 Luck, a 1-in-10,000 tier becomes 1-in-1,000). Every roll returns an animal.", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 90), 12, Config.UI.Muted, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
	end

	-- 2) PROMO CODES & LUCKY SPINS BAR (Slime RNG x Anime Dice)
	local codeRow = row(p.Body, 2, 74)
	local spins = data.LuckySpins or 0
	local armed = data.LuckySpinArmed == true
	UI.Label(codeRow, string.format("🎁 PROMO CODES & LUCKY SPINS  ·  <font color='#FFD166'>%d Lucky Spin%s</font>", spins, spins == 1 and "" or "s"), UDim2.fromOffset(360, 24), UDim2.fromOffset(14, 6), 16, C(40, 210, 255), UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	UI.Label(codeRow, "Try codes: OUROBOROS, ANIMALRNG, SLIMEDICE, RELEASE, UPDATE1", UDim2.fromOffset(360, 18), UDim2.fromOffset(14, 32), 12, Config.UI.Muted, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
	local tb = Instance.new("TextBox"); tb.Size = UDim2.fromOffset(165, 42); tb.Position = UDim2.new(1, -460, 0.5, -21)
	tb.BackgroundColor3 = C(14, 18, 34); tb.TextColor3 = Color3.new(1, 1, 1); tb.PlaceholderText = "ENTER CODE..."; tb.Text = promoInput
	tb.Font = Enum.Font.GothamBlack; tb.TextSize = 14; tb.ClearTextOnFocus = false; Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 10)
	local tbs = Instance.new("UIStroke"); tbs.Color = C(40, 210, 255); tbs.Thickness = 2; tbs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; tbs.Parent = tb
	tb.FocusLost:Connect(function() promoInput = tb.Text end)
	tb.Parent = codeRow
	UI.Button(codeRow, "Redeem", UDim2.fromOffset(120, 44), C(40, 180, 240), function()
		promoInput = tb.Text
		act("RedeemCode", tb.Text)
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -162, 0.5, 0) })
	UI.Button(codeRow, armed and "🎰 ARMED!" or ("🎰 Spin (" .. spins .. ")"), UDim2.fromOffset(140, 44), armed and C(255, 190, 40) or (spins > 0 and C(170, 90, 245) or C(50, 56, 84)), function()
		act("ArmLuckySpin")
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })

	-- 3) ANIME DICE: 8-TIER 3D DICE & RELIC FORGE (F2P Coin & Material progression)
	local diceHeader = row(p.Body, 3, 38)
	UI.Label(diceHeader, "🎲 3D DICE & RELIC FORGE  —  Throws in 3D on every roll & multiplies F2P Luck!", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(14, 0), 17, Config.UI.Gold, UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	local order = 4
	local ownedDice = data.Dice or { Wooden = true }
	for _, dKey in ipairs(Config.Dice.Order) do
		order += 1
		local d = Config.Dice.Types[dKey]
		local hasDie = ownedDice[dKey] == true
		local isEq = eqDie == dKey
		local f = row(p.Body, order, 72)
		f.Stroke.Color = isEq and d.Color or C(8, 10, 20)
		UI.Label(f, string.format("%s  %s  <font color='#%s' size='14'>[%s · ×%s Luck]</font>", d.Icon, d.Display, d.Color:ToHex(), d.Rarity:upper(), tostring(d.Luck)),
			UDim2.new(1, -200, 0, 28), UDim2.fromOffset(14, 8), 19, Config.UI.Text, UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
		local cStr = hasDie and "<font color='#78FFAA'>Unlocked — throws physical 3D " .. d.Display .. " on every roll</font>" or ("Cost:  " .. costText({ Coins = d.Coins, Materials = d.Materials }, data))
		UI.Label(f, cStr, UDim2.new(1, -200, 0, 24), UDim2.fromOffset(14, 38), 13, Config.UI.Muted, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
		local bText = isEq and "EQUIPPED" or (hasDie and "EQUIP" or ("BUY (" .. (d.Coins > 0 and NF.Short(d.Coins) or "FREE") .. ")"))
		local bCol = isEq and C(40, 175, 235) or (hasDie and C(60, 195, 110) or C(230, 160, 40))
		UI.Button(f, bText, UDim2.fromOffset(160, 46), bCol, function()
			if hasDie then act("EquipDie", dKey) else act("BuyDie", dKey) end
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })
	end

	-- 4) ROBUX PASSES & BOOSTS
	order += 1
	local passHeader = row(p.Body, order, 38)
	UI.Label(passHeader, "💎 GAME PASSES & SERVER BOOSTS", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(14, 0), 17, C(180, 130, 255), UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	local M = Config.Monetization
	local function item(kind, key, def, owned, extra)
		order += 1
		local isRestrItem = restricted and def.RandomModifier == true
		local f = row(p.Body, order, 74)
		UI.Label(f, def.Icon .. "  " .. def.Display, UDim2.new(1, -190, 0, 28), UDim2.fromOffset(14, 8), 20, Config.UI.Text, UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
		local desc = isRestrItem and "Restricted in your region — earn free Luck via Dice, Rebirth, Skills & Potions"
			or ((def.Desc or (def.Server and "Boosts EVERY player in the server" or "Stacks with your free luck")) .. (extra or ""))
		UI.Label(f, desc, UDim2.new(1, -190, 0, 28), UDim2.fromOffset(14, 38), 13, isRestrItem and C(255, 195, 110) or Config.UI.Muted, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
		local btnLabel = owned and "OWNED" or (isRestrItem and "FREE PATH" or ("R$ " .. def.Robux))
		local btnColor = owned and C(60, 150, 100) or (isRestrItem and C(60, 68, 96) or C(60, 200, 110))
		UI.Button(f, btnLabel, UDim2.fromOffset(150, 46), btnColor, function()
			if not owned then act("Buy", kind, key) end
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })
	end
	local passes = data.Passes or {}
	for _, key in ipairs(M.PassOrder) do item("Pass", key, M.Passes[key], passes[key]) end
	for _, key in ipairs(M.ProductOrder) do
		local def = M.Products[key]
		local left = def.Server and ((RS:GetAttribute("ServerLuckUntil") or 0) - workspace:GetServerTimeNow()) or ((data.LuckBoostUntil or 0) - (data.ServerOsTime or os.time()))
		local extra = left > 0 and string.format("  ·  <font color='#78FFAA'>active %d:%02d</font>", left // 60, math.floor(left % 60)) or ""
		if def.Infinite then
			extra = string.format("  ·  <font color='#28D2FF'>Purchased: +%.1fx (Stacks Infinitely!)</font>", data.InfinitePaidLuck or 0)
		end
		item("Product", key, def, false, extra)
	end
	footer(p, {})
end

render.Settings = function(p, data)
	local st = data.Settings or {}
	p.Subtitle.Text = "Spin fast on commons — keep the spectacle for the pulls that matter"
	list(p.Body)
	local f = row(p.Body, 1, 112)
	UI.Label(f, "🎬 Full cutscene from rarity", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(14, 8), 19, Config.UI.Text, UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	UI.Label(f, "Below this tier you get the instant card. Unattainable always plays in full.", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(14, 34), 13, Config.UI.Muted, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
	local rowF = Instance.new("Frame"); rowF.BackgroundTransparency = 1; rowF.Position = UDim2.fromOffset(14, 60); rowF.Size = UDim2.new(1, -28, 0, 42); rowF.Parent = f
	local ll = Instance.new("UIListLayout"); ll.FillDirection = Enum.FillDirection.Horizontal; ll.Padding = UDim.new(0, 8); ll.Parent = rowF
	for _, v in ipairs(Config.Cutscene.Options) do
		local on = st.CutsceneMin == v
		UI.Button(rowF, AnimalData.Tiers[v].Name .. "+", UDim2.fromOffset(96, 40), on and C(255, 170, 60) or C(50, 56, 92), function() act("SetSetting", "CutsceneMin", v) end)
	end
	local g = row(p.Body, 2, 78)
	UI.Label(g, "⚡ Reduce other players' VFX", UDim2.new(1, -190, 0, 26), UDim2.fromOffset(14, 10), 19, Config.UI.Text, UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	UI.Label(g, "Hide others' sky pillars & bass hits (banner still shows). Better FPS.", UDim2.new(1, -190, 0, 18), UDim2.fromOffset(14, 40), 13, Config.UI.Muted, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
	UI.Button(g, st.ReduceOthersFX and "ON" or "OFF", UDim2.fromOffset(120, 44), st.ReduceOthersFX and C(60, 190, 120) or C(80, 86, 120), function() act("SetSetting", "ReduceOthersFX", not st.ReduceOthersFX) end,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })
	footer(p, {})
end

local indexSpin
local function viewport(parent, animal, size, pos, discovered)
	local vp = Instance.new("ViewportFrame"); vp.Size = size; vp.Position = pos; vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(170, 160, 200); vp.LightColor = Color3.fromRGB(255, 240, 220); vp.LightDirection = Vector3.new(-1, -1, -1)
	if not discovered then vp.ImageColor3 = Color3.new(0, 0, 0) end
	local tpl = RS.Animals:FindFirstChild(AnimalData.TemplateName(animal))
	if tpl then
		local m = tpl:Clone()
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("LuaSourceContainer") then d:Destroy() end end
		m:PivotTo(CFrame.new()); m.Parent = vp
		local cf, sz = m:GetBoundingBox()
		local cam = Instance.new("Camera"); cam.FieldOfView = 40; cam.Parent = vp; vp.CurrentCamera = cam
		local dist = math.max(sz.X, sz.Y, sz.Z) * 1.55
		local center = cf.Position
		return vp, function(t) cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(t) * dist, sz.Y * 0.15, math.cos(t) * dist), center) end
	end
	return vp, function() end
end

local function currentWeatherBoosts()
	local w = RS:GetAttribute("Weather") or "Sunny"
	local wInfo = Config.Weather.Types[w] or Config.Weather.Types.Sunny
	local boosts = {}
	for k, v in pairs(wInfo.Boost or {}) do boosts[k] = v end
	for name, a in pairs(AnimalData.Animals) do
		if a.Biome == w and not a.Exclusive then boosts[name] = math.max(boosts[name] or 1, 3) end
	end
	return boosts, wInfo
end

render.Index = function(p, data)
	if indexSpin then indexSpin:Disconnect(); indexSpin = nil end
	local n = 0; for _ in pairs(data.Index) do n += 1 end
	local total = #AnimalData.Order * #AnimalData.MutationOrder
	list(p.Body)
	local spinners = {}
	local liveUpdaters = {}
	local function updateHeader()
		local luck = math.max(1, player:GetAttribute("Luck") or 1)
		local _, wInfo = currentWeatherBoosts()
		p.Subtitle.Text = string.format("%d / %d discovered  •  +%d%% Luck  •  +%d%% Coins  •  Live Luck ×%s (%s)",
			n, total, n * Config.Luck.IndexPerEntry * 100, n, NF.Luck(luck), wInfo.Display)
	end
	updateHeader()
	local function dots(parent, animal, pos)
		local holder = Instance.new("Frame"); holder.BackgroundTransparency = 1; holder.Position = pos; holder.Size = UDim2.new(1, -12, 0, 12); holder.Parent = parent
		local l = Instance.new("UIListLayout"); l.FillDirection = Enum.FillDirection.Horizontal; l.Padding = UDim.new(0, 4); l.Parent = holder
		for _, mk in ipairs(AnimalData.MutationOrder) do
			local key = mk == "Normal" and animal or (animal .. "|" .. mk)
			local d = Instance.new("Frame"); d.Size = UDim2.fromOffset(12, 12); d.BorderSizePixel = 0
			d.BackgroundColor3 = data.Index[key] and AnimalData.Mutations[mk].Color or C(40, 44, 64)
			Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0); d.Parent = holder
		end
	end
	-- 1) Unattainable showcase slot
	local ou = AnimalData.UnattainableCreature
	local found = data.Index[ou]
	local top = Instance.new("Frame"); top.Size = UDim2.new(1, -6, 0, 170); top.LayoutOrder = 1
	UI.Glass(top, 16, C(255, 255, 255), C(255, 120, 220)); top.Parent = p.Body
	top.Fill.Color = ColorSequence.new(C(40, 30, 70), C(10, 8, 24))
	local rg = top.Stroke:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", top.Stroke)
	rg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 90, 90)), ColorSequenceKeypoint.new(0.33, C(255, 220, 80)), ColorSequenceKeypoint.new(0.66, C(90, 200, 255)), ColorSequenceKeypoint.new(1, C(230, 110, 255)) })
	local vp, spin = viewport(top, ou, UDim2.fromOffset(170, 160), UDim2.fromOffset(6, 5), found)
	vp.Parent = top; table.insert(spinners, spin)
	UI.Label(top, "UNATTAINABLE // MYTHIC GRAIL", UDim2.new(1, -200, 0, 22), UDim2.fromOffset(186, 14), 15, C(255, 225, 150), UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	UI.Label(top, found and AnimalData.Animals[ou].Display or "???", UDim2.new(1, -200, 0, 40), UDim2.fromOffset(186, 38), 34, Color3.new(1, 1, 1), UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	local ouBase = AnimalData.Tiers[AnimalData.TierCount].Min
	local ouOddsLbl = UI.Label(top, "", UDim2.new(1, -200, 0, 20), UDim2.fromOffset(186, 82), 13, C(210, 205, 240), Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
	local function updateOuroOdds()
		local luck = math.max(1, player:GetAttribute("Luck") or 1)
		local liveT28 = AnimalData.EffectiveTierOdds(AnimalData.TierCount, luck)
		ouOddsLbl.Text = string.format("Tier 28 exclusive  •  Base %s  •  <font color='#78FFAA'>Live %s</font>",
			AnimalData.FormatRarity(ouBase), AnimalData.FormatRarityShort(liveT28))
	end
	updateOuroOdds()
	table.insert(liveUpdaters, updateOuroOdds)
	UI.Label(top, found and "Discovered — the serpent that devours eternity." or "Roll Tier 28 to reveal it.", UDim2.new(1, -200, 0, 18), UDim2.fromOffset(186, 106), 13, Config.UI.Muted, Enum.Font.GothamMedium, { TextXAlignment = Enum.TextXAlignment.Left })
	dots(top, ou, UDim2.fromOffset(186, 136))
	-- 2) groups (rarest first), 4 creatures per row
	local order = 10
	for gi = #AnimalData.Groups, 1, -1 do
		local g = AnimalData.Groups[gi]
		local members = AnimalData.GroupMembers[g.Key]
		if #members > 0 then
			order += 1
			UI.Label(p.Body, string.format("%s  ·  %d%% of rolls", g.Display:upper(), math.floor(g.EffectiveShare * 1000 + 0.5) / 10), UDim2.new(1, -6, 0, 26), nil, 16, g.Color, UI.Display, { LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left })
			local rowF
			for i, animal in ipairs(members) do
				if (i - 1) % 4 == 0 then
					order += 1
					rowF = Instance.new("Frame"); rowF.BackgroundTransparency = 1; rowF.Size = UDim2.new(1, -6, 0, 150); rowF.LayoutOrder = order; rowF.Parent = p.Body
					local rl = Instance.new("UIListLayout"); rl.FillDirection = Enum.FillDirection.Horizontal; rl.Padding = UDim.new(0, 10); rl.Parent = rowF
				end
				local fnd = data.Index[animal]
				local a = AnimalData.Animals[animal]
				local f = Instance.new("Frame"); f.Size = UDim2.new(0.25, -8, 1, 0)
				UI.Glass(f, 12, fnd and g.Color or C(70, 76, 100), C(20, 20, 40)); f.Parent = rowF
				local v, sp = viewport(f, animal, UDim2.new(1, 0, 0, 82), UDim2.fromOffset(0, 2), fnd); v.Parent = f
				if fnd then table.insert(spinners, sp) else sp(0.6) end
				UI.Label(f, fnd and a.Display or "???", UDim2.new(1, -12, 0, 22), UDim2.fromOffset(6, 84), 15, fnd and Color3.new(1, 1, 1) or Config.UI.Muted, UI.Display, { TextScaled = true })
				local baseOdds = math.floor(a.Odds + 0.5)
				local oddsLbl = UI.Label(f, "", UDim2.new(1, -12, 0, 16), UDim2.fromOffset(6, 106), 11, Config.UI.Muted, Enum.Font.GothamBold, { TextScaled = true })
				local function updateCardOdds()
					local boosts = currentWeatherBoosts()
					local liveOdds, bMult = AnimalData.EffectiveCreatureOdds(animal, boosts)
					local liveRounded = math.max(1, math.floor(liveOdds + 0.5))
					if bMult > 1 then
						oddsLbl.Text = string.format("base %s · <font color='#78FFAA'>live %s (%dx)</font>", AnimalData.FormatRarityShort(baseOdds), AnimalData.FormatRarityShort(liveRounded), bMult)
					else
						oddsLbl.Text = string.format("base %s · <font color='#B4BEDC'>live %s</font>", AnimalData.FormatRarityShort(baseOdds), AnimalData.FormatRarityShort(liveRounded))
					end
				end
				updateCardOdds()
				table.insert(liveUpdaters, updateCardOdds)
				dots(f, animal, UDim2.fromOffset(8, 128))
			end
		end
	end
	local t0 = os.clock()
	local lastLiveUpdate = t0
	indexSpin = RunService.RenderStepped:Connect(function()
		if open ~= "Index" then indexSpin:Disconnect(); indexSpin = nil; return end
		local now = os.clock()
		local t = (now - t0) * 0.8
		for _, f in ipairs(spinners) do f(t) end
		if now - lastLiveUpdate >= 0.5 then
			lastLiveUpdate = now
			updateHeader()
			for _, fn in ipairs(liveUpdaters) do fn() end
		end
	end)
	footer(p, {})
end

-- shared admin request helper (server re-checks every call)
local AdminRF = Net.GetFunction("Admin")
local adminOut = ""
local adm = { Target = "", Animal = 2, Tier = 7, Mut = 1 }
local function adminCall(kind, action, args)
	task.spawn(function()
		local ok, res = pcall(function() return AdminRF:InvokeServer(kind, action, args or {}) end)
		adminOut = ok and ((res.Ok and "✅ " or "⛔ ") .. tostring(res.Msg or "")) or "⛔ request failed"
		if ok and res.Cooldown then Ctl.vipCd = Ctl.vipCd or {}; Ctl.vipCd[action] = os.clock() + res.Cooldown end
		Ctl.Render()
	end)
end
local function textbox(parent, placeholder, value, size, pos, onChange)
	local tb = Instance.new("TextBox"); tb.Size = size; tb.Position = pos; tb.BackgroundColor3 = C(14, 16, 34); tb.TextColor3 = Color3.new(1, 1, 1)
	tb.PlaceholderText = placeholder; tb.Text = value or ""; tb.Font = Enum.Font.GothamBold; tb.TextSize = 15; tb.ClearTextOnFocus = false
	Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 10)
	local st = Instance.new("UIStroke"); st.Color = C(90, 100, 160); st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = tb
	tb.FocusLost:Connect(function() onChange(tb.Text) end)
	tb.Parent = parent
	return tb
end

render.Admin = function(p, data)
	if not player:GetAttribute("IsDevAdmin") then p.Subtitle.Text = "Not authorised"; UI.Clear(p.Body); footer(p, {}); return end
	p.Subtitle.Text = "Server-verified • every action is logged • target blank = yourself"
	list(p.Body)
	local order = AnimalData.Order
	adm.Animal = math.clamp(adm.Animal, 1, #order)
	local animal = order[adm.Animal]
	if animal == AnimalData.UnattainableCreature then adm.Tier = AnimalData.TierCount elseif adm.Tier >= AnimalData.TierCount then adm.Tier = AnimalData.TierCount - 1 end
	local mut = AnimalData.MutationOrder[adm.Mut]
	-- target
	local r1 = row(p.Body, 1, 56)
	UI.Label(r1, "🎯 Target", UDim2.fromOffset(110, 40), UDim2.fromOffset(12, 8), 16, Config.UI.Text, UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	textbox(r1, "player name (blank = you)", adm.Target, UDim2.new(1, -310, 0, 38), UDim2.fromOffset(120, 9), function(t) adm.Target = t end)
	UI.Button(r1, "Inspect", UDim2.fromOffset(160, 38), C(80, 110, 200), function() adminCall("Dev", "Inspect", { Target = adm.Target }) end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0) })
	-- combo builder
	local item = { Animal = animal, Tier = adm.Tier, Mutation = mut }
	local tier = AnimalData.TierFor(item)
	local r2 = row(p.Body, 2, 150)
	UI.Label(r2, "🧬 " .. AnimalData.ItemName(item) .. "  •  <font color='#" .. tier.Color:ToHex() .. "'>" .. tier.Name .. " (T" .. adm.Tier .. ")</font>", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 8), 18, Config.UI.Text, UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	UI.Label(r2, AnimalData.FormatRarity(AnimalData.ItemRarity(item)) .. "   ·   " .. AnimalData.FormatRarityShort(AnimalData.ItemRarity(item)), UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 36), 14, C(255, 209, 102), Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
	local ctrls = Instance.new("Frame"); ctrls.BackgroundTransparency = 1; ctrls.Position = UDim2.fromOffset(12, 62); ctrls.Size = UDim2.new(1, -24, 0, 36); ctrls.Parent = r2
	local cl = Instance.new("UIListLayout"); cl.FillDirection = Enum.FillDirection.Horizontal; cl.Padding = UDim.new(0, 6); cl.Parent = ctrls
	local function small(t, col, fn, w) UI.Button(ctrls, t, UDim2.fromOffset(w or 44, 34), col, fn) end
	small("◀", C(60, 66, 110), function() adm.Animal = (adm.Animal - 2) % #order + 1; Ctl.Render() end)
	small("Creature ▶", C(60, 66, 110), function() adm.Animal = adm.Animal % #order + 1; Ctl.Render() end, 120)
	small("T−", C(60, 66, 110), function() adm.Tier = math.max(1, adm.Tier - 1); Ctl.Render() end)
	small("T+", C(60, 66, 110), function() adm.Tier = math.min(AnimalData.TierCount, adm.Tier + 1); Ctl.Render() end)
	small("T×5", C(60, 66, 110), function() adm.Tier = math.min(AnimalData.TierCount, adm.Tier + 5); Ctl.Render() end, 56)
	small("Mutation ▶", AnimalData.Mutations[mut].Color:Lerp(C(20, 20, 40), 0.4), function() adm.Mut = adm.Mut % #AnimalData.MutationOrder + 1; Ctl.Render() end, 130)
	local acts = Instance.new("Frame"); acts.BackgroundTransparency = 1; acts.Position = UDim2.fromOffset(12, 104); acts.Size = UDim2.new(1, -24, 0, 38); acts.Parent = r2
	local al = Instance.new("UIListLayout"); al.FillDirection = Enum.FillDirection.Horizontal; al.Padding = UDim.new(0, 8); al.Parent = acts
	UI.Button(acts, "🎁 Grant", UDim2.fromOffset(140, 36), C(60, 180, 110), function() adminCall("Dev", "Grant", { Target = adm.Target, Animal = animal, Tier = adm.Tier, Mutation = mut }) end)
	UI.Button(acts, "🎲 Forced Roll", UDim2.fromOffset(160, 36), C(200, 120, 60), function() adminCall("Dev", "TestRoll", { Target = adm.Target, Animal = animal, Tier = adm.Tier, Mutation = mut }) end)
	UI.Button(acts, "🎲 Test Roll", UDim2.fromOffset(140, 36), C(110, 90, 200), function() adminCall("Dev", "TestRoll", { Target = adm.Target }) end)
	UI.Button(acts, "5× Test", UDim2.fromOffset(110, 36), C(110, 90, 200), function() adminCall("Dev", "TestRoll", { Target = adm.Target, Count = Config.Roll.MultiCount }) end)
	-- server events
	local r3 = row(p.Body, 3, 100)
	local evUntil = RS:GetAttribute("EventLuckUntil") or 0
	local left = evUntil - workspace:GetServerTimeNow()
	UI.Label(r3, "🌟 Server luck event" .. (left > 0 and string.format("  •  <font color='#78FFAA'>x%s active %d:%02d</font>", AnimalData.Comma(RS:GetAttribute("EventLuckMult") or 1), left // 60, math.floor(left % 60)) or ""), UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 6), 16, Config.UI.Text, UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	local ev = Instance.new("Frame"); ev.BackgroundTransparency = 1; ev.Position = UDim2.fromOffset(12, 40); ev.Size = UDim2.new(1, -24, 0, 50); ev.Parent = r3
	local el = Instance.new("UIListLayout"); el.FillDirection = Enum.FillDirection.Horizontal; el.Padding = UDim.new(0, 8); el.Parent = ev
	for _, m in ipairs({ 2, 5, 10, 100 }) do UI.Button(ev, "x" .. m .. " · 10m", UDim2.fromOffset(110, 44), C(200, 160, 50), function() adminCall("Dev", "ServerLuck", { Mult = m, Minutes = 10 }) end) end
	UI.Button(ev, "Clear", UDim2.fromOffset(90, 44), C(160, 70, 70), function() adminCall("Dev", "ClearLuck", {}) end)
	UI.Button(ev, "+1M 💰", UDim2.fromOffset(100, 44), C(60, 150, 90), function() adminCall("Dev", "Coins", { Target = adm.Target, Amount = 1e6 }) end)
	-- weather
	local r4 = row(p.Body, 4, 60)
	local wl = Instance.new("UIListLayout"); wl.FillDirection = Enum.FillDirection.Horizontal; wl.Padding = UDim.new(0, 8); wl.VerticalAlignment = Enum.VerticalAlignment.Center; wl.SortOrder = Enum.SortOrder.LayoutOrder; wl.Parent = r4
	local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 12); pad.Parent = r4
	UI.Label(r4, "☁️ Weather", UDim2.fromOffset(100, 40), nil, 16, Config.UI.Text, UI.Display, { LayoutOrder = -1 })
	local wnames = {}; for k in pairs(Config.Weather.Types) do table.insert(wnames, k) end; table.sort(wnames)
	for _, w in ipairs(wnames) do UI.Button(r4, Config.Weather.Types[w].Display or w, UDim2.fromOffset(130, 40), C(70, 90, 150), function() adminCall("Dev", "Weather", { Name = w }) end) end
	-- output
	local r5 = row(p.Body, 5, 84)
	UI.Label(r5, adminOut ~= "" and adminOut or "Results appear here.", UDim2.new(1, -24, 1, -12), UDim2.fromOffset(12, 6), 14, Config.UI.Text, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true })
	footer(p, {})
end

local shoutText = ""
render.VIP = function(p, data)
	if not player:GetAttribute("IsVIPAdmin") then
		p.Subtitle.Text = "Requires the 👑 VIP Admin pass"
		list(p.Body)
		local r = row(p.Body, 1, 90)
		UI.Label(r, "Fireworks, server-wide confetti, a personal spotlight and filtered server shouts.\nCosmetic only — never affects luck, rolls or other players' progress.", UDim2.new(1, -24, 1, -12), UDim2.fromOffset(12, 6), 14, Config.UI.Text, Enum.Font.GothamBold, { TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
		footer(p, { { "Get VIP Admin (R$ " .. Config.Monetization.Passes.VIPAdmin.Robux .. ")", C(60, 200, 110), function() act("Buy", "Pass", "VIPAdmin") end, W = 280 } })
		return
	end
	p.Subtitle.Text = "Cosmetic & social only • cooldowns are enforced by the server"
	list(p.Body)
	local cd = Ctl.vipCd or {}
	local function left(k) return math.max(0, math.ceil((cd[k] or 0) - os.clock())) end
	local r1 = row(p.Body, 1, 76)
	local l1 = Instance.new("UIListLayout"); l1.FillDirection = Enum.FillDirection.Horizontal; l1.Padding = UDim.new(0, 10); l1.VerticalAlignment = Enum.VerticalAlignment.Center; l1.HorizontalAlignment = Enum.HorizontalAlignment.Center; l1.Parent = r1
	for _, spec in ipairs({ { "Fireworks", "🎆 Fireworks", C(255, 120, 80) }, { "Confetti", "🎊 Confetti", C(255, 90, 200) }, { "Spotlight", "🔦 Spotlight", C(255, 210, 90) } }) do
		local l = left(spec[1])
		UI.Button(r1, l > 0 and (spec[2] .. " " .. l .. "s") or spec[2], UDim2.fromOffset(170, 52), l > 0 and C(60, 64, 90) or spec[3], function() adminCall("VIP", spec[1], {}) end)
	end
	local r2 = row(p.Body, 2, 76)
	textbox(r2, "Server shout (filtered, max 80 chars)…", shoutText, UDim2.new(1, -200, 0, 44), UDim2.fromOffset(12, 16), function(t) shoutText = t end)
	local ls = left("Shout")
	UI.Button(r2, ls > 0 and ("📣 " .. ls .. "s") or "📣 Shout", UDim2.fromOffset(160, 44), ls > 0 and C(60, 64, 90) or C(90, 130, 255), function() adminCall("VIP", "Shout", { Text = shoutText }) end,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0) })
	local r3 = row(p.Body, 3, 50)
	UI.Label(r3, adminOut ~= "" and adminOut or "Have fun — be kind!", UDim2.new(1, -24, 1, -10), UDim2.fromOffset(12, 5), 14, Config.UI.Text, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
	footer(p, {})
end

render.Rank = function(p, data)
	local cur = Config.Ranks[data.Rank]
	local reb = data.Rebirth or 0
	local coinCost, essenceCost = Config.RebirthCost(reb)
	local curLuckM = Config.RebirthLuckMult(reb)
	local nextLuckM = Config.RebirthLuckMult(reb + 1)
	local curCoinM = Config.RebirthCoinMult(reb)
	local nextCoinM = Config.RebirthCoinMult(reb + 1)
	p.Subtitle.Text = string.format("🔱 Rebirth %d (×%.2f Luck · ×%.2f Coins)   ·   Hunter Rank %d / %d (%s)",
		reb, curLuckM, curCoinM, data.Rank, #Config.Ranks, cur.Name)
	list(p.Body)

	-- 0) WORLD 2 COSMIC PORTAL STATUS (UNLOCKED AT REBIRTH 10)
	local w2Req = Config.Rebirth.World2RebirthRequired or 10
	local w2Unlocked = reb >= w2Req
	local w2Card = Instance.new("Frame"); w2Card.Size = UDim2.new(1, -6, 0, 76); w2Card.LayoutOrder = 0
	UI.Glass(w2Card, 16, w2Unlocked and C(0, 240, 255) or C(90, 80, 140), C(18, 14, 42))
	w2Card.Parent = p.Body
	UI.Label(w2Card, w2Unlocked and "🌌 WORLD 2 COSMIC PORTAL: ACTIVE ✓" or string.format("🌌 WORLD 2 PORTAL: LOCKED (Rebirth %d / %d Required)", reb, w2Req),
		UDim2.new(1, -195, 0, 24), UDim2.fromOffset(14, 10), 17, w2Unlocked and C(0, 240, 255) or Config.UI.Gold, UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	UI.Label(w2Card, w2Unlocked and "Step through the dimensional rift into the Astral Expanse (+200% Base Luck)!" or "Reach Rebirth 10 to break the dimensional seal and unlock World 2!",
		UDim2.new(1, -195, 0, 20), UDim2.fromOffset(14, 38), 12, Config.UI.Muted, Enum.Font.GothamMedium, { TextXAlignment = Enum.TextXAlignment.Left })
	if w2Unlocked then
		UI.Button(w2Card, "🌌 ENTER WORLD 2", UDim2.fromOffset(175, 46), C(0, 200, 255), function()
			act("TeleportWorld2")
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })
	else
		UI.Button(w2Card, string.format("🔒 LOCKED (R%d)", w2Req), UDim2.fromOffset(175, 46), C(50, 54, 78), nil, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })
	end

	-- 1) SLIME RNG ESSENCE REBIRTH PORTAL CARD
	local rbCard = Instance.new("Frame"); rbCard.Size = UDim2.new(1, -6, 0, 108); rbCard.LayoutOrder = 1
	UI.Glass(rbCard, 16, C(210, 130, 255), Config.UI.Gold)
	rbCard.Fill.Color = ColorSequence.new(C(52, 32, 88), C(22, 18, 46))
	rbCard.Parent = p.Body
	UI.Label(rbCard, string.format("🔱 ESSENCE REBIRTH %d  ➔  REBIRTH %d", reb, reb + 1), UDim2.new(1, -210, 0, 26), UDim2.fromOffset(14, 8), 19, Config.UI.Gold, UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	UI.Label(rbCard, string.format("Permanent Multipliers:  <font color='#78FFAA'>Luck ×%.2f ➔ ×%.2f</font>   ·   <font color='#FFD166'>Coins ×%.2f ➔ ×%.2f</font>", curLuckM, nextLuckM, curCoinM, nextCoinM),
		UDim2.new(1, -210, 0, 22), UDim2.fromOffset(14, 36), 14, Config.UI.Text, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
	local hasCoins = (data.Coins or 0) >= coinCost
	local hasEssence = (data.Essence or 0) >= essenceCost
	UI.Label(rbCard, string.format("✓ Keeps ALL Animals, Index, 3D Dice & Skills (Resets Coins)   ·   Cost: <font color='#%s'>💰%s</font>  +  <font color='#%s'>✨%s Essence</font>",
		hasCoins and "78FFAA" or "FF7090", NF.Short(coinCost),
		hasEssence and "78FFAA" or "FF7090", NF.Short(essenceCost)),
		UDim2.new(1, -210, 0, 20), UDim2.fromOffset(14, 62), 12, Config.UI.Muted, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
	local canReb = hasCoins and hasEssence
	UI.Button(rbCard, "🔱 REBIRTH (" .. NF.Short(coinCost) .. "💰)", UDim2.fromOffset(180, 56), canReb and C(170, 80, 245) or C(50, 54, 82), function()
		act("Rebirth")
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })

	-- 2) SLIME RNG BRANCHING COIN SKILL TREE
	local skHeader = row(p.Body, 2, 36)
	UI.Label(skHeader, "⚡ COIN SKILL TREE  —  Permanent upgrades that persist across every Rebirth!", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(14, 0), 16, C(120, 255, 170), UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	local skills = data.Skills or {}
	local order = 2
	for _, sKey in ipairs(Config.Skills.Order) do
		order += 1
		local node = Config.Skills.Nodes[sKey]
		local lv = skills[sKey] or 0
		local maxed = lv >= node.Max
		local cost = Config.SkillCost(sKey, lv)
		local sf = row(p.Body, order, 68)
		sf.Stroke.Color = maxed and C(120, 255, 170) or C(8, 10, 20)
		UI.Label(sf, string.format("%s  %s   <font color='#FFD166'>[Lv. %d / %d]</font>", node.Icon, node.Display, lv, node.Max),
			UDim2.new(1, -195, 0, 26), UDim2.fromOffset(14, 8), 18, Config.UI.Text, UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
		UI.Label(sf, node.Desc, UDim2.new(1, -195, 0, 20), UDim2.fromOffset(14, 36), 13, Config.UI.Muted, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Left })
		local bTxt = maxed and "MAXED ✓" or ("💰 " .. NF.Short(cost))
		local bCol = maxed and C(50, 140, 90) or (data.Coins >= cost and C(60, 195, 110) or C(55, 62, 90))
		UI.Button(sf, bTxt, UDim2.fromOffset(155, 44), bCol, function()
			if not maxed then act("BuySkill", sKey) end
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })
	end

	-- 3) HUNTER RANKS (1-10)
	order += 1
	local rkHeader = row(p.Body, order, 36)
	UI.Label(rkHeader, "🏆 HUNTER RANKS (1 – 10)", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(14, 0), 16, Config.UI.Gold, UI.Display, { TextXAlignment = Enum.TextXAlignment.Left })
	local indexCount = 0; for _ in pairs(data.Index) do indexCount += 1 end
	for i, r in ipairs(Config.Ranks) do
		order += 1
		local done = data.Rank >= i
		local isNext = i == data.Rank + 1
		local f = Instance.new("Frame"); f.Size = UDim2.new(1, -6, 0, isNext and 78 or 56); f.LayoutOrder = order
		UI.Glass(f, 14, done and C(120, 255, 170) or (isNext and Config.UI.Gold or C(80, 90, 130)), done and C(60, 160, 110) or C(90, 80, 160))
		f.BackgroundColor3 = isNext and C(36, 44, 74) or C(22, 31, 56)
		local num = UI.Label(f, done and "✓" or tostring(i), UDim2.fromOffset(34, 34), UDim2.fromOffset(12, 11), 16, done and C(20, 40, 30) or Config.UI.Text, Enum.Font.GothamBlack, { BackgroundTransparency = 0, BackgroundColor3 = done and C(120, 255, 170) or C(52, 60, 92) })
		local nc = Instance.new("UICorner"); nc.CornerRadius = UDim.new(1, 0); nc.Parent = num
		UI.Label(f, r.Name, UDim2.new(0.4, 0, 0, 22), UDim2.fromOffset(56, 8), 17, done and C(170, 255, 205) or Config.UI.Text, Enum.Font.GothamBlack, { TextXAlignment = Enum.TextXAlignment.Left })
		UI.Label(f, (r.Text or "Starting rank") .. (r.Unlock and ("  ·  <font color='#FFCD5A'>Unlocks " .. r.Unlock .. "</font>") or ""), UDim2.new(1, -70, 0, 18), UDim2.fromOffset(56, 30), 13, Config.UI.Muted, Enum.Font.GothamMedium, { TextXAlignment = Enum.TextXAlignment.Left })
		if isNext and r.Req then
			local v = r.Req.Stat == "IndexCount" and indexCount or (data.Stats[r.Req.Stat] or 0)
			local frac = math.clamp(r.Req.Stat == "RarestPull" and (math.log10(math.max(1, v)) / math.log10(r.Req.Value)) or (v / r.Req.Value), 0, 1)
			local track = Instance.new("Frame"); track.Position = UDim2.fromOffset(56, 56); track.Size = UDim2.new(1, -170, 0, 8); track.BackgroundColor3 = C(12, 16, 34); track.BorderSizePixel = 0; track.Parent = f
			local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(1, 0); tc.Parent = track
			local fill = Instance.new("Frame"); fill.Size = UDim2.fromScale(frac, 1); fill.BackgroundColor3 = Config.UI.Gold; fill.BorderSizePixel = 0; fill.Parent = track
			local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = fill
			UI.Label(f, string.format("%s / %s", r.Req.Stat == "RarestPull" and AnimalData.FormatRarityShort(math.max(1, v)) or comma(v), r.Req.Stat == "RarestPull" and AnimalData.FormatRarityShort(r.Req.Value) or comma(r.Req.Value)),
				UDim2.fromOffset(104, 16), UDim2.new(1, -110, 0, 52), 12, Config.UI.Gold, Enum.Font.GothamBold, { TextXAlignment = Enum.TextXAlignment.Right })
		end
		f.Parent = p.Body
	end
	footer(p, {})
end
render.Potions = function(p, data)
	local lucky = (data.LuckyUntil or 0) - (data.ServerOsTime or os.time()) - (os.clock() - (Ctl.syncClock or os.clock()))
	p.Subtitle.Text = (lucky > 0 and string.format("🍀 Lucky Potion active: %d:%02d", lucky // 60, math.floor(lucky % 60)) or "No potion active") .. (data.ElixirArmed and "   •   🌟 ELIXIR ARMED (next roll)" or "")
	list(p.Body)
	for i, key in ipairs({ "Lucky", "Elixir" }) do
		local cfg = Config.Potions[key]
		local f = Instance.new("Frame"); f.Size = UDim2.new(1, -10, 0, 86); f.LayoutOrder = i
		UI.Glass(f, 12, key == "Elixir" and Config.UI.Gold or C(120, 255, 170), C(110, 90, 200))
		UI.Label(f, string.format("%s %s  x%d", cfg.Icon, cfg.Display, data.Potions[key] or 0), UDim2.new(1, -170, 0, 30), UDim2.fromOffset(14, 8), 20, Config.UI.Text, Enum.Font.GothamBlack, { TextXAlignment = Enum.TextXAlignment.Left })
		UI.Label(f, key == "Lucky" and "+100% Luck for 5 minutes. Brew at the Altar." or "+50,000% Luck for your next roll. Golden aura so the server can watch!", UDim2.new(1, -170, 0, 40), UDim2.fromOffset(14, 40), 14, Config.UI.Muted, nil, { TextXAlignment = Enum.TextXAlignment.Left })
		local b = UI.Button(f, "Drink", UDim2.fromOffset(130, 48), C(110, 90, 220), function() act("DrinkPotion", key) end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })
		if (data.Potions[key] or 0) <= 0 then b.BackgroundColor3 = C(40, 46, 64) end
		f.Parent = p.Body
	end
	footer(p, {})
end
render.Gifts = function(p, data)
	local elapsed = (workspace:GetServerTimeNow() - (data.SessionStart or workspace:GetServerTimeNow())) / 60
	p.Subtitle.Text = string.format("Session playtime: %d min", math.floor(elapsed))
	list(p.Body)
	for i, g in ipairs(Config.PlaytimeGifts) do
		local claimed = data.GiftsClaimed and data.GiftsClaimed[i]
		local ready = elapsed >= g.Minutes
		local f = Instance.new("Frame"); f.Size = UDim2.new(1, -10, 0, 58); f.LayoutOrder = i
		UI.Glass(f, 12, ready and Config.UI.Gold or Config.UI.Accent, C(110, 90, 200))
		local rw = g.Reward
		local text = rw.Coins and ("💰 " .. comma(rw.Coins) .. " Coins") or (rw.Potion and (Config.Potions[rw.Potion].Icon .. " " .. Config.Potions[rw.Potion].Display)) or "❄️ 3 Frost Cores + 🔥 3 Magma Hearts"
		UI.Label(f, string.format("🎁 %d min  —  %s", g.Minutes, text), UDim2.new(1, -170, 1, 0), UDim2.fromOffset(14, 0), 17, Config.UI.Text, nil, { TextXAlignment = Enum.TextXAlignment.Left })
		local label = claimed and "Claimed" or (ready and "Claim!" or string.format("%d:%02d", math.max(0, g.Minutes - elapsed) // 1, math.floor((math.max(0, g.Minutes - elapsed) % 1) * 60)))
		local b = UI.Button(f, label, UDim2.fromOffset(130, 42), (ready and not claimed) and C(60, 170, 110) or C(40, 46, 64), function() if ready and not claimed then act("ClaimGift", i) end end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0) })
		f.Parent = p.Body
	end
	footer(p, {})
end
render.Altar = function(p, data)
	local gain = 0
	for _, it in ipairs(data.Inventory) do if sel.Altar[it.Id] then gain += itemRarity(it) end end
	p.Subtitle.Text = string.format("✨ Essence: %s   •   Select animals to sacrifice (rarer = more Essence)", comma(data.Essence))
	grid(p.Body)
	for i, it in ipairs(sortedInventory(data)) do
		local usable = not it.Locked and it.Id ~= data.Equipped
		itemCard(p.Body, it, i, { equipped = it.Id == data.Equipped, selected = sel.Altar[it.Id], badge = sel.Altar[it.Id] and "🔥" or nil,
			onClick = function() if usable then sel.Altar[it.Id] = not sel.Altar[it.Id] or nil; Ctl.Render() end end })
	end
	local elixir = Config.Potions.Elixir
	local rebCost = Config.RebirthCost(data.Rebirth or 0)
	footer(p, {
		{ "Sacrifice (+" .. comma(gain) .. ")", C(150, 70, 230), function()
			local ids = {}; for id in pairs(sel.Altar) do table.insert(ids, id) end
			sel.Altar = {}; act("Sacrifice", ids) end, W = 185, Disabled = gain == 0 },
		{ "🔱 Rebirth (" .. NF.Short(rebCost) .. "✨)", C(180, 90, 250), function() act("Rebirth") end, W = 185, Disabled = (data.Essence or 0) < rebCost },
		{ "Lucky Potion (750💰)", C(60, 170, 110), function() act("BrewLucky") end, W = 180 },
		{ data.Rank >= elixir.RankRequired and ("Eclipse Elixir (" .. comma(elixir.EssenceCost) .. "✨)") or ("🔒 Elixir: Rank " .. elixir.RankRequired), C(220, 160, 40), function() act("BrewElixir") end, W = 195,
			Disabled = data.Rank < elixir.RankRequired or data.Essence < elixir.EssenceCost },
	})
end
render.Totem = function(p, data)
	p.Subtitle.Text = string.format("Totem slots: %d / %d equipped  •  materials spawn during weather events", #data.EquippedTotems, data.TotemSlots or 1)
	list(p.Body)
	for i, id in ipairs(Config.TotemOrder) do
		local cfg = Config.Totems[id]
		local owned, equipped = 0, 0
		for _, t in ipairs(data.Totems) do if t == id then owned += 1 end end
		for _, t in ipairs(data.EquippedTotems) do if t == id then equipped += 1 end end
		local f = Instance.new("Frame"); f.Size = UDim2.new(1, -10, 0, 104); f.LayoutOrder = i
		UI.Glass(f, 12, C(120, 255, 180), Config.UI.Accent)
		UI.Label(f, string.format("%s %s   <font color='#B4BEDC' size='14'>owned %d • equipped %d</font>", cfg.Icon, cfg.Display, owned, equipped), UDim2.new(1, -330, 0, 30), UDim2.fromOffset(14, 6), 20, Config.UI.Text, Enum.Font.GothamBlack, { TextXAlignment = Enum.TextXAlignment.Left })
		local stats = {}
		if cfg.Luck > 0 then table.insert(stats, "+" .. math.floor(cfg.Luck * 100) .. "% Luck") end
		if cfg.Speed > 0 then table.insert(stats, "+" .. math.floor(cfg.Speed * 100) .. "% Roll Speed") end
		UI.Label(f, table.concat(stats, "  •  "), UDim2.new(1, -330, 0, 20), UDim2.fromOffset(14, 38), 15, C(160, 255, 200), nil, { TextXAlignment = Enum.TextXAlignment.Left })
		UI.Label(f, costText(cfg.Cost, data), UDim2.new(1, -330, 0, 36), UDim2.fromOffset(14, 60), 14, Config.UI.Text, nil, { TextXAlignment = Enum.TextXAlignment.Left })
		UI.Button(f, "Craft", UDim2.fromOffset(120, 44), C(60, 170, 110), function() act("CraftTotem", id) end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -150, 0.5, 0) })
		local eb = UI.Button(f, equipped > 0 and "Unequip" or "Equip", UDim2.fromOffset(120, 44), C(70, 130, 255), function() act("ToggleTotem", id) end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })
		if owned == 0 then eb.BackgroundColor3 = C(40, 46, 64) end
		f.Parent = p.Body
	end
	footer(p, {})
end
render.Forge = function(p, data)
	local target
	for _, it in ipairs(data.Inventory) do if it.Id == sel.Forge then target = it end end
	local dupCount = 0
	if target then for _, it in ipairs(data.Inventory) do if it.Id ~= target.Id and it.Animal == target.Animal and not it.Locked and it.Id ~= data.Equipped then dupCount += 1 end end end
	p.Subtitle.Text = target and string.format("Target: %s  •  duplicates available: %d  •  failure never destroys the target", AnimalData.ItemName(target), dupCount) or "Select an animal to mutate (needs a duplicate of the same animal)"
	grid(p.Body)
	for i, it in ipairs(sortedInventory(data)) do
		itemCard(p.Body, it, i, { equipped = it.Id == data.Equipped, selected = sel.Forge == it.Id, onClick = function() sel.Forge = it.Id; Ctl.Render() end })
	end
	local buttons = {}
	for _, m in ipairs(Config.Forge.Order) do
		local cfg = Config.Forge[m]
		local col = AnimalData.Mutations[m].Color
		table.insert(buttons, { string.format("%s %d%%\n<font size='12'>%s</font>", AnimalData.Mutations[m].Display, math.floor(cfg.Chance * 100), costText({ Coins = cfg.Coins, Materials = cfg.Materials }, data)), col:Lerp(C(20, 20, 40), 0.35),
			function() if target then act("Forge", target.Id, m) end end, W = 200, Disabled = not target or dupCount == 0 })
	end
	footer(p, buttons)
end

----------------------------------------------------------------- open / close / render
function Ctl.Open(name)
	local closing = open == name
	if open then
		local prev = gui[open .. "Panel"]
		UI.Tween(prev, { GroupTransparency = 1 }, 0.15)
		local was = prev; task.delay(0.15, function() if open ~= was.Name:gsub("Panel$", "") then was.Visible = false end end)
	end
	open = (not closing) and name or nil
	for _, n in ipairs({ "Inventory", "Index", "Rank", "Potions", "Gifts", "Shop", "Settings", "Admin", "VIP" }) do
		local b = gui.IconBar[n .. "Button"]
		UI.Tween(b.SelectRing, { Transparency = (open == n) and 0 or 1 }, 0.15)
		UI.Tween(b, { BackgroundColor3 = (open == n) and C(255, 255, 255) or C(190, 198, 216) }, 0.15)
	end
	gui.Backdrop.Visible = open ~= nil
	if open then
		local p = gui[open .. "Panel"]
		p.Visible = true; p.GroupTransparency = 1
		local sc = p:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", p)
		sc.Scale = 0.92
		UI.Tween(p, { GroupTransparency = 0 }, 0.2)
		UI.Tween(sc, { Scale = 1 }, 0.28, Enum.EasingStyle.Back)
		Ctl.Render()
	end
end

function Ctl.Render()
	local data = State.Data
	if not data or not open then return end
	render[open](gui[open .. "Panel"], data)
end

local function hud(data)
	local cps = data.PackCPS or 0
	local cpsTag = cps > 0 and string.format(" (+%s/s)", NF.Short(cps)) or ""
	gui.Wallet.Coins.Text = "💰 " .. (data.Coins >= 1e5 and NF.Short(data.Coins) or comma(data.Coins)) .. cpsTag
	local m = data.Materials
	local chips = gui.Wallet.Materials
	chips.FrostCore.Text = "❄️ " .. (m.FrostCore or 0)
	chips.MagmaHeart.Text = "🔥 " .. (m.MagmaHeart or 0)
	chips.EclipseDust.Text = "🌑 " .. (m.EclipseDust or 0)
	local rebTag = (data.Rebirth or 0) > 0 and (" · 🔱" .. data.Rebirth) or ""
	chips.Essence.Text = "✨ " .. ((data.Essence or 0) >= 10000 and string.format("%.0fK", data.Essence / 1000) or comma(data.Essence or 0)) .. rebTag
	local elapsed = (workspace:GetServerTimeNow() - (data.SessionStart or 0)) / 60
	local giftReady = false
	for i, g in ipairs(Config.PlaytimeGifts) do if elapsed >= g.Minutes and not (data.GiftsClaimed and data.GiftsClaimed[i]) then giftReady = true end end
	gui.IconBar.GiftsButton.Dot.Visible = giftReady
	gui.IconBar.PotionsButton.Dot.Visible = (data.Potions.Lucky or 0) + (data.Potions.Elixir or 0) > 0
	gui.IconBar.InventoryButton.Dot.Visible = (data.Vault ~= nil and #data.Vault > 0) or ((data.OfflineCoinsPending or 0) > 0)
	gui.IconBar.RankButton.Dot.Visible = (data.Essence or 0) >= Config.RebirthCost(data.Rebirth or 0)
	gui.IconBar.ShopButton.Dot.Visible = (data.LuckySpins or 0) > 0
	local cm = data.Settings and data.Settings.CutsceneMin
	local skip = gui.RollDock.Chips:FindFirstChild("Skip")
	if skip and cm then local t = AnimalData.Tiers[cm]; skip.Value.Text = "⏭ Skip < T" .. cm .. (t and (" " .. t.Name) or "") end
	Ctl.RefreshDock()
end

function Ctl.RefreshDock()
	gui.IconBar.AdminButton.Visible = player:GetAttribute("IsDevAdmin") == true
	gui.IconBar.VIPButton.Visible = true -- everyone sees the VIP tile (it advertises the pass); actions are server-gated
	local n = 0
	for _, c in ipairs(gui.IconBar:GetChildren()) do if c:IsA("GuiButton") and c.Visible then n += 1 end end
	gui.IconBar.Size = UDim2.fromOffset(148, math.ceil(n / 2) * 80)
end

local lastPackFloat = 0
function Ctl.Start()
	local Cut = require(script.Parent.CutsceneController)
	UI.JuiceAll(gui)
	-- responsive: scale the whole HUD with the viewport (phones -> ~0.6, 1080p -> 1.0+)
	local cam = workspace.CurrentCamera
	local function rescale()
		local v = cam.ViewportSize
		gui.Scale.Scale = math.clamp(math.min(v.Y / 720, v.X / 1150), 0.72, 1.3)
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	for _, n in ipairs({ "Inventory", "Index", "Rank", "Potions", "Gifts", "Shop", "Settings", "Admin", "VIP" }) do
		gui.IconBar[n .. "Button"].Activated:Connect(function() Ctl.Open(n) end)
	end
	for n in pairs(render) do gui[n .. "Panel"].Close.Activated:Connect(function() if open == n then Ctl.Open(n) end end) end
	gui.Backdrop.Activated:Connect(function() if open then Ctl.Open(open) end end)
	local chips = gui.RollDock.Chips
	if chips:FindFirstChild("Skip") then chips.Skip.Activated:Connect(function() Ctl.Open("Settings") end) end
	if chips.Luck:FindFirstChild("Hit") then chips.Luck.Hit.Activated:Connect(function() Ctl.Open("Shop") end) end
	player:GetAttributeChangedSignal("IsDevAdmin"):Connect(function() Ctl.RefreshDock(); if open == "Admin" then Ctl.Render() end end)
	player:GetAttributeChangedSignal("IsVIPAdmin"):Connect(function() if open == "VIP" then Ctl.Render() end end)
	task.spawn(function() while true do task.wait(1); if open == "VIP" or open == "Admin" then Ctl.Render() end end end)
	State.Changed:Connect(function(data) Ctl.syncClock = os.clock(); hud(data); Ctl.Render() end)
	Net.Get("Sync").OnClientEvent:Connect(State.Set)
	Net.Get("Notify").OnClientEvent:Connect(function(kind, p)
		if kind == "Toast" then UI.Toast(p.Text, p.Color)
		elseif kind == "Banner" then UI.Banner(p.Text, p.Color, 4)
		elseif kind == "Float" then UI.Float(p.Text, p.Color)
		elseif kind == "OpenStation" then if open ~= p then Ctl.Open(p) end
		elseif kind == "PowerUpFX" then
			if Cut and Cut.PowerUpFX then task.spawn(Cut.PowerUpFX, p) end
		elseif kind == "PackIncome" then
			if State.Data then
				State.Data.Coins = p.Coins
				State.Data.PackCPS = p.CPS
				hud(State.Data)
			end
			if os.clock() - lastPackFloat >= 3.8 and not State.CutsceneBusy then
				lastPackFloat = os.clock()
				UI.Float("🐾 +" .. NF.Short(p.Gain) .. " 💰", C(120, 255, 170))
			end
		elseif kind == "ForgeResult" then
			if p.Success then UI.Banner("FORGE SUCCESS! " .. p.Name:upper() .. " (" .. AnimalData.FormatRarity(p.Rarity) .. ")", AnimalData.Mutations[p.Mutation].Color, 5); UI.Sound("Reveal", 0.8, 0.9)
			else UI.Toast("The forge fizzled... your animal is safe, the duplicate and materials were consumed.", C(255, 140, 140)); UI.Sound("Fail", 0.6, 0.9) end
			local fx = workspace.Hub.Forge:FindFirstChild("Platform")
			if fx then
				local e = Instance.new("ParticleEmitter"); e.Texture = "rbxasset://textures/particles/sparkles_main.dds"; e.LightEmission = 1
				e.Color = ColorSequence.new(p.Success and AnimalData.Mutations[p.Mutation].Color or C(255, 120, 60)); e.Speed = NumberRange.new(18, 34)
				e.SpreadAngle = Vector2.new(60, 60); e.Lifetime = NumberRange.new(0.5, 1); e.Size = NumberSequence.new(1.2, 0); e.Rate = 0
				local a = Instance.new("Attachment"); a.Position = Vector3.new(0, 4, 0); a.Parent = fx; e.Parent = a
				e:Emit(p.Success and 90 or 30); task.delay(1.5, function() a:Destroy() end)
			end
		end
	end)
	-- live HUD: weather timer, luck pill, equipped die badge, alpha badge, gift timers
	local lastSec = -1
	RunService.RenderStepped:Connect(function()
		local w = RS:GetAttribute("Weather") or "Sunny"
		local info = Config.Weather.Types[w]
		local left = math.max(0, (RS:GetAttribute("WeatherEndsAt") or 0) - workspace:GetServerTimeNow())
		local pill = gui.TopCenter.WeatherPill
		pill.Icon.Text = info.Icon; pill.WeatherName.Text = info.Display
		pill.Timer.Text = string.format("%d:%02d", left // 60, math.floor(left % 60))
		local luck = player:GetAttribute("Luck") or 1
		local dieKey = player:GetAttribute("EquippedDie") or (State.Data and State.Data.EquippedDie) or "Wooden"
		local dieCfg = Config.Dice.Types[dieKey] or Config.Dice.Types.Wooden
		local spinTag = (State.Data and State.Data.LuckySpinArmed) and " · 🎰SPIN" or ""
		local bName, bMult = next(info.Boost)
		local bAnimal = bName and AnimalData.Animals[bName]
		local boost = (bAnimal and bMult) and string.format("  •  %dx %s", bMult, bAnimal.Display:match("(%S+)$") or bAnimal.Display) or ""
		gui.RollDock.Chips.Luck.Value.Text = string.format("%s %s · 🍀 ×%s%s", dieCfg.Icon, dieCfg.Display:gsub(" Die$", ""), NF.Luck(luck), spinTag)
		gui.RollDock.Chips.Weather.Value.Text = string.format("%s %s%s", info.Icon, info.Display, boost)
		gui.TopCenter.AlphaBadge.Visible = player:GetAttribute("InAlpha") == true
		local sec = math.floor(os.clock())
		if sec ~= lastSec then
			lastSec = sec
			if State.Data then hud(State.Data); if open == "Gifts" or open == "Potions" or open == "Shop" then Ctl.Render() end end
		end
	end)
	task.delay(2, function() if not State.Data then act("SyncRequest") end end)
end

return Ctl
