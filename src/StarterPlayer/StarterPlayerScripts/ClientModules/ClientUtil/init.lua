local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ClientUtil = {}

local thumbCache = {}

function ClientUtil:Init() end

function ClientUtil:WaitForDescendants(root, ...)
	local names = { ... }
	local current = root

	for _, name in ipairs(names) do
		current = current:WaitForChild(name)

		while not current do
			current = current:WaitForChild(name)
		end
	end

	return current
end

function ClientUtil:FormatToUSD(number)
	local formatted = string.format("%.2f", number)
	local beforeDecimal, afterDecimal = formatted:match("^(%-?%d+)%.*(%d*)$")
	beforeDecimal = beforeDecimal:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if beforeDecimal:sub(1, 1) == "," then
		beforeDecimal = beforeDecimal:sub(2)
	end
	return "$" .. beforeDecimal .. "." .. afterDecimal
end

function ClientUtil:FormatSecondsToMinutes(seconds)
	local minutes = math.floor(seconds / 60)
	local remainingSeconds = seconds % 60
	return string.format("%02dm:%02ds", minutes, remainingSeconds)
end

function ClientUtil:GetThumb(playerId: number)
	if thumbCache[playerId] then
		return thumbCache[playerId]
	end

	local thumbType = Enum.ThumbnailType.HeadShot
	local thumbSize = Enum.ThumbnailSize.Size420x420
	local content, isReady = Players:GetUserThumbnailAsync(playerId, thumbType, thumbSize)

	if content and isReady then
		thumbCache[playerId] = content
		return content
	end

	return nil
end

function ClientUtil:SortList(list, property, reverse)
	table.sort(list, function(a, b)
		local valueA = a[property]
		local valueB = b[property]

		if reverse then
			return valueA > valueB
		end

		return valueA < valueB
	end)

	return list
end

function ClientUtil:FormatNumberToSuffixes(n)
	local suffixes = { "", "K", "M", "B", "T", "Q" } -- pode adicionar mais se quiser
	local i = 1

	while n >= 1000 and i < #suffixes do
		n = n / 1000
		i = i + 1
	end

	-- Limita para 0 casa decimal e remove .0 se for inteiro
	local formatted = string.format("%.0f", n)
	formatted = formatted:gsub("%.0$", "")

	return formatted .. suffixes[i]
end

function ClientUtil:Color3(a, b, c)
	return Color3.new(a / 255, b / 255, c / 255)
end

function ClientUtil:GetPlayerNameById(playerId)
	local success, playerName = pcall(function()
		return Players:GetNameFromUserIdAsync(playerId)
	end)

	if success then
		return playerName
	end
end

function ClientUtil:PlayLabelBounceAnimation(textLabel1: TextLabel, textLabel2: TextLabel?, delayBetween: number?)
	delayBetween = delayBetween or 1

	local function playAnimation(textLabel: TextLabel, callback)
		local originalPosition = textLabel.Position

		local targetY = 0.5
		local overshootY = targetY - 0.030

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

			if callback then
				tweenBack.Completed:Once(callback)
			end
		end)
	end

	playAnimation(textLabel1, function()
		if textLabel2 then
			task.delay(delayBetween, function()
				playAnimation(textLabel2)
			end)
		end
	end)
end

return ClientUtil
