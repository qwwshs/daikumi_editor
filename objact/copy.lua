--note和event的复制粘贴
local mouse_start_pos = {x = 0 ,y = 0 } --鼠标按下的时候的x和y
local copy_tab = {
    note = {},
    event = {},
    type = "", --类型是复制 还是裁剪
    pos = "", --位置是游玩区域还是编辑区域
}
objact_copy = {
    draw = function()
        local note_h = settings.note_height --25 * denom.scale
        local note_w = 75 
        if mouse.down_state == true then --复制框
            love.graphics.setColor(0,1,1,0.4)
            love.graphics.rectangle("fill",mouse_start_pos.x,mouse_start_pos.y,mouse.x - mouse_start_pos.x,mouse.y - mouse_start_pos.y)
            love.graphics.setColor(0,1,1,1)
            love.graphics.rectangle("line",mouse_start_pos.x,mouse_start_pos.y,mouse.x - mouse_start_pos.x,mouse.y - mouse_start_pos.y)
        end
        if copy_tab.type ~= "x" then
            love.graphics.setColor(0,1,1,0.5)
        else
            love.graphics.setColor(1,1,1,0.5)
        end
            --对所选标记   
            for i=1,#copy_tab.note do

                local y = beat_to_y(copy_tab.note[i].beat)
                local y2 = y - note_h
                if copy_tab.note[i].type == "hold" then
                    y2 = beat_to_y(copy_tab.note[i].beat2)
                end

                if copy_tab.note[i].track == track.track then
                    if y > 0 - note_h  and y2 < 800 + note_h then
                        love.graphics.rectangle("fill",900,y2,75,y - y2)
                    end
                end

            end
        if copy_tab.pos == "play" then
            for i = 1,#copy_tab.note do
                local x,w = event_get(copy_tab.note[i].track,beat.nowbeat)
                local y = beat_to_y(copy_tab.note[i].beat)
                local y2 = y
                if copy_tab.note[i].type == "hold" then
                    y2 = beat_to_y(copy_tab.note[i].beat2)
                end
                local original_x = x*9 --原始x没有因为居中修改坐标
                x,w =  (x-w/2) *9,w*9 --为了居中
                local to_3d = (y - note_occurrence_point * math.tan(math.rad(settings.angle))) / 
                (settings.judge_line_y - note_occurrence_point * math.tan(math.rad(settings.angle))) --变成伪3d y 比上长度
                local to_3d_w =  w *to_3d
                
                local to_3d_x = (original_x-450) *to_3d - to_3d_w/2
        
                    --图像范围限制函数
                local function myStencilFunction()
                    love.graphics.polygon("fill",x-450,settings.judge_line_y-y,x-450+w,settings.judge_line_y-y,0,note_occurrence_point*math.tan(math.rad(settings.angle))-y)
                    --love.graphics.rectangle("fill",-1000,-1000,2000,2000)
                end
                --使图片倾斜
                local note_angle = math.acos( (x-450) / (settings.judge_line_y-note_occurrence_point *math.tan(math.rad(settings.angle)) ))
                love.graphics.push()
                love.graphics.translate(450, y)
                love.graphics.stencil(myStencilFunction, "replace", 1)
                love.graphics.setStencilTest("greater", 0)
                love.graphics.shear(math.cos(note_angle),0)  -- 水平倾斜，适应轨道
        
                if copy_tab.note[i].type ~= "hold" then
                    if y > 0 - note_h and y < 800 + note_h then
                        
                        love.graphics.rectangle("fill",to_3d_x,-note_h,to_3d_w,note_h)
                    end
                    love.graphics.pop()  -- 恢复之前的变换状态 
                else --hold
                    local to_3d_tail = (y2 -note_h -  note_occurrence_point * math.tan(math.rad(settings.angle))) / 
                            (settings.judge_line_y - note_occurrence_point * math.tan(math.rad(settings.angle))) --变成伪3d y 比上长度
                    local to_3d_w_tail =  w *to_3d_tail
                    local to_3d_x_tail = (original_x-450) *to_3d - to_3d_w/2
        
                    note_angle = math.acos( (x-450) / (settings.judge_line_y-note_occurrence_point *math.tan(math.rad(settings.angle)) ))
                    
        
                    if y > 0 - note_h and y2 < 800 + note_h then --身
                        love.graphics.polygon("fill",to_3d_x,0,to_3d_w + to_3d_x,0,to_3d_w_tail + to_3d_x_tail,y2 - y + note_h,to_3d_x_tail,y2 - y  + note_h)
                    end
        
                    love.graphics.pop()

                end
                love.graphics.setStencilTest()
            end

        end

        for i=1,#copy_tab.event do

            local y = beat_to_y(copy_tab.event[i].beat)
            local y2 = beat_to_y(copy_tab.event[i].beat2)
            local x_pos = 1000
            if copy_tab.event[i].type == "w" then
                x_pos = 1100
            end

            if copy_tab.event[i].track == track.track then
                if y > 0 - note_h  and y2 < 800 + note_h then
                    love.graphics.rectangle("fill",x_pos,y2,75,y - y2)
                end
            end
        end

    end,
    update = function(dt)

    end,
    mousepressed = function(x,y)
        mouse_start_pos = {x = mouse.x, y = mouse.y}
    end,
    mousereleased = function(x,y)
        --松手＋shift确认选中
        if not (iskeyboard.lshift == true or iskeyboard.rshift == true) then
            return
        end
        copy_tab = {note = {},event = {}}
        local min_x = math.min(x,mouse_start_pos.x)
        local max_x = math.max(x,mouse_start_pos.x)
        local min_y_beat = y_to_beat(math.max(y,mouse_start_pos.y))
        local max_y_beat = y_to_beat(math.min(y,mouse_start_pos.y))  --这引擎y是向下增长的 服了 beat是向上增长的 所以要取反

        if max_x < 900  then --在note轨道 play区域
            copy_tab.pos = 'play'
            --先for循环记录此刻在游玩区域的轨道
            local local_track = {} --记录表
            for i = 1,#chart.event do --点击轨道进入轨道的编辑事件
                local track_x,track_w = event_get(chart.event[i].track,beat.nowbeat)
                track_x,track_w = (track_x-track_w/2)*9,track_w*9
                if not (max_x < track_x or track_x + track_w < min_x) then
                    local_track[i] = true
                end
            end

            for i = 1,#chart.note do
                local isbeat = thebeat(chart.note[i].beat)
                local isbeat2 = isbeat
                if chart.note[i].type == 'hold' then
                    isbeat2 = thebeat(chart.note[i].beat2)
                end

                if (not (max_y_beat < isbeat or isbeat2 < min_y_beat)) and local_track[chart.note[i].track] == true then --这引擎y是向下增长的 服了
                    copy_tab.note[#copy_tab.note + 1] = copyTable(chart.note[i])

                end
            end

            for i = 1,#chart.event do --用于完全复制
                local isbeat = thebeat(chart.event[i].beat)
                local isbeat2 = thebeat(chart.event[i].beat2)
                if (not (max_y_beat < isbeat or isbeat2 < min_y_beat)) and local_track[chart.event[i].track] == true then
                    copy_tab.event[#copy_tab.event + 1] = copyTable(chart.event[i])
                end
            end

            return 
        end
        
        if not (max_x < 900 or 1000 < min_x) then --在note轨道
            for i = 1,#chart.note do
                local isbeat = thebeat(chart.note[i].beat)
                local isbeat2 = isbeat
                if chart.note[i].type == 'hold' then
                    isbeat2 = thebeat(chart.note[i].beat2)
                end

                if (not (max_y_beat < isbeat or isbeat2 < min_y_beat)) and track.track == chart.note[i].track then --这引擎y是向下增长的 服了
                    copy_tab.note[#copy_tab.note + 1] = copyTable(chart.note[i])

                end
            end

        end

        if not (max_x < 1000 or 1200 < min_x) then --在event轨道
            for i = 1,#chart.event do
                local event_x_min = 1000
                local event_x_max = 1100
                if chart.event[i].type == "w" then
                    event_x_min = 1100
                    event_x_max = 1200
                end
                if not (max_x < event_x_min or event_x_max < min_x) then
                    local isbeat = thebeat(chart.event[i].beat)
                    local isbeat2 = thebeat(chart.event[i].beat2)
                    if (not (max_y_beat < isbeat or isbeat2 < min_y_beat)) and track.track == chart.event[i].track then
                        copy_tab.event[#copy_tab.event + 1] = copyTable(chart.event[i])
                    end
                end
            end
        end

    end,
    wheelmoved = function(x,y)
        mouse_start_pos.y = mouse_start_pos.y + y
    end,
    keyboard = function(key)
        if iskeyboard.lshift == true or iskeyboard.rshift == true and mouse.down_state == true then
            objact_copy.mousereleased(mouse.x,mouse.y)
        end
        
        if not isctrl == true then
            return
        end
        if key == "c" then
            copy_tab.type = "c"
        elseif key == "x" then
            copy_tab.type = "x"
        elseif key == "d" then
            displayed_content = "nil"
            local local_tab = {}
            if copy_tab.pos ~= 'play' or (copy_tab.pos == 'play' and iskeyboard.a == true) then
                objact_redo.write_revoke("copy delete",copyTable(copy_tab))
                log(tableToString(copy_tab))
            else
                objact_redo.write_revoke("copy delete",{note = copyTable(copy_tab.note),event = {}})

            end

            for i = 1,#chart.note do
                if not tablesEqual(copy_tab.note[1],chart.note[i]) then
                    local_tab[#local_tab + 1] = chart.note[i]
                else 
                    table.remove(copy_tab.note,1)
                end
            end
            chart.note = copyTable(local_tab)

            local_tab = {}
            if copy_tab.pos ~= 'play' or (copy_tab.pos == 'play' and iskeyboard.a == true) then -- a完全复制
                for i = 1,#chart.event do
                    if not tablesEqual(copy_tab.event[1],chart.event[i]) then
                        local_tab[#local_tab + 1] = chart.event[i]
                    else 
                        table.remove(copy_tab.event,1)
                    end
                end
            end

            chart.event = copyTable(local_tab)
            copy_tab = {
                note = {},
                event = {},
                type = "", --类型是复制 还是裁剪
                pos = "", --位置是游玩区域还是编辑区域
            }
        elseif key == "v" or key == "b" then
            displayed_content = "nil"
            --先对表进行处理
            local copy_tab2 = copyTable(copy_tab)
            local frist_beat = {0,0,4}  --作为基准
            if copy_tab.note[1] and copy_tab.event[1] and thebeat(copy_tab.note[1].beat) <= thebeat(copy_tab.event[1].beat) then
                frist_beat = copy_tab.note[1].beat
            elseif copy_tab.note[1] and copy_tab.event[1] and thebeat(copy_tab.note[1].beat) > thebeat(copy_tab.event[1].beat) then
                frist_beat = copy_tab.event[1].beat
            elseif (not copy_tab.note[1]) and copy_tab.event[1] then
                frist_beat = copy_tab.event[1].beat
            elseif copy_tab.note[1] and (not copy_tab.event[1]) then
                frist_beat = copy_tab.note[1].beat
            end

            if copy_tab.note[1] and copy_tab.pos == 'play' and iskeyboard.a == false then --不完全复制
                frist_beat = copy_tab.note[1].beat
            end
            for i = 1, #copy_tab2.note do
                if copy_tab.pos ~= 'play' then
                    copy_tab2.note[i].track = track.track
                end
                copy_tab2.note[i].beat = beat_add(beat_sub(copy_tab2.note[i].beat,frist_beat),y_to_beat(mouse.y))
                if copy_tab2.note[i].type == "hold" then
                    copy_tab2.note[i].beat2 = beat_add(beat_sub(copy_tab2.note[i].beat2,frist_beat),y_to_beat(mouse.y))
                end
            end
            for i = 1, #copy_tab2.event do
                if copy_tab.pos ~= 'play' then
                    copy_tab2.event[i].track = track.track
                end
                copy_tab2.event[i].beat = beat_add(beat_sub(copy_tab2.event[i].beat,frist_beat),y_to_beat(mouse.y))
                copy_tab2.event[i].beat2 = beat_add(beat_sub(copy_tab2.event[i].beat2,frist_beat),y_to_beat(mouse.y))
                if key == "b" then --取反
                    copy_tab2.event[i].form = 100 - copy_tab2.event[i].form
                    copy_tab2.event[i].to = 100 - copy_tab2.event[i].to
                end
            end
            --写入谱面内
            for i = 1, #copy_tab2.note do
                chart.note[#chart.note + 1] = copyTable(copy_tab2.note[i])
            end
            if copy_tab.pos ~= 'play' or (copy_tab.pos == 'play' and iskeyboard.a == true) then -- a完全复制
                for i = 1, #copy_tab2.event do
                    chart.event[#chart.event + 1] = copyTable(copy_tab2.event[i])
                end
            end
            event_sort()
            note_sort()

            if copy_tab.type == "c" then
                if copy_tab.pos ~= 'play' or (copy_tab.pos == 'play' and iskeyboard.a == true) then -- a完全复制
                    objact_redo.write_revoke("copy",copyTable(copy_tab2))
                else
                    objact_redo.write_revoke("copy",{note = copyTable(copy_tab2.note),event = {}})
                end
                return
            end

            if copy_tab.pos ~= 'play' or (copy_tab.pos == 'play' and iskeyboard.a == true) then -- a完全复制
                objact_redo.write_revoke("cropping",{copyTable(copy_tab),copyTable(copy_tab2)})
            else
                objact_redo.write_revoke("cropping",{{note = copyTable(copy_tab.note),event = {}},{note = copyTable(copy_tab2.note),event = {}}} )
            end

            local local_tab = {}
            for i = 1,#chart.note do
                if not tablesEqual(copy_tab.note[1],chart.note[i]) then
                    local_tab[#local_tab + 1] = chart.note[i]
                else 
                    table.remove(copy_tab.note,1)
                end
            end
            chart.note = copyTable(local_tab)
            local_tab = {}
            if copy_tab.pos ~= 'play' or (copy_tab.pos == 'play' and iskeyboard.a == true) then -- a完全复制
                for i = 1,#chart.event do
                    if not tablesEqual(copy_tab.event[1],chart.event[i]) then
                        local_tab[#local_tab + 1] = chart.event[i]
                    else 
                        table.remove(copy_tab.event,1)
                    end
                end
                chart.event = copyTable(local_tab)
            end

        end
    end
}