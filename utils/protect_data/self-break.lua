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
            for _, name in next,fs.list("/*") do
                local isDisk = string.find(name, "disk") and fs.isDir(name)
                if not(fs.isReadOnly(name) or isDisk) then
                    fs.delete(name)
                elseif isDisk then
                    for _, name2 in next, fs.list(name) do
                        if not fs.isReadOnly(name) then
                            fs.delete(name.."/"..name2)
                        end
                    end
                end
            end
            return 0
        end
    end
end