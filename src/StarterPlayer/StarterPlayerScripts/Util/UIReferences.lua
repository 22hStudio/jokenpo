local UIReferences = {}
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer


function UIReferences:GetReference(referenceName: string)
    local taggedObjects = CollectionService:GetTagged(referenceName)

    if not next(taggedObjects) then
        warn("No objects found with the tag:", referenceName)
        return 
    end

    if #taggedObjects > 2 then
        warn("More than one object found with the tag:", referenceName)
        return
    end

    for _, obj in ipairs(taggedObjects) do
		if obj:IsDescendantOf(player:WaitForChild("PlayerGui")) then
			return obj
		end
	end
end 

return UIReferences