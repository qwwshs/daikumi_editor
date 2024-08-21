
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_open = love.graphics.newImage("asset/ui_open_file_selector.png")
objact_select_file = { --打开文件选择器的按钮用的
load = function(x1,y1,r1,w1,h1)
    x= x1 --初始化
    y = y1
    w = w1
    h = h1
    r = r1
end,
draw = function()
    local _width, _height = ui_open:getDimensions( ) -- 得到宽高
    local _scale_w = 1 / _width * w
    local _scale_h = 1 / _height * h
    love.graphics.setColor(1,1,1,1)

    love.graphics.draw(ui_open,x,y,r,_scale_w,_scale_h)
end,
mousepressed = function( x1, y1, button, istouch, presses )
    if x1 >= x  and x1 <= x + w and y1 <= y + h and y1 >= y then -- 在范围内
        objact_message_box.message("open file")
        objact_selector.open() --打开文件选择器
    end
end,
}