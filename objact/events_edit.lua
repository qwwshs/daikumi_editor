--多事件编辑
local x = 0
local y = 0
local r = 0
local w = 0
local h = 0
local pos = "multiple_events_edit"
events_edit_perturbation = 0 --扰动
events_edit_form = 0 --总的form
events_edit_to = 0 --总的to
events_edit_trans_expression = '' --过渡类型的表达式
local expression = function(x) return x end --表达式

local function will_draw()
    return room_type(pos) and the_room_pos({"edit",'tracks_edit'})
end
local function easings_input_ed_finish() --开关输入完成后的回调 写出表达式
    local temp_string = ''
    if events_edit_trans_expression:find("easing") then
        temp_string = events_edit_trans_expression:gsub('easing','')
        temp_string = temp_string:gsub(' ','')
        if string.match(temp_string, "%d") then --有数字用数字确定easings
            expression = loadstring ('x = ... return easings.easings_use_number['..temp_string..'](x)')
        else
            expression = loadstring ('x = ... return easings.easings_use_string.'..temp_string..'(x)')
        end
        return
    elseif events_edit_trans_expression:find("bezier") then
        temp_string = '{'..events_edit_trans_expression:gsub('bezier','') .. '}'
        temp_string = temp_string:gsub(' ','')
        expression = loadstring ('x = ... return bezier(0,1,0,1,'..temp_string..',x)')
        return
    elseif events_edit_trans_expression:find("function") then
        temp_string = events_edit_trans_expression:gsub('function','')
        temp_string = temp_string:gsub(' ','')
        expression = loadstring ('x = ... return '..temp_string)
        return
    end
end
function do_events() --执行

    local copy_table = get_copy()
    for i = 1,#copy_table.event do
        for k = 1,#chart.event do
            if tablesEqual(copy_table.event[i],chart.event[k]) then
                local ok,err = pcall(function() local a = expression(1) end)
                if not ok then --处理错误的表达式
                    expression = function(x) return x end
                    log('expression error:',err)
                end
                local form_to_random = math.random(-events_edit_perturbation,events_edit_perturbation)
                copy_table.event[i].form = copy_table.event[i].form + form_to_random + events_edit_form + 
                ((events_edit_to - events_edit_form) *
                expression(((thebeat(copy_table.event[i].beat) - thebeat(copy_table.event[1].beat))/
                (thebeat(copy_table.event[#copy_table.event].beat2) - thebeat(copy_table.event[1].beat) ) )) )--一起修改 保证copy_tab与chart的event一致
                
                copy_table.event[i].to = copy_table.event[i].to + form_to_random + events_edit_form +
                ((events_edit_to - events_edit_form) *
                expression(((thebeat(copy_table.event[i].beat2) - thebeat(copy_table.event[1].beat))/
                (thebeat(copy_table.event[#copy_table.event].beat2) - thebeat(copy_table.event[1].beat) ))) )
                chart.event[k].form = copy_table.event[i].form
                chart.event[k].to = copy_table.event[i].to
            end
        end
    end
end
function draw_events_button_do()
    love.graphics.setColor(1,1,1,1)
    love.graphics.rectangle("line",1220,700,100,40)
    love.graphics.setColor(1,1,1,1)
    love.graphics.print(objact_language.get_string_in_languages("do"),1220,700)


end
objact_events_edit = {
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
        button_new("events_edit_do",do_events,1220,700,100,40,draw_events_button_do,{will_draw = will_draw})
        input_box_new("events_edit_perturbation","events_edit_perturbation",1300,100,100,25,{type = "number",will_draw = will_draw})
        input_box_new("events_edit_form","events_edit_form",1300,150,100,25,{type = "number",will_draw = will_draw})
        input_box_new("events_edit_to","events_edit_to",1300,200,100,25,{type = "number",will_draw = will_draw})
        input_box_new("events_edit_trans_expression","events_edit_trans_expression",1300,250,100,25,{will_draw = will_draw,input_ed_finish = easings_input_ed_finish})
        if not room_type(pos) then
            return
        end
        
    end,
    draw = function()
        if not room_type(pos) then
            return
        end
        love.graphics.setColor(1,1,1,1)
        love.graphics.print(objact_language.get_string_in_languages("perturbation"),1220,100)
        love.graphics.print(objact_language.get_string_in_languages("form"),1220,150)
        love.graphics.print(objact_language.get_string_in_languages("to"),1220,200)
        love.graphics.print(objact_language.get_string_in_languages("trans_expression"),1220,250)

            --函数图像绘制
        love.graphics.rectangle('fill',1300,600,200,2)
        love.graphics.rectangle('fill',1300,600,2,-200)
        love.graphics.setColor(0,1,1,1)
        for i = 0, 1, 0.01 do
            local y = 0
            pcall(function() y = expression(i) end)
            y = y or 0
            love.graphics.rectangle('fill',1300 + i*200,600-y*200,2,2)
        end
    end,
}