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
    return the_room_pos("edit")
end

objact_track_scale = { --分度改变用的
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
        input_string = denom.scale
        input_box_new("scale","denom.scale",x-50,y + h,50,h,{type = "number",will_draw = will_draw})
    end,
    draw = function()
        local _width, _height = ui_up:getDimensions( ) -- 得到宽高
        local _scale_w = 1 / _width * w
        local _scale_h = 1 / _height * h
        love.graphics.setColor(1,1,1,1)

        love.graphics.draw(ui_up,x,y,r,_scale_w,_scale_h)
        love.graphics.draw(ui_down,x,y+h,r,_scale_w,_scale_h)
        love.graphics.print(objact_language.get_string_in_languages("scale"),x-50,y)

    end,
    keyboard = function(key)

    end,
    mousepressed = function( x1, y1, button, istouch, presses )
        if x1 >= x  and x1 <= x + w and y1 <= y + h and y1 >= y then -- 在up的范围内
            denom.scale = denom.scale + 0.1
            input_string = denom.scale
        elseif x1 >= x  and x1 <= x + w and y1 <= y + h + h and y1 >= y + h then -- 在down的范围内
            denom.scale = math.abs(denom.scale - 0.2) + 0.1--防止非自然数
            input_string = denom.scale
        end
    end,
    textinput = function(input)

    end
}