local GROUP_ID = 34498780
local RunService = game:GetService("RunService")

return function (registry)
    registry:RegisterHook("BeforeRun", function (context)
        local player = context.Executor
        local groupRank = player:GetRankInGroup(GROUP_ID)

        if groupRank < 10 then
            if not RunService:IsStudio() then
                return "You don't have permission to run this command!"
            end
        end
    end)
end