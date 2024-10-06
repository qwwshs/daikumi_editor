
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_open = love.graphics.newImage("asset/ui_open_chart_list.png")
local function will_draw()
    return the_room_pos('select')
end
local function will_do()
    love.system.openURL(love.filesystem.getRealDirectory( "chart" ))
end
objact_open_chart_list = { --分度改变用的
load = function(x1,y1,r1,w1,h1)
    x= x1 --初始化
    y = y1
    w = w1
    h = h1
    r = r1
    button_new("open_chart_list",will_do,x,y,w,h,ui_open,{will_draw = will_draw})
end,
draw = function()
end,
mousepressed = function( x1, y1, button, istouch, presses )
end,
}