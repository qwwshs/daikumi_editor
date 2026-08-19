--[[
    模块名: colors/base
    描述: 共享基色定义，所有颜色配置文件从此处引用主色彩
    作者: qwwshs

    主色彩:
    - white:  白色，用于文字、线条、高亮
    - cyan:   青色，用于选择、复制、轨道高亮
    - dcyan:  暗青色，用于判定线内部
    - black:  黑色，用于背景、遮挡
    - red:    红色，用于假音符、错误提示
    - lred:   浅红色，用于错误提示
    - dgray:  深灰色，用于面板背景
]]

local base = {
    white  = {1, 1, 1},
    cyan   = {0, 1, 1},
    dcyan  = {0, 0.7, 0.7},
    black  = {0, 0, 0},
    red    = {1, 0, 0},
    lred   = {1, 0.5, 0.5},
    dgray  = {0.18, 0.18, 0.18},
}

--- 事件颜色（eventInDemo 专用，保持嵌套结构）
local event = {
    x    = {0, 1, 1, 1},   -- 青色
    w    = {1, 0, 1, 1},   -- 品红
    lpos = {1, 1, 0, 1},   -- 黄色
    rpos = {0, 0, 1, 1},   -- 蓝色
}

--- 从基色和 alpha 创建 RGBA 颜色表
-- @tparam table rgb 基色 {r, g, b}
-- @tparam number alpha 透明度 (0~1)
-- @treturn table {r, g, b, a}
local function rgba(rgb, alpha)
    return {rgb[1], rgb[2], rgb[3], alpha}
end

return {
    base = base,
    event = event,
    rgba = rgba,
}
