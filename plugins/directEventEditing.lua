--[[
    插件名: directEventEditing
    描述: Event 直观编辑插件，提供可视化的拖拽控制点编辑 event
    作者: qwwshs
    版本: 1.0.0
    依赖: object, input, messageBox, sidebar, chart, beat, fTrack, fEvent, mouse, transIndex, easings, Slab, i18n

    功能：
    - 拖拽 event 的头/尾控制点
    - 拖拽 bezier 控制点
    - 右键菜单切换过渡类型
    - 添加/删除 bezier 控制点
]]

local ChartService = require("src.services.chartService")
local CoordinateService = require("src.services.coordinateService")
local directEventEditing = object:new('directEventEditing')

--- 是否开启直观编辑模式
directEventEditing.open = false

--- 当前被拖拽的控制点（nil, 'head', 'tail', 'control1', 'control2', ...）
directEventEditing.catch_point = nil

--- 控制点半径（用于点击检测）
local CONTROL_RADIUS = 20

-- ============================================================
-- 辅助函数
-- ============================================================

--- 获取当前正在编辑的 event
-- @return table|nil event 数据
local function getCurrentEvent()
    if sidebar.displayed_content ~= 'event' then return nil end
    local idx = sidebar.incoming[1]
    if not idx then return nil end
    return ChartService:getEvent(idx)
end

--- 获取 event 的屏幕坐标
-- @tparam Event isevent 事件对象
-- @treturn number c_x 头部 x 坐标
-- @treturn number c_y 头部 y 坐标
-- @treturn number c_x2 尾部 x 坐标
-- @treturn number c_y2 尾部 y 坐标
local function getEventScreenPos(isevent)
    local c_y = CoordinateService:toY(isevent:getBeat())
    local c_y2 = CoordinateService:toY(isevent:getBeat2())
    local c_x = fTrack:to_play_track_x(isevent:getFrom())
    local c_x2 = fTrack:to_play_track_x(isevent:getTo())
    return c_x, c_y, c_x2, c_y2
end

--- 获取 bezier 控制点的屏幕坐标列表
-- @tparam Event isevent 事件对象
-- @tparam number c_x 头部 x 坐标
-- @tparam number c_y 头部 y 坐标
-- @tparam number c_x2 尾部 x 坐标
-- @tparam number c_y2 尾部 y 坐标
-- @treturn table 控制点列表 {{x, y}, ...}
local function getBezierControlPoints(isevent, c_x, c_y, c_x2, c_y2)
    local points = {}
    if isevent:getTransType() ~= 'bezier' then return points end
    local transData = isevent:getTransData()
    for i = 1, #transData, 2 do
        local nowx = transData[i]
        local nowy = transData[i + 1]
        if not (nowx and nowy) then break end
        nowx = c_x + (c_x2 - c_x) * nowx
        nowy = c_y + (c_y2 - c_y) * nowy
        table.insert(points, { x = nowx, y = nowy })
    end
    return points
end

--- 检测鼠标是否在指定点的范围内
-- @tparam number px 点的 x 坐标
-- @tparam number py 点的 y 坐标
-- @tparam number radius 检测半径
-- @treturn boolean 是否在范围内
local function isMouseOnPoint(px, py, radius)
    return math.intersect(mouse.x, mouse.x, px - radius, px + radius) and
           math.intersect(mouse.y, mouse.y, py - radius, py + radius)
end

-- ============================================================
-- 生命周期方法
-- ============================================================

--- 键盘事件：切换直观编辑模式
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

--- 绘制控制点和 bezier 曲线
function directEventEditing:draw()
    if not self.open then return end
    if tabs and not tabs:isSingle() then return end --多标签页时 demo 区域不可交互
    local isevent = getCurrentEvent()
    if not isevent then return end

    local c_x, c_y, c_x2, c_y2 = getEventScreenPos(isevent)

    -- 绘制头/尾控制点
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle('line', c_x, c_y, CONTROL_RADIUS)
    love.graphics.circle('line', c_x2, c_y2, CONTROL_RADIUS)

    -- 绘制 bezier 曲线和控制点
    if isevent:getTransType() == 'bezier' then
        local control_points = { c_x, c_y }
        local bezier_points = getBezierControlPoints(isevent, c_x, c_y, c_x2, c_y2)
        for _, point in ipairs(bezier_points) do
            table.insert(control_points, point.x)
            table.insert(control_points, point.y)
            love.graphics.circle('line', point.x, point.y, CONTROL_RADIUS, 4)
        end
        table.insert(control_points, c_x2)
        table.insert(control_points, c_y2)
        love.graphics.line(control_points)
    end
end

--- 每帧更新：处理拖拽和右键菜单
function directEventEditing:update(dt)
    if not self.open then return end
    if tabs and not tabs:isSingle() then return end --多标签页时 demo 区域不可交互
    local isevent = getCurrentEvent()
    if not isevent then return end

    local c_x, c_y, c_x2, c_y2 = getEventScreenPos(isevent)

    -- 处理拖拽
    if love.mouse.isDown(1) then
        if self.catch_point == 'head' then
            -- 拖动头
            local now_beat = beat:toNearby(CoordinateService:yToBeat(mouse.y))
            if beat:get(now_beat) < isevent:getBeat2Value() then
                isevent:setBeat(now_beat)
            end
            local now_from = fTrack:track_get_near_fence_x()
            isevent:setFrom(math.roundToPrecision(now_from, 1000))

        elseif self.catch_point == 'tail' then
            -- 拖动尾
            local now_beat = beat:toNearby(CoordinateService:yToBeat(mouse.y))
            if beat:get(now_beat) > isevent:getBeatValue() then
                isevent:setBeat2(now_beat)
            end
            local now_to = fTrack:track_get_near_fence_x()
            isevent:setTo(math.roundToPrecision(now_to, 1000))
        end

        -- 拖拽 bezier 控制点
        if isevent:getTransType() == 'bezier' then
            local bezier_points = getBezierControlPoints(isevent, c_x, c_y, c_x2, c_y2)
            local transData = isevent:getTransData()
            for index, point in ipairs(bezier_points) do
                if self.catch_point == 'control' .. index then
                    local nowx = math.roundToPrecision((mouse.x - c_x) / (c_x2 - c_x), 1000)
                    local nowy = math.roundToPrecision((mouse.y - c_y) / (c_y2 - c_y), 1000)
                    transData[(index - 1) * 2 + 1] = nowx
                    transData[(index - 1) * 2 + 2] = nowy
                end
            end
        end

        sidebar:to('event', sidebar.incoming[1])
    end

    -- 右键菜单
    local original_x, original_y = love.mouse.getPosition()
    Slab.BeginWindow('Left_Mouse_Context_Menu', {
        Title = "", X = original_x, Y = original_y, W = 0, H = 0,
        BgColor = {0, 0, 0, 0}
    })
    if Slab.BeginContextMenuWindow() then
        -- 切换过渡类型
        if Slab.MenuItem(i18n:get('switch trans type')) then
            if isevent:getTransType() == 'bezier' then
                isevent:setTransType('easings')
            else
                isevent:setTransType('bezier')
            end
        end

        -- 切换到下一个曲线类型
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

        -- 切换到上一个曲线类型
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

        -- bezier 控制点操作
        if isevent:getTransType() == 'bezier' then
            if Slab.MenuItem(i18n:get('add control point')) then
                local x = (mouse.x - c_x) / (c_x2 - c_x)
                local y = (mouse.y - c_y) / (c_y2 - c_y)
                local td = isevent:getTransData()
                table.insert(td, x)
                table.insert(td, y)
            end
            if Slab.MenuItem(i18n:get('delete control point')) then
                local td = isevent:getTransData()
                if #td > 2 then
                    table.remove(td, #td)
                    table.remove(td, #td)
                end
            end
        end

        Slab.EndContextMenu()
        sidebar:to('event', sidebar.incoming[1])
    end
    Slab.EndWindow()

    -- 松手清除
    if not love.mouse.isDown(1) and self.catch_point then
        self.catch_point = nil
    end
end

--- 鼠标按下：检测控制点点击
function directEventEditing:mousepressed(x, y, button, istouch, presses)
    if not self.open then return end
    if tabs and not tabs:isSingle() then return end --多标签页时 demo 区域不可交互
    local isevent = getCurrentEvent()
    if not isevent then return end

    local c_x, c_y, c_x2, c_y2 = getEventScreenPos(isevent)

    if love.mouse.isDown(1) then
        -- 检测头控制点
        if isMouseOnPoint(c_x, c_y, CONTROL_RADIUS) then
            self.catch_point = 'head'
            return
        end

        -- 检测尾控制点
        if isMouseOnPoint(c_x2, c_y2, CONTROL_RADIUS) then
            self.catch_point = 'tail'
            return
        end

        -- 检测 bezier 控制点
        if isevent:getTransType() == 'bezier' then
            local bezier_points = getBezierControlPoints(isevent, c_x, c_y, c_x2, c_y2)
            for index, point in ipairs(bezier_points) do
                if isMouseOnPoint(point.x, point.y, CONTROL_RADIUS) then
                    self.catch_point = 'control' .. index
                    return
                end
            end
        end
    end
end

-- 注册为插件
if PluginManager then
    PluginManager:register({
        name = "directEventEditing",
        version = "1.0.0",
        description = "Event 直观编辑",
    })
end

return directEventEditing
