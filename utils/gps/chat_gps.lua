local chat = peripheral.find("chatBox")
local playerInfo = peripheral.find("playerDetector")
while 1 do
    local event, username, message, uuid, isHidden = os.pullEvent("chat")
    if string.sub(message, 0, 3) == "gps" then
        local player_name = string.sub(message,5)
        local player = playerInfo.getPlayerPos(player_name)
        if player == nil then
            print(player_name.." was not found.")
        else
            spawnPoint="[World Spawn Point]"
            if player["respawnPosition"] ~= nil then
               spawnPoint="[x:"..player["respawnPosition"]["x"]..", y:"..player["respawnPosition"]["y"]..", z:"..player["respawnPosition"]["z"].."]"
            end
            info=player_name.." Pos[x:"..player["x"]..", y:"..player["y"]..", z:"..player["z"].."], Dim:\""..player["dimension"].."\", health:"..player["health"].."/"..player["maxHealth"]..", SpawnPoint:"..spawnPoint
            chat.sendMessage(info, "GPS")
            print(username.."("..uuid..")displayed  "..info)
        end
    end
end
