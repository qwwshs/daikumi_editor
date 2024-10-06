
objact_note = {
    load = function(x1,y1,r1,w1,h1)
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
    mousepressed = function(x,y,button)
        if  mouse.x >= 900 and mouse.x <= 1000 then -- 选择note
            local pos = note_click(mouse.y)
            if pos then
                displayed_content = 'note'..pos
                objact_note_edit.load(1200,40,0,30,30) --调用编辑界面
            else
                displayed_content = 'nil'
            end
            objact_message_box.message("note click")
        end
    end
}