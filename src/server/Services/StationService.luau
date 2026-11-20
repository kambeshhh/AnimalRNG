-- StationService: station prompts (Altar / Totem / Forge) + server-side range checks
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Modules.Config)

local StationService = {}
local S
local anchors = {}

function StationService.Init(services) S = services end

function StationService.Near(player, station)
	local root = player.Character and player.Character.PrimaryPart
	local a = anchors[station]
	return root ~= nil and a ~= nil and (root.Position - a).Magnitude <= Config.StationRange
end

function StationService.Start()
	for _, pr in ipairs(workspace.Hub:GetDescendants()) do
		if pr:IsA("ProximityPrompt") and pr:GetAttribute("Station") then
			local station = pr:GetAttribute("Station")
			anchors[station] = pr.Parent.Position
			pr.Triggered:Connect(function(player)
				S.DataService.Notify(player, "OpenStation", station)
			end)
		end
	end
end

return StationService
