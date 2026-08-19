--[[
    模块名: colors/demo
    描述: 演示/游玩模式的颜色配置，从 base 基色派生
]]

local c = require('config.colors.base')
local rgba = c.rgba
local base = c.base

return {
    combo = rgba(base.white, 1),           -- 纯白: 连击数
    score = rgba(base.white, 0.5),         -- 半透白: 分数
}
