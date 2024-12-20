
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local function draw_this_button()
    ui_style:button(x,y,w,h,objact_language.get_string_in_languages("flushed"))
end
local function will_draw() --刷新
    return the_room_pos('select')
end
local function will_do()
    load_select()
end
objact_flushed = { --分度改变用的
load = function(x1,y1,r1,w1,h1)
    x= x1 --初始化
    y = y1
    w = w1
    h = h1
    r = r1
    button_new("flushed",will_do,x,y,w,h,draw_this_button,{will_draw = will_draw})
end,
}