-- ClientInit: boots every client controller
local ORDER = { "UIController", "RollController", "CutsceneController", "AbilityController", "AnimationController" }
for _, name in ipairs(ORDER) do
	local ok, ctl = pcall(require, script.Parent:WaitForChild(name))
	if ok and ctl.Start then
		local ok2, err = pcall(ctl.Start)
		if not ok2 then warn("[ClientInit] " .. name .. ".Start failed: " .. tostring(err)) end
	elseif not ok then warn("[ClientInit] require " .. name .. " failed: " .. tostring(ctl)) end
end
