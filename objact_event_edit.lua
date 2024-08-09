local x = 0
local y = 0
local r = 0
local w = 0
local h = 0
objact_event_edit = {  --编辑界面
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
        objact_message_box.message(string.sub(displayed_content,1,5))
        objact_event_edit_bezier.load(x+50,y+400,0,300,300)
        if not(string.sub(displayed_content,1,5) == "event") then -- 太特殊 所以不用type 和roomtype 判断
            return
        end
        input_box_delete_all()
        switch_delete_all()
        input_box_new(displayed_content.."track","chart.event["..string.sub(displayed_content,6,#displayed_content).."].track",x + 240,y,30,30,"number")
        input_box_new(displayed_content.."form","chart.event["..string.sub(displayed_content,6,#displayed_content).."].form",x + 140,y + 50,100,30,"number")
        input_box_new(displayed_content.."to","chart.event["..string.sub(displayed_content,6,#displayed_content).."].to",x + 140,y + 100,100,30,"number")
        input_box_new(displayed_content.."beat_start1","chart.event["..string.sub(displayed_content,6,#displayed_content).."].beat[1]",x + 140,y + 150,30,30,"number")
        input_box_new(displayed_content.."beat_start2","chart.event["..string.sub(displayed_content,6,#displayed_content).."].beat[2]",x + 180,y + 150,30,30,"number")
        input_box_new(displayed_content.."beat_start3","chart.event["..string.sub(displayed_content,6,#displayed_content).."].beat[3]",x + 220,y + 150,30,30,"number")
        input_box_new(displayed_content.."beat_end1","chart.event["..string.sub(displayed_content,6,#displayed_content).."].beat2[1]",x + 140,y + 200,30,30,"number")
        input_box_new(displayed_content.."beat_end2","chart.event["..string.sub(displayed_content,6,#displayed_content).."].beat2[2]",x + 180,y + 200,30,30,"number")
        input_box_new(displayed_content.."beat_end3","chart.event["..string.sub(displayed_content,6,#displayed_content).."].beat2[3]",x + 220,y + 200,30,30,"number")
        input_box_new(displayed_content.."trans1","chart.event["..string.sub(displayed_content,6,#displayed_content).."].trans[1]",x + 140,y + 250,30,30,"number")
        input_box_new(displayed_content.."trans2","chart.event["..string.sub(displayed_content,6,#displayed_content).."].trans[2]",x + 180,y + 250,30,30,"number")
        input_box_new(displayed_content.."trans3","chart.event["..string.sub(displayed_content,6,#displayed_content).."].trans[3]",x + 220,y + 250,30,30,"number")
        input_box_new(displayed_content.."trans4","chart.event["..string.sub(displayed_content,6,#displayed_content).."].trans[4]",x + 260,y + 250,30,30,"number")

        objact_event_edit_default_bezier.load(x + 100,y + 300,0,30,30)
    end,
    draw = function() -- sidebar里的
        if not(string.sub(displayed_content,1,5) == "event") then -- 太特殊 所以不用type 和roomtype 判断
            return
        end
        input_box_draw_all()
        love.graphics.setColor(1,1,1,1)
        love.graphics.print(objact_language.get_string_in_languages("track"),x+200,y)
        love.graphics.print(objact_language.get_string_in_languages("form"),x+40,y+50)
        love.graphics.print(objact_language.get_string_in_languages("to"),x+40,y+100)
        love.graphics.print(objact_language.get_string_in_languages("beat_start"),x+40,y+150)
        love.graphics.print(objact_language.get_string_in_languages("beat_end"),x+40,y+200)
        love.graphics.print(objact_language.get_string_in_languages("trans"),x+40,y+250)

        objact_event_edit_bezier.draw()
        objact_event_edit_default_bezier.draw()
    end,
    update = function(dt)
        if not(string.sub(displayed_content,1,5) == "event") then -- 太特殊 所以不用type 和roomtype 判断
            return
        end
        objact_event_edit_bezier.update(dt)
    end,
    mousepressed = function(x1, y1, button, istouch, presses)
        if not(string.sub(displayed_content,1,5) == "event")then
            return
        end
        
        input_box_mousepressed(x1, y1)
        objact_event_edit_bezier.mousepressed(x1,y1)
        objact_event_edit_default_bezier.mousepressed(x1,y1)
    end,
    mousereleased = function(x1, y1, button, istouch, presses)
        objact_event_edit_bezier.mousereleased(x1,y1)
    end,
    keypressed = function(key)
        objact_event_edit_default_bezier.keyboard(key)
    end
}