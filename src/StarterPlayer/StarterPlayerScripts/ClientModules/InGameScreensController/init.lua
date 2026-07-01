local InGameScreensController = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")

-- Init Bridg Net
local Utility = ReplicatedStorage.Utility
local BridgeNet2 = require(Utility.BridgeNet2)
local bridge = BridgeNet2.ReferenceBridge("InGameScreenService")
local actionIdentifier = BridgeNet2.ReferenceIdentifier("action")
local statusIdentifier = BridgeNet2.ReferenceIdentifier("status")
local messageIdentifier = BridgeNet2.ReferenceIdentifier("message")
-- End Bridg Net

local player = Players.LocalPlayer

local UIReferences = require(Players.LocalPlayer.PlayerScripts.Util.UIReferences)
local ClientUtil = require(Players.LocalPlayer.PlayerScripts.ClientModules.ClientUtil)
local MatchController = require(Players.LocalPlayer.PlayerScripts.ClientModules.MatchController)
local HudController = require(Players.LocalPlayer.PlayerScripts.ClientModules.HudController)
local CameraController = require(Players.LocalPlayer.PlayerScripts.ClientModules.CameraController)

local screens = {}

local screenElements = {}

local replySent = false

function InGameScreensController:Init()
	InGameScreensController:CreateReferences()
	InGameScreensController:InitBridgeListener()
	InGameScreensController:ConfigureButtonScreens()
end

function InGameScreensController:InitBridgeListener()
	bridge:Connect(function(response)
		InGameScreensController:ExecuteFunctionFromServer(response[actionIdentifier], response)
	end)
end

function InGameScreensController:ExecuteFunctionFromServer(functionName, response)
	local actions = {
		ShowGameIniting = function()
			InGameScreensController:OpenScreen("INITING_GAME")
		end,

		UpdateGameIniting = function()
			local infoTime = response.data.InfoTime
			screenElements["INITING_GAME"]["GAME_STARTING_TIME"].Text = "Game Starting (" .. infoTime .. ")"
		end,

		IntroducingPlayer = function()
			local player1Name = response.data.Player1Name
			local player2Name = response.data.Player2Name
			local tableNumber = response.data.TableNumber
			local screenDuration = response.data.ScreenDuration

			-- Labels com o nome dos jogadores
			local introducingPlayerName1 = screenElements["INTRODUCING_PLAYER"]["INTRODUCING_PLAYER_1"]
			local introducingPlayerName2 = screenElements["INTRODUCING_PLAYER"]["INTRODUCING_PLAYER_2"]
			local fightTextLabel = screens["FIGHT"]
			local introducingPlayerScreen = screens["INTRODUCING_PLAYER"]

			-- Configura a posição e nome das labels
			introducingPlayerName1.Text = player1Name
			introducingPlayerName2.Text = player2Name

			-- Abre a tela
			InGameScreensController:OpenScreen("INTRODUCING_PLAYER")

			CameraController:ShowIntroducingPlayers(
				tableNumber,
				introducingPlayerName1,
				introducingPlayerName2,
				fightTextLabel,
				introducingPlayerScreen,
				screenDuration
			)
		end,

		ShowOptions = function()
			replySent = false
			local matchTarget = response.data.MatchTarget

			local optionPaper = screenElements["GAME_OPTIONS"]["OPTION_PAPER"]
			local optionRock = screenElements["GAME_OPTIONS"]["OPTION_ROCK"]
			local optionScissors = screenElements["GAME_OPTIONS"]["OPTION_SCISSORS"]

			local currentRound = screenElements["GAME_OPTIONS"]["CURRENT_ROUND"]

			local playerResultImages = screenElements["GAME_OPTIONS"]["PLAYER_RESULT_IMAGES"]
			local timeLeft = screenElements["GAME_OPTIONS"]["TIME_LEFT"]
			-- Inicia Cronometro
			task.spawn(function()
				for i = 7, 1, -1 do
					timeLeft.Text = "TIME LEFT:" .. i
					task.wait(1)
				end

				if not replySent then
					print("ENVIANDO AUTOMÁTICAMENTE")
					local option = MatchController:SendAutomaticOption()

					if option == "PAPER" then
						optionPaper.Parent:WaitForChild("Check").Visible = true
						optionPaper.Parent.Visible = true

						optionRock.Parent.Visible = false
						optionScissors.Parent.Visible = false
					end

					if option == "ROCK" then
						optionRock.Parent:WaitForChild("Check").Visible = true
						optionRock.Parent.Visible = true

						optionPaper.Parent.Visible = false
						optionScissors.Parent.Visible = false
					end

					if option == "SCISSORS" then
						optionScissors.Parent:WaitForChild("Check").Visible = true
						optionScissors.Parent.Visible = true

						optionPaper.Parent.Visible = false
						optionRock.Parent.Visible = false
					end
				end
			end)
			-- Reconfigura a informação dos ganhadores

			for _, value in playerResultImages:GetChildren() do
				if value:GetAttribute("RUNTIME") then
					value:Destroy()
				end
			end

			for i = 1, matchTarget do
				local template = playerResultImages:WaitForChild("Template"):Clone()
				template:SetAttribute("RUNTIME", true)
				template.Visible = true
				template.Parent = playerResultImages
				template.LayoutOrder = i
				template.Name = i
			end

			for index, winner in response.data.Winners do
				task.spawn(function()
					local item = playerResultImages:WaitForChild(index)
					item.ImageLabel.Image = ""
					item.UIStrokeBlack.Enabled = false
					item.UIStrokeGreen.Enabled = true
					if winner.Name == "IA" then
						local npcId = winner:GetAttribute("ID")
						item.ImageLabel.Image = ClientUtil:GetThumb(npcId)
					else
						item.ImageLabel.Image = ClientUtil:GetThumb(winner.UserId)
					end
				end)
			end

			-- Informa o Round
			currentRound.Text = "ROUND " .. response.data.RoundNumber

			-- Reconfigura as opções
			optionPaper.Parent.Visible = true
			optionRock.Parent.Visible = true
			optionScissors.Parent.Visible = true

			optionPaper.Parent:WaitForChild("Check").Visible = false
			optionRock.Parent:WaitForChild("Check").Visible = false
			optionScissors.Parent:WaitForChild("Check").Visible = false

			-- Abre a Tela de Opções
			InGameScreensController:OpenScreen("GAME_OPTIONS")
		end,

		CloseAllScreen = function()
			InGameScreensController:CloseAllScreen()
		end,

		ShowRoundResult = function()
			local result = response.data.Result

			if result ~= "DRAW" then
				result = result .. " WON"
			end

			screenElements["ROUND_RESULT"]["ROUND_RESULT_TEXT"].Text = result
			InGameScreensController:OpenScreen("ROUND_RESULT")
		end,

		ShowMatchResult = function()
			screenElements["GAME_RESULT"]["WINNER"].Visible = false
			screenElements["GAME_RESULT"]["LOSER"].Visible = false
			screenElements["GAME_RESULT"]["WINNER_PLAYER_LEFT"].Visible = false
			screenElements["GAME_RESULT"]["WINNER_NAME"].Text = player.Name

			-- Configura a tela de resultado da partida
			local winner = response.data.Winner
			if player == winner then
				screenElements["GAME_RESULT"]["WINNER"].Visible = true
			else
				screenElements["GAME_RESULT"]["LOSER"].Visible = true
			end
			InGameScreensController:EndMatch()
		end,

		ShowMatchResultFromPlayerLeft = function()
			screenElements["GAME_RESULT"]["WINNER"].Visible = false
			screenElements["GAME_RESULT"]["LOSER"].Visible = false
			screenElements["GAME_RESULT"]["WINNER_PLAYER_LEFT"].Visible = true
			screenElements["GAME_RESULT"]["WINNER_NAME_PLAYER_LEFT"].Text = player.Name

			InGameScreensController:EndMatch()
		end,
	}

	local action = actions[functionName]

	if action then
		action()
	end
end

function InGameScreensController:CreateReferences()
	-- Tela de Aguardando Jogador
	screens["WAIT_FOR_ANOTHER_PLAYER"] = UIReferences:GetReference("WAIT_FOR_ANOTHER_PLAYER")
	screenElements["WAIT_FOR_ANOTHER_PLAYER"] = {
		["LEAVEL_BUTTON"] = UIReferences:GetReference("LEAVE_BUTTON"),
		["INVITE_FRIENDS"] = UIReferences:GetReference("INVITE_FRIENDS_BUTTON"),
		["PLAY_SOLO_BUTTON"] = UIReferences:GetReference("PLAY_SOLO_BUTTON"),
	}

	-- Tela de Iniciando Jogo
	screens["INITING_GAME"] = UIReferences:GetReference("INITING_GAME")
	screenElements["INITING_GAME"] = {
		["GAME_STARTING_TIME"] = UIReferences:GetReference("GAME_STARTING_TIME"),
	}

	-- Tela de Apresentando Jogadores
	screens["INTRODUCING_PLAYER"] = UIReferences:GetReference("INTRODUCING_PLAYER")
	screenElements["INTRODUCING_PLAYER"] = {
		["INTRODUCING_PLAYER_1"] = UIReferences:GetReference("INTRODUCING_PLAYER_1"),
		["INTRODUCING_PLAYER_2"] = UIReferences:GetReference("INTRODUCING_PLAYER_2"),
	}

	-- Tela com as opções
	screens["GAME_OPTIONS"] = UIReferences:GetReference("GAME_OPTIONS")
	screenElements["GAME_OPTIONS"] = {
		["OPTION_PAPER"] = UIReferences:GetReference("OPTION_PAPER"),
		["OPTION_ROCK"] = UIReferences:GetReference("OPTION_ROCK"),
		["OPTION_SCISSORS"] = UIReferences:GetReference("OPTION_SCISSORS"),
		["CURRENT_ROUND"] = UIReferences:GetReference("CURRENT_ROUND"),
		["PLAYER_RESULT_IMAGES"] = UIReferences:GetReference("PLAYER_RESULT_IMAGES"),
		["TIME_LEFT"] = UIReferences:GetReference("TIME_LEFT"),
	}

	-- Tela do resultado do Round
	screens["ROUND_RESULT"] = UIReferences:GetReference("ROUND_RESULT")
	screenElements["ROUND_RESULT"] = {
		["ROUND_RESULT_TEXT"] = UIReferences:GetReference("ROUND_RESULT_TEXT"),
	}

	-- Tela do resultado da Partida
	screens["GAME_RESULT"] = UIReferences:GetReference("GAME_RESULT")
	screenElements["GAME_RESULT"] = {
		["WINNER"] = UIReferences:GetReference("WINNER"),
		["LOSER"] = UIReferences:GetReference("LOSER"),
		["WINNER_PLAYER_LEFT"] = UIReferences:GetReference("WINNER_PLAYER_LEFT"),
		["WINNER_NAME"] = UIReferences:GetReference("WINNER_NAME"),
		["WINNER_NAME_PLAYER_LEFT"] = UIReferences:GetReference("WINNER_NAME_PLAYER_LEFT"),
	}

	-- Fight
	screens["FIGHT"] = UIReferences:GetReference("FIGHT")
end

function InGameScreensController:EndMatch()
	local TablesController = require(Players.LocalPlayer.PlayerScripts.ClientModules.TablesController)
	CameraController:StopCamera()
	InGameScreensController:OpenScreen("GAME_RESULT")
	task.wait(2)
	InGameScreensController:CloseAllScreen()
	TablesController:ReconfigureAllProxities()
	HudController:Show()
end

function InGameScreensController:CloseAllScreen()
	HudController:Hide()
	for _, screen in screens do
		screen.Visible = false
	end
end

function InGameScreensController:OpenScreen(screenName: string)
	if not screens[screenName] then
		warn("SCREEN NOT FOUND")
		return
	end

	-- Desliga a Hud
	HudController:Hide()

	for _, screen in screens do
		screen.Visible = false
	end

	screens[screenName].Visible = true
end

function InGameScreensController:ConfigureButtonScreens()
	local TablesController = require(Players.LocalPlayer.PlayerScripts.ClientModules.TablesController)

	local function configureWaitForAnotherPlayers()
		local leavelButton = screenElements["WAIT_FOR_ANOTHER_PLAYER"]["LEAVEL_BUTTON"]
		local inviteFriendsButton = screenElements["WAIT_FOR_ANOTHER_PLAYER"]["INVITE_FRIENDS"]
		local playSoloButton = screenElements["WAIT_FOR_ANOTHER_PLAYER"]["PLAY_SOLO_BUTTON"]

		leavelButton.MouseButton1Click:Connect(function()
			InGameScreensController:CloseAllScreen()
			TablesController:ExitTable()
			CameraController:StopCamera()
			HudController:Show()
			TablesController:ReconfigureAllProxities()
		end)

		playSoloButton.MouseButton1Click:Connect(function()
			TablesController:PlaySolo()
		end)

		inviteFriendsButton.MouseButton1Click:Connect(function()
			print("CLICK 2")
		end)
	end

	local function configureGameOptions()
		local optionPaper = screenElements["GAME_OPTIONS"]["OPTION_PAPER"]
		local optionRock = screenElements["GAME_OPTIONS"]["OPTION_ROCK"]
		local optionScissors = screenElements["GAME_OPTIONS"]["OPTION_SCISSORS"]

		optionPaper.MouseButton1Click:Connect(function()
			replySent = true
			-- Esconde os outros
			optionRock.Parent.Visible = false
			optionScissors.Parent.Visible = false

			-- Exibe o Check
			optionPaper.Parent:WaitForChild("Check").Visible = true

			-- Envia a Opção para o servidor
			MatchController:SendOption("PAPER")
		end)

		optionRock.MouseButton1Click:Connect(function()
			replySent = true

			-- Esconde os outros
			optionPaper.Parent.Visible = false
			optionScissors.Parent.Visible = false

			-- Exibe o Check
			optionRock.Parent:WaitForChild("Check").Visible = true

			-- Envia a Opção para o servidor
			MatchController:SendOption("ROCK")
		end)

		optionScissors.MouseButton1Click:Connect(function()
			replySent = true

			-- Esconde os outros
			optionPaper.Parent.Visible = false
			optionRock.Parent.Visible = false

			-- Exibe o Check
			optionScissors.Parent:WaitForChild("Check").Visible = true

			-- Envia a Opção para o servidor
			MatchController:SendOption("SCISSORS")
		end)
	end

	configureWaitForAnotherPlayers()
	configureGameOptions()
end

return InGameScreensController
