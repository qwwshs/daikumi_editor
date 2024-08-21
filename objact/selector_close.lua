--返回上一层文件夹
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_close = love.graphics.newImage("asset/ui_close.png")
objact_selector_close = {
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
    end,
    draw = function()
        local _width, _height = ui_close:getDimensions( ) -- 得到宽高
        local _scale_w = 1 / _width * w
        local _scale_h = 1 / _height * h
        love.graphics.setColor(1,1,1,1)

        love.graphics.draw(ui_close,x,y,r,_scale_w,_scale_h)
    end,
    mousepressed = function( x1, y1, button, istouch, presses )
        if x1 >= x  and x1 <= x + w and y1 <= y + h and y1 >= y then -- 在退出的范围内 返回上一层
            if string.find(selector_now_path, "/[^/]*$") then
                selector_file_open = false
                objact_message_box.message('close')
            end
        end
    end,
}