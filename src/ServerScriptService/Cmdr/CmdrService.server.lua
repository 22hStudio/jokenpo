local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")

local Cmdr = require(ServerScriptService.libs.Cmdr)

Cmdr:RegisterDefaultCommands()
Cmdr:RegisterCommandsIn(ServerScriptService.Cmdr.Commands)
Cmdr:RegisterHooksIn(ServerScriptService.Cmdr.Hooks)
