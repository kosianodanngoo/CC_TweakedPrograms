local ownerName = "" -- input your name if use on pocket computer

local x = 0 -- input coumuter pos
local y = 0

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
map.pixelPerBlock = 200
map.stopRender = false
map.tracePlayer = ""
map.players = {}
map.updatePlayerInfo = function()
    if map.fixed then
        pcall(function() traceInfo = playerDetector.getPlayer(map.tracePlayer) end)
        if traceInfo.x ~= nil then
            map.x = traceInfo.x
            map.z = traceInfo.z
        end
    end
    local players = playerDetector.getPlayersInCoords(
        {x = map.x - map.pixelPerBlock * map.width / 2, y = -math.huge, z = map.z - map.pixelPerBlock * map.height / 2},
        {x = map.x + map.pixelPerBlock * map.width / 2, y = math.huge, z = map.z + map.pixelPerBlock * map.height / 2}
    )
    local players_info = {}
    for i, player in ipairs(players) do
        players_info[i] = playerDetector.getPlayer(player)
        players_info[i].name = player
    end
    map.players = players_info
end
map.renderMap = function()
    repeat
        if not map.stopRender then
            term.clear()
            for i, info in ipairs(map.players) do
                term.setCursorPos((info.x - map.x) / map.pixelPerBlock + map.width / 2, (info.z - map.z) / map.pixelPerBlock + map.height / 2)
                term.write(string.sub(info.name, 1, 1))
            end
            term.setCursorPos(1, map.height - 1)
            print("PPB:"..math.floor(map.pixelPerBlock))
            term.write("x:"..math.floor(map.x).." z:"..math.floor(map.z))
        end
        sleep(0.05)
    until false
end

if pocket then
    map.tracePlayer = ownerName
    local ownerInfo = playerDetector.getPlayer(ownerName)
    map.x = ownerInfo.x or map.x
    map.z = ownerInfo.z or map.z
    map.dimension = ownerInfo.dimension or map.dimension
    map.fixed = not not ownerInfo.x
end

local function main()
    parallel.waitForAll(map.renderMap, function()
        repeat
            pcall(map.updatePlayerInfo)
            sleep(0.5)
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
                term.setCursorPos(1,1)
                print("Player Name:")
                sleep(0.05)
                local playerName = read()
                pcall(function()
                    local playerInfo = playerDetector.getPlayer(playerName)
                    if playerInfo.dimension == nil then
                        term.setCursorPos(1, 3)
                        print("Player not found")
                        sleep(2)
                    elseif playerInfo.dimension ~= map.dimension then
                        term.setCursorPos(1, 3)
                        print("Player is in a different dimension")
                        sleep(2)
                    else
                        map.x = playerInfo.x
                        map.z = playerInfo.z
                        map.tracePlayer = playerName
                        map.fixed = true
                    end
                end)
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
                map.x = map.x - (x - prevX) * map.pixelPerBlock
                map.z = map.z - (y - prevY) * map.pixelPerBlock
            end
            prevX = x
            prevY = y
        until false
    end
    local function scrollHandler()
        repeat
            local event, dir, x, y = os.pullEvent("mouse_scroll")
            map.pixelPerBlock = map.pixelPerBlock + map.pixelPerBlock * 0.1 * dir
        until false
    end
    parallel.waitForAny(keyHandler, clickHandler, dragHandler, scrollHandler)
end

parallel.waitForAny(main, inputHandler)