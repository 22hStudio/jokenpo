local PlayerDataHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = ReplicatedStorage.Utility
local BridgeNet2 = require(Utility.BridgeNet2)

local bridge = BridgeNet2.ReferenceBridge("PlayerLoaded")
local actionIdentifier = BridgeNet2.ReferenceIdentifier("action")
local statusIdentifier = BridgeNet2.ReferenceIdentifier("status")
local messageIdentifier = BridgeNet2.ReferenceIdentifier("message")

local ServerScriptService = game:GetService("ServerScriptService")

local bridgePlayer = BridgeNet2.ReferenceBridge("Player")

bridgePlayer.OnServerInvoke = function(player, data)
	if data[actionIdentifier] == "getPlayerData" then
		local playerData = PlayerDataHandler:GetAll(player)
		return {
			[statusIdentifier] = "success",
			[messageIdentifier] = "Player data retrieved",
			playerData = playerData,
		}
	end
end

local cachedJoinTimestamps = {}
local dataTemplate = {
	totalPlaytime = 0,
}

local ProfileService = require(ServerScriptService.libs.ProfileService)
local TableService = require(ServerScriptService.Modules.TableService)
local MatchService = require(ServerScriptService.Modules.MatchService)

local ProfileStore = ProfileService.GetProfileStore("PlayerProfile", dataTemplate)

local Profiles = {}

local function playerAdded(player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)

	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile:ListenToRelease(function()
			Profiles[player] = nil

			player:Kick()
		end)

		if not player:IsDescendantOf(Players) then
			profile:Release()
		else
			Profiles[player] = profile
		end

		profile:Reconcile()

		bridge:Fire(player, {
			[actionIdentifier] = "PlayerLoaded",
			[statusIdentifier] = "success",
			[messageIdentifier] = "Player data loaded",
			data = profile.Data,
		})
	else
		player:Kick()
	end
end

local function getProfile(player)
	-- Try waiting for the profile to load but don't wait too long
	local startTime = os.time()
	while not Profiles[player] and os.time() - startTime < 30 do
		task.wait()
	end

	assert(Profiles[player], "Profile not found for player " .. player.Name)

	return Profiles[player]
end

function PlayerDataHandler:Wipe(player)
	local success = ProfileStore:WipeProfileAsync("Player_" .. player.UserId)
	if success then
		player:Kick()
	end
end

-- Getter/Setter methods
function PlayerDataHandler:Get(player, key)
	local profile = getProfile(player)

	--assert(profile.Data[key]"Key not found in player data: " .. key)

	return profile.Data[key]
end

function PlayerDataHandler:Set(player, key, value)
	local profile = getProfile(player)

	-- Check if key exists
	-- assert(profile.Data[key], "Key not found in player data: " .. key)

	-- Check if there is a type mismatch
	assert(type(value) == type(profile.Data[key]), "Value type mismatch for key " .. key)

	profile.Data[key] = value
end

function PlayerDataHandler:Update(player, key, callback)
	-- local profile = getProfile(player)

	local oldData = self:Get(player, key)

	local newData = callback(oldData)

	self:Set(player, key, newData)
end

function PlayerDataHandler:GetAll(player)
	local profile = getProfile(player)

	return profile.Data
end

function PlayerDataHandler:Init()
	for _, player in Players:GetPlayers() do
		task.spawn(playerAdded, player)
	end

	Players.PlayerAdded:Connect(function(player)
		playerAdded(player)

		local joinTimestamp = os.time()
		cachedJoinTimestamps[player] = joinTimestamp
	end)

	Players.PlayerRemoving:Connect(function(player)
		pcall(function()
			TableService:RemovePlayerFromTable(player)
			MatchService:ProcessPlayerLeft(player)
		end)
		local joinTimestamp = cachedJoinTimestamps[player]
		local leaveTimestamp = os.time()
		local playtime = leaveTimestamp - joinTimestamp

		PlayerDataHandler:Update(player, "totalPlaytime", function(currentPlaytime)
			local totalPlaytime = currentPlaytime + playtime
			return totalPlaytime
		end)

		if Profiles[player] then
			Profiles[player]:Release()
		end
	end)
end

return PlayerDataHandler
