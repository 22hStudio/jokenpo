local UtilService = {}

local Players = game:GetService("Players")

function UtilService:Init() end

function UtilService:SerializeCFrame(cf)
	return {
		cf:GetComponents(),
	}
end

function UtilService:DeserializeCFrame(tbl)
	return CFrame.new(unpack(tbl))
end

function UtilService:GetDevModel(playerFolder: Folder, workerId: number)
	for _, value in playerFolder:GetChildren() do
		if value:GetAttribute("DEV") and tonumber(value:GetAttribute("ID")) == tonumber(workerId) then
			return value
		end
	end
end

function UtilService:formatCamelCase(word: string)
	local formatted = word:gsub("(%l)(%u)", "%1 %2")
	formatted = formatted:gsub("(%a)([%w_']*)", function(a, b)
		return string.upper(a) .. b
	end)
	return formatted
end

function UtilService:WaitForDescendants(root, ...)
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

function UtilService:GetPositionHeightReference(player: Player, floorNumber: number)
	local base = workspace.Map.BaseMaps[player:GetAttribute("BASE")]

	for _, floor in base:GetChildren() do
		if floor:GetAttribute("IS_BASE") then
			if tonumber(floor.Name) == floorNumber then
				return floor.PositionHeightReference.Position.Y - floor.PositionHeightReference.Size.Y / 2
			end
		end
	end
end

function UtilService:FormatNumberToSuffixes(n)
	local suffixes = { "", "K", "M", "B", "T", "Q" } -- pode adicionar mais se quiser
	local i = 1

	while n >= 1000 and i < #suffixes do
		n = n / 1000
		i = i + 1
	end

	-- Limita para 1 casa decimal e remove .0 se for inteiro
	local formatted = string.format("%.0f", n)
	formatted = formatted:gsub("%.0$", "")

	return formatted .. suffixes[i]
end

function UtilService:FormatToUSD(number)
	-- Arredonda o número (use math.floor se quiser truncar)
	number = math.floor(number + 0.5)

	-- Converte para string sem decimais
	local formatted = string.format("%d", number)

	-- Adiciona vírgulas a cada 3 dígitos
	formatted = formatted:reverse():gsub("(%d%d%d)", "%1,"):reverse()

	-- Remove vírgula no início, se aparecer
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end

	return "$" .. formatted
end

function UtilService:GetThumb(playerId: number)
	local thumbType = Enum.ThumbnailType.HeadShot
	local thumbSize = Enum.ThumbnailSize.Size420x420
	local content, isReady = Players:GetUserThumbnailAsync(playerId, thumbType, thumbSize)

	if content and isReady then
		return content
	end
end

function UtilService:GetPlayerNameById(playerId)
	local success, playerName = pcall(function()
		return Players:GetNameFromUserIdAsync(playerId)
	end)

	if success then
		return playerName
	end
end

function UtilService:Color3(a, b, c)
	return Color3.new(a / 255, b / 255, c / 255)
end

function UtilService:SortList(list, property, reverse)
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

function UtilService:PrepareParts(parts: BasePart | { BasePart }, props: {})
	if not parts then
		return
	end

	local list = typeof(parts) == "table" and parts or { parts }

	for _, part in ipairs(list) do
		if part and part:IsA("BasePart") then
			for property, value in pairs(props) do
				part[property] = value
			end
		end
	end
end

function UtilService:FormatSecondsToMinutes(seconds)
	local minutes = math.floor(seconds / 60)
	local remainingSeconds = seconds % 60
	return string.format("%02dm:%02ds", minutes, remainingSeconds)
end

function UtilService:DeepCopy(tbl)
	local copy = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			copy[k] = UtilService:DeepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

return UtilService
