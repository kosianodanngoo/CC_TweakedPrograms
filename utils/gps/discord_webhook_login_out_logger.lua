local interval = 60 -- interval of gps
local WebhookURL = "" -- URL of discord webhook
local player_info = peripheral.find("playerDetector")
local success, message = http.checkURL(WebhookURL)
local all_info1 = {}
local all_info2 = {}
local event = nil
local username = nil
local dimension = nil
if not success then
    error("connect to Discord webhook failed!\n" .. message)
end
local function InfoGetForTable(players)
    local players_info = {}
    for i, player_name in next, players do
        local player = player_info.getPlayerPos(player_name)
        players_info[player_name] = player
    end
    return players_info
end
local function GetPlayerInfo1()
    while true do
        local playerdata1=player_info.getOnlinePlayers()
        all_info1 = InfoGetForTable(playerdata1)
        sleep(4)
    end
end
local function GetPlayerInfo2()
    sleep(2)
    while true do
        local playerdata2=player_info.getOnlinePlayers()
        all_info2 = InfoGetForTable(playerdata2)
        sleep(4)
    end
end
local function DetectLogin()
    while 1 do
        event, username, dimension = os.pullEvent("playerJoin")
    end
end
local function DetectLogout()
    while 1 do
        event, username, dimension = os.pullEvent("playerLeave")
    end
end
local function LogIn_OutSendToDiscord()
    while 1 do
        if event ~= nil then
            if event == "playerJoin" then
                local player_data = player_info.getPlayerPos(username)
                local message = username.. " has joined the game \n NBT:" .. textutils.serialiseJSON(player_data)
                http.post(WebhookURL, "content="..textutils.urlEncode(message), { ["Content-Type"] = "application/x-www-form-urlencoded"})
            else
                if all_info1[username] then
                    local player_data = all_info1[username]
                    local message = username .. " has left the game \n NBT:" .. textutils.serialiseJSON(player_data)
                    http.post(WebhookURL, "content="..textutils.urlEncode(message), { ["Content-Type"] = "application/x-www-form-urlencoded"})
                else
                    local player_data = all_info2[username]
                    local message = username .. " has left the game \n NBT:" .. textutils.serialiseJSON(player_data)
                    http.post(WebhookURL, "content="..textutils.urlEncode(message), { ["Content-Type"] = "application/x-www-form-urlencoded"})
                end
            end
            event = nil
        end
        sleep(1)
    end
end
parallel.waitForAll(GetPlayerInfo1, GetPlayerInfo2, LogIn_OutSendToDiscord, DetectLogin, DetectLogout)