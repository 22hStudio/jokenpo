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
local function getAnimator(player: Player): Animator?
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	return animator
end

-- Pré-carrega TODAS as animações no Animator do jogador e guarda os tracks prontos.
-- Deve ser chamado quando o jogador entra e a cada respawn (o respawn troca o Animator).
function AnimationService:PreLoadAnimations(player: Player)
	local animator = getAnimator(player)
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

	preloadedTracks[player] = {
		animator = animator,
		byKey = byKey,
	}
end

-- Retorna um track já pré-carregado. Se ainda não houver (ou o personagem respawnou
-- e o Animator mudou), pré-carrega na hora como rede de segurança.
local function getPreloadedTrack(player: Player, animationType: string, animationName: string)
	local data = preloadedTracks[player]

	-- Cache inválido se o Animator atual for diferente do que carregou os tracks.
	if data then
		local currentAnimator = getAnimator(player)
		if not currentAnimator or data.animator ~= currentAnimator then
			data = nil
		end
	end

	if not data then
		AnimationService:PreLoadAnimations(player)
		data = preloadedTracks[player]
	end

	if not data then
		return nil
	end

	return data.byKey[animationType .. "/" .. animationName]
end

function AnimationService:PlayPlayerAnimation(
	player: Player,
	animations: { { AnimationType: string, AnimationName: string } }
)
	playerGeneration[player] = (playerGeneration[player] or 0) + 1
	local myGeneration = playerGeneration[player]

	local CROSSFADE = 0.2
	-- Quanto tempo o loop da sequência anterior continua tocando por baixo depois que a
	-- nova sequência entra. Cobre a "pausa"/load do END no cliente: o END entra primeiro
	-- e só paramos o loop anterior depois disso, pra não sobrar buraco (sit).
	local HANDOFF_HOLD = 0.35

	local tracks = {}

	for _, animationInfo in ipairs(animations) do
		local track = getPreloadedTrack(player, animationInfo.AnimationType, animationInfo.AnimationName)

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
	local previousSequence = playerTracks[player]

	playerTracks[player] = tracks

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
						if playerGeneration[player] ~= myGeneration then
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
				if previousTrack and previousTrack.IsPlaying and playerGeneration[player] == myGeneration then
					previousTrack:Stop(0)
				end
			end)
		end

		if index < #tracks then
			local timeout = 0

			while track.Length <= 0 and timeout < 5 do
				timeout += task.wait()

				if playerGeneration[player] ~= myGeneration then
					track:Stop(0)
					return track
				end
			end

			local waitTime = math.max(track.Length - CROSSFADE, 0)

			task.wait(waitTime)

			if playerGeneration[player] ~= myGeneration then
				track:Stop(0)
				return track
			end
		end
	end

	return lastTrack
end

function AnimationService:StopPlayerAnimations(player: Player)
	playerGeneration[player] = (playerGeneration[player] or 0) + 1

	local tracks = playerTracks[player]

	if not tracks then
		return
	end

	for _, track in ipairs(tracks) do
		if track.IsPlaying then
			track:Stop(0.15)
		end
	end

	playerTracks[player] = nil
end

-- Limpa todo o cache do jogador. Chame no PlayerRemoving.
function AnimationService:CleanupPlayer(player: Player)
	playerGeneration[player] = (playerGeneration[player] or 0) + 1

	local active = playerTracks[player]
	if active then
		for _, track in active do
			if track.IsPlaying then
				track:Stop(0)
			end
		end
		playerTracks[player] = nil
	end

	local data = preloadedTracks[player]
	if data then
		for _, track in data.byKey do
			track:Destroy()
		end
		preloadedTracks[player] = nil
	end

	playerGeneration[player] = nil
end

return AnimationService
