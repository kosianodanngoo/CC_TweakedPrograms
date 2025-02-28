local GUI = require("/modules.gui")
local gui = GUI.create(nil,nil,nil,nil,term.getBackgroundColour())
gui.box(2,2,22,4,colours.white)
gui.text(3,2,20,1,"gui tick timer",colours.black,colours.white)
local input = gui.input(3,3,20,2,"input:",nil,colours.grey)
gui.render()
local inputNumber = input.onClick()
if type(tonumber(inputNumber)) == "number" then
    for t = 1, inputNumber do
        input.text=t
        gui.render()
        sleep(0.05)
    end
end