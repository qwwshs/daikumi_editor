--[[
    模块名: colors/editTool
    描述: 编辑工具栏的颜色配置，从 base 基色派生
]]

local c = require('config.colors.base')
local rgba = c.rgba
local base = c.base

return {
    sliderLine = rgba(base.white, 0.5),    -- 半透白: 滑块轨道线
    slider     = rgba(base.dgray, 0.7),    -- 深灰: 滑块背景
    progress   = rgba(base.white, 1),      -- 纯白: 进度条
}
