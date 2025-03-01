local ownerName = "" -- input your name if use on pocket computer

local x = 0 -- input coumuter pos
local y = 0

local completion = require("cc.completion")
local playerDetector = peripheral.find("playerDetector")

local monitor = peripheral.find("monitor")
if monitor then
    term.redirect(monitor)
end

local termSize = {term.getSize()}

local map = {}
map.width = termSize[1]
map.height = termSize[2]
map.fixed = false
map.x = x
map.z = y
map.dimension = "minecraft:overworld"
map.blockPerPixel = 200
map.stopRender = false
map.tracePlayer = ""
map.players = {}
map.updatePlayerInfo = function()
    if map.fixed then
        pcall(function() traceInfo = playerDetector.getPlayerPos(map.tracePlayer) end)
        if traceInfo.x ~= nil then
            map.x = traceInfo.x
            map.z = traceInfo.z
            map.dimension = traceInfo.dimension
        end
    end
    local players = playerDetector.getPlayersInCoords(
        {x = map.x - map.blockPerPixel * map.width, y = -math.huge, z = map.z - map.blockPerPixel * map.height},
        {x = map.x + map.blockPerPixel * map.width, y = math.huge, z = map.z + map.blockPerPixel * map.height}
    )
    local players_info = {}
    for i, player in ipairs(players) do
        local player_info = playerDetector.getPlayerPos(player)
        if player_info.dimension == map.dimension then
            players_info[#players_info + 1] = player_info
            players_info[#players_info].name = player
        end
    end
    map.players = players_info
end
map.renderMap = function()
    repeat
        if not map.stopRender then
            local termSize = {term.getSize()}
            map.width = termSize[1]
            map.height = termSize[2]
            term.clear()
            local prevTermTextColor = term.getTextColor()
            term.setTextColor(colors.lightGray)
            term.setCursorPos(1, map.height - 2)
            print("BPP:"..math.floor(map.blockPerPixel))
            print("x:"..math.floor(map.x).." z:"..math.floor(map.z))
            term.write("Dimension:"..map.dimension)
            term.setTextColor(colors.white)
            for i, info in ipairs(map.players) do
                term.setCursorPos((info.x - map.x) / map.blockPerPixel + map.width / 2, (info.z - map.z) / map.blockPerPixel + map.height / 2)
                term.write(string.sub(info.name, 1, 1))
            end
            term.setTextColor(prevTermTextColor)
        end
        sleep(0.05)
    until false
end

if pocket then
    map.tracePlayer = ownerName
    local ownerInfo = playerDetector.getPlayerPos(ownerName)
    map.x = ownerInfo.x or map.x
    map.z = ownerInfo.z or map.z
    map.dimension = ownerInfo.dimension or map.dimension
    map.fixed = not not ownerInfo.x
end

local function main()
    parallel.waitForAll(map.renderMap, function()
        repeat
            pcall(map.updatePlayerInfo)
            sleep(0.05)
        until false
    end)
end

local function inputHandler()
    local prevX, prevY
    local function keyHandler()
        repeat
            local event, key, is_held = os.pullEvent("key")
            if key == keys.p and not is_held then
                map.fixed = not map.fixed
            elseif key == keys.f and not is_held then
                map.stopRender = true
                map.fixed = false
                local playerList = playerDetector.getOnlinePlayers()
                term.setCursorPos(1,1)
                print("Player Name:")
                sleep(0.05)
                local playerName = read(nil, nil, function(text)
                    choices = {}
                    for i, player in ipairs(playerList) do
                        choices[i] = player
                    end
                    return completion.choice(text, choices)
                end)
                pcall(function()
                    local playerInfo = playerDetector.getPlayerPos(playerName)
                    if playerInfo.dimension == nil then
                        term.setCursorPos(1, 3)
                        print("Player not found")
                        sleep(2)
                    else
                        map.x = playerInfo.x
                        map.z = playerInfo.z
                        map.tracePlayer = playerName
                        map.fixed = true
                    end
                end)
                map.stopRender = false
            elseif key == keys.d then
                map.stopRender = true
                map.fixed = false
                term.setCursorPos(1,1)
                print("Dimension:")
                sleep(0.05)
                local dimension = read()
                map.dimension = dimension
                map.stopRender = false
            elseif key == keys.backspace then
                map.stopRender = true
                term.clear()
                term.setCursorPos(1,1)
                return
            end
        until false
    end
    local function clickHandler()
        repeat
            local event, button, x, y = os.pullEvent("mouse_click")
            prevX = x
            prevY = y
        until false
    end
    local function dragHandler()
        repeat
            local event, button, x, y = os.pullEvent("mouse_drag")
            if not map.fixed then
                map.x = map.x - (x - prevX) * map.blockPerPixel
                map.z = map.z - (y - prevY) * map.blockPerPixel
            end
            prevX = x
            prevY = y
        until false
    end
    local function scrollHandler()
        repeat
            local event, dir, x, y = os.pullEvent("mouse_scroll")
            map.blockPerPixel = map.blockPerPixel + map.blockPerPixel * 0.1 * dir
        until false
    end
    parallel.waitForAny(keyHandler, clickHandler, dragHandler, scrollHandler)
end

parallel.waitForAny(main, inputHandler)