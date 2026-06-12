local MatchController = {}

-- Init Bridg Net
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = ReplicatedStorage.Utility
local BridgeNet2 = require(Utility.BridgeNet2)
local bridge = BridgeNet2.ReferenceBridge("MatchController")
local actionIdentifier = BridgeNet2.ReferenceIdentifier("action")
local statusIdentifier = BridgeNet2.ReferenceIdentifier("status")
local messageIdentifier = BridgeNet2.ReferenceIdentifier("message")
-- End Bridg Net

function MatchController:Init() end

function MatchController:SendOption(option: string)
	local result = bridge:InvokeServerAsync({
		[actionIdentifier] = "SendOption",
		data = {
			Option = option,
		},
	})
end

function MatchController:SendAutomaticOption()
	local result = bridge:InvokeServerAsync({
		[actionIdentifier] = "SendAutomaticOption",
	})
	return result
end

return MatchController
