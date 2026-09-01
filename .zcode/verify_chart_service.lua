-- 模拟验证脚本：在无 LOVE2D 环境下验证 ChartService 私有化重构的加载链与核心逻辑
package.path = "E:/LOVE/mylua/dakumi editor/dakumi editor/?.lua;" ..
               "E:/LOVE/mylua/dakumi editor/dakumi editor/?/init.lua;" .. package.path

-- mock 必要的全局
WINDOW = { w = 1600, h = 900 }
loadstring = loadstring or load -- LuaJIT(5.1) 兼容：5.4 无 loadstring

-- 1. 基础设施
require("src.utils.room")     -- object/container/group/room
require("src.utils.table")    -- table.copy/fill/find/eq

-- 2. beat 与 meta（纯数据）
require("src.utils.beat")
require("src.objects.meta")
dkjson = require("src.utils.dkjson")

-- 3. 服务层
local ChartService = require("src.services.chartService")

-- 4. 核心工具（require 链：event → coordinateService → chartService 缓存复用）
-- 与 isRequire.lua 一致，fEvent/fNote 是全局赋值
fEvent = require("src.utils.event")
fNote = require("src.utils.note")
local fTrack = require("src.utils.track")

-- 5. mock 运行期全局（仅验证用桩）
save = function() end
time = { nowtime = 0, alltime = 1 }
redo = { writeRevoke = function() end }
PluginManager = { emit = function() end }

local failures = 0
local function check(name, cond)
    if cond then
        print("PASS: " .. name)
    else
        print("FAIL: " .. name)
        failures = failures + 1
    end
end

-- ============================================================
-- setChart / 列表读取
-- ============================================================
ChartService:setChart({
    note = { { type = 'note', track = 1, beat = { 1, 0, 1 } } },
    event = { { type = 'x', track = 1, beat = { 1, 0, 1 }, beat2 = { 2, 0, 1 }, from = 0, to = 1,
        trans = { trans = { 0, 0, 1, 1 }, type = 'bezier', easings = 1 } } },
    offset = 0,
})
check("getNoteCount = 1", ChartService:getNoteCount() == 1)
check("getNote(1) 返回对象", type(ChartService:getNote(1)) == 'table')
check("getEventCount = 1", ChartService:getEventCount() == 1)
check("getBpmCount 默认 1 条", ChartService:getBpmCount() == 1)
check("getOffset 默认 0", ChartService:getOffset() == 0)
check("getEffectCount = 0", ChartService:getEffectCount() == 0)
check("getInfoField 默认空串", ChartService:getInfoField('song_name') == '')
check("getPreferenceField 默认 x_offset=0", ChartService:getPreferenceField('x_offset') == 0)

-- ============================================================
-- 字段写入
-- ============================================================
ChartService:setOffset(100)
ChartService:setInfoField('song_name', 'test')
ChartService:setPreferenceField('event_scale', 200)
ChartService:setBpmList({ { beat = { 0, 0, 1 }, bpm = 120, linear_ramp = 0 } })
check("setOffset 生效", ChartService:getOffset() == 100)
check("setInfoField 生效", ChartService:getInfoField('song_name') == 'test')
check("setPreferenceField 生效", ChartService:getPreferenceField('event_scale') == 200)
check("setBpmList 生效", ChartService:getBpmCount() == 1 and ChartService:getBpm(1).bpm == 120)

-- ============================================================
-- 轨道定义（懒创建）
-- ============================================================
ChartService:ensureTrack(3)
check("ensureTrack 创建默认定义", ChartService:getTrackField(3, 'name') == '')
check("getTrackField 懒创建", ChartService:getTrackField(7, 'parent') == 0)
ChartService:setTrackField(3, 'name', 'track3')
ChartService:setTrackField(3, 'w0thenShow', 1)
check("setTrackField 生效", ChartService:getTrackField(3, 'name') == 'track3')
check("setTrackField w0thenShow", ChartService:getTrackField(3, 'w0thenShow') == 1)

-- ============================================================
-- load()：转换对象 + 构建 extra_chart 索引
-- ============================================================
ChartService:load()
check("load 后 note 转为对象", ChartService:getNote(1).getBeat ~= nil)
check("load 后 event 转为对象", ChartService:getEvent(1).getType ~= nil)
check("hasTrack(1) 索引存在", ChartService:hasTrack(1) == true)
check("hasTrack(99) 不存在", ChartService:hasTrack(99) == false)
check("getTrackEventCount(1,'x') = 1", ChartService:getTrackEventCount(1, 'x') == 1)
check("getTrackEvent(1,'x',1) 是 x 事件", ChartService:getTrackEvent(1, 'x', 1):getType() == 'x')
check("getTrackEventCount(1,'w') = 0", ChartService:getTrackEventCount(1, 'w') == 0)
check("getTrackEventCount(99,'x') = 0", ChartService:getTrackEventCount(99, 'x') == 0)

-- ============================================================
-- add/delete（经 ChartService，同步索引）
-- ============================================================
local Note = require("src.objects.Note")
local Event = require("src.objects.Event")
local n2 = Note.new({ type = 'note', track = 2, beat = { 2, 0, 1 } })
ChartService:add(n2)
check("add note 后计数 = 2", ChartService:getNoteCount() == 2)
check("add note 后索引同步", ChartService:getTrackEventCount(2, 'note') == 1)
check("add note 后 hasTrack(2)", ChartService:hasTrack(2) == true)

ChartService:delete(n2)
check("delete note 后计数 = 1", ChartService:getNoteCount() == 1)
check("delete note 后索引同步", ChartService:getTrackEventCount(2, 'note') == 0)

-- ============================================================
-- push/pop 批量操作（缓冲）
-- ============================================================
ChartService:push()
ChartService:add(Note.new({ type = 'note', track = 1, beat = { 3, 0, 1 } }))
ChartService:add(Note.new({ type = 'note', track = 1, beat = { 4, 0, 1 } }))
check("push 期间计数不变", ChartService:getNoteCount() == 1)
ChartService:pop()
check("pop 后计数 = 3", ChartService:getNoteCount() == 3)
check("pop 后索引同步", ChartService:getTrackEventCount(1, 'note') == 3)

-- ============================================================
-- 排序
-- ============================================================
ChartService:add(Note.new({ type = 'note', track = 1, beat = { 0, 0, 1 } }))
ChartService:sortNotes()
check("sortNotes 后第一条 beat 最小", ChartService:getNote(1):getBeatValue() == 0)
check("sortNotes 后索引同步", ChartService:getTrackEvent(1, 'note', 1):getBeatValue() == 0)
ChartService:sortEvents()
check("sortEvents 不崩溃", true)

-- ============================================================
-- beat 桥接
-- ============================================================
local b = ChartService:toBeat(60) -- 120bpm 下 60 秒 = 120 拍
check("toBeat(60) = 120", math.abs(b - 120) < 0.001)
local t = ChartService:toTime(120)
check("toTime(120) = 60", math.abs(t - 60) < 0.001)

-- ============================================================
-- encodeJson / save
-- ============================================================
local json = ChartService:encodeJson()
check("encodeJson 可解析", dkjson ~= nil or json ~= nil)

print("")
if failures == 0 then
    print("=== 全部验证通过 ===")
else
    print("=== " .. failures .. " 项失败 ===")
    os.exit(1)
end
