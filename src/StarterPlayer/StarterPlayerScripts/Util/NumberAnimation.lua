local NumberAnimation = {}

function NumberAnimation:Animate(TextLabel, newValue, animationDuration)
	animationDuration = animationDuration or 1 -- Define uma duração padrão, caso não seja passada
	local currentValue = tonumber(TextLabel.Text) or 0 -- Obtém o valor atual exibido (ou 0 se inválido)
	local elapsedTime = 0

	while elapsedTime < animationDuration do
		elapsedTime += task.wait() -- Incrementa com o tempo decorrido
		local progress = math.min(elapsedTime / animationDuration, 1) -- Progresso da animação (0 a 1)
		local interpolatedValue = math.floor(currentValue + (newValue - currentValue) * progress) -- Interpolação linear
		TextLabel.Text = tostring(interpolatedValue) -- Atualiza o texto do TextLabel
	end

	TextLabel.Text = tostring(newValue)
end

return NumberAnimation
