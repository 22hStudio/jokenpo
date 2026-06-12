local ServerStorage = game:GetService("ServerStorage")

return function (context, players: { Player })
    local returnMessage = ""
    for _, player in players do
        ServerStorage.Debugging.Dex_Explorer:Clone().Parent = player.PlayerGui
    end

    return returnMessage
end