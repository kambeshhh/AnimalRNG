-- ClientInit: boots every client controller & preloads textures/sounds with matching Instance types
local RS = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
task.spawn(function()
	local ok, Config = pcall(require, RS:WaitForChild("Modules"):WaitForChild("Config"))
	if ok and Config then
		local objs, seen = {}, {}
		for _, tbl in ipairs({ Config.Sounds, Config.AnimeSounds }) do
			for _, id in pairs(tbl or {}) do
				if not seen[id] then
					seen[id] = true
					local s = Instance.new("Sound"); s.SoundId = id
					table.insert(objs, s)
				end
			end
		end
		for _, tbl in ipairs({ Config.VFXTextures, Config.BuiltinTextures }) do
			for _, id in pairs(tbl or {}) do
				if not seen[id] then
					seen[id] = true
					local img = Instance.new("ImageLabel"); img.Image = id
					table.insert(objs, img)
				end
			end
		end
		pcall(function() ContentProvider:PreloadAsync(objs) end)
		for _, o in ipairs(objs) do o:Destroy() end
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
