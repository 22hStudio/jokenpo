local PlayerAddedController = {}
  
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

-- Init Bridg Net
local Utility = ReplicatedStorage.Utility
local BridgeNet2 = require(Utility.BridgeNet2)
local TablesController = require(Players.LocalPlayer.PlayerScripts.ClientModules.TablesController)
local bridge = BridgeNet2.ReferenceBridge("PlayerAddedService")
local actionIdentifier = BridgeNet2.ReferenceIdentifier("action")
local statusIdentifier = BridgeNet2.ReferenceIdentifier("status")
local messageIdentifier = BridgeNet2.ReferenceIdentifier("message")
-- End Bridg Net

-- Pré-carrega no CLIENTE todas as animações do jogo (IDs ficam em workspace.Animations
-- como NumberValue). As animações do Jokenpo tocam no servidor e replicam; sem o asset
-- em cache no cliente, a primeira exibição tem um delay de load — e era esse delay que
-- deixava o personagem "voltar pro sentado" entre uma animação e outra. Pré-carregando
-- aqui, o END (e demais) aparece instantâneo quando o servidor manda tocar.
local function preloadAnimations()
	local animFolder = workspace:FindFirstChild("Animations")
	if not animFolder then
		return
	end

	local toPreload = {}
	for _, desc in animFolder:GetDescendants() do
		if desc:IsA("NumberValue") then
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://" .. desc.Value
			table.insert(toPreload, anim)
		end
	end

	if #toPreload > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(toPreload)
		end)
	end
end

local function safeCall(stepName, fn)
	local success, err = pcall(fn)

	if not success then
		warn("[PlayerAddedController][" .. stepName .. "] ERRO:")
		warn(err)
		warn(debug.traceback())
	end

	return success
end

function PlayerAddedController:Init(data)
	safeCall("BridgeOnJoin", function()
		local result = bridge:InvokeServerAsync({
			[actionIdentifier] = "OnJoin",
			data = {},
		})

		TablesController:ConfigureAllProximities()
	end)

	-- Pré-carrega as animações no cliente em paralelo (não trava o join).
	task.spawn(preloadAnimations)
end

return PlayerAddedController
