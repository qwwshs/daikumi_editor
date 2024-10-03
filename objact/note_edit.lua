local x = 0
local y = 0
local r = 0
local w = 0
local h = 0
local function will_draw()
    return string.sub(displayed_content,1,4) == "note" and the_room_pos("edit")
end
objact_note_edit = {  --编辑界面
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
        objact_message_box.message(string.sub(displayed_content,1,4))
        if not(string.sub(displayed_content,1,4) == "note") then -- 太特殊 所以不用type 和roomtype 判断
            return
        end
        input_box_new(string.sub(displayed_content,1,4).."track","chart.note["..string.sub(displayed_content,5,#displayed_content).."].track",x + 240,y,30,30,{type = "number",will_draw = will_draw})
        input_box_new(string.sub(displayed_content,1,4).."beat_start1","chart.note["..string.sub(displayed_content,5,#displayed_content).."].beat[1]",x + 140,y + 50,30,30,{type = "number",will_draw = will_draw,input_ed_finish = note_sort})
        input_box_new(string.sub(displayed_content,1,4).."beat_start2","chart.note["..string.sub(displayed_content,5,#displayed_content).."].beat[2]",x + 180,y + 50,30,30,{type = "number",will_draw = will_draw,input_ed_finish = note_sort})
        input_box_new(string.sub(displayed_content,1,4).."beat_start3","chart.note["..string.sub(displayed_content,5,#displayed_content).."].beat[3]",x + 220,y + 50,30,30,{type = "number",will_draw = will_draw,input_ed_finish = note_sort})
        if chart.note[tonumber(string.sub(displayed_content,5,#displayed_content))].type == "hold" then
            input_box_new(string.sub(displayed_content,1,4).."beat_end1","chart.note["..string.sub(displayed_content,5,#displayed_content).."].beat2[1]",x + 140,y + 100,30,30,{type = "number",will_draw = will_draw,input_ed_finish = note_sort})
            input_box_new(string.sub(displayed_content,1,4).."beat_end2","chart.note["..string.sub(displayed_content,5,#displayed_content).."].beat2[2]",x + 180,y + 100,30,30,{type = "number",will_draw = will_draw,input_ed_finish = note_sort})
            input_box_new(string.sub(displayed_content,1,4).."beat_end3","chart.note["..string.sub(displayed_content,5,#displayed_content).."].beat2[3]",x + 220,y + 100,30,30,{type = "number",will_draw = will_draw,input_ed_finish = note_sort})
        else
            input_box_delete(string.sub(displayed_content,1,4).."beat_end1")
            input_box_delete(string.sub(displayed_content,1,4).."beat_end2")
            input_box_delete(string.sub(displayed_content,1,4).."beat_end3")
        end
        if not chart.note[tonumber(string.sub(displayed_content,5,#displayed_content))].fake then
            chart.note[tonumber(string.sub(displayed_content,5,#displayed_content))].fake = 0
        end
        switch_new(string.sub(displayed_content,1,4).."fake","chart.note["..string.sub(displayed_content,5,#displayed_content).."].fake",x + 220,y + 150,30,30,1,{will_draw = will_draw})
    end,
    draw = function() -- sidebar里的
        if not(string.sub(displayed_content,1,4) == "note") then -- 太特殊 所以不用type 和roomtype 判断
            return
        end
        love.graphics.setColor(1,1,1,1)
        love.graphics.print(objact_language.get_string_in_languages("track"),x+200,y)
        love.graphics.print(objact_language.get_string_in_languages("beat_start"),x+40,y+50)
        if chart.note[tonumber(string.sub(displayed_content,5,#displayed_content))].type == "hold" then
            love.graphics.print(objact_language.get_string_in_languages("beat_end"),x+40,y+100)
        end
        love.graphics.print(objact_language.get_string_in_languages("fake"),x+40,y+150)
        if chart.note[tonumber(string.sub(displayed_content,5,#displayed_content))].fake == 0 then
            love.graphics.print(objact_language.get_string_in_languages("true"),x+100,y+150)
        else
            love.graphics.print(objact_language.get_string_in_languages("false"),x+100,y+150)
        end
    end,
}