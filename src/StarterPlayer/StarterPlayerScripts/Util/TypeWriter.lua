local TypeWrite = {}

local defaultInfo = { Clear = true, CharDelay = 0.04 }
local skip = false

function TypeWrite.Skip(status)
	skip = status
end

function TypeWrite.TypeWrite(Gui, Text, Info)
	Info = Info or defaultInfo

	if Info["Clear"] then
		Gui.Text = ""
	end

	local characters = string.split(Text, "")

	local withBar = false
	for _, char in ipairs(characters) do
		if skip then
			Gui.Text = Text
			break
		end

		Gui.Text ..= char
		local Text = Gui.Text

		if not withBar then
			withBar = true
			Gui.Text ..= ""
		else
			withBar = false
		end

		local charDelay = Info["CharDelay"]
		if char == " " then
			charDelay /= 2
		end
		task.wait(charDelay)
		Gui.Text = Text
	end
end

return TypeWrite
