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
objact_track = { --改变现在显示的轨道
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1

        input_box_new("track","track.track",x-50,y + h,50,h,{type = "number",will_draw = will_draw})
    end,
    draw = function()
        local _width, _height = ui_up:getDimensions( ) -- 得到宽高
        local _scale_w = 1 / _width * w
        local _scale_h = 1 / _height * h
        love.graphics.setColor(1,1,1,1)

        love.graphics.draw(ui_up,x,y,r,_scale_w,_scale_h)
        love.graphics.draw(ui_down,x,y+h,r,_scale_w,_scale_h)
        love.graphics.print(objact_language.get_string_in_languages("track"),x-50,y)

    end,
    keyboard = function(key)
        if key == "right" then
            track.track = track.track + 1
            input_string = track.track
        elseif key == "left" then
            track.track = math.abs(track.track - 2) + 1--防止非自然数
            input_string = track.track
        end

        if input_type == true then
            if key == "backspace" then -- 退格
                input_string = string.sub(input_string, 1, -2)
            end
            if key == "return" then -- 关闭 
                input_type = false
                track.track = tonumber(input_string) or 1
                input_string = track.track
            end
            if string.match(key, "%d") ~= nil then --为数字
                input_string = input_string..key
            end
        end
    end,
    mousepressed = function( x1, y1, button, istouch, presses )
        
        if x1 >= x  and x1 <= x + w and y1 <= y + h and y1 >= y then -- 在up的范围内
            objact_track.keyboard("right")
            
        elseif x1 >= x  and x1 <= x + w and y1 <= y + h + h and y1 >= y + h then -- 在down的范围内
            objact_track.keyboard("left")
        end
    end,
    textinput = function(input)

    end,
    update = function(dt) --数据更新
        input_string = track.track
    end,
}