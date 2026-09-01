-- 标签页系统布局（位于 editTool 下方，与 editTool 同长度同 x 位置）
-- 大部分数值由 tabs:load() 根据 play.layout / editTool.layout 动态计算
-- 这里只定义不依赖运行时的常量与占位值
return {
    tabBar = {
        x = 0, y = 100, w = 1215, h = 70,
    },
    scroll = {
        x = 0, y = 170, w = 1215, h = 22,
    },
    region = {
        y = 192,
        h = 708,
    },
    tabW = 300,
    plusW = 30,
    titleH = 24,
    rowH = 0,
    gutter = 18,
    lane = { 'note', 'x', 'w', 'lpos', 'rpos' },
    demoW = 900,
    regionW = 1200,

    -- 标签页内部间距常量
    closeW = 34,       -- 关闭按钮列宽
    closeHitW = 37,    -- 关闭按钮点击检测宽（按钮实际左缘 = tab 右缘 - 窗口边距1 - 内边距2 - closeW）
    gapH = 8,          -- 标题行与开关行之间的间隙
    buttonPad = 4,     -- + 按钮相对 tabBar 的内缩
    hitPad = 2,        -- 鼠标点击检测的额外容差
}
