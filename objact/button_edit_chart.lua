
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_delete = love.graphics.newImage("asset/ui_edit.png")
local function will_draw()
    return the_room_pos('select')
end
local function will_do()
    love.audio.stop( ) --停止歌曲
    room_pos = 'edit' --进入编辑
end
objact_edit_chart = { --进入谱面用的
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
        button_new("edit_chart",will_do,x,y,w,h,ui_delete,{will_draw = will_draw})
    end,
    draw = function()

    end,
    mousepressed = function( x1, y1, button, istouch, presses )
    end,
}