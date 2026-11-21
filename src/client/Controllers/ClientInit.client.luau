-- ClientInit: boots every client controller & preloads custom VFX textures
local RS = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
task.spawn(function()
	local ok, Config = pcall(require, RS:WaitForChild("Modules"):WaitForChild("Config"))
	if ok and Config and Config.VFXTextures then
		local list = {}
		for _, id in pairs(Config.VFXTextures) do table.insert(list, id) end
		pcall(function() ContentProvider:PreloadAsync(list) end)
	end
end)

local ORDER = { "UIController", "RollController", "CutsceneController", "AbilityController", "AnimationController" }
for _, name in ipairs(ORDER) do
	local ok, ctl = pcall(require, script.Parent:WaitForChild(name))
	if ok and ctl.Start then
		local ok2, err = pcall(ctl.Start)
		if not ok2 then warn("[ClientInit] " .. name .. ".Start failed: " .. tostring(err)) end
	elseif not ok then warn("[ClientInit] require " .. name .. " failed: " .. tostring(ctl)) end
end
