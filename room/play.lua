
local pos = "edit"
room_play = { -- 最基础的 播放页面
load = function()
    objact_hit.load()
    objact_note.load(400,50,0,50,16.6)
    objact_note_edit_inplay.load(100,50,0,50,16.6)
end,
update = function(dt)
    if not the_room_pos(pos) then
        return
    end
    objact_hit.update(dt)
end,

draw = function()
    if not the_room_pos(pos) then
        return
    end
    
    love.graphics.setColor(1,1,1,settings.bg_alpha / 100)

    if bg then -- 背景存在就显示
        local bg_width, bg_height = bg:getDimensions( ) -- 得到宽高
            bg_scale_h = 1 / bg_width * 900 / (window_h_scale / window_w_scale)
            bg_scale_w = 1 / bg_width * 900
        if demo_mode == true then
            bg_scale_h = 1 / bg_width * 900 / (window_h_scale / window_w_scale)   / ((1 + 150 / 800) / (1600/900))
            bg_scale_w = 1 / bg_width * 900
        end

        love.graphics.draw(bg,0,0,0,bg_scale_w,bg_scale_h)

    end
    
    objact_demo_inplay.draw()
    
    if demo_mode == true then
        return
    end


    
    love.graphics.setColor(1,1,1,1) --总note event 数
    local str = 'note: '..#chart.note..'  event: '..#chart.event
    love.graphics.print(str,450 - #str * 4 /2,settings.judge_line_y + 60)

    
    
    objact_denom_play.draw()
    objact_note_play_in_edit.draw()

        --音频图渲染
    if settings.audio_picture == 1 then
        love.graphics.setColor(0,1,1,1)
        for i =  chart.offset / 1000,time.alltime, beat_to_time(chart.bpm_list,1 / ((denom.denom * 4))) do  
            if beat_to_y(time_to_beat(chart.bpm_list,i  - chart.offset / 1000)) >= 0 and 
                beat_to_y(time_to_beat(chart.bpm_list,i  - chart.offset / 1000)) <= 800 then
                -- 计算在音频样本数组中的位置  
                local sampleIndex = math.floor((i - chart.offset / 1000) * music_data.count / (time.alltime  - chart.offset / 1000))
                -- 获取该样本的值  
                local sampleValue = music_data.soundData:getSample(sampleIndex)
                -- 绘制线段  
                love.graphics.rectangle("fill",900 - math.abs(sampleValue) * 300, beat_to_y(time_to_beat(chart.bpm_list,i - chart.offset / 1000)), 
                math.abs(sampleValue) * 300,2) -- 音频振幅  
            elseif beat_to_y(time_to_beat(chart.bpm_list,i  - chart.offset / 1000)) < 0 then
                break
            end
        end
    end


    

    --栅栏绘制
    love.graphics.setColor(1,1,1,0.5)
    for i = 1, track.fence do
        love.graphics.rectangle("fill",900 / track.fence * i,100,2,900)
    end
    love.graphics.setColor(0,1,1,0.7)
    love.graphics.rectangle("fill",900 / track.fence * track_get_near_fence(),100,2,900)


    --note放置相关
    objact_note.draw()
    --复制粘贴相关
    objact_copy.draw()
end,
keypressed = function(key)
    if not the_room_pos(pos) then
        return
    end
    if mouse.x > 1200 then  --限制范围
        return
    end

    objact_note_event_move.keyboard(key)
    objact_note.keyboard(key)
    objact_note_edit_inplay.keyboard(key)
    objact_event.keyboard(key)

    objact_copy.keyboard(key)
    objact_redo.keyboard(key)

end,

wheelmoved = function(x,y)
    if mouse.x > 1200 then  --限制范围
        return
    end
    --beat更改
        local temp = settings.contact_roller--临时数值

        music_play = false

        if y > 0 then
            temp = settings.contact_roller/ denom.denom
        else
            temp = -settings.contact_roller/ denom.denom
        end
        local y_beat = temp
    objact_denom.wheelmoved(x,y)
    objact_copy.wheelmoved(x,y_beat * denom.scale * 100)

        
end,
mousepressed = function( x, y, button, istouch, presses )
    if not the_room_pos(pos) then
        return
    end
    objact_event.mousepressed( x, y, button, istouch, presses )
    objact_note.mousepressed( x, y, button, istouch, presses )
    objact_copy.mousepressed(x, y, button, istouch, presses)
    objact_note_edit_inplay.mousepressed(x, y, button, istouch, presses)
end,
textinput = function(input)
    if not the_room_pos(pos) then
        return
    end
end,
mousereleased = function( x, y, button, istouch, presses )
    if not the_room_pos(pos) then
        return
    end
    objact_copy.mousereleased(x, y, button, istouch, presses)
end,
keyreleased = function(key)
    if not the_room_pos(pos) then
        return
    end
end,
quit = function()
    if not the_room_pos(pos) then
        return
    end
end
}