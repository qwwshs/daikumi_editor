local hit_sound
local hit_light = love.graphics.newImage("asset/hit_light.png")
local hit_sound_tab ={}
local hit_tab ={}
--用来对照的 true需要播放 false为播放完成
local hit = {}
for i = 1, 19 do
    hit[i] = love.graphics.newImage("asset/hit/hit-"..i..".png")
end
local hitlight_w, hitlight_h = hit_light:getDimensions( ) -- 得到宽高
local hit_w, hit_h = hit[1]:getDimensions( ) -- 得到宽高
--note的打击
objact_hit = {
    load = function()
        -- 读取音频文件
        local tab = love.filesystem.getDirectoryItems("" ) --得到文件夹下的所有文件
        for i,v in ipairs(tab) do
            if string.find(v,"hit_sound") then
                hit_sound = love.audio.newSource(v, "stream")
                break
            end
        end
    end,
    update = function(dt)
        for i = 1,#chart.note do
            if not hit_sound_tab["b"..thebeat(chart.note[i].beat).."tk"..chart.note[i].track.."ty"..chart.note[i].type] then --不存在 记录
                if thebeat(chart.note[i].beat) <= beat.nowbeat then
                    hit_sound_tab["b"..thebeat(chart.note[i].beat).."tk"..chart.note[i].track.."ty"..chart.note[i].type] = false
                else
                    hit_sound_tab["b"..thebeat(chart.note[i].beat).."tk"..chart.note[i].track.."ty"..chart.note[i].type] = true
                end
            end
            if thebeat(chart.note[i].beat) < beat.nowbeat and --播放
            hit_sound_tab["b"..thebeat(chart.note[i].beat).."tk"..chart.note[i].track.."ty"..chart.note[i].type] == true then
                local x,w = event_get(chart.note[i].track,beat.nowbeat)
                hit_sound_tab["b"..thebeat(chart.note[i].beat).."tk"..chart.note[i].track.."ty"..chart.note[i].type] = false --播放完成

                if hit_sound and settings.hit_sound == 1 and music_play == true and w > 0 and not( chart.note[i].fake == 1) then --播放
                    love.audio.setVolume( settings.hit_volume / 100 ) --设置音量大小
                    hit_sound:seek(0)
                    hit_sound:play()
                end
                if settings.hit == 1 and music_play == true and w > 0 and not( chart.note[i].fake == 1) then
                    
                    hit_tab[#hit_tab + 1] = {x = to_play_track_original_x(x),time = time.nowtime,track = chart.note[i].track}
                end
            end
            if thebeat(chart.note[i].beat) >= beat.nowbeat then
                hit_sound_tab["b"..thebeat(chart.note[i].beat).."tk"..chart.note[i].track.."ty"..chart.note[i].type] = true --未播放
            end

        end

        --hit动画更新
        local local_tab = {}
        for i = 1,#hit_tab do
            if time.nowtime <= hit_tab[i].time + 0.5 then
                local_tab[#local_tab + 1] = hit_tab[i]
            end
        end
        hit_tab = local_tab
    end,
    draw = function()
        if settings.hit == 0 then
            return
        end
        for i = 1,#hit_tab do
            local hit_scale_w = 1 / hit_w * 500
            local hit_scale_h = 1 / hit_h * 500 / (window_h_scale / window_w_scale)
            
            local hit_light_scale_w = 1 / hitlight_w
            local hit_light_scale_h = 1 / hitlight_h  / (window_h_scale / window_w_scale)
            if demo_mode then
                hit_scale_h = 1 / hit_h * 500 / (window_h_scale / window_w_scale)   / ((1 + 150 / 800) / (1600/900))
                hit_scale_w = 1 / hit_w * 500
            end
            love.graphics.setColor(1,1,1,1)
            local v = math.floor((time.nowtime - hit_tab[i].time) / 0.5 * 19)+1
            if v > 19 then
                v = 19
                love.graphics.setColor(1,1,1,0)
            elseif v < 1 then
                v = 1
                love.graphics.setColor(1,1,1,0)
            end

            local hit_angle = math.acos( (hit_tab[i].x-450) / (settings.judge_line_y-note_occurrence_point *math.tan(math.rad(settings.angle)) ))
            love.graphics.push()
            love.graphics.translate(450, settings.judge_line_y)
            love.graphics.shear(math.cos(hit_angle),0)  -- 水平倾斜，适应轨道
            if demo_mode then
                love.graphics.draw(hit[v]
                ,hit_tab[i].x-450-250,-250 / (window_h_scale / window_w_scale)/ ((1 + 150 / 800) / (1600/900)),0,hit_scale_w,hit_scale_h)
                
            else
                love.graphics.draw(hit[v]
                ,hit_tab[i].x-450-250,-250 /(window_h_scale / window_w_scale),0,hit_scale_w,hit_scale_h)
            end

            --光效
            if not (v >= 19 or v <= 1) then --防止暂停时滞留
                love.graphics.setColor(1,1,1,(19-v)/(19*3)) --只要1/4的alpha
                local x,w = to_play_track(event_get(hit_tab[i].track,beat.nowbeat))
                love.graphics.draw(hit_light,x-450,-300,0,hit_light_scale_w*w,hit_light_scale_h*300)
            end

            love.graphics.pop()
        end
    end
}