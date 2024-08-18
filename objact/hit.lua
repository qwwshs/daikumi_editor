local hit_sound
local hit_sound_tab ={}
local hit_tab ={}
--用来对照的 true需要播放 false为播放完成
local hit = {}
for i = 1, 19 do
    hit[i] = love.graphics.newImage("asset/hit/hit-"..i..".png")
end

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

                hit_sound_tab["b"..thebeat(chart.note[i].beat).."tk"..chart.note[i].track.."ty"..chart.note[i].type] = false --播放完成

                if hit_sound and settings.hit_sound == 1 and music_play == true then --播放
                    love.audio.setVolume( settings.hit_volume / 100 ) --设置音量大小
                    hit_sound:seek(0)
                    hit_sound:play()
                end
                if settings.hit == 1 and music_play == true then
                    local x,w = event_get(chart.note[i].track,beat.nowbeat)
                    hit_tab[#hit_tab + 1] = {x = x * 9,time = time.nowtime}
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
        for i = 1,#hit_tab do
            local hit_w, hit_h = hit[1]:getDimensions( ) -- 得到宽高
            local hit_scale = 1 / hit_h * 500
            love.graphics.setColor(1,1,1,1)
            local v = math.floor((time.nowtime - hit_tab[i].time) / 0.5 * 19)+1
            if v > 19 then
                v = 19
                love.graphics.setColor(1,1,1,0)
            elseif v < 1 then
                v = 1
                love.graphics.setColor(1,1,1,0)
            end
            local note_angle = math.acos( (hit_tab[i].x-450) / (settings.judge_line_y-note_occurrence_point *math.tan(math.rad(settings.angle)) ))
            love.graphics.push()
            love.graphics.translate(450, settings.judge_line_y)
            love.graphics.shear(math.cos(note_angle),0)  -- 水平倾斜，适应轨道
            love.graphics.draw(hit[v]
            ,hit_tab[i].x-450-250,-250 ,0,hit_scale,hit_scale)
            love.graphics.pop()
        end
    end
}