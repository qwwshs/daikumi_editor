
local contact_roller = 1 -- 鼠标滚动系数
local ui_note = love.graphics.newImage("asset_ui_note.png")
local ui_wipe = love.graphics.newImage("asset_ui_wipe.png")
local ui_hold = love.graphics.newImage("asset_ui_hold_head.png")
local ui_hold_body = love.graphics.newImage("asset_ui_hold_body.png")
local ui_hold_tail = love.graphics.newImage("asset_ui_hold_tail.png")
room_play = { -- 最基础的 播放页面
load = function()
    objact_hit.load()
    objact_music_speed.load(650,50,0,25,25)
    objact_denom.load(875,50,0,25,25)
    objact_track.load(725,50,0,25,25)
    objact_track_scale.load(800,50,0,25,25)
    objact_music_play.load(500,50,0,50,50)
    objact_note.load(400,50,0,50,16.6)
    objact_note.load(100,50,0,50,16.6)
    objact_note_edit_inplay.load(100,50,0,50,16.6)
    objact_save.load(50,50,0,50,50)
    objact_slider.load(0,100,0,20,700)
end,
update = function(dt)
    objact_music_play.update(dt)
    objact_slider.update(dt)
    objact_hit.update(dt)
end,

draw = function()
    love.graphics.setColor(1,1,1,1)
    if bg then -- 背景存在就显示
        local bg_width, bg_height = bg:getDimensions( ) -- 得到宽高
        local bg_scale_h = 1 / bg_height * 800 
        local bg_scale_w = 1 / bg_height * 800 / (window_w_scale / window_h_scale)
        if 1 / bg_height * 800 / (window_h_scale / window_w_scale) < 1 / bg_width * 900 / (window_w_scale / window_h_scale) then
            bg_scale_h = 1 / bg_width * 900 / (window_h_scale / window_w_scale)
            bg_scale_w = 1 / bg_width * 900
        end
        if demo_mode == true then
            bg_scale_h = 1 / bg_height * 800 
            bg_scale_w = 1 / bg_height * 800 / (window_w_scale / window_h_scale) / ((1600/900)/(1 + 150 / 800))
            if 1 / bg_height * 800 / (window_h_scale / window_w_scale)  / ((1 + 150 / 800) / (1600/900)) <
            1 / bg_width * 900 / (window_w_scale / window_h_scale) / ((1600/900)/(1 + 150 / 800)) then
                bg_scale_h = 1 / bg_width * 900 / (window_h_scale / window_w_scale)   / ((1 + 150 / 800) / (1600/900))
                bg_scale_w = 1 / bg_width * 900
            end
        end

        love.graphics.draw(bg,0,0,0,bg_scale_w,bg_scale_h)

    end
    love.graphics.setColor(RGBA_hexToRGBA("#64000000")) --游玩区域显示的背景板
    love.graphics.rectangle("fill",0,0,900,800)

    
    for i=1 ,#chart.event do --轨道底板绘制
        local x,w = event_get(chart.event[i].track,beat.nowbeat)
        x,w =  (x-w/2) *9,w*9 --为了居中
        --倾斜计算
        love.graphics.setColor(0,0,0,1)  --底板
        love.graphics.polygon("fill",x,settings.judge_line_y,x+w,settings.judge_line_y,450,note_occurrence_point*math.tan(math.rad(settings.angle)))

    end
    local draw_exist = false --选择时底板已经绘制
    for i=1 ,#chart.event do --轨道侧线绘制
        local x,w = event_get(chart.event[i].track,beat.nowbeat)
        x,w =  (x-w/2) *9,w*9 --为了居中
        --倾斜计算

        if track.track == chart.event[i].track and draw_exist == false and demo_mode == false then --选择时的底板
            draw_exist = true
            love.graphics.setColor(1,1,1,0.2) 
            love.graphics.polygon("fill",x,settings.judge_line_y,x+w,settings.judge_line_y,450,note_occurrence_point*math.tan(math.rad(settings.angle)))
        end
        
        love.graphics.setColor(1,1,1,1) --侧线
        love.graphics.polygon("line",x,settings.judge_line_y,x+w,settings.judge_line_y,450,note_occurrence_point*math.tan(math.rad(settings.angle)))
        love.graphics.setColor(1,1,1,1) --轨道编号
        if track.track == chart.event[i].track and demo_mode == false then
            love.graphics.setColor(0,1,1,1) --轨道编号
        end
        love.graphics.print(chart.event[i].track,x+w/2,settings.judge_line_y+20) --为了居中
    end

    local note_h = settings.note_height --25 * denom.scale
    local note_w = 75
    love.graphics.setColor(1,1,1,settings.note_alpha / 100)
    --展示侧note渲染
    for i = 1,#chart.note do
        local x,w = event_get(chart.note[i].track,beat.nowbeat)
        local y = beat_to_y(chart.note[i].beat)
        local y2 = y
        if chart.note[i].type == "hold" then
            y2 = beat_to_y(chart.note[i].beat2)
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

        if chart.note[i].type == "note" then
            local _width, _height = ui_note:getDimensions() -- 得到宽高

            local _scale_w = 1 / _width * to_3d_w

            local _scale_h = 1 / _height * note_h
            if y > 0 - note_h and y < 800 + note_h then
                
                love.graphics.draw(ui_note,to_3d_x
                ,-note_h,0,_scale_w,_scale_h)
            end
            love.graphics.pop()  -- 恢复之前的变换状态 
        elseif chart.note[i].type == "wipe" then
            local _width, _height = ui_note:getDimensions() -- 得到宽高

            local _scale_w = 1 / _width * to_3d_w

            local _scale_h = 1 / _height * note_h
            if y > 0 - note_h and y < 800 + note_h then
                love.graphics.draw(ui_wipe,to_3d_x
                ,-note_h,0,_scale_w,_scale_h)
            end
            love.graphics.pop()  -- 恢复之前的变换状态 
        else --hold
            local _width, _height = ui_note:getDimensions() -- 得到宽高

            local _scale_w = 1 / _width * to_3d_w

            local _scale_h = 1 / _height * note_h
            if y > 0 - note_h and y < 800 + note_h then
                love.graphics.draw(ui_hold,to_3d_x
                ,-note_h,0,_scale_w,_scale_h)
            end
            love.graphics.pop() --提前释放 重新偏移
            
            love.graphics.push()
            to_3d = (y2 -note_h -  note_occurrence_point * math.tan(math.rad(settings.angle))) / 
                    (settings.judge_line_y - note_occurrence_point * math.tan(math.rad(settings.angle))) --变成伪3d y 比上长度
            to_3d_w =  w *to_3d
            _scale_w = 1 / _width * to_3d_w
            to_3d_x = (original_x-450) *to_3d - to_3d_w/2

            note_angle = math.acos( (x-450) / (settings.judge_line_y-note_occurrence_point *math.tan(math.rad(settings.angle)) ))
            

            if y2 > 0 - note_h and y2 < 800 + note_h and settings.angle == 90 then --尾
                love.graphics.translate(450, y2)
                love.graphics.shear(math.cos(note_angle),0)  -- 水平倾斜，适应轨道
                love.graphics.draw(ui_hold_tail,to_3d_x
                ,0,0,_scale_w,_scale_h)
            end

            love.graphics.pop() --提前释放 重新偏移

            local note_h2 = y - y2
            local _scale_h2 = 1 / _height * note_h / 4
            if y > 0 - note_h and y2 < 800 + note_h then
                --把长条拆成一段段来渲染 以达到倾斜效果
                for i = y2 + note_h ,y-note_h - note_h/4,note_h /4 do
                    love.graphics.push()
                    

                    to_3d = (i - note_occurrence_point * math.tan(math.rad(settings.angle))) / 
                    (settings.judge_line_y - note_occurrence_point * math.tan(math.rad(settings.angle))) --变成伪3d y 比上长度
                    to_3d_w =  w *to_3d 
                    _scale_w = 1 / _width * to_3d_w
                    to_3d_x = (original_x-450) *to_3d - to_3d_w/2

                    note_angle = math.acos( (x-450) / (settings.judge_line_y-note_occurrence_point *math.tan(math.rad(settings.angle)) ))
                    love.graphics.translate(450, i) --减去尾的位置
                    love.graphics.shear(math.cos(note_angle),0)  -- 水平倾斜，适应轨道

                    love.graphics.draw(ui_hold_body,to_3d_x
                    ,0,0,_scale_w,_scale_h2) --身
                    love.graphics.pop()
                end
            end
            
        end
        love.graphics.setStencilTest()
    end


    
    love.graphics.setColor(1,1,1,1) --轨道
    love.graphics.rectangle("line",900,0,75,800)

    love.graphics.setColor(1,1,1,1) -- x轨道
    love.graphics.rectangle("line",1000,0,75,800)

    love.graphics.setColor(1,1,1,1) -- w轨道
    love.graphics.rectangle("line",1100,0,75,800)

    love.graphics.setColor(1,1,1,1) --判定线
    love.graphics.rectangle("fill",900,settings.judge_line_y,275,10)

    love.graphics.rectangle("line",0,settings.judge_line_y,900,10)

    love.graphics.setColor(1,1,1,1) --现在节拍
    love.graphics.print(beat.nowbeat,900,settings.judge_line_y+20)
    if demo_mode == false then
        for isbeat = 0, beat.allbeat do -- beat和分度的渲染
            local denom_size = 1
            local beat_y = 0
            for isdenom=1,denom.denom - 1 do --分度刷新
                local denom_beat = (1 / denom.denom)* isdenom 
                beat_y = beat_to_y(isbeat - denom_beat)

                if denom_size > 0 and denom_size < 10 then
                        love.graphics.setColor(RGBA_hexToRGBA("#FF646464"))

                        if denom.denom % 3 == 0 and denom.denom % 4 ~= 0 then
                            love.graphics.setColor(RGBA_hexToRGBA("#6400FF37"))
                        end

                        if  isdenom % 2 == 0 and denom.denom % 2 == 0 then
                            love.graphics.setColor(RGBA_hexToRGBA("#FFCD37FF"))
                        end

                        if isdenom  == denom.denom / 2 then --中线
                            love.graphics.setColor(RGBA_hexToRGBA("#FF7FFFF4"))
                        end
                    love.graphics.rectangle("fill",0,beat_y,1175,1)
                end
            end
            love.graphics.setColor(RGBA_hexToRGBA("#FFFFFFFF"))
            beat_y = beat_to_y(isbeat)
            love.graphics.rectangle("fill",0,beat_y,1175,1) -- 节拍线
            love.graphics.print(isbeat,1200,beat_y)
        end
        --鼠标指针所在位置所对应的beat渲染
        if mouse.x < 1200 then--在play里面
            --根据距离反推出beat
            local mouse_beat = y_to_beat(mouse.y)
            local mouse_min_denom = 1 --假设1最近
            for i = 1, denom.denom do --取分度 哪个近取哪个
                if math.abs(mouse_beat - (math.floor(mouse_beat) + i / denom.denom)) < math.abs(mouse_beat - (math.floor(mouse_beat) + mouse_min_denom / denom.denom)) then
                    mouse_min_denom = i
                end
            end
            local mouse_y = settings.judge_line_y + (beat.nowbeat - math.floor(mouse_beat)-mouse_min_denom / denom.denom) * denom.scale * 100
            love.graphics.setColor(1,1,1,0.5)
            love.graphics.rectangle("fill",0,mouse_y,1200,2)
        end
    end
    
    local _width, _height = ui_note:getDimensions( ) -- 得到宽高
    local _scale_w = 1 / _width * note_w
    local _scale_h = 1 / _height * note_h
    love.graphics.setColor(1,1,1,1)
    --note(edit区域渲染)
    for i=1,#chart.note do

        local y = beat_to_y(chart.note[i].beat)
        local y2 = y
        if chart.note[i].type == "hold" then
            y2 = beat_to_y(chart.note[i].beat2)
        end

        if chart.note[i].track == track.track then
            if chart.note[i].type == "note" then
                
                if y > 0 - note_h and y < 800 + note_h then
                    love.graphics.draw(ui_note,900,y-note_h,0,_scale_w,_scale_h)
                end
            elseif chart.note[i].type == "wipe" then
                if y > 0 - note_h and y < 800 + note_h then
                    love.graphics.draw(ui_wipe,900,y-note_h,0,_scale_w,_scale_h)
                end
            else --hold

                if y > 0 - note_h and y < 800 + note_h then
                    love.graphics.draw(ui_hold,900,y-note_h,0,_scale_w,_scale_h) -- 头
                end
                    
                local note_h2 = y - y2 -note_h * 2
                local _scale_h2 = 1 / _height * note_h2
                if y2 > 0 - note_h and y2 < 800 + note_h then
                    love.graphics.draw(ui_hold_tail,900,y2,0,_scale_w,_scale_h) -- 尾
                end

                if y > 0 - note_h  and y2 < 800 + note_h then
                    love.graphics.draw(ui_hold_body,900,y2+note_h,0,_scale_w,_scale_h2) --身
                end

            end

        end
        
    end
    --放置一半的长条渲染
    local thelocal_hold = get_hold_table()
    if thelocal_hold.beat and thelocal_hold.track == track.track then -- 存在
        local _width, _height = ui_hold:getDimensions( ) -- 得到宽高
        local _scale_w = 1 / _width * note_w
        local _scale_h = 1 / _height * note_h
        love.graphics.setColor(1,1,1,1)
        local y = settings.judge_line_y + (beat.nowbeat - thebeat(thelocal_hold.beat)) * denom.scale * 100
        if y > 0 - note_h and y < 800 + note_h then
            love.graphics.draw(ui_hold,900,y-note_h,0,_scale_w,_scale_h) -- 头
        end
    end

        --event渲染
        local event_h = settings.note_height
        local event_w = 75
        for i=1,#chart.event do
            if chart.event[i].track == track.track then
                local _width, _height = ui_hold:getDimensions( ) -- 得到宽高
                local _scale_w = 1 / _width * event_w
                local _scale_h = 1 / _height * event_h
                    
                love.graphics.setColor(1,1,1,1)
                local y = beat_to_y(chart.event[i].beat)
                local y2 = beat_to_y(chart.event[i].beat2)
                local event_h2 = y - y2 - event_h * 2
                local _scale_h2 = 1 / _height * event_h2
                local x_pos = 1000
                if chart.event[i].type == "w" then
                    x_pos = 1100
                end
                if y > 0 - event_h and y < 800 + event_h then
                    love.graphics.draw(ui_hold,x_pos,y-event_h,0,_scale_w,_scale_h) -- 头
                    love.graphics.print(chart.event[i].form,x_pos+37.5-#tostring(chart.event[i].form)*3.5,y-event_h) -- 头 初始
                end
                if y > 0 - event_h  and y2 < 800 + event_h then
                    love.graphics.draw(ui_hold_body,x_pos,y2+event_h,0,_scale_w,_scale_h2) --身
                end
                if y2 > 0 - event_h and y2 < 800 + event_h then
                    love.graphics.draw(ui_hold_tail,x_pos,y2,0,_scale_w,_scale_h) --尾
                    love.graphics.print(chart.event[i].to,x_pos+37.5-#tostring(chart.event[i].to)*3.5,y2) --尾 结尾 --tostring是为了居中
                end
                -- beizer曲线
                if y > 0 - event_h  and y2 < 800 + event_h then
                    for k = 1,10 do
                        local nowx = low_bezier(1,10,(chart.event[i].form - 50) / 100 * 75 + x_pos +37.5,x_pos + 37.5 + (chart.event[i].to - 50) / 100 *75,chart.event[i].trans,k) --减去50是为了使50居中
                        local nowy = y + (y2 - y) * k / 10
                        love.graphics.rectangle("fill",nowx,nowy -  (y2 - y)/10,5, (y2 - y)/10) --减去一个 (y2 - y)/10是为了与头对齐
                    end
                end
            end
        end
        --放置一半的event渲染
        local thelocal_event = get_event_table()
        if thelocal_event.beat and thelocal_event.track == track.track then -- 存在
            local _width, _height = ui_hold:getDimensions( ) -- 得到宽高
            local _scale_w = 1 / _width * event_w
            local _scale_h = 1 / _height * event_h
            love.graphics.setColor(1,1,1,1)
            local y = beat_to_y(thelocal_event.beat)
            --头
            if y > 0 - note_h and y < 800 + note_h then
                if thelocal_event.type == "x" then
                    love.graphics.draw(ui_hold,1000,y-note_h,0,_scale_w,_scale_h)
                else -- w
                    love.graphics.draw(ui_hold,1100,y-note_h,0,_scale_w,_scale_h)
                end
            end
        end

        if string.sub(displayed_content,1,5) == "event" and --选中event框绘制
        chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].track == track.track then --框出现在编辑的event
            local y = beat_to_y(chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].beat)
            local y2 = beat_to_y(chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].beat2)
            love.graphics.setColor(1,1,1,0.5)
            if chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].type == "x" then
                love.graphics.rectangle("fill",1000,y2,75,y - y2)
            else
                love.graphics.rectangle("fill",1100,y2,75,y - y2)
            end
            
        end

    --顶上的工具栏
    love.graphics.setColor(RGBA_hexToRGBA("#64646464"))
    love.graphics.rectangle("fill",0,0,1175,100) -- 节拍线

    love.graphics.setColor(RGBA_hexToRGBA("#FFFFFFFF"))
    --ui 节拍线
    objact_denom.draw()

    --ui 播放速度调节
    objact_music_speed.draw()

    --ui 轨道缩放 第几轨道
    objact_track_scale.draw()
    objact_track.draw()

    --播放键
    objact_music_play.draw()

    --保存键
    objact_save.draw()

    --note放置相关
    objact_note.draw()
    
    --event放置相关
    objact_note.draw()

    --进度条
    objact_slider.draw()

    --hit
    objact_hit.draw()

    --复制粘贴相关
    objact_copy.draw()
end,
keypressed = function(key)
    
    objact_denom.keyboard(key)
    objact_music_speed.keyboard(key)
    objact_track.keyboard(key)
    objact_track_scale.keyboard(key)

    objact_music_play.keyboard(key)

    objact_note.keyboard(key)
    objact_note_edit_inplay.keyboard(key)
    objact_event.keyboard(key)
    objact_save.keyboard(key)

    objact_copy.keyboard(key)
end,

wheelmoved = function(x,y)
    if mouse.x > 1200 then  --限制范围
        return
    end
    --beat更改
        local temp = contact_roller --临时数值

        music_play = false

        if y > 0 then
            temp = contact_roller / denom.denom
        else
            temp = -contact_roller / denom.denom
        end

        beat.nowbeat = beat.nowbeat +temp
        if beat.nowbeat < 0 then
            beat.nowbeat = 0
        end
        if beat.nowbeat >= beat.allbeat then
            beat.nowbeat = beat.allbeat
        end

        local min_denom = 0 --假设0最近
        for i = 1, denom.denom do --取分度 哪个近取哪个
            if math.abs(beat.nowbeat - (math.floor(beat.nowbeat) + i / denom.denom)) < math.abs(beat.nowbeat - (math.floor(beat.nowbeat) + min_denom / denom.denom)) then
                min_denom = i
            end
        end
        beat.nowbeat = math.floor(beat.nowbeat) + min_denom / denom.denom --更正位置

        time.nowtime = beat_to_time(chart.bpm_list,beat.nowbeat)

        local y_beat = temp
        objact_copy.wheelmoved(x,y_beat * denom.scale * 100)
end,
mousepressed = function( x, y, button, istouch, presses )
    objact_denom.mousepressed( x, y, button, istouch, presses )
    objact_music_speed.mousepressed( x, y, button, istouch, presses )
    objact_track_scale.mousepressed( x, y, button, istouch, presses )
    objact_track.mousepressed( x, y, button, istouch, presses )
    objact_music_play.mousepressed( x, y, button, istouch, presses )
    objact_event.mousepressed( x, y, button, istouch, presses )
    objact_save.mousepressed( x, y, button, istouch, presses )
    objact_slider.mousepressed( x, y, button, istouch, presses )
    objact_copy.mousepressed(x, y, button, istouch, presses)
    objact_note_edit_inplay.mousepressed(x, y, button, istouch, presses)
end,
textinput = function(input)
    objact_denom.textinput(input)
    objact_music_speed.textinput(input)
    objact_track_scale.textinput(input)
    objact_track.textinput(input)
end,
mousereleased = function( x, y, button, istouch, presses )
    objact_slider.mousereleased(x, y, button, istouch, presses)
    objact_copy.mousereleased(x, y, button, istouch, presses)
end,
keyreleased = function(key)

end,
quit = function()
    objact_save.quit()
end
}