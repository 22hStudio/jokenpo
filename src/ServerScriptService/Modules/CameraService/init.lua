local CameraService = {}

-- Init Bridg Net
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = ReplicatedStorage.Utility
local BridgeNet2 = require(Utility.BridgeNet2)
local bridge = BridgeNet2.ReferenceBridge("CameraService")
local actionIdentifier = BridgeNet2.ReferenceIdentifier("action")
local statusIdentifier = BridgeNet2.ReferenceIdentifier("status")
local messageIdentifier = BridgeNet2.ReferenceIdentifier("message")
-- End Bridg Net

function CameraService:Init() end

function CameraService:SetInGame(player1: Player, player2: Player, tableNumber: number)
	bridge:Fire(player1, {
		[actionIdentifier] = "SetInGame",
		data = {
			TableNumber = tableNumber,
		},
	})

	bridge:Fire(player2, {
		[actionIdentifier] = "SetInGame",
		data = {
			TableNumber = tableNumber,
		},
	})
end

return CameraService
