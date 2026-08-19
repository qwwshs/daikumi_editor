--[[
    模块名: colors/play
    描述: 编辑/游玩区域的颜色配置，从 base 基色派生
    denom 系列颜色保持独立定义（不从 base 派生）
]]

local c = require('config.colors.base')
local rgba = c.rgba
local base = c.base

return {
    -- 通用白色系
    white      = rgba(base.white, 1),      -- 纯白: trackNum, judge, beat, ProgressBar, demoTrackline2
    white_half = rgba(base.white, 0.5),    -- 半透白: fence, cutAndPaste, selectingNote, selectingEvent, demoTrackline, mouseBeat
    white_dim  = rgba(base.white, 0.2),    -- 淡白: selectingTrack

    -- 青色系（选择/复制/高亮）
    cyan        = rgba(base.cyan, 1),      -- 亮青: selectingTrackNum, copySelectLine
    cyan_half   = rgba(base.cyan, 0.5),    -- 半透明青: copyAndPaste
    cyan_fade   = rgba(base.cyan, 0.4),    -- 淡青: copySelectFill
    cyan_bright = rgba(base.cyan, 0.7),    -- 亮青: nearFence
    dcyan       = rgba(base.dcyan, 1),     -- 暗青: judgeLine

    -- 黑色系（背景/遮挡）
    black       = rgba(base.black, 1),     -- 纯黑: Shield
    black_half  = rgba(base.black, 0.5),   -- 半透明黑: editInJudgheLineDownBg
    black_fade  = rgba(base.black, 0.4),   -- 淡黑: demoInJudgheLineDownBg

    -- 特殊色
    red = rgba(base.red, 1),               -- 红色: isFakeNote

    -- 事件颜色（嵌套结构，消费者用动态 key 访问）
    eventInDemo = c.event,

    -- denom 分度线颜色（独立定义，不从 base 派生）
    denom      = {0, 0.4, 0.4},
    denom3and4 = {0, 1, 0.2},
    denom2     = {0.8, 0.2, 1},
    denomMid   = {0.5, 1, 0.95},
}
