
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_save = love.graphics.newImage("asset_ui_save.png")

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
    quit = function()
    -- 读取文本文件 内容相同直接退出
    local chart_file = io.open("chart.txt", "r")  -- 以只读模式打开文件
    local ischart
    if chart_file then
        local content = chart_file:read("*a")  -- 读取整个文件内容
        chart_file:close()  -- 关闭文件
        ischart = loadstring("return "..content)()
    end
    if type(chart) ~= "table" then
        return
    end
    if tablesEqual(ischart,chart) then
        return
    end
    
        local isbutton = love.window.showMessageBox( "quit", "save?",{"Y","N"},"info",false)
        if isbutton == 1 then
            save(chart,"chart.txt")
            objact_message_box.message("save")
        end
    end,
}