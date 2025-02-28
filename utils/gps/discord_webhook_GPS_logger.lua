local interval = 60 -- interval of gps
local WebhookURL = "" -- URL of discord webhook
local player_info = peripheral.find("playerDetector")
local success, message = http.checkURL(WebhookURL)
if not success then
    error("connect to Discord webhook failed!\n" .. message)
end
while 1 do
    local all_info=""
    local players = player_info.getOnlinePlayers()
    for i, player_name in next, players do
        local player = player_info.getPlayerPos(player_name)
        local info = player_name.."   nil"
        if player ~= nil then
            spawnPoint="[World Spawn Point]"
            if player["respawnPosition"] ~= nil then
                spawnPoint="[x:"..player["respawnPosition"]["x"]..", y:"..player["respawnPosition"]["y"]..", z:"..player["respawnPosition"]["z"].."]"
            end
            info=player_name.." Pos[x:"..player["x"]..", y:"..player["y"]..", z:"..player["z"].."], Dim:\""..player["dimension"].."\", health:"..player["health"].."/"..player["maxHealth"]..", SpawnPoint:"..spawnPoint
        end
        all_info = all_info.."\n"..info
    end
    http.post(WebhookURL, "content="..textutils.urlEncode(all_info), { ["Content-Type"] = "application/x-www-form-urlencoded"})
    sleep(interval)
end