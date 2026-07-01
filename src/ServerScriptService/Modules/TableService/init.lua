local TableService = {}

-- Init Bridg Net
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = ReplicatedStorage.Utility
local BridgeNet2 = require(Utility.BridgeNet2)

local bridge = BridgeNet2.ReferenceBridge("TableService")
local actionIdentifier = BridgeNet2.ReferenceIdentifier("action")
local statusIdentifier = BridgeNet2.ReferenceIdentifier("status")
local messageIdentifier = BridgeNet2.ReferenceIdentifier("message")
-- End Bridg Net

-- Services
local UtilService = require(ServerScriptService.Modules.UtilService)
local MatchService = require(ServerScriptService.Modules.MatchService)
local FolderService = require(ServerScriptService.Modules.FolderService)

local tables = {}

function TableService:Init()
	TableService:InitBridgeListener()
	TableService:CreateAllTables()
end

function TableService:CreateAllTables()
	local tablesFromMap = UtilService:WaitForDescendants(workspace, "Map", "GameTables")

	for _, table in tablesFromMap:GetChildren() do
		local tableIndex = tonumber(table.Name)
		local chairs = {
			[1] = {
				Player = nil,
				Chair = table.Chairs[1].Seat,
			},
			[2] = {
				Player = nil,
				Chair = table.Chairs[2].Seat,
			},
		}

		tables[tableIndex] = chairs
	end
end

function TableService:InitBridgeListener()
	bridge.OnServerInvoke = function(player, data)
		if data[actionIdentifier] == "JoinTable" then
			local tableNumber = data.data.TableNumber
			return TableService:AddPlayerToTable(player, tableNumber)
		end

		if data[actionIdentifier] == "ExitTable" then
			TableService:RemovePlayerFromTable(player)
		end

		if data[actionIdentifier] == "PlaySolo" then
			TableService:RunPlaySolo(player)
		end
	end
end

function TableService:RunPlaySolo(player)
	-- Pega a mesa que o jogador está
	local tableIndex = TableService:GetTableIndexFromPlayer(player)

	-- Em Play Solo, o jogador sempre vai ocupar o posicao 1
	-- Atualiza o Player 2 para IA
	tables[tableIndex][2].Player = "IA"
	local chair = tables[tableIndex][2].Chair

	-- Sortear uma Skin Aleatoria e colocar pra sentar na cadeira
	local npcId, npc = UtilService:CreateRandomAvatar()
	npc.Name = "IA"
	npc.Parent = FolderService:GetNpcFolder(player)
	npc:SetAttribute("ID", npcId)

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = "AI"

	npc:PivotTo(chair.CFrame)
	chair:Sit(npc:FindFirstChildOfClass("Humanoid"))

	-- Inicia a Partida
	player:SetAttribute("PLAYER_SOLO", true)

	-- Cria a Partida
	MatchService:CreateFromPlayerSolo(player, npc, tableIndex)
end

function TableService:SitPlayer(player: Player, tableNumber: number, sitNumber: number)
	if tables[tableNumber] and tables[tableNumber][sitNumber] then
		local character = player.Character
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		tables[tableNumber][sitNumber].Chair:Sit(humanoid)
	end
end

function TableService:StandPlayer(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- Para as animações tocadas no Animator do servidor (ex: Jokenpo em loop)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end

	-- Remove a solda do assento, se existir
	local seatPart = humanoid.SeatPart
	if seatPart then
		local weld = seatPart:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
	end

	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

function TableService:AddPlayerToTable(player: Player, tableNumber: number)
	-- Pega a mesa
	local table = tables[tableNumber]

	if not table then
		warn("TABLE NOT FOUND!")
		return 0
	end

	player:SetAttribute("PLAYER_SOLO", false)

	-- Pega as cadeiras
	local chair1, chair2 = table[1], table[2]

	-- Verifica se a mesa tem cadeira disponivel
	if chair1.Player and chair2.Player then
		warn("TABLE IS NOT AVAILABLE")
		return 0
	end

	-- se a primeira cadeira estiver vazia, coloca o jogador nela apenas
	if not chair1.Player then
		tables[tableNumber][1].Player = player
		TableService:SitPlayer(player, tableNumber, 1)
		return 1
	end

	-- Se a primeira cadeira estiver com uma pessoa, coloca no segundo e começa a partida
	tables[tableNumber][2].Player = player
	TableService:SitPlayer(player, tableNumber, 2)

	task.spawn(function()
		MatchService:Create(tables[tableNumber][1].Player, tables[tableNumber][2].Player, tableNumber)
	end)

	return 2
end

function TableService:RemovePlayerFromTable(player: Player)
	local tableIndex = nil
	-- Encontra a Table que o jogador está
	for index, table in tables do
		local chair1, chair2 = table[1], table[2]
		if chair1.Player == player or chair2.Player == player then
			tableIndex = index
			break
		end
	end

	if tableIndex then
		local chair1, chair2 = tables[tableIndex][1], tables[tableIndex][2]
		if chair1.Player == player then
			tables[tableIndex][1].Player = nil
		end

		if chair2.Player == player then
			tables[tableIndex][2].Player = nil
		end

		TableService:StandPlayer(player)
		bridge:Fire(player, {
			[actionIdentifier] = "UnfreezePlayerSitted",
		})
	end
end

function TableService:GetTableIndexFromPlayer(player: Player)
	for index, table in tables do
		local chair1, chair2 = table[1], table[2]
		if chair1.Player == player or chair2.Player == player then
			return index
		end
	end
end

return TableService
