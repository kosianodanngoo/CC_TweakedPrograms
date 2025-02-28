local GUI = {}
local completion = require("cc.completion")

function GUI.create(width, height, x, y, guiBackgroundColour)
    local this = {}
    local termSize = {term.getSize()}
    this.width = width or termSize[1]
    this.height = height or termSize[2]
    this.x = x or 1
    this.y = y or 1
    this.backgroundColour = guiBackgroundColour or nil
    this.elements = {}
    function this.box(fromX, fromY, width, height, colour, onClick)
        local this_element = {}
        if fromX + this.x > this.width or fromX < this.x or fromY + this.y > this.height or fromY < this.y then
            error("The box is out of the gui.")
        end
        this_element.fromX = fromX or nil
        this_element.fromY = fromY or nil
        this_element.width = width or nil
        this_element.height = height or nil
        this_element.backgroundColour = colour or nil
        this_element.onClick = onClick or function() end
        this_element.type = "box"
        table.insert(this.elements, this_element)
        return this_element
    end
    function this.text(fromX, fromY, width, height, text, textColour, backgroundColour, onClick)
        local this_element = this.box(fromX, fromY, width, height, backgroundColour, onClick)
        this_element.text = text or ""
        this_element.textColour = textColour or nil
        this_element.type = "textBox"
        return this_element
    end
    function this.input(fromX, fromY, width, height, text, textColour, backgroundColour, isPassword, choices)
        local this_element = this.text(fromX, fromY, width, height, text, textColour, backgroundColour, nil)
        this_element.onClick = function()
            local prevTextColour = term.getTextColour()
            local prevBackgroundColour = term.getBackgroundColour()
            local prevCursorX, prevCursorY = term.getCursorPos()
            local x = this.x + this_element.fromX - 1
            local y = this.y + this_element.fromY - 1
            term.setCursorPos(x + string.len(this_element.text) % this.width, y + math.floor(string.len(this_element.text) / this.width))
            term.setBackgroundColour(this_element.backgroundColour or term.getBackgroundColour())
            term.setTextColour(this_element.textColour or term.getTextColour())
            local out = read((function()
                    if this_element.isPassword then return "*" end
                end)(), nil, function(text)
                    return completion.choice(text, this_element.choices or {})
                end)
            term.setTextColour(prevTextColour)
            term.setBackgroundColour(prevBackgroundColour)
            term.setCursorPos(prevCursorX, prevCursorY)
            return out
        end
        this_element.isPassword = isPassword or false
        this_element.choices = choices or {}
        return this_element
    end
    function this.render()
        local prevTextColour = term.getTextColour()
        local prevBackgroundColour = term.getBackgroundColour()
        local prevCursorX, prevCursorY = term.getCursorPos()
        local defaultBackgroundColour = prevBackgroundColour
        if this.backgroundColour then
            term.setBackgroundColour(this.backgroundColour)
            defaultBackgroundColour = this.backgroundColour
            for i = 1, this.height do
                term.setCursorPos(this.x, this.y + i - 1)
                term.write(string.rep(" ", this.width))
            end
        end
        for _, element in ipairs(this.elements) do
            if element.fromX and element.fromY and element.width and element.height then
                term.setBackgroundColour(defaultBackgroundColour)
                if element.backgroundColour then
                    term.setBackgroundColour(element.backgroundColour)
                    for i = 1, element.height do
                        term.setCursorPos(this.x + element.fromX - 1, this.y + element.fromY + i - 2)
                        term.write(string.rep(" ", element.width))
                    end
                end
                if element.type ~= "box" then
                    term.setTextColour(prevTextColour)
                    if element.textColour then
                        term.setTextColour(element.textColour)
                    end
                    for i = 1, element.height do
                        term.setCursorPos(this.x + element.fromX - 1, this.y + element.fromY + i - 2)
                        term.write(string.sub(element.text, (i - 1) * element.width + 1, i * element.width))
                    end
                end
            end
        end
        term.setTextColour(prevTextColour)
        term.setBackgroundColour(prevBackgroundColour)
        term.setCursorPos(prevCursorX, prevCursorY)
        return true
    end
    function this.waitUserInput(targetElements)
        repeat
            local event, button, x, y = os.pullEvent("mouse_click")
            local clickedElements = {}
            for _, element in ipairs(this.elements) do
                if x >= this.x + element.fromX - 1 and x < this.x + element.fromX + element.width and y >= this.y + element.fromY - 1 and y < this.y + element.fromY + element.height then
                    if targetElements then
                        for _, targetElement in ipairs(targetElements) do
                            if element == targetElement then
                                table.insert(clickedElements, element)
                            end
                        end
                    else
                        table.insert(clickedElements, element)
                    end
                end
            end
            if clickedElements[1] then
                return clickedElements
            end
        until false
    end
    return this
end

return GUI