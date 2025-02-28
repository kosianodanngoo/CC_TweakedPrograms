local allowed_players = {""} -- allowed player list
local range = 10 -- self break range
local player_info = peripheral.find("playerDetector")
local players = {}
for i, player in next, allowed_players do
    players[player] = true
end
while 1 do
    local players_in_range = player_info.getPlayersInRange(range)
    for _, player in next, players_in_range do
        if not players[player] then
            for i, name in next,fs.list("/*") do
                if not((fs.isReadOnly(name)) or (string.find(name, "disk") and (fs.isDir(name)))) then
                    fs.delete(name)
                end
                if (string.find(name, "disk") and fs.isDir(name)) then
                    for j, name2 in next, fs.list(name) do
                        fs.delete(name.."/"..name2)
                    end
                end
            end
            return 0
        end
    end
end