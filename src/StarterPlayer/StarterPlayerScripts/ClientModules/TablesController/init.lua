local TablesController = {}

-- Init Bridg Net
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = ReplicatedStorage.Utility
local BridgeNet2 = require(Utility.BridgeNet2)
local bridge = BridgeNet2.ReferenceBridge("TableService")
local actionIdentifier = BridgeNet2.ReferenceIdentifier("action")
local statusIdentifier = BridgeNet2.ReferenceIdentifier("status")
local messageIdentifier = BridgeNet2.ReferenceIdentifier("message")
-- End Bridg Net

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local ClientUtil = require(Players.LocalPlayer.PlayerScripts.ClientModules.ClientUtil)
local InGameScreensController = require(Players.LocalPlayer.PlayerScripts.ClientModules.InGameScreensController)
local CameraController = require(Players.LocalPlayer.PlayerScripts.ClientModules.CameraController)

function TablesController:Init()
	TablesController:InitBridgeListener()
end

function TablesController:InitBridgeListener()
	bridge:Connect(function(response)
		if response[actionIdentifier] == "UnfreezePlayerSitted" then
			TablesController:UnfreezePlayerSitted()
		end
	end)
end

function TablesController:ReconfigureAllProxities()
	local tables = ClientUtil:WaitForDescendants(workspace, "Map", "GameTables")

	for _, table in tables:GetChildren() do
		local proximity = ClientUtil:WaitForDescendants(table, "ProximityPart", "ProximityPrompt")
		proximity.Enabled = true
	end
end

function TablesController:PlaySolo()
	local result = bridge:InvokeServerAsync({
		[actionIdentifier] = "PlaySolo",
	})
end

function TablesController:ConfigureAllProximities()
	local character = player.Character

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	local tables = ClientUtil:WaitForDescendants(workspace, "Map", "GameTables")

	for _, table in tables:GetChildren() do
		local proximity = ClientUtil:WaitForDescendants(table, "ProximityPart", "ProximityPrompt")

		proximity.Triggered:Connect(function(player)
			proximity.Enabled = false
			local result = bridge:InvokeServerAsync({
				[actionIdentifier] = "JoinTable",
				data = {
					TableNumber = tonumber(table.Name),
				},
			})

			if result == 1 then
				-- Congela o jogador
				TablesController:FreezePlayerSitted()

				-- Mostra a UI de esperando jogador
				InGameScreensController:OpenScreen("WAIT_FOR_ANOTHER_PLAYER")

				-- Coloca a animação da Camera
				CameraController:ShowWaitingForPlayerCamera(table.Name)
			end

			if result == 2 then
				-- Congela o jogador
				TablesController:FreezePlayerSitted()

				-- Coloca a animação da Camera
				CameraController:ShowWaitingForPlayerCamera(table.Name)
			end
		end)
	end
end

function TablesController:ExitTable()
	local result = bridge:InvokeServerAsync({
		[actionIdentifier] = "ExitTable",
	})
end

function TablesController:FreezePlayerSitted()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- Mantém sentado
	humanoid.Sit = true

	-- Bloqueia movimento
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false

	-- Impede levantar
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
end

function TablesController:UnfreezePlayerSitted()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- Reabilita estados
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)

	-- Sai do estado sentado
	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

	-- Restaura movimento
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50
	humanoid.AutoRotate = true
end

return TablesController
