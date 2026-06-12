local Players = game:GetService("Players")

local UIReferences = require(Players.LocalPlayer.PlayerScripts.Util.UIReferences)

local HudController = {}

local hudContainer

function HudController:Init()
	HudController:CreateReferences()
end

function HudController:CreateReferences()
	hudContainer = UIReferences:GetReference("HUD_CONTAINER")
end
function HudController:Show()
	hudContainer.Visible = true
end

function HudController:Hide()
	hudContainer.Visible = false
end

return HudController
