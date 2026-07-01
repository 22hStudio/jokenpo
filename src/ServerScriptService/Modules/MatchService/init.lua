local MatchService = {}

-- Init Bridg Net
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = ReplicatedStorage.Utility
local BridgeNet2 = require(Utility.BridgeNet2)
local bridge = BridgeNet2.ReferenceBridge("MatchController")
local actionIdentifier = BridgeNet2.ReferenceIdentifier("action")
local statusIdentifier = BridgeNet2.ReferenceIdentifier("status")
local messageIdentifier = BridgeNet2.ReferenceIdentifier("message")
-- End Bridg Net

local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local AnimationService = require(ServerScriptService.Modules.AnimationService)
local CameraService = require(ServerScriptService.Modules.CameraService)
local InGameScreensService = require(ServerScriptService.Modules.InGameScreensService)

-- Posicao/rotacao de cada item na mao do personagem.
-- Offset = posicao em studs relativa a mao direita.
-- Rotation = rotacao em GRAUS relativa a mao direita.
-- Ajuste estes valores para alinhar cada item (entre em Play, veja como ficou e refine).
local HAND_ITEM_CONFIG = {
	ROCK = {
		Offset = Vector3.new(0, -0.5, -0.4),
		Rotation = Vector3.new(0, 0, 0),
	},
	PAPER = {
		Offset = Vector3.new(0, -0.5, -0.4),
		Rotation = Vector3.new(90, 0, 0),
	},
	SCISSORS = {
		Offset = Vector3.new(0, -0.5, -0.4),
		Rotation = Vector3.new(90, 130, 0),
	},
}
local matchs = {}

function MatchService:Init()
	MatchService:InitBridgeListener()
end

function MatchService:InitBridgeListener()
	bridge.OnServerInvoke = function(player, data)
		if data[actionIdentifier] == "SendOption" then
			local option = data.data.Option
			MatchService:ProcessOption(player, option)
		end

		if data[actionIdentifier] == "SendAutomaticOption" then
			return MatchService:ProcessAutomaticOption(player)
		end
	end
end

function MatchService:ProcessAutomaticOption(player: Player)
	local options = { "ROCK", "PAPER", "SCISSORS" }
	local randomOption = options[math.random(1, #options)]
	task.spawn(function()
		MatchService:ProcessOption(player, randomOption)
	end)
	return randomOption
end

function MatchService:ProcessOptionFromPlayerSolo(player: Player, option: string)
	local match = MatchService:GetMatchFromPlayer(player)
	local matchId = match.Id

	if option ~= "ROCK" and option ~= "PAPER" and option ~= "SCISSORS" then
		warn("INVALID OPTION ")
		return
	end

	if not match then
		warn("MATCH NOT FOUND")
		return
	end

	-- Atualiza com a opção
	MatchService:UpdateMatch(matchId, { CurrentOptionPlayer1 = option, Processing = false })

	-- Atualiza o indicador na cabeça do jogador
	MatchService:SetInfoReadyToPlayer(player)

	-- Desliga toda a ui
	InGameScreensService:CloseAllScreenFromPlayerSolo(player)

	task.wait(1)

	MatchService:RemoveInfoReadyFromPlayer(player)

	-- Roda a Animação do Jokenpo End
	MatchService:RunJokeponEndAnimationFromPlayerSolo(player, match.NpcCharacter)

	-- Mostra o Resultado na cabeça do jogador
	MatchService:SetInfoOptionToPlayer(match.Player1, match.CurrentOptionPlayer1)
	-- Seta o item na mao do jogador
	MatchService:AddItemToCharacterHand(match.Player1.Character, match.CurrentOptionPlayer1)

	-- Sorteia o resultado do npc, salva na partida e mostra na cabeça do npc
	local npcOption = MatchService:DrawOptionFromIA()
	MatchService:UpdateMatch(matchId, { CurrentOptionNpc = npcOption })
	MatchService:SetInfoOptionToNpc(match.NpcCharacter, npcOption)
	MatchService:AddItemToCharacterHand(match.NpcCharacter, npcOption)

	local resultPlayer, resultName = MatchService:CalculateResultFromPlayerSolo(match)
	local winners = match.Winners

	task.wait(2)
	MatchService:RemoveInfoOptionFromPlayer(match.Player1)
	MatchService:RemoveInfoOptionFromNPC(match.NpcCharacter)

	MatchService:RemoveItemFromCharacterHand(match.Player1.Character)
	MatchService:RemoveItemFromCharacterHand(match.NpcCharacter)

	-- Se tiver um ganhador Atualiza a Lista de Ganhadores
	if resultPlayer then
		table.insert(winners, resultPlayer)
		MatchService:UpdateMatch(matchId, { Winners = winners })

		local IsLastRound, winnerPlayer = MatchService:IsLastRound(winners, match.Target)
		if IsLastRound then
			local TableService = require(ServerScriptService.Modules.TableService)

			-- Roda a Animação de vitória
			print(resultPlayer)

			MatchService:AddItemToCharacterHand(match.Player1.Character, match.CurrentOptionPlayer1)
			MatchService:AddItemToCharacterHand(match.NpcCharacter, npcOption)

			-- Vencedor foi o jogador
			if resultPlayer == match.Player1.Character then
				print("Alysson Ganhou")

				AnimationService:PlayWinAnimation(
					match.CurrentOptionPlayer1,
					resultPlayer,
					match.NpcCharacter,
					"1",
					match.TableNumber,
					true
				)
			else
				print("IA Ganhou")

				-- Vencedor foi a  IA

				-- Vencedor foi a  IA (perdedor = jogador; resultPlayer aqui e o NPC)
				AnimationService:PlayWinAnimation(
					match.CurrentOptionNpc,
					match.NpcCharacter,
					match.Player1.Character,
					"2",
					match.TableNumber,
					true
				)
			end

			-- Limpa as opções
			MatchService:UpdateMatch(matchId, { CurrentOptionPlayer1 = false, CurrentOptionNpc = false })
			MatchService:RemoveItemFromCharacterHand(match.Player1.Character)
			MatchService:RemoveItemFromCharacterHand(match.NpcCharacter)

			-- Tira os dois jogadores
			TableService:RemovePlayerFromTable(match.Player1)
			match.NpcCharacter:Destroy()

			-- Deleta a Match
			MatchService:RemoveMatch(matchId)

			-- Mostra o Resultado
			InGameScreensService:ShowMatchResultFromPlayerSolo(match.Player1, winnerPlayer)
			return
		end
	end

	-- Limpa as opções
	MatchService:UpdateMatch(matchId, { CurrentOptionPlayer1 = false, CurrentOptionNpc = false })

	task.wait(1)
	-- Mostra o Resultado
	InGameScreensService:ShowRoundResultFromPlayerSolo(match.Player1, resultName)

	AnimationService:StopPlayerAnimations(match.Player1.Character)
	AnimationService:StopPlayerAnimations(match.NpcCharacter)

	task.wait(2)

	-- Limpa a UI
	InGameScreensService:CloseAllScreenFromPlayerSolo(match.Player1)

	-- Roda a Animação
	MatchService:RunJokeponAnimationFromPlayerSolo(match.Player1, match.NpcCharacter)

	task.wait(3)

	-- Atualiza o Round e libera o lock para a próxima rodada
	MatchService:UpdateMatch(matchId, { CurrentRound = match.CurrentRound + 1, Resolving = false })

	-- Exibe as opções para o jogador escolher
	InGameScreensService:ShowOptionsFromPlayerSolor(match.Player1, match.Target, match.CurrentRound, winners)
	MatchService:SetInfoReadyToNpc(match.NpcCharacter)
end

function MatchService:ProcessOption(player: Player, option: string)
	local match = MatchService:GetMatchFromPlayer(player)
	local matchId = match.Id

	if option ~= "ROCK" and option ~= "PAPER" and option ~= "SCISSORS" then
		warn("INVALID OPTION ")
		return false
	end

	if not match then
		warn("MATCH NOT FOUND")
		return false
	end
	-- Verifica se o jogador está jogando contra a IA
	if player:GetAttribute("PLAYER_SOLO") then
		MatchService:ProcessOptionFromPlayerSolo(player, option)
		return
	end

	local processing = match.Processing

	while processing do
		match = MatchService:GetMatchFromPlayer(player)
		processing = match.Processing
		task.wait(1)
	end

	MatchService:UpdateMatch(matchId, { Processing = true })

	local isPlayer1 = match.Player1 == player
	local isPlayer2 = match.Player2 == player

	-- Verifica se ja tem opção escolhida

	if isPlayer1 then
		if match.CurrentOptionPlayer1 then
			warn("OPTION ALREADY EXISTS")
			return false
		end

		-- Atualiza com a opção
		MatchService:UpdateMatch(matchId, { CurrentOptionPlayer1 = option, Processing = false })

		-- Atualiza o indicador na cabeça do jogador
		MatchService:SetInfoReadyToPlayer(player)
	end

	if isPlayer2 then
		if match.CurrentOptionPlayer2 then
			warn("OPTION ALREADY EXISTS")
			return false
		end

		MatchService:UpdateMatch(matchId, { CurrentOptionPlayer2 = option, Processing = false })
		MatchService:SetInfoReadyToPlayer(player)
	end

	-- Se tiver recebido as 2 respotas, da o resultado
	match = MatchService:GetMatchFromPlayer(player)

	if match.CurrentOptionPlayer1 and match.CurrentOptionPlayer2 then
		-- Garante que apenas UMA das duas execuções (player1/player2) resolva a rodada.
		-- Sem isso o bloco roda 2x: o segundo passa vê as opções já limpas e dá "empate".
		if match.Resolving then
			return
		end
		MatchService:UpdateMatch(matchId, { Resolving = true })

		-- Desliga toda a ui
		InGameScreensService:CloseAllScreen(match.Player1, match.Player2)

		-- Remove os indicativos de pronto
		MatchService:RemoveInfoReadyFromPlayer(match.Player1)
		MatchService:RemoveInfoReadyFromPlayer(match.Player2)

		-- Roda a Animação do Jokenpo End
		MatchService:RunJokeponEndAnimation(match.Player1, match.Player2)

		-- Mostra o Resultado na cabeça do jogador
		MatchService:SetInfoOptionToPlayer(match.Player1, match.CurrentOptionPlayer1)
		MatchService:SetInfoOptionToPlayer(match.Player2, match.CurrentOptionPlayer2)

		MatchService:AddItemToCharacterHand(match.Player1.Character, match.CurrentOptionPlayer1)
		MatchService:AddItemToCharacterHand(match.Player2.Character, match.CurrentOptionPlayer2)

		task.wait(1)

		local resultPlayer, resultName = MatchService:CalculateResult(match)
		local winners = match.Winners

		-- Limpa as opções
		MatchService:UpdateMatch(matchId, { CurrentOptionPlayer1 = false, CurrentOptionPlayer2 = false })
		MatchService:RemoveInfoOptionFromPlayer(match.Player1)
		MatchService:RemoveInfoOptionFromPlayer(match.Player2)

		MatchService:RemoveItemFromCharacterHand(match.Player1.Character)
		MatchService:RemoveItemFromCharacterHand(match.Player2.Character)

		-- Se tiver um ganhador Atualiza a Lista de Ganhadores
		if resultPlayer then
			table.insert(winners, resultPlayer)
			MatchService:UpdateMatch(matchId, { Winners = winners })

			local IsLastRound, winnerPlayer = MatchService:IsLastRound(winners, match.Target)
			if IsLastRound then
				local TableService = require(ServerScriptService.Modules.TableService)

				-- Tira os dois jogadores
				TableService:RemovePlayerFromTable(match.Player1)
				TableService:RemovePlayerFromTable(match.Player2)

				-- Deleta a Match
				MatchService:RemoveMatch(matchId)

				-- Mostra o Resultado
				InGameScreensService:ShowMatchResult(match.Player1, match.Player2, winnerPlayer)
				return
			end
		end

		task.wait(1)
		-- Mostra o Resultado
		InGameScreensService:ShowRoundResult(match.Player1, match.Player2, resultName)

		AnimationService:StopPlayerAnimations(match.Player1)
		AnimationService:StopPlayerAnimations(match.Player2)

		task.wait(2)

		-- Limpa a UI
		InGameScreensService:CloseAllScreen(match.Player1, match.Player2)

		-- Roda a Animação
		MatchService:RunJokeponAnimation(match.Player1, match.Player2)

		task.wait(3)

		-- Atualiza o Round e libera o lock para a próxima rodada
		MatchService:UpdateMatch(matchId, { CurrentRound = match.CurrentRound + 1, Resolving = false })

		-- Exibe as opções para o jogador escolher
		InGameScreensService:ShowOptions(match.Player1, match.Player2, match.Target, match.CurrentRound, winners)
	end
end

function MatchService:IsLastRound(winners, target)
	local winsToWin = math.floor(target / 2) + 1
	local score = {}

	for _, winner in winners do
		score[winner] = (score[winner] or 0) + 1

		if score[winner] >= winsToWin then
			return true, winner
		end
	end

	return false, nil
end

function MatchService:CalculateResultFromPlayerSolo(match)
	local player1Option = match.CurrentOptionPlayer1
	local npcOption = match.CurrentOptionNpc

	-- Empate
	if player1Option == npcOption then
		return nil, "DRAW"
	end

	-- Jogador 1 venceu
	if
		(player1Option == "ROCK" and npcOption == "SCISSORS")
		or (player1Option == "SCISSORS" and npcOption == "PAPER")
		or (player1Option == "PAPER" and npcOption == "ROCK")
	then
		return match.Player1.Parent and match.Player1.Character, match.Player1.Name or ""
	end

	-- Npc Venceu
	return match.NpcCharacter, "IA"
end

function MatchService:CalculateResult(match)
	local player1Option = match.CurrentOptionPlayer1
	local player2Option = match.CurrentOptionPlayer2

	-- Empate
	if player1Option == player2Option then
		return nil, "DRAW"
	end

	-- Jogador 1 venceu
	if
		(player1Option == "ROCK" and player2Option == "SCISSORS")
		or (player1Option == "SCISSORS" and player2Option == "PAPER")
		or (player1Option == "PAPER" and player2Option == "ROCK")
	then
		return match.Player1.Parent and match.Player1, match.Player1.Name or ""
	end

	-- Jogador 2 venceu
	return match.Player2.Parent and match.Player2, match.Player2.Name or ""
end

function MatchService:ProcessPlayerLeft(player: Player)
	-- Verifica se tem alguma partida para esse jogador
	local match = MatchService:GetMatchFromPlayer(player)

	if match then
		local otherPlayer = nil
		if match.Player1 == player then
			otherPlayer = match.Player2
		end

		if match.Player2 == player then
			otherPlayer = match.Player1
		end

		if otherPlayer then
			local TableService = require(ServerScriptService.Modules.TableService)

			-- Informa ao outro jogador que ele ganhou
			InGameScreensService:ShowMatchResultFromPlayerLeft(otherPlayer)

			AnimationService:StopPlayerAnimations(otherPlayer)

			-- Tira os dois jogadores
			TableService:RemovePlayerFromTable(otherPlayer)

			-- Deleta a Match
			MatchService:RemoveMatch(match.Id)
		end
	end
end

function MatchService:GetMatchFromPlayer(player: Player)
	for _, match in matchs do
		if match.Player1 == player or match.Player2 == player then
			return match
		end
	end
end

function MatchService:SetInfoReadyToPlayer(player: Player)
	if not player.Parent then
		return
	end
	local character = player.Character or player.CharacterAdded:Wait()
	local head = character:WaitForChild("Head")

	-- Remove billboard antigo se existir
	local existingBillboard = head:FindFirstChild("Ready")
	if existingBillboard then
		existingBillboard:Destroy()
	end

	-- Clona e coloca na cabeça
	local billboard = ReplicatedStorage.GUI.BiilboardGui.READY:Clone()
	billboard.Name = "Ready"
	billboard.Adornee = head
	billboard.Parent = head
end

function MatchService:SetInfoReadyToNpc(character)
	local head = character:WaitForChild("Head")

	-- Remove billboard antigo se existir
	local existingBillboard = head:FindFirstChild("Ready")
	if existingBillboard then
		existingBillboard:Destroy()
	end

	-- Clona e coloca na cabeça
	local billboard = ReplicatedStorage.GUI.BiilboardGui.READY:Clone()
	billboard.Name = "Ready"
	billboard.Adornee = head
	billboard.Parent = head
end

function MatchService:RemoveInfoReadyFromNpc(character)
	local head = character:WaitForChild("Head")

	-- Remove billboard antigo se existir
	local existingBillboard = head:FindFirstChild("Ready")
	if existingBillboard then
		existingBillboard:Destroy()
	end
end

function MatchService:RemoveInfoReadyFromPlayer(player: Player)
	if not player.Parent then
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local head = character:WaitForChild("Head")

	-- Remove billboard antigo se existir
	local existingBillboard = head:FindFirstChild("Ready")
	if existingBillboard then
		existingBillboard:Destroy()
	end
end

function MatchService:SetInfoOptionToNpc(character, option: string)
	local head = character:WaitForChild("Head")

	-- Remove billboard antigo se existir
	local existingBillboard = head:FindFirstChild("Ready")
	if existingBillboard then
		existingBillboard:Destroy()
	end

	-- Clona e coloca na cabeça
	local billboard = ReplicatedStorage.GUI.BiilboardGui:FindFirstChild(option):Clone()
	billboard.Name = "OPTION"
	billboard.Adornee = head
	billboard.Parent = head
end

function MatchService:SetInfoOptionToPlayer(player: Player, option: string)
	if not player.Parent then
		return
	end
	local character = player.Character or player.CharacterAdded:Wait()
	local head = character:WaitForChild("Head")

	-- Remove billboard antigo se existir
	local existingBillboard = head:FindFirstChild("Ready")
	if existingBillboard then
		existingBillboard:Destroy()
	end

	-- Clona e coloca na cabeça
	local billboard = ReplicatedStorage.GUI.BiilboardGui:FindFirstChild(option):Clone()
	billboard.Name = "OPTION"
	billboard.Adornee = head
	billboard.Parent = head
end

function MatchService:DrawOptionFromIA()
	local options = { "ROCK", "PAPER", "SCISSORS" }
	return options[math.random(#options)]
end

function MatchService:RemoveInfoOptionFromPlayer(player: Player)
	if not player.Parent then
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local head = character:WaitForChild("Head")

	-- Remove billboard antigo se existir
	local existingBillboard = head:FindFirstChild("OPTION")
	if existingBillboard then
		existingBillboard:Destroy()
	end
end

function MatchService:RemoveInfoOptionFromNPC(character)
	local head = character:WaitForChild("Head")

	-- Remove billboard antigo se existir
	local existingBillboard = head:FindFirstChild("OPTION")
	if existingBillboard then
		existingBillboard:Destroy()
	end
end

function MatchService:CreateFromPlayerSolo(player: Player, npcCharacter, tableNumber: number)
	local data = {
		Id = HttpService:GenerateGUID(false),
		TableNumber = tableNumber,
		Processing = false,
		Target = 3,
		CurrentRound = 1,
		Player1 = player,
		NpcCharacter = npcCharacter,
		CurrentOptionPlayer1 = nil,
		CurrentOptionNpc = nil,
		Winners = {},
	}

	table.insert(matchs, data)

	-- Informa ao jogador que a partida vai começar
	InGameScreensService:ShowGameInitingFromPlayerSolo(player, 5)

	-- Mostra a introdução dos jogadores na partida
	InGameScreensService:ShowIntroducingPlayersFromPlayerSolo(player, 3.5, data.TableNumber)

	-- Roda a animação de começo
	MatchService:RunJokeponAnimationFromPlayerSolo(player, npcCharacter)

	task.wait(3)

	-- Indica que o NPC ja escolheu a sua opção
	MatchService:SetInfoReadyToNpc(npcCharacter)

	-- Exibe as opções para o jogador escolher
	InGameScreensService:ShowOptionsFromPlayerSolor(player, data.Target, data.CurrentRound, data.Winners)
end

function MatchService:Create(player1: Player, player2: Player, tableNumber: number)
	-- Cria a Partida
	local data = {
		Id = HttpService:GenerateGUID(false),
		TableNumber = tableNumber,
		Processing = false,
		Target = 3,
		CurrentRound = 1,
		Player1 = player1,
		Player2 = player2,
		CurrentOptionPlayer1 = nil,
		CurrentOptionPlayer2 = nil,
		Winners = {},
	}

	table.insert(matchs, data)

	-- Informa ao jogador que a partida vai começar
	InGameScreensService:ShowGameIniting(player1, player2, 5)

	-- Mostra a introdução dos jogadores na partida
	InGameScreensService:ShowIntroducingPlayers(player1, player2, 3.5, data.TableNumber)

	-- Roda a Animação de Jokepon
	MatchService:RunJokeponAnimation(player1, player2)

	task.wait(3)

	-- Exibe as opções para o jogador escolher
	InGameScreensService:ShowOptions(player1, player2, data.Target, data.CurrentRound, data.Winners)
end

function MatchService:RunJokeponAnimationFromPlayerSolo(player: Player, npcCharacter)
	task.spawn(function()
		AnimationService:PlayPlayerAnimation(player.Character, {
			{
				AnimationType = "JOKENPO",
				AnimationName = "START",
			},
			{
				AnimationType = "JOKENPO",
				AnimationName = "LOOP_START",
			},
		})
	end)

	task.spawn(function()
		AnimationService:PlayPlayerAnimation(npcCharacter, {
			{
				AnimationType = "JOKENPO",
				AnimationName = "START",
			},
			{
				AnimationType = "JOKENPO",
				AnimationName = "LOOP_START",
			},
		})
	end)
end

function MatchService:RunJokeponAnimation(player1: Player, player2: Player)
	task.spawn(function()
		AnimationService:PlayPlayerAnimationFromPlayer(player1, {
			{
				AnimationType = "JOKENPO",
				AnimationName = "START",
			},
			{
				AnimationType = "JOKENPO",
				AnimationName = "LOOP_START",
			},
		})
	end)

	task.spawn(function()
		AnimationService:PlayPlayerAnimationFromPlayer(player2, {
			{
				AnimationType = "JOKENPO",
				AnimationName = "START",
			},
			{
				AnimationType = "JOKENPO",
				AnimationName = "LOOP_START",
			},
		})
	end)
end

function MatchService:RunJokeponEndAnimationFromPlayerSolo(player1: Player, npcCharacter)
	task.spawn(function()
		AnimationService:PlayPlayerAnimation(player1.Character, {
			{
				AnimationType = "JOKENPO",
				AnimationName = "END",
			},
			{
				AnimationType = "JOKENPO",
				AnimationName = "LOOP_END",
			},
		})
	end)

	task.spawn(function()
		AnimationService:PlayPlayerAnimation(npcCharacter, {
			{
				AnimationType = "JOKENPO",
				AnimationName = "END",
			},
			{
				AnimationType = "JOKENPO",
				AnimationName = "LOOP_END",
			},
		})
	end)
end

function MatchService:RunJokeponEndAnimation(player1: Player, player2: Player)
	task.spawn(function()
		AnimationService:PlayPlayerAnimationFromPlayer(player1, {
			{
				AnimationType = "JOKENPO",
				AnimationName = "END",
			},
			{
				AnimationType = "JOKENPO",
				AnimationName = "LOOP_END",
			},
		})
	end)

	task.spawn(function()
		AnimationService:PlayPlayerAnimationFromPlayer(player2, {
			{
				AnimationType = "JOKENPO",
				AnimationName = "END",
			},
			{
				AnimationType = "JOKENPO",
				AnimationName = "LOOP_END",
			},
		})
	end)
end

function MatchService:UpdateMatch(matchId: number, newData: table)
	for _, match in matchs do
		if match.Id == matchId then
			for key, value in newData do
				match[key] = value
			end

			return match
		end
	end

	return nil
end

function MatchService:RemoveMatch(matchId)
	for index, match in ipairs(matchs) do
		if match.Id == matchId then
			table.remove(matchs, index)
			return true
		end
	end

	return false
end

function MatchService:AddItemToCharacterHand(character: Model, itemName: string)
	local template = ReplicatedStorage.Models:FindFirstChild(itemName)
	if not template then
		warn("ITEM NAO ENCONTRADO: " .. tostring(itemName))
		return
	end

	local rightHand = character:FindFirstChild("RightHand")
	if not rightHand then
		warn("RightHand nao encontrada em " .. character.Name)
		return
	end

	-- Evita item duplicado na mao
	MatchService:RemoveItemFromCharacterHand(character)

	local item = template:Clone()
	item.Name = "HAND_ITEM"

	local handle = item.PrimaryPart
	assert(handle, string.format("O modelo %s precisa ter um PrimaryPart.", itemName))

	-- Offset/rotacao por item, definidos no codigo (HAND_ITEM_CONFIG no topo do modulo).
	local config = HAND_ITEM_CONFIG[itemName] or DEFAULT_HAND_CONFIG
	local offset = config.Offset
	local rot = config.Rotation

	local goalCFrame = rightHand.CFrame
		* CFrame.new(offset)
		* CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))

	item.Parent = character

	-- Garante que TODAS as partes acompanhem a mao (sem ancora, sem colisao, sem peso).
	-- A pedra estava ficando para tras porque a Union estava Anchored = true.
	for _, part in item:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end

	-- Move o MODELO INTEIRO de forma que o PrimaryPart fique exatamente na mao
	-- (mantendo o offset das demais partes, ex.: as laminas da tesoura).
	item:PivotTo(goalCFrame * handle.CFrame:ToObjectSpace(item:GetPivot()))

	-- Solda o PrimaryPart na mao direita; as demais partes seguem pelos joints internos.
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rightHand
	weld.Part1 = handle
	weld.Parent = handle
end

function MatchService:RemoveItemFromCharacterHand(character: Model)
	local item = character:FindFirstChild("HAND_ITEM")

	if item then
		item:Destroy()
	end
end

return MatchService
