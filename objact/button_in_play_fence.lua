--栅栏
local ui_up = nil
local ui_down = nil
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_up = love.graphics.newImage("asset/ui_up.png")
local ui_down = love.graphics.newImage("asset/ui_down.png")
local function will_draw()
    return the_room_pos({"edit",'tracks_edit'})
end
local function do_up()
    track.fence = track.fence + 1
end
local function do_down()
    track.fence = math.abs(track.fence - 1)--防止非自然数
end
objact_track_fence = { --分度改变用的
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
        input_box_new("fence","track.fence",x-50,y + h,50,h,{type = "number",will_draw = will_draw})
        button_new("fence_up",do_up,x,y,w,h,ui_up,{will_draw = will_draw})
        button_new("fence_down",do_down,x,y+h,w,h,ui_down,{will_draw = will_draw})
    end,
    draw = function()

        love.graphics.print(objact_language.get_string_in_languages("fence"),x-50,y)

    end,
    keyboard = function(key)

    end,
    mousepressed = function( x1, y1, button, istouch, presses )

    end,
    textinput = function(input)

    end
}