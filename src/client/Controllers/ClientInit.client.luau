-- ClientInit: boots every client controller & preloads custom VFX textures + custom 44.1kHz WAV SFX
local RS = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
task.spawn(function()
	local ok, Config = pcall(require, RS:WaitForChild("Modules"):WaitForChild("Config"))
	if ok and Config then
		local list = {}
		local seen = {}
		for _, tbl in ipairs({ Config.VFXTextures, Config.Sounds, Config.AnimeSounds, Config.BuiltinTextures }) do
			for _, id in pairs(tbl or {}) do
				if not seen[id] then seen[id] = true; table.insert(list, id) end
			end
		end
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
