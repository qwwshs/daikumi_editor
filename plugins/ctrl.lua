--[[
    模块名: ctrl
    描述: 复制/粘贴/框选管理模块
    作者: qwwshs
    依赖: object, mouse, input, beat, fTrack, fEvent, fNote, chart, sidebar, track, trackSequence, messageBox

    实现了 note 和 event 的复制、剪切、粘贴、框选删除功能。
    支持：
    - 单选（右键点击）
    - 框选（Shift + 左键拖拽）
    - 复制/剪切/粘贴（Ctrl+C/X/V）
    - 取反粘贴（Ctrl+B）
    - 包含 event 的粘贴（Ctrl+A+V）
    - 删除所选（Ctrl+D）
]]

local ctrl = object:new('ctrl')
local ChartService = require("src.services.chartService")
local Note = require("src.objects.Note")
local Event = require("src.objects.Event")
local CoordinateService = require("src.services.coordinateService")

--- 深拷贝可能包含 Note/Event 对象的表
local function deepCopyWithNotes(tab)
    if tab._data then return tab:copy() end
    local result = {}
    for k, v in pairs(tab) do
        if type(v) == 'table' then
            if v._data then
                result[k] = v:copy()
            else
                result[k] = deepCopyWithNotes(v)
            end
        else
            result[k] = v
        end
    end
    return result
end

--- 鼠标按下时的起始位置和状态
ctrl.mouse_start_pos = { x = 0, y = 0, down = false }

--- 默认的空剪贴板结构
ctrl.meta_copy_tab = {
    note = {},
    event = {},
    note_tracks = {},   -- 与 note 并行的轨道数组（框选时的实际轨道）
    event_tracks = {},  -- 与 event 并行的轨道数组
    note_tabidx = {},   -- 与 note 并行的标签页下标数组
    event_tabidx = {},  -- 与 event 并行的标签页下标数组
    type = "",   -- 操作类型: "copy" 或 "cut"
    pos = "",    -- 来源位置: "play" 或 "edit" 或 "tabs"
}

--- 当前剪贴板数据
ctrl.copy_tab = table.copy(ctrl.meta_copy_tab)

-- ============================================================
-- 剪贴板操作辅助函数
-- ============================================================

--- 按 beat 排序剪贴板（保持轨道/标签页并行数组对齐）
local function sortCopy(istype)
    local items = ctrl.copy_tab[istype]
    local tracks = ctrl.copy_tab[istype .. '_tracks']
    local tabidx = ctrl.copy_tab[istype .. '_tabidx']
    local order = {}
    for i = 1, #items do order[i] = i end
    table.sort(order, function(a, b) return items[a]:getBeatValue() < items[b]:getBeatValue() end)
    local nitems, ntracks, ntabidx = {}, {}, {}
    for i, idx in ipairs(order) do
        nitems[i] = items[idx]
        ntracks[i] = tracks[idx]
        ntabidx[i] = tabidx[idx]
    end
    ctrl.copy_tab[istype] = nitems
    ctrl.copy_tab[istype .. '_tracks'] = ntracks
    ctrl.copy_tab[istype .. '_tabidx'] = ntabidx
end

--- 从剪贴板中移除指定元素
-- @tparam table new_table 要移除的元素
-- @tparam string istype 类型 ("note" 或 "event")
function ctrl:copy_sub(new_table, istype)
    if istype ~= "note" and istype ~= "event" then return end
    for i, v in ipairs(self.copy_tab[istype]) do
        if self.copy_tab[istype][i] == new_table then
            table.remove(self.copy_tab[istype], i)
            table.remove(self.copy_tab[istype .. '_tracks'], i)
            table.remove(self.copy_tab[istype .. '_tabidx'], i)
            return
        end
    end
end

--- 向剪贴板添加元素（去重）
-- @tparam table new_table 要添加的元素
-- @tparam string istype 类型 ("note" 或 "event")
-- @tparam number|nil track 元素所在实际轨道
-- @tparam number|nil tabidx 元素所在标签页下标
function ctrl:copy_add(new_table, istype, track, tabidx)
    if istype ~= "note" and istype ~= "event" then return end
    for i = 1, #self.copy_tab[istype] do
        if self.copy_tab[istype][i] == new_table then
            return -- 已存在，不重复添加
        end
    end
    self.copy_tab[istype][#self.copy_tab[istype] + 1] = new_table
    self.copy_tab[istype .. '_tracks'][#self.copy_tab[istype .. '_tracks'] + 1] = track or 0
    self.copy_tab[istype .. '_tabidx'][#self.copy_tab[istype .. '_tabidx'] + 1] = tabidx or 1
    sortCopy(istype)
end

--- 检查元素是否在剪贴板中
-- @tparam table new_table 要检查的元素
-- @tparam string istype 类型 ("note" 或 "event")
-- @treturn boolean 是否存在
function ctrl:copy_exist(new_table, istype)
    if istype ~= "note" and istype ~= "event" then return end
    for i = 1, #self.copy_tab[istype] do
        if self.copy_tab[istype][i] == new_table then
            return true
        end
    end
    return false
end

--- 获取剪贴板数据
-- @treturn table 剪贴板数据
function ctrl:get_copy()
    return self.copy_tab
end

-- ============================================================
-- 生命周期方法
-- ============================================================

--- 每帧更新：重置鼠标按下状态
function ctrl:update(dt)
    if not love.mouse.isDown(1) then
        self.mouse_start_pos.down = false
    end
end

--- 绘制框选区域和剪贴板标记
function ctrl:draw()
    local note_h = settings.note_height
    local note_w = play.layout.edit.noteW

    -- 绘制框选矩形
    if self.mouse_start_pos.down then
        love.graphics.setColor(play.colors.cyan_fade)
        love.graphics.rectangle("fill", self.mouse_start_pos.x, self.mouse_start_pos.y,
            mouse.x - self.mouse_start_pos.x, mouse.y - self.mouse_start_pos.y)
        love.graphics.setColor(play.colors.cyan)
        love.graphics.rectangle("line", self.mouse_start_pos.x, self.mouse_start_pos.y,
            mouse.x - self.mouse_start_pos.x, mouse.y - self.mouse_start_pos.y)
    end

    -- 绘制剪贴板中的选中标记
    if self.copy_tab.type ~= "cut" then
        love.graphics.setColor(play.colors.cyan_half)
    else
        love.graphics.setColor(play.colors.white_half)
    end

    -- 标记 edit 区域中的 note
    if tabs and not tabs:isSingle() then
        -- 多标签页：按标签页位置绘制（仅记录过标签页下标的项）
        for i = 1, #self.copy_tab.note do
            local n = self.copy_tab.note[i]
            local ti = self.copy_tab.note_tabidx[i]
            if ti then
                local y = CoordinateService:toY(n:getBeat())
                local y2 = y - note_h
                if n:isHold() then
                    y2 = CoordinateService:toY(n:getBeat2())
                end
                if y > 0 - note_h and y2 < WINDOW.h + note_h then
                    love.graphics.rectangle("fill", tabs:windowX(ti), y2, note_w, y - y2)
                end
            end
        end
    else
        for i = 1, #self.copy_tab.note do
            local n = self.copy_tab.note[i]
            local y = CoordinateService:toY(n:getBeat())
            local y2 = y - note_h
            if n:isHold() then
                y2 = CoordinateService:toY(n:getBeat2())
            end
            if n:getTrack() == track.track then
                if y > 0 - note_h and y2 < WINDOW.h + note_h then
                    love.graphics.rectangle("fill", play.layout.edit.x, y2, note_w, y - y2)
                end
            end
        end
    end

    -- 标记 play 区域中的 note
    if self.copy_tab.pos == "play" then
        local all_track_pos = play:get_all_track_pos()
        for i = 1, #self.copy_tab.note do
            local n = self.copy_tab.note[i]
            local trackPos = all_track_pos[n:getTrack()]
            local x, w = fTrack:to_play_track(trackPos.x, trackPos.w)
            local y = CoordinateService:toY(n:getBeat())
            local y2 = y
            if n:isHold() then
                y2 = CoordinateService:toY(n:getBeat2())
            end
            if y < 0 - note_h then break end
            if math.intersect(y, y2, settings.judge_line_y + note_h, 0 - note_h) and
                (not (y > settings.judge_line_y and n:isFakeNote())) then
                if y ~= y2 and y > settings.judge_line_y then y = settings.judge_line_y end
                if not n:isHold() then
                    love.graphics.rectangle("fill", x, y - note_h, w, note_h)
                else
                    love.graphics.rectangle("fill", x, y, w, y2 - y)
                end
            end
        end
    end

    -- 标记 edit 区域中的 event
    if tabs and not tabs:isSingle() then
        -- 多标签页：按标签页位置与事件类型轨道绘制
        for i = 1, #self.copy_tab.event do
            local e = self.copy_tab.event[i]
            local ti = self.copy_tab.event_tabidx[i]
            if ti then
                local lane_k
                for k = 1, #tabs.layout.lane do
                    if tabs.layout.lane[k] == e:getType() then
                        lane_k = k
                        break
                    end
                end
                if lane_k then
                    local y = CoordinateService:toY(e:getBeat())
                    local y2 = CoordinateService:toY(e:getBeat2())
                    local x_pos = tabs:windowX(ti) + play.layout.edit.interval * (lane_k - 1)
                    if math.intersect(y, y2, 0 - note_h, WINDOW.h + note_h) then
                        love.graphics.rectangle("fill", x_pos, y2, note_w, y - y2)
                    end
                end
            end
        end
    else
        for i = 1, #self.copy_tab.event do
            local e = self.copy_tab.event[i]
            local y = CoordinateService:toY(e:getBeat())
            local y2 = CoordinateService:toY(e:getBeat2())
            local x_pos = trackSequence:getRange(e:getType())
            if e:getTrack() == track.track then
                if math.intersect(y, y2, 0 - note_h, WINDOW.h + note_h) then
                    love.graphics.rectangle("fill", x_pos, y2, note_w, y - y2)
                end
            end
        end
    end
end

-- ============================================================
-- 鼠标事件处理
-- ============================================================

--- 鼠标按下：单选（右键）或开始框选（左键）
function ctrl:mousepressed(x, y, button)
    -- 标签条/拖动条区域不允许选择
    if mouse.y < play.layout.y then return end

    -- 右键单选
    if love.mouse.isDown(2) then
        local track_type
        local istrack = track.track
        local tabidx = nil
        if tabs and not tabs:isSingle() then
            -- 多标签页：解析鼠标所在窗口的轨道与标签页
            local ti, lane = tabs:getLane(mouse.x, mouse.y)
            if not lane then return end
            local tab = tabs.list[ti]
            if not tab.copy[lane] then return end
            track_type = lane
            istrack = tabs:getTabTrack(tab)
            tabidx = ti
            self.copy_tab.pos = 'tabs'
        else
            track_type = trackSequence:getType(mouse.x)
            if not track_type then return end
        end

        if track_type == 'note' then
            local note_idx = fNote:click(mouse.y, istrack)
            if note_idx then
                if self:copy_exist(ChartService:getNote(note_idx), "note") then
                    self:copy_sub(ChartService:getNote(note_idx), "note")
                else
                    self:copy_add(ChartService:getNote(note_idx), "note", istrack, tabidx or 1)
                end
            end
        else
            local event_idx = fEvent:click(track_type, mouse.y, istrack)
            if event_idx then
                if self:copy_exist(ChartService:getEvent(event_idx), "event") then
                    self:copy_sub(ChartService:getEvent(event_idx), "event")
                else
                    self:copy_add(ChartService:getEvent(event_idx), "event", istrack, tabidx or 1)
                end
            end
        end
        messageBox:add("add copy")

        if #self.copy_tab.event > 0 then
            sidebar:to('events')
        end
    end

    -- 左键开始框选
    if love.mouse.isDown(1) then
        self.mouse_start_pos = { x = mouse.x, y = mouse.y, down = true }
    end
end

-- ============================================================
-- 框选辅助函数
-- ============================================================

--- 在 play 区域框选 note 和 event
-- @tparam number min_x 最小屏幕 x 坐标
-- @tparam number max_x 最大屏幕 x 坐标
-- @tparam number min_y_beat 最小 beat 值
-- @tparam number max_y_beat 最大 beat 值
local function selectInPlayArea(min_x, max_x, min_y_beat, max_y_beat)
    ctrl.copy_tab.pos = 'play'

    -- 记录此刻在框选范围内的轨道
    local local_track = {}
    for i = 1, ChartService:getEventCount() do
        local e = ChartService:getEvent(i)
        local track_x, track_w = fTrack:to_play_track(fEvent:get(e:getTrack(), beat.nowbeat))
        if math.intersect(min_x, max_x, track_x, track_x + track_w) then
            local_track[e:getTrack()] = true
        end
        if e:getBeatValue() > max_y_beat then
            break
        end
    end

    -- 框选 note
    for i = 1, ChartService:getNoteCount() do
        local n = ChartService:getNote(i)
        local isbeat = n:getBeatValue()
        local isbeat2 = isbeat
        if n:isHold() then
            isbeat2 = n:getBeat2Value()
        end
        if math.intersect(min_y_beat, max_y_beat, isbeat, isbeat2) and local_track[n:getTrack()] then
            ctrl.copy_tab.note[#ctrl.copy_tab.note + 1] = n:copy()
        end
        if isbeat > max_y_beat then break end
    end

    -- 框选 event（用于完全复制）
    for i = 1, ChartService:getEventCount() do
        local e = ChartService:getEvent(i)
        local isbeat = e:getBeatValue()
        local isbeat2 = e:getBeat2Value()
        if math.intersect(min_y_beat, max_y_beat, isbeat, isbeat2) and local_track[e:getTrack()] then
            ctrl.copy_tab.event[#ctrl.copy_tab.event + 1] = e:copy()
        end
        if e:getBeatValue() > max_y_beat then break end
    end
end

--- 在 note 轨道框选
-- @tparam number min_y_beat 最小 beat 值
-- @tparam number max_y_beat 最大 beat 值
local function selectInNoteTrack(min_y_beat, max_y_beat)
    for i = 1, ChartService:getNoteCount() do
        local n = ChartService:getNote(i)
        local isbeat = n:getBeatValue()
        local isbeat2 = isbeat
        if n:isHold() then
            isbeat2 = n:getBeat2Value()
        end
        if math.intersect(min_y_beat, max_y_beat, isbeat, isbeat2) and track.track == n:getTrack() then
            ctrl.copy_tab.note[#ctrl.copy_tab.note + 1] = n:copy()
        end
        if isbeat > max_y_beat then break end
    end
end

--- 在 event 轨道框选
-- @tparam number x 鼠标 x 坐标
-- @tparam number start_x 鼠标起始 x 坐标
-- @tparam number min_y_beat 最小 beat 值
-- @tparam number max_y_beat 最大 beat 值
local function selectInEventTrack(x, start_x, min_y_beat, max_y_beat)
    for i = 1, ChartService:getEventCount() do
        local e = ChartService:getEvent(i)
        local event_x_min, event_x_max = trackSequence:getRange(e:getType())
        if math.intersect(x, start_x, event_x_min, event_x_max) then
            local isbeat = e:getBeatValue()
            local isbeat2 = e:getBeat2Value()
            if math.intersect(min_y_beat, max_y_beat, isbeat, isbeat2) and track.track == e:getTrack() then
                ctrl.copy_tab.event[#ctrl.copy_tab.event + 1] = e:copy()
            end
        end
        if e:getBeatValue() > max_y_beat then break end
    end
end

--- 在多标签页 edit 区域框选（可跨标签页，仅可复制的轨道参与）
-- @tparam number selx1 框选左 x（原始屏幕坐标）
-- @tparam number selx2 框选右 x（原始屏幕坐标）
-- @tparam number min_y_beat 最小 beat 值
-- @tparam number max_y_beat 最大 beat 值
local function selectInTabs(selx1, selx2, min_y_beat, max_y_beat)
    ctrl.copy_tab.pos = 'tabs'
    local interval = play.layout.edit.interval
    for ti = 1, #tabs.list do
        local tab = tabs.list[ti]
        local istrack = tabs:getTabTrack(tab)
        local wx = tabs:windowX(ti)
        for k = 1, 5 do
            local lane = tabs.layout.lane[k]
            local lx1 = wx + interval * (k - 1)
            local lx2 = wx + interval * k
            if math.intersect(selx1, selx2, lx1, lx2) then
                if lane == 'note' then
                    if tab.copy.note then
                        for i = 1, ChartService:getNoteCount() do
                            local n = ChartService:getNote(i)
                            local isbeat = n:getBeatValue()
                            local isbeat2 = isbeat
                            if n:isHold() then isbeat2 = n:getBeat2Value() end
                            if math.intersect(min_y_beat, max_y_beat, isbeat, isbeat2) and istrack == n:getTrack() then
                                ctrl:copy_add(n:copy(), 'note', istrack, ti)
                            end
                            if isbeat > max_y_beat then break end
                        end
                    end
                else
                    if tab.copy[lane] then
                        for i = 1, ChartService:getEventCount() do
                            local e = ChartService:getEvent(i)
                            local isbeat = e:getBeatValue()
                            local isbeat2 = e:getBeat2Value()
                            if math.intersect(min_y_beat, max_y_beat, isbeat, isbeat2) and istrack == e:getTrack() and
                                e:getType() == lane then
                                ctrl:copy_add(e:copy(), 'event', istrack, ti)
                            end
                            if e:getBeatValue() > max_y_beat then break end
                        end
                    end
                end
            end
        end
    end
end

--- 鼠标释放：确认框选
function ctrl:mousereleased(x, y)
    if not (input('select') and love.mouse.isDown(1)) then
        return
    end
    messageBox:add('select')
    self.copy_tab = table.copy(self.meta_copy_tab)

    local min_x = fTrack:to_play_track(fTrack:to_chart_track(math.min(x, self.mouse_start_pos.x)), 1)
    local max_x = fTrack:to_play_track(fTrack:to_chart_track(math.max(x, self.mouse_start_pos.x)), 1)
    local min_y_beat = CoordinateService:yToBeat(math.max(y, self.mouse_start_pos.y))
    local max_y_beat = CoordinateService:yToBeat(math.min(y, self.mouse_start_pos.y))

    local edit_start = play.layout.edit.x
    local edit_end = play.layout.edit.x + play.layout.edit.interval * 5
    local note_track_end = play.layout.edit.x + play.layout.edit.interval
    local event_track_start = play.layout.edit.x + play.layout.edit.interval

    if tabs and not tabs:isSingle() then
        -- 多标签页：跨标签页框选，demo 区域不可交互
        local selx1 = math.min(x, self.mouse_start_pos.x)
        local selx2 = math.max(x, self.mouse_start_pos.x)
        selectInTabs(selx1, selx2, min_y_beat, max_y_beat)
        if #self.copy_tab.event > 0 then
            sidebar:to('events')
        end
        return
    end

    if not math.intersect(x, self.mouse_start_pos.x, edit_start, edit_end) then
        -- 在 play 区域框选
        selectInPlayArea(min_x, max_x, min_y_beat, max_y_beat)
        return
    end

    if math.intersect(x, self.mouse_start_pos.x, edit_start, note_track_end) then
        -- 在 note 轨道框选
        selectInNoteTrack(min_y_beat, max_y_beat)
    end

    if math.intersect(x, self.mouse_start_pos.x, event_track_start, edit_end) then
        -- 在 event 轨道框选
        selectInEventTrack(x, self.mouse_start_pos.x, min_y_beat, max_y_beat)
    end

    if #self.copy_tab.event > 0 then
        sidebar:to('events')
    end
end

-- ============================================================
-- 滚轮事件处理
-- ============================================================

--- 鼠标滚轮：调整 beat 位置（仅框选过程中）
function ctrl:wheelmoved(x, y)
    if not self.mouse_start_pos.down then return end
    local temp = settings.contact_roller
    if input('accelerate') then
        temp = temp * 4
    end
    music_play = false
    if y > 0 then
        temp = temp / denom.denom
    else
        temp = -temp / denom.denom
    end
    local y_beat = temp
    self.mouse_start_pos.y = self.mouse_start_pos.y + CoordinateService:toY(0) - CoordinateService:toY(y_beat)
end

-- ============================================================
-- 键盘事件处理：拆分为独立的处理函数
-- ============================================================

--- 处理复制操作
local function handleCopy()
    ctrl.copy_tab.type = "copy"
    messageBox:add("copy")
end

--- 处理剪切操作
local function handleCut()
    ctrl.copy_tab.type = "cut"
    messageBox:add("cut")
end

--- 处理删除所选操作
local function handleDelete()
    sidebar:to("nil")
    local all = input('deleteAllSelect')
    ChartService:push()

    -- 删除选中的 note
    for _, v in ipairs(ctrl.copy_tab.note) do
        for i = 1, ChartService:getNoteCount() do
            if ctrl.copy_tab.note[1] == ChartService:getNote(i) then
                table.remove(ctrl.copy_tab.note, 1)
                ChartService:delete(ChartService:getNote(i))
            end
        end
    end

    -- 删除选中的 event（仅在非 play 模式或全部删除时）
    if ctrl.copy_tab.pos ~= 'play' or all then
        for _, v in ipairs(ctrl.copy_tab.event) do
            for i = 1, ChartService:getEventCount() do
                if ctrl.copy_tab.event[1] == ChartService:getEvent(i) then
                    table.remove(ctrl.copy_tab.event, 1)
                    ChartService:delete(ChartService:getEvent(i))
                end
            end
        end
    end

    ChartService:pop()
    ctrl.copy_tab = table.copy(ctrl.meta_copy_tab)
end

--- 处理粘贴操作
local function handlePaste()
    local all = input('pasteAll') or input('flipPasteAll')
    local flip = input('flipPaste') or input('flipPasteAll')
    local copy_tab2 = deepCopyWithNotes(ctrl.copy_tab)

    -- 找到最小 track 和最小 beat 作为基准
    local min_track
    if copy_tab2.note[1] then min_track = copy_tab2.note[1]:getTrack() end
    if copy_tab2.event[1] then min_track = copy_tab2.event[1]:getTrack() end
    for i = 1, #copy_tab2.note do
        if min_track > copy_tab2.note[i]:getTrack() then min_track = copy_tab2.note[i]:getTrack() end
    end
    for i = 1, #copy_tab2.event do
        if min_track > copy_tab2.event[i]:getTrack() then min_track = copy_tab2.event[i]:getTrack() end
    end

    sidebar:to("nil")
    local to_beat = beat:toNearby(CoordinateService:yToBeat(mouse.y))

    -- 确定基准 beat
    local first_beat = { 0, 0, 4 }
    if ctrl.copy_tab.note[1] and ctrl.copy_tab.event[1] then
        if ctrl.copy_tab.note[1]:getBeatValue() <= ctrl.copy_tab.event[1]:getBeatValue() then
            first_beat = ctrl.copy_tab.note[1]:getBeat()
        else
            first_beat = ctrl.copy_tab.event[1]:getBeat()
        end
    elseif ctrl.copy_tab.note[1] then
        first_beat = ctrl.copy_tab.note[1]:getBeat()
    elseif ctrl.copy_tab.event[1] then
        first_beat = ctrl.copy_tab.event[1]:getBeat()
    end

    if ctrl.copy_tab.note[1] and ctrl.copy_tab.pos == 'play' and not all then
        first_beat = ctrl.copy_tab.note[1]:getBeat()
    end

    -- 跨标签页粘贴：以鼠标所在标签页为锚点，按标签页下标整体平移。
    -- 鼠标标签页参与了框选 → 内容保持各自原标签页不动；
    -- 未参与 → 最左框选内容平移到鼠标标签页，其余内容依次顺移到后续标签页；
    -- 目标标签页不存在的内容不粘贴；鼠标不在任何标签页上时保持各自原标签页
    local is_tabs_paste = ctrl.copy_tab.pos == 'tabs'
    if is_tabs_paste then
        local mouse_ti
        if tabs and not tabs:isSingle() then
            mouse_ti = tabs:getTabAtMouse()
        end
        -- 参照标签页：鼠标标签页参与了框选则以它自身为参照，否则取最左框选标签页
        local ref_ti
        if mouse_ti then
            for i = 1, #ctrl.copy_tab.note do
                if ctrl.copy_tab.note_tabidx[i] == mouse_ti then
                    ref_ti = mouse_ti
                    break
                end
            end
            if not ref_ti then
                for i = 1, #ctrl.copy_tab.event do
                    if ctrl.copy_tab.event_tabidx[i] == mouse_ti then
                        ref_ti = mouse_ti
                        break
                    end
                end
            end
        end
        if not ref_ti then
            for i = 1, #ctrl.copy_tab.note do
                local t = ctrl.copy_tab.note_tabidx[i] or 1
                if not ref_ti or t < ref_ti then ref_ti = t end
            end
            for i = 1, #ctrl.copy_tab.event do
                local t = ctrl.copy_tab.event_tabidx[i] or 1
                if not ref_ti or t < ref_ti then ref_ti = t end
            end
        end
        local shift = ref_ti and mouse_ti and (mouse_ti - ref_ti) or 0
        -- 每个内容平移到目标标签页（下标 + 位移），目标标签页不存在则不粘贴
        local function mapTabs(items, tabidxs)
            local out = {}
            for i = 1, #items do
                local ti = (tabidxs[i] or 1) + shift
                local tab = tabs and tabs.list[ti]
                if tab then
                    items[i]:setTrack(tabs:getTabTrack(tab))
                    out[#out + 1] = items[i]
                end
            end
            return out
        end
        copy_tab2.note = mapTabs(copy_tab2.note, ctrl.copy_tab.note_tabidx)
        copy_tab2.event = mapTabs(copy_tab2.event, ctrl.copy_tab.event_tabidx)
    end

    -- 调整 note 的 beat 和 track
    for i = 1, #copy_tab2.note do
        local n = copy_tab2.note[i]
        if ctrl.copy_tab.pos ~= 'play' and not is_tabs_paste then
            n:setTrack(track.track)
        end
        n:setBeat(beat:add(beat:sub(n:getBeat(), first_beat), to_beat))
        if n:isHold() then
            n:setBeat2(beat:add(beat:sub(n:getBeat2(), first_beat), to_beat))
        end
    end

    -- 调整 event 的 beat、track 和翻转
    for i = 1, #copy_tab2.event do
        local isevent = copy_tab2.event[i]
        if ctrl.copy_tab.pos ~= 'play' and not is_tabs_paste then
            isevent:setTrack(track.track)
        end
        isevent:setBeat(beat:add(beat:sub(isevent:getBeat(), first_beat), to_beat))
        isevent:setBeat2(beat:add(beat:sub(isevent:getBeat2(), first_beat), to_beat))
        local need_flip_event = {'x', 'lpos', 'rpos'}
        if flip and table.find(need_flip_event, isevent:getType()) then
            local center = 2 * (ChartService:getPreferenceField('x_offset') + ChartService:getPreferenceField('event_scale') / 2)
            isevent:setFrom(center - isevent:getFrom())
            isevent:setTo(center - isevent:getTo())
        end
    end

    ChartService:push()

    -- 写入谱面
    for i = 1, #copy_tab2.note do
        ChartService:add(copy_tab2.note[i]:copy())
    end
    if ctrl.copy_tab.pos ~= 'play' or all then
        for i = 1, #copy_tab2.event do
            ChartService:add(copy_tab2.event[i]:copy())
        end
    end

    if ctrl.copy_tab.type == "copy" then
        ChartService:pop()
        return
    end

    -- 剪切模式：删除原始数据
    for _, v in ipairs(ctrl.copy_tab.note) do
        for i = 1, ChartService:getNoteCount() do
            if ctrl.copy_tab.note[1] == ChartService:getNote(i) then
                table.remove(ctrl.copy_tab.note, 1)
                ChartService:delete(ChartService:getNote(i))
            end
        end
    end
    if ctrl.copy_tab.pos ~= 'play' or all then
        for _, v in ipairs(ctrl.copy_tab.event) do
            for i = 1, ChartService:getEventCount() do
                if ctrl.copy_tab.event[1] == ChartService:getEvent(i) then
                    table.remove(ctrl.copy_tab.event, 1)
                    ChartService:delete(ChartService:getEvent(i))
                end
            end
        end
    end
    ChartService:pop()
end

--- 键盘事件主入口
function ctrl:keypressed(key)
    -- Shift + 鼠标按下时确认框选
    if input('select') and mouse.down then
        self:mousereleased(mouse.x, mouse.y)
    end

    -- Escape 取消框选
    if key == 'escape' then
        self.copy_tab = table.copy(self.meta_copy_tab)
    end

    if not iskeyboard.ctrl then return end

    if input('copy') then
        handleCopy()
    elseif input('cut') then
        handleCut()
    elseif input('deleteSelect') or input('deleteAllSelect') then
        handleDelete()
    elseif input('paste') or input('flipPaste') or input('pasteAll') or input('flipPasteAll') then
        handlePaste()
    end
end

-- 注册为插件
if PluginManager then
    PluginManager:register({
        name = "ctrl",
        version = "1.0.0",
        description = "复制/粘贴/框选管理",
    })
end

return ctrl
