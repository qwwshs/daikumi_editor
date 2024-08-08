--进入谱面基本信息显示与修改
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local type = "nil"

objact_button_chart_info = {
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
    end,
    draw = function()
        if not room_type(type) then
            return
        end
        love.graphics.setColor(1,1,1,1)
        love.graphics.rectangle("line",x,y,w,h)
        love.graphics.print("info",x + 10,y)
    end,
    mousepressed = function( x1, y1, button, istouch, presses )
        if not room_type(type) then
            return
        end
        if x1 >= x and x1 <= x + w and y1 <= y + h and y1 >= y and room_type(type) then -- 在范围内
            objact_message_box.message("info")
            displayed_content = "info"
            objact_chart_info.load(1250,100,0,150,50)
        end
    end,
}