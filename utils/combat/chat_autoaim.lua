-- require: Advanced Peripherals, More Peripherals

local playerDetector = peripheral.find("playerDetector") or peripheral.find("player_detector")
local chatBox = peripheral.find("chatBox") or peripheral.find("chat_box")
local playerInterface = peripheral.find("player_interface")

local targetName = ""
local autoTarget = false
local ownerInfo = nil
local shouldAimDead = true
local range = 1024

if not playerDetector then
    error("Player detector was not found!")
elseif not chatBox then
    error("Chat box was not found!")
elseif not playerInterface then
    error("Player interface was not found!")
end

local function bulkGetPlayerInfo(players)
    local infoTable = {}
    local getters = {}
    for _, player in ipairs(players) do
        table.insert(getters, function()
            local info = playerDetector.getPlayerPos(player, 10)
            if info then
                infoTable[player] = info
            end
        end)
    end
    parallel.waitForAll(table.unpack(getters))
    return infoTable
end

local function getNearestPlayer()
    local players = playerDetector.getOnlinePlayers()
    local nearestPlayer = nil
    local nearestDistanceSqr = math.huge
    if not ownerInfo then return nil end
    -- exclude owner
    for i = #players, 1, -1 do
        if players[i] == ownerInfo.name then
            table.remove(players, i)
            break
        end
    end
    local playerInfos = bulkGetPlayerInfo(players)
    for playerName, info in pairs(playerInfos) do
        if info and ownerInfo.dimension == info.dimension and (shouldAimDead or info.health > 0) then
            local distanceSqr = (ownerInfo.pos.x - info.x)^2 + (ownerInfo.pos.y - info.y)^2 + (ownerInfo.pos.z - info.z)^2
            if distanceSqr < nearestDistanceSqr and distanceSqr <= range^2 then
                nearestDistanceSqr = distanceSqr
                nearestPlayer = info
            end
        end
    end
    return nearestPlayer
end

local function chatHandler()
    repeat
        local event, username, message, uuid, isHidden, messageUtf8 = os.pullEvent("chat")
        if ownerInfo and username == ownerInfo.name and string.sub(message, 0, 7) == "autoaim" then
            local playerName = string.sub(message,9)
            if playerName == "" then
                targetName = ""
                autoTarget = false
                playerInterface.displayMessage("[AutoAim] Auto-aiming disabled!")
                print(username.."("..uuid..") disabled auto-aim")
            elseif playerName == "!auto" then
                autoTarget = true
                playerInterface.displayMessage("[AutoAim] Auto-aiming at all players!")
                print(username.."("..uuid..") set auto-aim to all players")
            elseif playerName == "!aimdead" then
                shouldAimDead = not shouldAimDead
                playerInterface.displayMessage("[AutoAim] Should Aim Dead: "..tostring(shouldAimDead))
                print("should Aim Dead: "..tostring(shouldAimDead))
            elseif playerName == "!range" then
                pcall(function() range = tonumber(string.sub(message, 16)) or range end)
                playerInterface.displayMessage("[AutoAim] Auto-aiming range set to "..range.."!")
                print(username.."("..uuid..") set auto-aim range to "..range)
            else
                autoTarget = false
                local player = playerDetector.getPlayerPos(playerName)
                if player == nil then
                    print(playerName.." was not found.")
                else
                    targetName = playerName
                    playerInterface.displayMessage("[AutoAim] Auto-aiming at "..playerName.."!")
                    print(username.."("..uuid..") set auto-aim to "..playerName)
                end
            end
        end
    until false
end

local function ownerInfoGetter()
    repeat
        ownerInfo = playerInterface.getPlayerInfo() or ownerInfo
    until false
end

local function autoAim()
    repeat
        local playerInfo = nil
        if autoTarget then
            playerInfo = getNearestPlayer()
        elseif targetName ~= "" then
            local info = playerDetector.getPlayerPos(targetName, 10)
            if info and ownerInfo and ownerInfo.dimension == info.dimension and math.sqrt((ownerInfo.pos.x - info.x)^2 + (ownerInfo.pos.y - info.y)^2 + (ownerInfo.pos.z - info.z)^2) <= range and (shouldAimDead or info.health > 0) then
                playerInfo = info
            end
        end
        if playerInfo then
            playerInterface.lookAt(playerInfo.x, playerInfo.y + playerInfo.eyeHeight, playerInfo.z)
        else
            sleep(0.05)
        end
    until false
end

parallel.waitForAny(chatHandler, ownerInfoGetter, autoAim)