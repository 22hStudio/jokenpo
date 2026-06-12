local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = ReplicatedStorage.Utility
local BridgeNet2 = require(Utility.BridgeNet2)

local bridge = BridgeNet2.ReferenceBridge("PlayerLoaded")
local actionIdentifier = BridgeNet2.ReferenceIdentifier("action")
local statusIdentifier = BridgeNet2.ReferenceIdentifier("status")
local messageIdentifier = BridgeNet2.ReferenceIdentifier("message")

bridge:Connect(function(response)
	if response[actionIdentifier] ~= "PlayerLoaded" then
		return
	end

	local clientModules = script.Parent.ClientModules
	local PlayerGui = Players.LocalPlayer.PlayerGui

	for _, module in clientModules:GetChildren() do
		if module:IsA("ModuleScript") then
			-- Inicializa as Screens
			if module.Name == "PlayerAddedController" then
				continue
			end

			local clientModule = require(module)

			if clientModule.Init then
				pcall(function()
					clientModule:Init(response.data)
				end)
			end
		end
	end

	local PlayerAddedController = clientModules:FindFirstChild("PlayerAddedController")
	local PlayerAddedControllerModule = require(PlayerAddedController)
	PlayerAddedControllerModule:Init(response.data)
end)
