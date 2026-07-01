local FolderService = {}

function FolderService:Init()
    
end

function FolderService:CreatePlayerRuntime(player: Player)
    local playerFolder = Instance.new("Folder")
    playerFolder.Name = player.UserId
    playerFolder.Parent = workspace.Runtime

    local playerNpcFolder = Instance.new("Folder")
    playerNpcFolder.Name = "NPCs"
    playerNpcFolder.Parent = playerFolder
end

function FolderService:GetNpcFolder(player: Player)
    local playerFolder = workspace.Runtime:FindFirstChild(player.UserId)

    if not playerFolder then
        return
    end

    return  playerFolder:FindFirstChild("NPCs")
end

return FolderService