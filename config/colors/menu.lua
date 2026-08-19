--[[
    模块名: colors/menu
    描述: 菜单界面的颜色配置，从 base 基色派生
]]

local c = require('config.colors.base')
local rgba = c.rgba
local base = c.base

return {
    -- 白色系（文字/线条）
    white       = rgba(base.white, 1),     -- 纯白: selectThisMusicText, selectThischartText, line3
    white_half  = rgba(base.white, 0.5),   -- 半透白: unSelectThisMusicText, unSelectThischartText, fft, line2
    white_fade  = rgba(base.white, 0.2),   -- 淡白: selectThisMusicTextBg, chartInofoBg, line1
    white_dim   = rgba(base.white, 0.1),   -- 极淡白: line4

    -- 背景/特殊色
    dgray = rgba(base.dgray, 0.7),         -- 深灰: bg
    lred  = rgba(base.lred, 1),            -- 浅红: errorChart
}
