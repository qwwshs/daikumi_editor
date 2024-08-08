local play = nil
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_play = love.graphics.newImage("asset_ui_play.png")
local ui_pause = love.graphics.newImage("asset_ui_pause.png")
objact_music_play = { --分度改变用的
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
    end,
    draw = function()
        love.graphics.setColor(1,1,1,1)
        local _width, _height = ui_play:getDimensions( ) -- 得到宽高
        local _scale_w = 1 / _width * w
        local _scale_h = 1 / _height * h
        if music_play == false then -- 正在播放
            love.graphics.draw(ui_play,x,y,r,_scale_w,_scale_h)
        else
            love.graphics.draw(ui_pause,x,y,r,_scale_w,_scale_h)
        end
    end,
    keyboard = function(key)
        if key == "space" then
            music_play = not music_play
        end
    end,
    mousepressed = function( x1, y1, button, istouch, presses )
        if x1 >= x  and x1 <= x + w and y1 <= y + h and y1 >= y then -- 在play的范围内
            objact_music_play.keyboard("space")
        end
    end,
    update = function(dt)
        if music_play == true then
            time.nowtime = time.nowtime + dt *music_speed
            beat.nowbeat = time_to_beat(chart.bpm_list,time.nowtime)
            if music then
                music:setPitch(music_speed)
            end
            if time.nowtime - chart.offset / 1000 >= 0 then
                if music then
                    love.audio.setVolume( settings.music_volume / 100 ) --设置音量大小
                    music:play()
                end
            end
    
        else
            if music then
                music:pause() 
            end
            if time.nowtime - chart.offset / 1000 >= 0 then
                if music then
                    music:seek(time.nowtime - chart.offset / 1000 )
                end
            else -- 超时
                if music then
                    music:seek(0)
                end
            end
        end
    end,
}