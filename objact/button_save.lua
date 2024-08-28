
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_save = love.graphics.newImage("asset/ui_save.png")
local quit_click = 0 --点击次数
local save_time = 0 --保存时间
objact_save = { --分度改变用的
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
    end,
    draw = function()
        local _width, _height = ui_save:getDimensions( ) -- 得到宽高
        local _scale_w = 1 / _width * w
        local _scale_h = 1 / _height * h
        love.graphics.setColor(1,1,1,1)

        love.graphics.draw(ui_save,x,y,r,_scale_w,_scale_h)
    end,
    keyboard = function(key)
        if key == "s" and isctrl == true  then
            save(chart,"chart.txt")
            objact_message_box.message("save")
        end
    end,
    mousepressed = function( x1, y1, button, istouch, presses )
        if x1 >= x  and x1 <= x + w and y1 <= y + h and y1 >= y then -- 在play的范围内
            save(chart,"chart.txt")
            objact_message_box.message("save")
        end
    end,
    update = function(dt)
        if elapsed_time - save_time >= 114 and demo_mode == false and settings.auto_save == 1 then --保存
            save_time = elapsed_time
            save(chart,"chart.txt")
            objact_message_box.message("auto_save")
        end
    end,
    quit = function()
    if quit_click > 0 then --防止无法退出
        return
    end
    quit_click = quit_click + 1

    -- 读取文本文件 内容相同直接退出
    local ischart = {}
    if chart_info.chart_name[select_chart_pos] then
        ischart = love.filesystem.read(chart_info.chart_name[select_chart_pos].path)  -- 以只读模式打开文件
    end
    if type(chart) ~= "table" then
        return
    end
    if tablesEqual(ischart,chart) then
        return
    end
        local yes_func = function() save(chart,"chart.txt") love.event.quit(0) end
        local no_func = function()  love.event.quit(0) end
        objact_message_box.message_window_dlsplay(objact_language.get_string_in_languages("save"),yes_func,no_func)
        return true
    end,
}