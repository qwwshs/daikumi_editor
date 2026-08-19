--event直观编辑
local CoordinateService = require("src.services.coordinateService")
local directEventEditing = object:new('directEventEditing')
directEventEditing.open = false
directEventEditing.catch_point = nil
function directEventEditing:keypressed(key)
    if input('directEventEditing') then
        self.open = not self.open
        if self.open then
            messageBox:add("direct event editing open")
        else
            messageBox:add("direct event editing close")
        end
    end
end

function directEventEditing:draw()
    if not self.open then
        return
    end
    if sidebar.displayed_content ~= 'event' then
        return
    end
    local radius = 20
    love.graphics.setColor(1, 1, 1, 1) --头和尾的两个可拖动的圆
    --得到event
    local isevent = chart.event[sidebar.incoming[1]]
    local c_y = CoordinateService:toY(isevent:getBeat())
    local c_y2 = CoordinateService:toY(isevent:getBeat2())
    local c_x = fTrack:to_play_track_x(isevent:getFrom())
    local c_x2 = fTrack:to_play_track_x(isevent:getTo())
    love.graphics.circle('line', c_x, c_y, radius)
    love.graphics.circle('line', c_x2, c_y2, radius)

    love.graphics.setColor(1, 1, 1, 1)

    if isevent:getTransType() == 'bezier' then
        local control_point = { c_x, c_y }
        local transData = isevent:getTransData()
        for i = 1, #transData, 2 do
            local nowx = transData[i]
            local nowy = transData[i + 1]
            if not (nowx and nowy) then break end
            --进行缩放
            nowx = c_x + (c_x2 - c_x) * nowx
            nowy = c_y + (c_y2 - c_y) * nowy
            table.insert(control_point, nowx)
            table.insert(control_point, nowy)
            love.graphics.circle('line', nowx, nowy, radius,4)
        end
        table.insert(control_point, c_x2)
        table.insert(control_point, c_y2)
        love.graphics.line(control_point)
    end
end

function directEventEditing:update(dt)
    if not self.open then
        return
    end
    if sidebar.displayed_content ~= 'event' then
        return
    end
    local isevent = chart.event[sidebar.incoming[1]]
    if not isevent then return end
    local c_y = CoordinateService:toY(isevent:getBeat())
    local c_y2 = CoordinateService:toY(isevent:getBeat2())
    local c_x = fTrack:to_play_track_x(isevent:getFrom())
    local c_x2 = fTrack:to_play_track_x(isevent:getTo())
    local radius = 20
    if love.mouse.isDown(1) then
        if self.catch_point == 'head' then --拖动头
            local now_beat = beat:toNearby(CoordinateService:yToBeat(mouse.y))
            if beat:get(now_beat) < isevent:getBeat2Value() then
                isevent:setBeat(now_beat)
            end

            --有fance就吸附
            local now_from = fTrack:track_get_near_fence_x()
            isevent:setFrom(math.roundToPrecision(now_from,1000))
        elseif self.catch_point == 'tail' then --拖动尾
            local now_beat = beat:toNearby(CoordinateService:yToBeat(mouse.y))
            if beat:get(now_beat) > isevent:getBeatValue() then
                isevent:setBeat2(now_beat)
            end

            --有fance就吸附
            local now_to = fTrack:track_get_near_fence_x()
            isevent:setTo(math.roundToPrecision(now_to,1000))
        end
        if isevent:getTransType() == 'bezier' then
            local bezier_points = {}
            local transData = isevent:getTransData()
            for i = 1, #transData, 2 do
                local nowx = transData[i]
                local nowy = transData[i + 1]
                if not (nowx and nowy) then break end
                --进行缩放
                nowx = c_x + (c_x2 - c_x) * nowx
                nowy = c_y + (c_y2 - c_y) * nowy
                table.insert(bezier_points, { x = nowx, y = nowy })
            end
            for index, point in pairs(bezier_points) do
                if self.catch_point == 'control' .. index then --拖动控制点
                    local nowx = mouse.x
                    local nowy = mouse.y
                    --进行缩放
                    nowx = math.roundToPrecision((nowx - c_x) / (c_x2 - c_x),1000)
                    nowy = math.roundToPrecision((nowy - c_y) / (c_y2 - c_y),1000)
                    isevent:getTransData()[(index - 1) * 2 + 1] = nowx
                    isevent:getTransData()[(index - 1) * 2 + 2] = nowy
                end
            end
        end
        sidebar:to('event', sidebar.incoming[1]) --更新信息
    end
    local original_x, original_y = love.mouse.getPosition() --对缩放进行处理
    Slab.BeginWindow('Left_Mouse_Context_Menu', { Title = "", X = original_x, Y = original_y, W = 0, H = 0 ,BgColor = {0,0,0,0}})
    if Slab.BeginContextMenuWindow() then
        if Slab.MenuItem(i18n:get('switch trans type')) then
            if isevent:getTransType() == 'bezier' then isevent:setTransType('easings') else isevent:setTransType('bezier') end
        end

        if Slab.MenuItem(i18n:get('switch the curve to the next type')) then
            if isevent:getTransType() == 'bezier' then
                if fEvent.bezier[transIndex.bezier + 1] then
                    transIndex.bezier = transIndex.bezier + 1
                    isevent:setTransData(table.copy(fEvent.bezier[transIndex.bezier]))
                end
            else
                if easings[transIndex.easings + 1] then
                    transIndex.easings = transIndex.easings + 1
                    isevent:setEasings(transIndex.easings)
                end
            end
        end

        if Slab.MenuItem(i18n:get('switch the curve back to the previous type')) then
            if isevent:getTransType() == 'bezier' then
                if fEvent.bezier[transIndex.bezier - 1] then
                    transIndex.bezier = transIndex.bezier - 1
                    isevent:setTransData(table.copy(fEvent.bezier[transIndex.bezier]))
                end
            else
                if easings[transIndex.easings - 1] then
                    transIndex.easings = transIndex.easings - 1
                    isevent:setEasings(transIndex.easings)
                end
            end
        end

        if isevent:getTransType() == 'bezier' then
            if Slab.MenuItem(i18n:get('add control point')) then
                local x = (mouse.x - c_x) / (c_x2 - c_x)
                local y = (mouse.y - c_y) / (c_y2 - c_y)
                table.insert(isevent:getTransData(),x)
                table.insert(isevent:getTransData(),y)
            end
            if Slab.MenuItem(i18n:get('delete control point')) then
                local td = isevent:getTransData()
                if #td > 2 then
                    table.remove(td,-1)
                    table.remove(td,-1)
                end
            end
        end

        Slab.EndContextMenu()
        sidebar:to('event', sidebar.incoming[1]) --更新信息
    end
    Slab.EndWindow()

    
    --松手清除
    if not love.mouse.isDown(1) and self.catch_point then
        self.catch_point = nil
    end

end

function directEventEditing:mousepressed(x, y, button, istouch, presses)
    if not self.open then
        return
    end
    if sidebar.displayed_content ~= 'event' then
        return
    end
    local isevent = chart.event[sidebar.incoming[1]]
    if not isevent then return end
    local c_y = CoordinateService:toY(isevent:getBeat())
    local c_y2 = CoordinateService:toY(isevent:getBeat2())
    local c_x = fTrack:to_play_track_x(isevent:getFrom())
    local c_x2 = fTrack:to_play_track_x(isevent:getTo())
    local radius = 20
    if love.mouse.isDown(1) then
        if math.intersect(mouse.x, mouse.x, c_x - radius, c_x + radius) and math.intersect(mouse.y, mouse.y, c_y - radius, c_y + radius) then --拖动头
            self.catch_point = 'head'
            return
        elseif math.intersect(mouse.x, mouse.x, c_x2 - radius, c_x2 + radius) and math.intersect(mouse.y, mouse.y, c_y2 - radius, c_y2 + radius) then --拖动尾
            self.catch_point = 'tail'
            return
        end
        if isevent:getTransType() == 'bezier' then
            local bezier_points = {}
            local transData = isevent:getTransData()
            for i = 1, #transData, 2 do
                local nowx = transData[i]
                local nowy = transData[i + 1]
                if not (nowx and nowy) then break end
                --进行缩放
                nowx = c_x + (c_x2 - c_x) * nowx
                nowy = c_y + (c_y2 - c_y) * nowy
                table.insert(bezier_points, { x = nowx, y = nowy })
            end
            for index, point in pairs(bezier_points) do
                if math.intersect(mouse.x, mouse.x, point.x - radius, point.x + radius) and math.intersect(mouse.y, mouse.y, point.y - radius, point.y + radius) then --拖动控制点
                    self.catch_point = 'control' .. index
                    return
                end
            end
        end
    end
end

return directEventEditing
