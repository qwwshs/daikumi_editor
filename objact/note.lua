local x = 0
local y = 0
local r = 0
local w = 0
local h = 0
local ui_note = love.graphics.newImage("asset/ui_note.png")
local ui_wipe = love.graphics.newImage("asset/ui_wipe.png")
local ui_hold = love.graphics.newImage("asset/ui_hold.png")
local ui_delete = love.graphics.newImage("asset/ui_delete.png")
objact_note = {
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
    end,
    draw = function()

    end,
    keyboard = function(key)
        if not(mouse.x >= 900 and mouse.x <= 1000 and mouse.y >= 100) then --不在轨道范围内
            return
        end
        if key == "q" then -- note
            note_place("note",mouse.y)
            objact_message_box.message("note place")
        elseif key == "w" then --wipe
            note_place("wipe",mouse.y)
            objact_message_box.message("wipe place")
        elseif key == "e" then --hold
            hold_place = not hold_place
            note_place("hold",mouse.y)
            objact_message_box.message("hold place")
        elseif key == "d" then --delete
            note_delete(mouse.y)
            objact_message_box.message("note delete")
        end
    end,
}