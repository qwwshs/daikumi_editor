
function low_bezier(startTime, endTime, startValue, endValue, bezierTable,nowtime,tr)  -- 减少计算量
    -- 计算时间点在时间范围内的百分比
    local timePercent = (nowtime - startTime) / (endTime - startTime)
    
    -- 限制时间范围在0到1之间
    timePercent = math.max(0, math.min(1, timePercent))

    local p0 = {0, 0}  -- 起点
    local p1 = {bezierTable[1], bezierTable[2]}  -- 控制点1
    local p2 = {bezierTable[3], bezierTable[4]}  -- 控制点2
    local p3 = {1, 1}  -- 终点

    -- 线1 先算出线性方程 然后求点坐标
  --  local line1 = math.sqrt((p1[1] - p0[1]) * (p1[1] - p0[1]) + (p1[2] - p0[2]) * (p1[2] - p0[2])) --线长度 1
    local line1_now = {((p1[1] - p0[1]) * timePercent) + p0[1],((p1[2] - p0[2]) * timePercent) + p0[2]} --现在点位置


    local line2_now = {((p2[1] - p1[1]) * timePercent) + p1[1],((p2[2] - p1[2]) * timePercent) + p1[2]} --现在点位置 动点1


    local line3_now = {((p3[1] - p2[1]) * timePercent) + p2[1],((p3[2] - p2[2]) * timePercent) + p2[2]} --现在点位置 动点2 


    local line21_now = {((line2_now[1] - line1_now[1]) * timePercent) + line1_now[1],((line2_now[2] - line1_now[2]) * timePercent) + line1_now[2]}

    local line22_now = {((line3_now[1] - line2_now[1]) * timePercent) + line2_now[1],((line3_now[2] - line2_now[2]) * timePercent) + line2_now[2]}

    local line31_now = {((line22_now[1] - line21_now[1]) * timePercent) + line21_now[1],((line22_now[2] - line21_now[2]) * timePercent) + line21_now[2]}
    --当时间t作为kx的时候 推出ky
    local value,v2 = startValue + (endValue - startValue) * line31_now[1],startValue + (endValue - startValue) * line31_now[2]
    local ky = 0

    --二分求解 
    local accuracy = 0.01
    --精度
    local lf = 0
    local rl = 1
    
    while rl - lf > accuracy do --精度之外

        
         local rl_x = math.abs( ((1-rl)^3 * p0[1] + 3 * (1 - rl)^2 * rl * p1[1] + 3 * (1 - rl) * rl^2 * p2[1] + rl ^ 3 * p3[1]) - timePercent)
         local lf_x =  math.abs( ((1-lf)^3 * p0[1] + 3 * (1 - lf)^2 * lf * p1[1] + 3 * (1 - lf) * lf^2 * p2[1] + lf ^ 3 * p3[1]) - timePercent)
        if lf_x < rl_x then -- 往右偏
                mid = (lf + rl) / 2
            rl = rl - accuracy
        elseif lf_x > rl_x then --往左偏
                mid = (lf + rl) / 2
            lf = lf + accuracy
        elseif 0 == rl_x then -- 右同
            mid = rl
            break
        elseif lf_x == 0 then --左同
            mid = lf 
            break
        elseif rl_x == lf_x then
            mid = (lf + rl) / 2
            break
        end

    end

    local t = mid
    local u = 1 - t
    local tt = t * t
    local uu = u * u
    local uuu = uu * u
    local ttt = tt * t
    
    -- 根据插值点计算数值
    local ky = startValue + (endValue - startValue) * (uuu * p0[2] + 3 * uu * t * p1[2] + 3 * u * tt * p2[2] + ttt * p3[2])

    if tr then
        return 1,line1_now,line2_now,line3_now,line21_now,line22_now,line31_now
    else --通过kx 求ky 
        return ky
    end
end


function bezier(startTime, endTime, startValue, endValue, bezierTable,nowtime,tr)
    -- 计算时间点在时间范围内的百分比
    local timePercent = (nowtime - startTime) / (endTime - startTime)
    
    -- 限制时间范围在0到1之间
    timePercent = math.max(0, math.min(1, timePercent))

    local p0 = {0, 0}  -- 起点
    local p1 = {bezierTable[1], bezierTable[2]}  -- 控制点1
    local p2 = {bezierTable[3], bezierTable[4]}  -- 控制点2
    local p3 = {1, 1}  -- 终点

    -- 线1 先算出线性方程 然后求点坐标
  --  local line1 = math.sqrt((p1[1] - p0[1]) * (p1[1] - p0[1]) + (p1[2] - p0[2]) * (p1[2] - p0[2])) --线长度 1
    local line1_now = {((p1[1] - p0[1]) * timePercent) + p0[1],((p1[2] - p0[2]) * timePercent) + p0[2]} --现在点位置


    local line2_now = {((p2[1] - p1[1]) * timePercent) + p1[1],((p2[2] - p1[2]) * timePercent) + p1[2]} --现在点位置 动点1


    local line3_now = {((p3[1] - p2[1]) * timePercent) + p2[1],((p3[2] - p2[2]) * timePercent) + p2[2]} --现在点位置 动点2 


    local line21_now = {((line2_now[1] - line1_now[1]) * timePercent) + line1_now[1],((line2_now[2] - line1_now[2]) * timePercent) + line1_now[2]}

    local line22_now = {((line3_now[1] - line2_now[1]) * timePercent) + line2_now[1],((line3_now[2] - line2_now[2]) * timePercent) + line2_now[2]}

    local line31_now = {((line22_now[1] - line21_now[1]) * timePercent) + line21_now[1],((line22_now[2] - line21_now[2]) * timePercent) + line21_now[2]}
    --当时间t作为kx的时候 推出ky
    local value,v2 = startValue + (endValue - startValue) * line31_now[1],startValue + (endValue - startValue) * line31_now[2]
    local ky = 0

    --二分求解 
    local accuracy = 0.005
    --精度
    local lf = 0
    local rl = 1
    
    while rl - lf > accuracy do --精度之外

        
         local rl_x = math.abs( ((1-rl)^3 * p0[1] + 3 * (1 - rl)^2 * rl * p1[1] + 3 * (1 - rl) * rl^2 * p2[1] + rl ^ 3 * p3[1]) - timePercent)
         local lf_x =  math.abs( ((1-lf)^3 * p0[1] + 3 * (1 - lf)^2 * lf * p1[1] + 3 * (1 - lf) * lf^2 * p2[1] + lf ^ 3 * p3[1]) - timePercent)
        if lf_x < rl_x then -- 往右偏
                mid = (lf + rl) / 2
            rl = rl - accuracy
        elseif lf_x > rl_x then --往左偏
                mid = (lf + rl) / 2
            lf = lf + accuracy
        elseif 0 == rl_x then -- 右同
            mid = rl
            break
        elseif lf_x == 0 then --左同
            mid = lf 
            break
        elseif rl_x == lf_x then
            mid = (lf + rl) / 2
            break
        end

    end

    local t = mid
    local u = 1 - t
    local tt = t * t
    local uu = u * u
    local uuu = uu * u
    local ttt = tt * t
    
    -- 根据插值点计算数值
    local ky = startValue + (endValue - startValue) * (uuu * p0[2] + 3 * uu * t * p1[2] + 3 * u * tt * p2[2] + ttt * p3[2])

    if tr then
        return 1,line1_now,line2_now,line3_now,line21_now,line22_now,line31_now
    else --通过kx 求ky 
        return ky
    end
end
