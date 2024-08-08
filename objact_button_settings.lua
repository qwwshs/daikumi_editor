--设置
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local type = 'nil'
objact_button_settings = {
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
        love.graphics.print("settings",x + 10,y)
    end,
    mousepressed = function( x1, y1, button, istouch, presses )
        if not room_type(type) then
            return
        end
        if x1 >= x and x1 <= x + w and y1 <= y + h and y1 >= y and room_type(type) then -- 在输入框的范围内
            objact_message_box.message("settings")
            displayed_content = "settings"
            objact_settings.load(1250,100,0,150,50)
        end
    end,
}