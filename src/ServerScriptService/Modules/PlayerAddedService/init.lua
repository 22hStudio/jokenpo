local PlayerAddedService = {}

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Init Bridg Net
local Utility = ReplicatedStorage.Utility
local BridgeNet2 = require(Utility.BridgeNet2)
local bridge = BridgeNet2.ReferenceBridge("PlayerAddedService")
local actionIdentifier = BridgeNet2.ReferenceIdentifier("action")
local statusIdentifier = BridgeNet2.ReferenceIdentifier("status")
local messageIdentifier = BridgeNet2.ReferenceIdentifier("message")
-- End Bridg Net

-- Modules
local AnimationService = require(ServerScriptService.Modules.AnimationService)
local FolderService = require(ServerScriptService.Modules.FolderService)


local playerInitializer = {}

function PlayerAddedService:Init()
	PlayerAddedService:InitBridgeListener()

	Players.PlayerRemoving:Connect(function(player)
		playerInitializer[player] = nil
	end)
end

function PlayerAddedService:InitBridgeListener()
	bridge.OnServerInvoke = function(player, data)
		if data[actionIdentifier] == "OnJoin" then
			-- Segurança para evitar que seja inicializado mais de uma vez
			if playerInitializer[player] then
				return false
			end

			playerInitializer[player] = true

			-- Cria as Pastas para o jogador em runtime
			FolderService:CreatePlayerRuntime(player)
			-- Carrega todas as animações do jogador
			AnimationService:PreLoadAnimations(player.Character or player.CharacterAdded)
		end
	end
end

return PlayerAddedService
