local AnimationService = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ContentProvider = game:GetService("ContentProvider")

local UtilService = require(ServerScriptService.Modules.UtilService)

-- Guarda os tracks ativos de cada jogador: playerTracks[player] = { track1, track2, ... }
local playerTracks = {}

-- Geração atual de cada player; usada para cancelar sequências em andamento
local playerGeneration = {}

-- Tracks PRÉ-CARREGADOS por jogador (carregados uma vez quando entra/respawna).
-- preloadedTracks[player] = { animator = Animator, byKey = { ["JOKENPO/START"] = track, ... } }
local preloadedTracks = {}

local animationsIds = {
	["SCISSORS"] = {
		CAMERA = UtilService:WaitForDescendants(workspace, "Animations", "Wins", "Scissors", "Camera"),
		WINNER = UtilService:WaitForDescendants(workspace, "Animations", "Wins", "Scissors", "Winner"),
		LOSER = UtilService:WaitForDescendants(workspace, "Animations", "Wins", "Scissors", "Loser"),
	},

	["PAPER"] = {
		CAMERA = UtilService:WaitForDescendants(workspace, "Animations", "Wins", "Paper", "Camera"),
		WINNER = UtilService:WaitForDescendants(workspace, "Animations", "Wins", "Paper", "Winner"),
		LOSER = UtilService:WaitForDescendants(workspace, "Animations", "Wins", "Paper", "Loser"),
	},

	["ROCK"] = {
		CAMERA = UtilService:WaitForDescendants(workspace, "Animations", "Wins", "Rock", "Camera"),
		WINNER = UtilService:WaitForDescendants(workspace, "Animations", "Wins", "Rock", "Winner"),
		LOSER = UtilService:WaitForDescendants(workspace, "Animations", "Wins", "Rock", "Loser"),
	},
	["JOKENPO"] = {
		START = {
			Id = UtilService:WaitForDescendants(workspace, "Animations", "WaitingOptions", "Start"),
			Priority = Enum.AnimationPriority.Action3,
		},
		LOOP_START = {
			Id = UtilService:WaitForDescendants(workspace, "Animations", "WaitingOptions", "LoopStart"),
			Priority = Enum.AnimationPriority.Action3,
		},
		END = {
			Id = UtilService:WaitForDescendants(workspace, "Animations", "WaitingOptions", "End"),
			Priority = Enum.AnimationPriority.Action4,
		},
		LOOP_END = {
			Id = UtilService:WaitForDescendants(workspace, "Animations", "WaitingOptions", "LoopEnd"),
			Priority = Enum.AnimationPriority.Action4,
		},
	},
}

-- Lê uma entrada de animationsIds. Aceita dois formatos:
--  - NumberValue puro (SCISSORS/PAPER/ROCK): usa prioridade padrão Action4.
--  - Tabela { Id = NumberValue, Priority = Enum } (JOKENPO): usa a prioridade da entrada.
-- Retorna (idValue: number?, priority: Enum.AnimationPriority).
local function resolveEntry(entry)
	if typeof(entry) == "Instance" and entry:IsA("NumberValue") then
		return entry.Value, Enum.AnimationPriority.Action4
	end

	if type(entry) == "table" and entry.Id then
		local id = entry.Id
		if typeof(id) == "Instance" and id:IsA("NumberValue") then
			id = id.Value
		end
		if type(id) == "number" then
			return id, entry.Priority or Enum.AnimationPriority.Action4
		end
	end

	return nil, Enum.AnimationPriority.Action4
end

-- Resolve (ou cria) o Animator do personagem do jogador.
local function getAnimator(character): Animator?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end

	animator = Instance.new("Animator")
	animator.Parent = humanoid

	return animator
end

-- Pré-carrega TODAS as animações no Animator do jogador e guarda os tracks prontos.
-- Deve ser chamado quando o jogador entra e a cada respawn (o respawn troca o Animator).
function AnimationService:PreLoadAnimations(character)
	local animator = getAnimator(character)
	if not animator then
		return
	end

	local byKey = {}

	for animationType, names in animationsIds do
		for animationName, entry in names do
			local idValue, priority = resolveEntry(entry)
			if idValue then
				local key = animationType .. "/" .. animationName

				local animation = Instance.new("Animation")
				animation.AnimationId = "rbxassetid://" .. idValue

				-- IMPORTANTE: LoadAnimation NÃO baixa o asset; o download só ocorre no
				-- :Play() (ou aqui). Por isso Length ficava 0 e Priority/Looping não
				-- aplicavam. PreloadAsync força o download e deixa o track 100% pronto.
				local ok = pcall(function()
					ContentProvider:PreloadAsync({ animation })
				end)
				if not ok then
					warn(("[ANIM] %s falhou no PreloadAsync. Id=%s"):format(key, tostring(idValue)))
				end

				local track = animator:LoadAnimation(animation)
				track.Name = key

				-- Aplica a prioridade definida por animação (START/LOOP_START = Action3,
				-- END/LOOP_END = Action4). END > LOOP_START faz o END sobrepor o loop
				-- anterior na troca de sequência, sem mistura de poses.
				pcall(function()
					track.Priority = priority
				end)

				byKey[key] = track
			end
		end
	end

	preloadedTracks[character] = {
		animator = animator,
		byKey = byKey,
	}
end

-- Retorna um track já pré-carregado. Se ainda não houver (ou o personagem respawnou
-- e o Animator mudou), pré-carrega na hora como rede de segurança.
local function getPreloadedTrack(character, animationType: string, animationName: string)
	local data = preloadedTracks[character]

	-- Cache inválido se o Animator atual for diferente do que carregou os tracks.
	if data then
		local currentAnimator = getAnimator(character)
		if not currentAnimator or data.animator ~= currentAnimator then
			data = nil
		end
	end

	if not data then
		AnimationService:PreLoadAnimations(character)
		data = preloadedTracks[character]
	end

	if not data then
		return nil
	end

	return data.byKey[animationType .. "/" .. animationName]
end

function AnimationService:PlayPlayerAnimationFromPlayer(
	player: Player,
	animations: { { AnimationType: string, AnimationName: string } }
)
	AnimationService:PlayPlayerAnimation(player.Character, animations)
end

function AnimationService:PlayPlayerAnimation(
	character,
	animations: { { AnimationType: string, AnimationName: string } }
)
	playerGeneration[character] = (playerGeneration[character] or 0) + 1
	local myGeneration = playerGeneration[character]

	local CROSSFADE = 0.2
	-- Quanto tempo o loop da sequência anterior continua tocando por baixo depois que a
	-- nova sequência entra. Cobre a "pausa"/load do END no cliente: o END entra primeiro
	-- e só paramos o loop anterior depois disso, pra não sobrar buraco (sit).
	local HANDOFF_HOLD = 0.35

	local tracks = {}

	for _, animationInfo in ipairs(animations) do
		local track = getPreloadedTrack(character, animationInfo.AnimationType, animationInfo.AnimationName)

		if not track then
			warn(
				("Animação não pré-carregada: %s/%s"):format(
					tostring(animationInfo.AnimationType),
					tostring(animationInfo.AnimationName)
				)
			)
			return
		end

		table.insert(tracks, track)
	end

	-- Guarda a sequência anterior para encerrá-la quando a nova entrar.
	local previousSequence = playerTracks[character]

	playerTracks[character] = tracks

	local lastTrack

	for index, track in ipairs(tracks) do
		lastTrack = track

		if index == 1 then
			-- Toca a NOVA sequência primeiro (em weight cheio).
			track:Play(0)

			-- ...e só para o loop ANTERIOR DEPOIS de um instante (HANDOFF_HOLD). O END
			-- leva um tempinho pra carregar/aparecer no cliente (a "pausa"); se pararmos o
			-- LOOP_START antes disso, o cliente fica sem animação e o sit aparece. Mantendo
			-- o LOOP_START tocando por baixo até o END entrar, o fundo fica sempre coberto.
			-- Como END (Action4) > LOOP_START (Action3), o END domina por cima: o loop
			-- anterior fica invisível, só servindo de rede. Depois é parado com fade.
			if previousSequence then
				local toStop = {}
				for _, previousTrack in ipairs(previousSequence) do
					if previousTrack ~= track and previousTrack.IsPlaying then
						table.insert(toStop, previousTrack)
					end
				end

				if #toStop > 0 then
					task.delay(HANDOFF_HOLD, function()
						if playerGeneration[character] ~= myGeneration then
							return
						end
						for _, previousTrack in ipairs(toStop) do
							if previousTrack.IsPlaying then
								previousTrack:Stop(CROSSFADE)
							end
						end
					end)
				end
			end
		else
			track:Play(CROSSFADE)

			local previousTrack = tracks[index - 1]

			task.delay(CROSSFADE, function()
				if previousTrack and previousTrack.IsPlaying and playerGeneration[character] == myGeneration then
					previousTrack:Stop(0)
				end
			end)
		end

		if index < #tracks then
			local timeout = 0

			while track.Length <= 0 and timeout < 5 do
				timeout += task.wait()

				if playerGeneration[character] ~= myGeneration then
					track:Stop(0)
					return track
				end
			end

			local waitTime = math.max(track.Length - CROSSFADE, 0)

			task.wait(waitTime)

			if playerGeneration[character] ~= myGeneration then
				track:Stop(0)
				return track
			end
		end
	end

	return lastTrack
end

function AnimationService:StopPlayerAnimations(character)
	playerGeneration[character] = (playerGeneration[character] or 0) + 1

	local tracks = playerTracks[character]

	if not tracks then
		return
	end

	for _, track in ipairs(tracks) do
		if track.IsPlaying then
			track:Stop(0.15)
		end
	end

	playerTracks[character] = nil
end

-- Limpa todo o cache do jogador. Chame no PlayerRemoving.
function AnimationService:CleanupPlayer(character)
	playerGeneration[character] = (playerGeneration[character] or 0) + 1

	local active = playerTracks[character]
	if active then
		for _, track in active do
			if track.IsPlaying then
				track:Stop(0)
			end
		end
		playerTracks[character] = nil
	end

	local data = preloadedTracks[character]
	if data then
		for _, track in data.byKey do
			track:Destroy()
		end
		preloadedTracks[character] = nil
	end

	playerGeneration[character] = nil
end

-- Toca a animação de vitória/derrota correspondente ao tipo de vitória.
-- winType: "SCISSORS", "PAPER" ou "ROCK".
-- winnerCharacter: personagem que ganhou (toca a animação WINNER).
-- loserCharacter: personagem que perdeu (toca a animação LOSER).
-- SEGURA (yield) ate a animacao terminar: vencedor e perdedor tocam ao mesmo
-- tempo e o metodo so retorna quando a mais longa das duas acabar.
-- Toca as animacoes de vitoria correspondentes ao tipo de vitoria, SINCRONIZADAS:
-- WINNER (vencedor), LOSER (perdedor) e CAMERA (num clone do CameraRig na cadeira).
-- winType: "SCISSORS", "PAPER" ou "ROCK".
-- winnerCharacter: personagem que ganhou (toca a animacao WINNER).
-- loserCharacter: personagem que perdeu (toca a animacao LOSER).
-- winnerSide: lado do vencedor na mesa (1 ou 2) -> escolhe Chair1/Chair2.
-- tableNumber: numero da mesa (1..16) -> escolhe qual GameTable usar.
-- isPlayerSolo: reservado (partida contra a IA).
-- SEGURA (yield): as tres animacoes comecam juntas e o metodo so retorna quando
-- a mais longa delas terminar.
function AnimationService:PlayWinAnimation(
	winType: string,
	winnerCharacter: Model,
	loserCharacter: Model,
	winnerSide: string,
	tableNumber: number,
	isPlayerSolo: boolean
)
	local entries = animationsIds[winType]
	if not entries or not entries.WINNER or not entries.LOSER then
		warn(("[ANIM] Tipo de vitoria invalido: %s"):format(tostring(winType)))
		return
	end

	local pending = 0

	-- Toca a animacao e espera ela terminar (dentro do proprio thread).
	local function playAndWait(character: Model, animationName: string)
		pending += 1

		task.spawn(function()
			local track = AnimationService:PlayPlayerAnimation(character, {
				{ AnimationType = winType, AnimationName = animationName },
			})

			if track then
				-- Length so fica > 0 apos o asset carregar; espera carregar.
				local timeout = 0
				while track.Length <= 0 and timeout < 5 do
					timeout += task.wait()
				end

				-- Espera o tempo restante da animacao (uma passada completa).
				if track.Length > 0 then
					task.wait(math.max(track.Length - track.TimePosition, 0))
				end
			end

			pending -= 1
		end)
	end

	-- Toca a animacao de CAMERA num clone do CameraRig, posicionado na cadeira do
	-- lado vencedor. O rig e: RootPart -> Motor6D(CameraRoot) -> CameraRoot (Part).
	-- A animacao move a Part CameraRoot; a camera do cliente deve seguir essa Part.
	local function playCameraAndWait(cameraId: number)
		pending += 1

		task.spawn(function()
			-- Cadeira/ancora: mesa = tableNumber, lado = winnerSide (Chair1 ou Chair2).
			local chairAnimationPart = UtilService:WaitForDescendants(
				workspace,
				"Map",
				"GameTables",
				tableNumber,
				"Cameras",
				"Animation",
				"Chair" .. tostring(winnerSide)
			)

			-- Clona o rig de camera e posiciona o RootPart na cadeira;
			-- o CameraRoot (parte animada) acompanha pelo Motor6D.
			local rigTemplate = UtilService:WaitForDescendants(workspace, "Animations", "Rig", "Camera", "CameraRig")
			local rig = rigTemplate:Clone()
			rig.RootPart.CFrame = chairAnimationPart.CFrame
			-- Parenteia na pasta Animation da mesa para o cliente achar o rig por mesa
			-- (o cliente segue a Part CameraRoot deste clone).
			rig.Parent = chairAnimationPart.Parent

			local animator = rig.AnimationController.Animator
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://" .. cameraId

			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Action4
			track:Play(0)

			-- Espera carregar (Length > 0) e depois o tempo restante da animacao.
			local timeout = 0
			while track.Length <= 0 and timeout < 5 do
				timeout += task.wait()
			end
			if track.Length > 0 then
				task.wait(math.max(track.Length - track.TimePosition, 0))
			end

			rig:Destroy()
			pending -= 1
		end)
	end

	-- Dispara as 3 animacoes AO MESMO TEMPO (sincronizadas).
	if winnerCharacter then
		playAndWait(winnerCharacter, "WINNER")
	end

	if loserCharacter then
		playAndWait(loserCharacter, "LOSER")
	end

	-- Camera: so toca se tivermos o id da animacao, a mesa e o lado vencedor.
	local cameraId = resolveEntry(entries.CAMERA)
	if cameraId and tableNumber and winnerSide then
		-- Avisa o(s) cliente(s) para seguir a Part CameraRoot do rig durante a cutscene.
		local Players = game:GetService("Players")
		local CameraService = require(ServerScriptService.Modules.CameraService)

		local winnerPlayer = winnerCharacter and Players:GetPlayerFromCharacter(winnerCharacter)
		local loserPlayer = loserCharacter and Players:GetPlayerFromCharacter(loserCharacter)

		if isPlayerSolo then
			-- Um dos personagens e o NPC; avisa apenas o jogador real.
			local realPlayer = winnerPlayer or loserPlayer
			if realPlayer then
				CameraService:ShowCameraAnimationFromPlayerSolo(realPlayer, tableNumber)
			end
		elseif winnerPlayer and loserPlayer then
			CameraService:ShowCameraAnimation(winnerPlayer, loserPlayer, tableNumber)
		end

		playCameraAndWait(cameraId)
	elseif not cameraId then
		warn(("[ANIM] Animacao CAMERA ausente para %s"):format(tostring(winType)))
	end

	-- Segura ate TODAS (winner, loser e camera) terminarem -- a mais longa das tres.
	while pending > 0 do
		task.wait()
	end
end

return AnimationService
