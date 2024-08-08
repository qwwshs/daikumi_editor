--拖动条
local now_y = 0 --现在所在y位置
local x = 0
local y = 0
local r = 0
local w = 0
local h = 0
objact_slider = {
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
        now_y = y + h
    end,
    draw = function()
        if demo_mode == true then
            return
        end
        love.graphics.setColor(1,1,1,1)
        love.graphics.circle('line',x + w /2,now_y,w / 2,4) --现在所在位置点 
        love.graphics.rectangle('line',x,y,w,h) -- 框
        if isbutton == true then
            love.graphics.setColor(1,1,1,1)
            love.graphics.circle('fill',x + w /2,now_y,w / 2,4) --现在所在位置点 
            love.graphics.print("nowtime:"..(math.floor(time.nowtime*100)/100).."\nbeat:"..math.floor(beat.nowbeat*100)/100,x+w,now_y)
        end
        local local_tab = {1} --用来计算密度的
        for i = 1 ,100 do
            local_tab[i] = 1
        end
        --全谱平均note密度表示 分成100部分
        for i = 1, #chart.note do
            if not  --超界
            local_tab[math.floor(thebeat(chart.note[i].beat) / beat.allbeat * 100)] then 
                local_tab[math.floor(thebeat(chart.note[i].beat) / beat.allbeat * 100)] = 1 
            end

            local_tab[math.floor(thebeat(chart.note[i].beat) / beat.allbeat * 100)] = 
            local_tab[math.floor(thebeat(chart.note[i].beat) / beat.allbeat * 100)] + 1
        end
        --换算成相对高度
        local max =local_tab[1]
        local min =  local_tab[1]
        for i = 1, 100 do
            if max < local_tab[i] then
                max = local_tab[i]
            end
            if local_tab[i] < min then
                min = local_tab[i]
            end
        end
        if max == min then max = min + 1 end
        love.graphics.setColor(0,1,1,0.5)
        for i = 1, 100, 1 do
            local max_h = w
            local density_ratio = (local_tab[i]-min) / (max - min) --密度比例
            love.graphics.setColor(density_ratio * 1,1 - density_ratio * 1,1 - density_ratio * 1,0.5)
            love.graphics.rectangle("fill",x,y+ h - h / 100 * i,density_ratio * max_h,h / 100)
        end
    end,
    update = function(dt)
        now_y = -(time.nowtime / time.alltime * h) + y + h
        local y1 = mouse.y
        if  y1 < y then y1 = y  end ---限制范围
        if y1 > y + h then  y1 = y + h  end
        if isbutton == true then
            music_play = false
            now_y = y1
            time.nowtime = -(now_y-y - h) / h  * time.alltime
            beat.nowbeat = time_to_beat(chart.bpm_list,time.nowtime)
        end
    end,
    mousepressed = function(x1,y1)
        if not (y1 >= y - 10 and x1 >= x - 10 and y1 <= y + h + 10 and x1 <= x + w + 10)  then --加减10是为了更好抓取
            return
        end
        isbutton = true
        music_play = false
    end,
    mousereleased = function(x1,y1)
        isbutton = false
    end
}