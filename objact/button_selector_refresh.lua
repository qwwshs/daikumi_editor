--不再使用
--[[
--返回上一层文件夹
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_refresh = love.graphics.newImage("asset/ui_refresh.png")
local function will_draw()
    return the_room_pos('select') and selector_file_open
end
local function will_do()
    if string.find(selector_now_path, "/[^/]*$") then --刷新
        objact_selector.anew_find()
        objact_message_box.message('refresh')
    end
end
objact_selector_refresh = {
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
        button_new("selector_refresh",will_do,x,y,w,h,ui_refresh,{will_draw = will_draw})
    end,
    draw = function()
    end,
    mousepressed = function( x1, y1, button, istouch, presses )
    end,
}
]]