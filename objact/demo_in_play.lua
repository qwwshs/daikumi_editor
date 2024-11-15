
local ui_note = love.graphics.newImage("asset/ui_note.png")
local ui_wipe = love.graphics.newImage("asset/ui_wipe.png")
local ui_hold = love.graphics.newImage("asset/ui_hold_head.png")
local ui_hold_body = love.graphics.newImage("asset/ui_hold_body.png")
local ui_hold_tail = love.graphics.newImage("asset/ui_hold_tail.png")
local ui_tab = love.filesystem.getDirectoryItems("ui") --得到文件夹下的所有文件
if ui_tab and #ui_tab > 0 then
    for i=1,#ui_tab do
        local v = ui_tab[i]
        if string.find(v,"ui_note") then
            ui_note = love.graphics.newImage("ui/"..v)
        elseif string.find(v,"ui_wipe") then
            ui_wipe = love.graphics.newImage("ui/"..v)
        elseif string.find(v,"ui_hold_head") then
            ui_hold = love.graphics.newImage("ui/"..v)
        elseif string.find(v,"ui_hold_body") then
            ui_hold_body = love.graphics.newImage("ui/"..v)
        elseif string.find(v,"ui_hold_tail") then
            ui_hold_tail = love.graphics.newImage("ui/"..v)
        end
    end
end
--演示的
objact_demo_inplay = {
    draw = function(sx,sy) --x缩放和y缩放
    sx = sx or 1
    sy = sy or 1
    love.graphics.push()
    love.graphics.scale(sx,sy)
        love.graphics.setColor(RGBA_hexToRGBA("#64000000")) --游玩区域显示的背景板
    love.graphics.rectangle("fill",0,0,900,800)

    love.graphics.setColor(0,0,0,1) --游玩区域显示的背景板2底板
    love.graphics.rectangle("fill",0,settings.judge_line_y,900,800 - settings.judge_line_y)



    local drawed_track = {} --已经绘制的track
    for i=1 ,#chart.event do --轨道底板绘制
        if thebeat(chart.event.beat) > beat.nowbeat then
            break
        end
        if drawed_track[chart.event[i].track] == nil then
            local x,w = event_get(chart.event[i].track,beat.nowbeat)
            x,w = to_play_track(x,w) --为了居中
            --倾斜计算
            if w ~= 0 then
                love.graphics.setColor(0,0,0,0.5 )  --底板
                love.graphics.polygon("fill",x,settings.judge_line_y,x+w,settings.judge_line_y,450,note_occurrence_point*math.tan(math.rad(settings.angle)))
            end
            drawed_track[chart.event[i].track] = true
        end
    end
    local draw_exist = false --选择时底板已经绘制
    drawed_track = {} --已经绘制的track
    for i=1 ,#chart.event do --轨道侧线绘制
        if drawed_track[chart.event[i].track] == nil then
            local x,w = event_get(chart.event[i].track,beat.nowbeat)
            x,w = to_play_track(x,w) --为了居中
            --倾斜计算

            if track.track == chart.event[i].track and draw_exist == false and demo_mode == false then --选择时的底板
                draw_exist = true
                love.graphics.setColor(1,1,1,0.2) 
                love.graphics.polygon("fill",x,settings.judge_line_y,x+w,settings.judge_line_y,450,note_occurrence_point*math.tan(math.rad(settings.angle)))
            end
            if w ~= 0 then
                love.graphics.setColor(1,1,1,1) --侧线
                love.graphics.polygon("line",x,settings.judge_line_y,x+w,settings.judge_line_y,450,note_occurrence_point*math.tan(math.rad(settings.angle)))
            end
            love.graphics.setColor(1,1,1,1) --轨道编号
            if demo_mode == false then
                if track.track == chart.event[i].track then
                    love.graphics.setColor(0,1,1,1) --轨道编号
                end
                love.graphics.print(chart.event[i].track,x+w/2,settings.judge_line_y+20) --为了居中
            end
            drawed_track[chart.event[i].track] = true
        end
    end

    --游玩区域侧线
    love.graphics.setColor(1,1,1,1) --侧线
    local x,w = to_play_track(0,1)
    love.graphics.polygon("fill",x,settings.judge_line_y,x+w,settings.judge_line_y,450,note_occurrence_point*math.tan(math.rad(settings.angle)))
    x,w = to_play_track(100,1)
    love.graphics.polygon("fill",x,settings.judge_line_y,x+w,settings.judge_line_y,450,note_occurrence_point*math.tan(math.rad(settings.angle)))
    
    
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
        local original_x = to_play_track_original_x(x) --原始x没有因为居中修改坐标
        local original_w = to_play_track_original_w(w) --原始x没有因为居中修改坐标
        x,w = to_play_track(x,w) --为了居中
        if w > 40 and chart.note[i].type ~= "wipe" then --增加间隙
            w = w - 20
        elseif w <= 40 and w > 20 and chart.note[i].type ~= "wipe" then
            w = 20
        elseif w > 60 and chart.note[i].type == "wipe" then --增加间隙
            w = w - 30
        elseif w <= 60 and w > 30 and chart.note[i].type == "wipe" then
            w = 30
        end
        
        if (not  (y2 > 800 + note_h or y < 0 -  note_h)) and (not  (y > settings.judge_line_y and chart.note[i].fake == 1  ) )then
            local to_3d = (y - note_occurrence_point * math.tan(math.rad(settings.angle))) / 
                (settings.judge_line_y - note_occurrence_point * math.tan(math.rad(settings.angle))) --变成伪3d y 比上长度
            local to_3d_w =  w *to_3d
        
            local to_3d_x = (original_x-450) *to_3d - to_3d_w/2

            --图像范围限制函数
            local function myStencilFunction()
                love.graphics.polygon("fill",x-450,settings.judge_line_y-y,x-450+original_w,settings.judge_line_y-y,0,note_occurrence_point*math.tan(math.rad(settings.angle))-y)
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
        elseif y < 0 - note_h then
            break --因为note按顺序排的 所以不用再算一遍
        end
    end
    love.graphics.setColor(0,0,0,1) --判定线 play

    love.graphics.rectangle("fill",0,settings.judge_line_y - 3,900,16) --2是为了对其中心

    love.graphics.setColor(1,1,1,1) --判定线 play

    love.graphics.rectangle("line",0,settings.judge_line_y - 3,900,16) --2是为了对其中心

    love.graphics.setColor(0.7,0.7,0.7,0.5) --判定线内部
    love.graphics.rectangle("fill",0,settings.judge_line_y,900,10)

    --hit
    objact_hit.draw()
    love.graphics.pop()
    end
}