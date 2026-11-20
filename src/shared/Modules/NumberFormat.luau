--!strict
-- NumberFormat: one formatter for Coins, Luck, costs, odds and leaderboards (K → Dc)
local NF = {}
local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function NF.Comma(n: number): string
	local s = string.format("%.0f", math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then out = out:sub(2) end
	return (n < 0 and "-" or "") .. out
end

-- 950 → "950", 12,345 → "12.3K", 1.5e15 → "1.5Qa"
function NF.Short(n: number, decimals: number?): string
	if n ~= n then return "0" end
	local a = math.abs(n)
	if a < 1000 then return (n < 0 and "-" or "") .. tostring(math.floor(a)) end
	local tier = math.min(#SUFFIX, math.floor(math.log10(a) / 3) + 1)
	local v = a / 10 ^ ((tier - 1) * 3)
	local d = decimals or (v < 10 and 2 or (v < 100 and 1 or 0))
	local s = string.format("%." .. d .. "f", v):gsub("%.?0+$", "")
	return (n < 0 and "-" or "") .. s .. SUFFIX[tier]
end

-- exact commas while readable, short suffix once it would clutter
function NF.Smart(n: number): string
	if math.abs(n) < 1e6 then return NF.Comma(n) end
	return NF.Short(n)
end

-- EXACT combined odds, full commas: cutscenes, announcements, inspection ("1 in 1,567,675,420")
function NF.Odds(n: number): string return "1 in " .. NF.Comma(n) end
-- COMPACT odds for cards / badges / boards ("1 in 1.57B"); exact below 1M so small odds stay precise
function NF.OddsShort(n: number): string return "1 in " .. NF.Smart(n) end

function NF.Luck(n: number): string
	if n < 100 then return string.format("%.2f", n):gsub("%.?0+$", "") end
	return NF.Short(n)
end

return NF
