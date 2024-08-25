
function low_bezier(startTime, endTime, startValue, endValue, bezierTable,nowtime)
    -- 计算时间点在时间范围内的百分比
    local timePercent = (nowtime - startTime) / (endTime - startTime)
    
    -- 限制时间范围在0到1之间
    timePercent = math.max(0, math.min(1, timePercent))

    local p0 = {0, 0}  -- 起点
    local p1 = {bezierTable[1], bezierTable[2]}  -- 控制点1
    local p2 = {bezierTable[3], bezierTable[4]}  -- 控制点2
    local p3 = {1, 1}  -- 终点
    --二分求解 
    local accuracy = 0.05
    --精度
    local lf = 0
    local rl = 1
    local mid = 0.5
    while rl - lf > accuracy do --精度之外
        --算出x和时间百分比的距离
        mid = (lf + rl) / 2
        local mid_x = ((1-mid)^3 * p0[1] + 3 * (1 - mid)^2 * mid * p1[1] + 3 * (1 - mid) * mid^2 * p2[1] + mid ^ 3 * p3[1])
        if mid_x < timePercent then -- 往右偏
            lf = mid
        elseif mid_x > timePercent then --往左偏
            rl = mid
        else-- 同
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

    return ky
end


function bezier(startTime, endTime, startValue, endValue, bezierTable,nowtime)
    -- 计算时间点在时间范围内的百分比
    local timePercent = (nowtime - startTime) / (endTime - startTime)
    
    -- 限制时间范围在0到1之间
    timePercent = math.max(0, math.min(1, timePercent))

    local p0 = {0, 0}  -- 起点
    local p1 = {bezierTable[1], bezierTable[2]}  -- 控制点1
    local p2 = {bezierTable[3], bezierTable[4]}  -- 控制点2
    local p3 = {1, 1}  -- 终点
    --二分求解 
    local accuracy = 0.0005
    --精度
    local lf = 0
    local rl = 1
    local mid = 0.5
    while rl - lf > accuracy do --精度之外
        --算出x和时间百分比的距离
        mid = (lf + rl) / 2
        local mid_x = ((1-mid)^3 * p0[1] + 3 * (1 - mid)^2 * mid * p1[1] + 3 * (1 - mid) * mid^2 * p2[1] + mid ^ 3 * p3[1])
        if mid_x < timePercent then -- 往右偏
            lf = mid
        elseif mid_x > timePercent then --往左偏
            rl = mid
        else-- 同
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

    return ky
end