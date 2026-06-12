local CameraController = {}

-- Init Bridg Net
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = ReplicatedStorage.Utility
local BridgeNet2 = require(Utility.BridgeNet2)
local bridge = BridgeNet2.ReferenceBridge("CameraService")
local actionIdentifier = BridgeNet2.ReferenceIdentifier("action")
local statusIdentifier = BridgeNet2.ReferenceIdentifier("status")
local messageIdentifier = BridgeNet2.ReferenceIdentifier("message")
-- End Bridg Net

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ClientUtil = require(Players.LocalPlayer.PlayerScripts.ClientModules.ClientUtil)

CameraController.CurrentRenderConnection = nil
CameraController.CurrentTween = nil

function CameraController:Init()
	CameraController:InitBridgeListener()
end

function CameraController:InitBridgeListener()
	bridge:Connect(function(response)
		if response[actionIdentifier] == "SetInGame" then
			local tableNumber = response.data.TableNumber
			CameraController:ShowInGame(tableNumber)
		end
	end)
end

function CameraController:StopCamera()
	if self.CurrentRenderConnection then
		self.CurrentRenderConnection:Disconnect()
		self.CurrentRenderConnection = nil
	end

	if self.CurrentTween then
		self.CurrentTween:Cancel()
		self.CurrentTween = nil
	end

	RunService:UnbindFromRenderStep("Camera")

	-- Devolve a câmera ao padrão (volta a seguir o personagem)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

function CameraController:ShowWaitingForPlayerCamera(tableNumber: number)
	self:StopCamera()

	local cameraRef =
		ClientUtil:WaitForDescendants(workspace, "Map", "GameTables", tableNumber, "Cameras", "Orbit", "Ref")

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 75

	local target = cameraRef

	local radius = 8
	local height = 3
	local speed = 0.1

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	local angle = 0

	if rootPart then
		local lookVector = rootPart.CFrame.LookVector

		local direction = -Vector3.new(lookVector.X, 0, lookVector.Z).Unit

		angle = math.atan2(direction.Z, direction.X)
	end

	local startX = math.cos(angle) * radius
	local startZ = math.sin(angle) * radius

	local startPosition = target.Position + Vector3.new(startX, height, startZ)

	camera.CFrame = CFrame.lookAt(startPosition, target.Position + Vector3.new(0, 1, 0))

	self.CurrentRenderConnection = RunService.RenderStepped:Connect(function(dt)
		angle += dt * speed

		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local y = height + math.sin(angle * 2) * 0.25

		local cameraPosition = target.Position + Vector3.new(x, y, z)

		local targetCFrame = CFrame.lookAt(cameraPosition, target.Position + Vector3.new(0, 1, 0))

		camera.CFrame = camera.CFrame:Lerp(targetCFrame, dt * 3)
	end)
end

function CameraController:ShowIntroducingPlayers(
	tableNumber: number,
	introducingPlayerName1: TextLabel,
	introducingPlayerName2: TextLabel,
	fightTextLabel: TextLabel,
	introducingPlayerScreen: Frame,
	duration: number
)
	introducingPlayerName1.Position = UDim2.fromScale(0.332, 1.5)
	introducingPlayerName2.Position = UDim2.fromScale(0.666, 1.5)

	-- Deixa a label invisível e centralizada para o punch de escala
	-- (Size = {1,0},{1,0} -> continua cobrindo a tela inteira)
	fightTextLabel.Visible = false
	fightTextLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	fightTextLabel.Position = UDim2.fromScale(0.5, 0.5)
	fightTextLabel.BackgroundTransparency = 1
	fightTextLabel.TextTransparency = 1
	fightTextLabel.TextStrokeTransparency = 1

	local fightScale = fightTextLabel:FindFirstChildOfClass("UIScale")
	if not fightScale then
		fightScale = Instance.new("UIScale")
		fightScale.Parent = fightTextLabel
	end
	fightScale.Scale = 1

	self:StopCamera()

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 75

	local camerasFolder = ClientUtil:WaitForDescendants(workspace, "Map", "GameTables", tableNumber, "Cameras")

	local pointA = camerasFolder.IntroducingPlayers.StartRef
	local pointB = camerasFolder.IntroducingPlayers.EndRef

	camera.CFrame = pointA.CFrame

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local tween = TweenService:Create(camera, tweenInfo, {
		CFrame = pointB.CFrame,
	})

	self.CurrentTween = tween

	local function animateLabel(textLabel: TextLabel)
		local originalPosition = textLabel.Position

		local targetY = 0.5
		local overshootY = targetY - 0.03

		local tweenUp =
			TweenService:Create(textLabel, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(originalPosition.X.Scale, overshootY),
			})

		local tweenBack =
			TweenService:Create(textLabel, TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(originalPosition.X.Scale, targetY),
			})

		tweenUp:Play()

		tweenUp.Completed:Once(function()
			tweenBack:Play()
		end)
	end

	tween.Completed:Connect(function()
		if self.CurrentTween == tween then
			self.CurrentTween = nil
		end
	end)

	tween:Play()

	-- 10% da animação
	task.delay(duration * 0.1, function()
		if self.CurrentTween ~= tween then
			return
		end

		animateLabel(introducingPlayerName1)
	end)

	-- 50% da animação
	task.delay(duration * 0.5, function()
		if self.CurrentTween ~= tween then
			return
		end

		animateLabel(introducingPlayerName2)
	end)

	-- 75% da animação -- entrada cinematográfica do "Fight!"
	task.delay(duration * 0.75, function()
		if self.CurrentTween ~= tween then
			return
		end

		-- Começa um pouco maior e transparente, depois assenta
		fightScale.Scale = 1.75
		fightTextLabel.Visible = true

		local impactTime = duration * 0.12
		local holdTime = duration * 0.06
		local fadeOutTime = duration * 0.12

		-- Impacto: a escala desacelera até assentar (Quint) enquanto tudo aparece
		local scaleIn = TweenService:Create(
			fightScale,
			TweenInfo.new(impactTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{
				Scale = 1,
			}
		)

		local fadeIn = TweenService:Create(
			fightTextLabel,
			TweenInfo.new(impactTime * 0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{
				TextTransparency = 0,
				TextStrokeTransparency = 0,
				BackgroundTransparency = 0,
			}
		)

		scaleIn:Play()
		fadeIn:Play()

		-- Esconde os nomes enquanto o "Fight!" cobre a tela, para que não
		-- reapareçam atrás dele durante o fade-out de saída
		fadeIn.Completed:Once(function()
			introducingPlayerScreen.Visible = false
		end)

		scaleIn.Completed:Once(function()
			task.delay(holdTime, function()
				if self.CurrentTween ~= tween then
					return
				end

				-- Troca para a câmera de jogo enquanto o "Fight!" ainda cobre a
				-- tela inteira (fundo preto opaco), então o jogador não vê a câmera
				-- mudando de posição. O fade-out a seguir revela a câmera de jogo.
				self:ShowInGame(tableNumber)

				-- Saída: dissolve crescendo levemente
				local scaleOut = TweenService:Create(
					fightScale,
					TweenInfo.new(fadeOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{
						Scale = 1.15,
					}
				)

				local fadeOut = TweenService:Create(
					fightTextLabel,
					TweenInfo.new(fadeOutTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
					{
						TextTransparency = 1,
						TextStrokeTransparency = 1,
						BackgroundTransparency = 1,
					}
				)

				scaleOut:Play()
				fadeOut:Play()

				fadeOut.Completed:Once(function()
					fightTextLabel.Visible = false
					fightScale.Scale = 1
				end)
			end)
		end)
	end)

	-- Aguarda o tempo total da animação por tempo fixo, e NÃO pelo Completed
	-- do tween da câmera: o SetInGame chama StopCamera e cancela esse tween,
	-- e um tween cancelado não dispara Completed de forma confiável -- o que
	-- antes deixava os nomes presos na tela.
	task.wait(duration)

	-- Garantia final (caso a sequência do "Fight!" tenha sido pulada pelo guard)
	introducingPlayerScreen.Visible = false
end

function CameraController:ShowInGame(tableNumber: number)
	self:StopCamera()

	local inGameCamera =
		ClientUtil:WaitForDescendants(workspace, "Map", "GameTables", tableNumber, "Cameras", "InGame", "Ref")

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 75

	-- câmera totalmente fixa
	camera.CFrame = inGameCamera.CFrame
end

return CameraController
