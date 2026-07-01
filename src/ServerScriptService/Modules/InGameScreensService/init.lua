local InGameScreensServices = {}

-- Init Bridg Net
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = ReplicatedStorage.Utility
local BridgeNet2 = require(Utility.BridgeNet2)
local bridge = BridgeNet2.ReferenceBridge("InGameScreenService")
local actionIdentifier = BridgeNet2.ReferenceIdentifier("action")
local statusIdentifier = BridgeNet2.ReferenceIdentifier("status")
local messageIdentifier = BridgeNet2.ReferenceIdentifier("message")
-- End Bridg Net

function InGameScreensServices:Init() end

function InGameScreensServices:ShowGameInitingFromPlayerSolo(player1: Player, screenDuration)
	bridge:Fire(player1, {
		[actionIdentifier] = "ShowGameIniting",
	})

	for i = screenDuration, 1, -1 do
		bridge:Fire(player1, {
			[actionIdentifier] = "UpdateGameIniting",
			data = {
				InfoTime = i,
			},
		})

		task.wait(1)
	end
end

function InGameScreensServices:ShowGameIniting(player1: Player, player2: Player, screenDuration)
	bridge:Fire(player1, {
		[actionIdentifier] = "ShowGameIniting",
	})

	bridge:Fire(player2, {
		[actionIdentifier] = "ShowGameIniting",
	})

	for i = screenDuration, 1, -1 do
		bridge:Fire(player1, {
			[actionIdentifier] = "UpdateGameIniting",
			data = {
				InfoTime = i,
			},
		})

		bridge:Fire(player2, {
			[actionIdentifier] = "UpdateGameIniting",
			data = {
				InfoTime = i,
			},
		})
		task.wait(1)
	end
end

function InGameScreensServices:ShowIntroducingPlayersFromPlayerSolo(
	player1: Player,
	screenDuration: number,
	tableNumber: number
)
	bridge:Fire(player1, {
		[actionIdentifier] = "IntroducingPlayer",
		data = {
			Player1Name = player1.Name,
			Player2Name = "AI",
			TableNumber = tableNumber,
			ScreenDuration = screenDuration,
		},
	})

	task.wait(screenDuration + 1)
end

function InGameScreensServices:ShowIntroducingPlayers(
	player1: Player,
	player2: Player,
	screenDuration: number,
	tableNumber: number
)
	bridge:Fire(player1, {
		[actionIdentifier] = "IntroducingPlayer",
		data = {
			Player1Name = player1.Name,
			Player2Name = player2.Name,
			TableNumber = tableNumber,
			ScreenDuration = screenDuration,
		},
	})

	bridge:Fire(player2, {
		[actionIdentifier] = "IntroducingPlayer",
		data = {
			Player1Name = player1.Name,
			Player2Name = player2.Name,
			TableNumber = tableNumber,
			ScreenDuration = screenDuration,
		},
	})

	task.wait(screenDuration + 1)
end

function InGameScreensServices:ShowOptionsFromPlayerSolor(
	player1: Player,
	matchTarget: number,
	roundNumber: number,
	winners
)
	bridge:Fire(player1, {
		[actionIdentifier] = "ShowOptions",
		data = {
			RoundNumber = roundNumber,
			Winners = winners,
			MatchTarget = matchTarget,
		},
	})
end

function InGameScreensServices:ShowOptions(
	player1: Player,
	player2: Player,
	matchTarget: number,
	roundNumber: number,
	winners
)
	bridge:Fire(player1, {
		[actionIdentifier] = "ShowOptions",
		data = {
			RoundNumber = roundNumber,
			Winners = winners,
			MatchTarget = matchTarget,
		},
	})

	bridge:Fire(player2, {
		[actionIdentifier] = "ShowOptions",
		data = {
			RoundNumber = roundNumber,
			Winners = winners,
			MatchTarget = matchTarget,
		},
	})
end

function InGameScreensServices:CloseAllScreenFromPlayerSolo(player1: Player)
	bridge:Fire(player1, {
		[actionIdentifier] = "CloseAllScreen",
	})
end

function InGameScreensServices:CloseAllScreen(player1: Player, player2: Player)
	bridge:Fire(player1, {
		[actionIdentifier] = "CloseAllScreen",
	})

	bridge:Fire(player2, {
		[actionIdentifier] = "CloseAllScreen",
	})
end

function InGameScreensServices:ShowRoundResult(player1: Player, player2: Player, result: string)
	bridge:Fire(player1, {
		[actionIdentifier] = "ShowRoundResult",
		data = {
			Result = result,
		},
	})

	bridge:Fire(player2, {
		[actionIdentifier] = "ShowRoundResult",
		data = {
			Result = result,
		},
	})
end

function InGameScreensServices:ShowRoundResultFromPlayerSolo(player1: Player, result: string)
	bridge:Fire(player1, {
		[actionIdentifier] = "ShowRoundResult",
		data = {
			Result = result,
		},
	})
end

function InGameScreensServices:ShowMatchResult(player1: Player, player2: Player, winner: string)
	bridge:Fire(player1, {
		[actionIdentifier] = "ShowMatchResult",
		data = {
			Winner = winner,
		},
	})

	bridge:Fire(player2, {
		[actionIdentifier] = "ShowMatchResult",
		data = {
			Winner = winner,
		},
	})
end

function InGameScreensServices:ShowMatchResultFromPlayerSolo(player1: Player, winner: string)
	bridge:Fire(player1, {
		[actionIdentifier] = "ShowMatchResult",
		data = {
			Winner = winner,
		},
	})
end

function InGameScreensServices:ShowMatchResultFromPlayerLeft(player: Player)
	bridge:Fire(player, {
		[actionIdentifier] = "ShowMatchResultFromPlayerLeft",
	})
end

return InGameScreensServices
