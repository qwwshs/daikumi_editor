--进入谱面基本信息显示与修改
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local type = "nil"
local function will_draw()
    return room_type(type) and the_room_pos({"edit",'tracks_edit'})
end
local function draw_this_button()
    love.graphics.setColor(1,1,1,1)
    love.graphics.rectangle("line",x,y,w,h)
    love.graphics.print(objact_language.get_string_in_languages("info"),x + 10,y)
end
local function will_do()
    objact_message_box.message("info")
    displayed_content = "info"
    objact_chart_info.load(1250,100,0,150,50)
end
objact_button_chart_info = {
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
        button_new("chart_info",will_do,x,y,w,h,draw_this_button,{will_draw = will_draw})
    end,
    draw = function()

    end,
    mousepressed = function( x1, y1, button, istouch, presses )

    end,
}