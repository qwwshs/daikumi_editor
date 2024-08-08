--返回上一层
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_break = love.graphics.newImage("asset_ui_break.png")
objact_button_break = {
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
    end,
    draw = function()
        local _width, _height = ui_break:getDimensions( ) -- 得到宽高
        local _scale_w = 1 / _width * w
        local _scale_h = 1 / _height * h
        love.graphics.setColor(1,1,1,1)

        love.graphics.draw(ui_break,x,y,r,_scale_w,_scale_h)
    end,
    keyboard = function(key)
        if key == "escape" then
            displayed_content = "nil" --回到主界面
            input_box_delete_all() -- 删除所有输入框
            
        end
    end,
    mousepressed = function( x1, y1, button, istouch, presses )
        if x1 >= x  and x1 <= x + w and y1 <= y + h and y1 >= y then -- 在退出的范围内
            objact_button_break.keyboard("escape")
            switch_delete_all()
            input_box_delete_all()
        end
    end,
}