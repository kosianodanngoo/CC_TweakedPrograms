local playerDetector = peripheral.find("playerDetector")

local players = {}
local nowY = 1
local selected = 1
local isList = true
local targetInfo = {}


if not playerDetector then
    error("Player detector was not found!")
end

local monitor = peripheral.find("monitor")
if monitor then
    term.redirect(monitor)
end

local function clamp(num, min, max)
    return math.max(min, math.min(num, max))
end

local function refresh()
    local nowPlayers = playerDetector.getOnlinePlayers()
    if selected > #nowPlayers then
        nowY = math.min(1, nowY - (#nowPlayers - selected))
        selected = #nowPlayers
    end
    local size = {term.getSize()}
    players = nowPlayers
end

local function drawList()
    local prevTermBGColor = term.getBackgroundColor()
    local prevTermTextColor = term.getTextColor()
    for i, player in ipairs(players) do
        if i == selected then
            term.setBackgroundColor(colors.white)
            term.setTextColor(colors.black)
        else
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
        end
        term.setCursorPos(1, i - nowY + 1)
        term.write(player)
    end
    term.setBackgroundColor(prevTermBGColor)
    term.setTextColor(prevTermTextColor)
end

local function displayInfo()
    local size = {term.getSize()}
    if selected ~= 1 then
        term.setCursorPos(size[1]/2,1)
        term.write(string.char(24))
    end
    if selected ~= #players then
        term.setCursorPos(size[1]/2, size[2])
        term.write(string.char(25))
    end
    term.setCursorPos(3,2)
    print(players[selected])
    local respawnPos = targetInfo.respawnPosition or {x = 0/0, y = 0/0, z = 0/0}
    if targetInfo.x == nil then
        refresh()
        return
    end
    print("X:"..targetInfo.x)
    print("Y:"..targetInfo.y)
    print("Z:"..targetInfo.z)
    print("Dimension:"..targetInfo.dimension)
    if targetInfo.health ~= nil then
        print("Health:"..math.floor(targetInfo.health).."/"..targetInfo.maxHealth)
        print("air:"..targetInfo.airSupply)
        print("RespawnDim:"..targetInfo.respawnDimension)
        print("respawnX:"..respawnPos.x)
        print("respawnY:"..respawnPos.y)
        print("respawnZ:"..respawnPos.z)
    end
end

local function drawScreen()
    refresh()
    repeat
        term.clear()
        if isList then
            drawList()
        else
            displayInfo()
        end
        local size = {term.getSize()}
        local listPos = selected.."/"..#players
        term.setCursorPos(size[1] - string.len(listPos) + 1, 1)
        term.write(listPos)
        sleep(0.05)
    until false
end

local function infoGetter()
    local counter = 0
    repeat
        if counter >= 100 then
            counter = 0
            refresh()
        end
        targetInfo = playerDetector.getPlayerPos(players[selected] or "")
        sleep(0.05)
        counter = counter + 1
    until false
end

local function main()
    parallel.waitForAny(drawScreen, infoGetter)
end

local function inputHandler()
    local prevX, prevY
    local function keyHandler()
        repeat
            local event, key, is_held = os.pullEvent("key")
            if key == keys.r and not is_held then
                refresh()
            elseif key == keys.enter and not is_held then
                isList = not isList
            elseif key == keys.up then
                selected = clamp(selected - 1, 1, #players)
                if selected < nowY then
                    nowY = selected
                end
            elseif key == keys.down then
                selected = clamp(selected + 1, 1, #players)
                local size = {term.getSize()}
                if selected > nowY + size[2] then
                    nowY = selected - size[2]
                end
            elseif key == keys.backspace then
                term.clear()
                term.setCursorPos(1,1)
                return
            end
        until false
    end
    local function clickHandler()
        repeat
            local event, button, x, y = os.pullEvent("mouse_click")
        until false
    end
    local function dragHandler()
        repeat
            local event, button, x, y = os.pullEvent("mouse_drag")
        until false
    end
    local function scrollHandler()
        repeat
            local event, dir, x, y = os.pullEvent("mouse_scroll")
        until false
    end
    parallel.waitForAny(keyHandler, clickHandler, dragHandler, scrollHandler)
end

parallel.waitForAny(main, inputHandler)