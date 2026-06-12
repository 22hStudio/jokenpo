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

function MatchService:ProcessOption(player: Player, option: string)
	if option ~= "ROCK" and option ~= "PAPER" and option ~= "SCISSORS" then
		warn("INVALID OPTION ")
		return
	end

	local match = MatchService:GetMatchFromPlayer(player)
	local matchId = match.Id
	if not match then
		warn("MATCH NOT FOUND")
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

	task.wait(1)

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

		task.wait(1)

		local resultPlayer, resultName = MatchService:CalculateResult(match)
		local winners = match.Winners

		-- Limpa as opções
		MatchService:UpdateMatch(matchId, { CurrentOptionPlayer1 = false, CurrentOptionPlayer2 = false })
		MatchService:RemoveInfoOptionFromPlayer(match.Player1)
		MatchService:RemoveInfoOptionFromPlayer(match.Player2)

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

		print("INICIANDO PROXIMA RODADA")
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

	-- Seta a Camera do jogador na posição de jogo
	--CameraService:SetInGame(player1, player2, data.TableNumber)

	-- Roda a Animação de Jokepon
	MatchService:RunJokeponAnimation(player1, player2)

	task.wait(3)

	-- Exibe as opções para o jogador escolher
	InGameScreensService:ShowOptions(player1, player2, data.Target, data.CurrentRound, data.Winners)
end

function MatchService:RunJokeponAnimation(player1: Player, player2: Player)
	task.spawn(function()
		AnimationService:PlayPlayerAnimation(player1, {
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
		AnimationService:PlayPlayerAnimation(player2, {
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

function MatchService:RunJokeponEndAnimation(player1: Player, player2: Player)
	task.spawn(function()
		AnimationService:PlayPlayerAnimation(player1, {
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
		AnimationService:PlayPlayerAnimation(player2, {
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

return MatchService
