--预设的bezier表格
local ui_up = nil
local ui_down = nil
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_up = love.graphics.newImage("asset_ui_up.png")
local ui_down = love.graphics.newImage("asset_ui_down.png")
local input_type = false --输入状态
local input_string = "" --键入的内容
local bezier_index = 1 --表格位置索引
local default_bezier = {}
local meta_default_bezier = {
    __index ={
        {1,1,1,1}
    
    }
}

objact_event_edit_default_bezier = { --bezier表格的
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
        input_string = bezier_index
        local bezier_file = io.open("default_bezier.txt", "r")  -- 以只读模式打开文件
        if bezier_file then
            local content = bezier_file:read("*a")  -- 读取整个文件内容
            bezier_file:close()  -- 关闭文件
            default_bezier = loadstring("return "..content)()
        end
    if type(default_bezier) ~= "table" then
        default_bezier = {}
    end
    setmetatable(default_bezier,meta_default_bezier) --防报废

    end,
    draw = function()
        if not(string.sub(displayed_content,1,5) == "event") then -- 太特殊 所以不用type 和roomtype 判断
            return
        end
        local _width, _height = ui_up:getDimensions( ) -- 得到宽高
        local _scale_w = 1 / _width * w
        local _scale_h = 1 / _height * h
        love.graphics.setColor(1,1,1,1)

        love.graphics.draw(ui_up,x,y,r,_scale_w,_scale_h)
        love.graphics.draw(ui_down,x,y+h,r,_scale_w,_scale_h)
        love.graphics.print(objact_language.get_string_in_languages("bezier"),x-50,y)

        love.graphics.setColor(0.1,0.1,0.1,0.5)
        love.graphics.rectangle("fill",x-50,y + h,50,h) --输入框
        love.graphics.setColor(1,1,1,1)
        love.graphics.print(input_string,x-25,y + h) --输入框

        if input_type == true then -- 输入状态
            love.graphics.setColor(1,1,1,1)
            love.graphics.rectangle("line",x-50,y + h,50,h) --输入框外框
        end
    end,
    keyboard = function(key)
        if not(string.sub(displayed_content,1,5) == "event") then -- 太特殊 所以不用type 和roomtype 判断
            return
        end
        if input_type == true then
            if key == "backspace" then -- 退格
                input_string = string.sub(input_string, 1, -2)
            end
            if key == "return" then -- 关闭 
                bezier_index = tonumber(input_string) or 1
                if not default_bezier[bezier_index] then
                    bezier_index = 1
                end
                input_string = bezier_index
                local trans1,trans2,trans3,trans4 = default_bezier[bezier_index][1],default_bezier[bezier_index][2],
                default_bezier[bezier_index][3],default_bezier[bezier_index][4]

                trans1 = math.floor(trans1 * 100) / 100
                trans2 = math.floor(trans2 * 100) / 100
                trans3 = math.floor(trans3 * 100) / 100
                trans4 = math.floor(trans4 * 100) / 100
                chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].trans = {trans1,trans2,trans3,trans4}
            end
            if string.match(key, "%d") ~= nil then --为数字
                input_string = input_string..key
            end
        end
    end,
    mousepressed = function( x1, y1, button, istouch, presses )
        if not(string.sub(displayed_content,1,5) == "event") then -- 太特殊 所以不用type 和roomtype 判断
            return
        end
        if x1 >= x -50  and x1 <= x and y1 <= y + h + h and y1 >= y + h then -- 在输入框的范围内
            input_type = true
        else
            if input_type == true then --赋值
                bezier_index = tonumber(input_string) or 1
                if not default_bezier[bezier_index] then
                    bezier_index = 1
                end
                input_string = bezier_index
                local trans1,trans2,trans3,trans4 = default_bezier[bezier_index][1],default_bezier[bezier_index][2],
                default_bezier[bezier_index][3],default_bezier[bezier_index][4]

                trans1 = math.floor(trans1 * 100) / 100
                trans2 = math.floor(trans2 * 100) / 100
                trans3 = math.floor(trans3 * 100) / 100
                trans4 = math.floor(trans4 * 100) / 100
                chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].trans = {trans1,trans2,trans3,trans4}
            end
            input_type = false

        end
        if x1 >= x  and x1 <= x + w and y1 <= y + h and y1 >= y then -- 在up的范围内
            bezier_index = bezier_index + 1
            input_string = bezier_index
            if not default_bezier[bezier_index] then
                bezier_index = 1
            end
            input_string = bezier_index
            local trans1,trans2,trans3,trans4 = default_bezier[bezier_index][1],default_bezier[bezier_index][2],
            default_bezier[bezier_index][3],default_bezier[bezier_index][4]

            trans1 = math.floor(trans1 * 100) / 100
            trans2 = math.floor(trans2 * 100) / 100
            trans3 = math.floor(trans3 * 100) / 100
            trans4 = math.floor(trans4 * 100) / 100
            chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].trans = {trans1,trans2,trans3,trans4}
        elseif x1 >= x  and x1 <= x + w and y1 <= y + h + h and y1 >= y + h then -- 在down的范围内
            bezier_index = math.abs(bezier_index - 2) + 1--防止非自然数
            input_string = bezier_index
            if not default_bezier[bezier_index] then
                bezier_index = 1
            end
            input_string = bezier_index
                local trans1,trans2,trans3,trans4 = default_bezier[bezier_index][1],default_bezier[bezier_index][2],
                default_bezier[bezier_index][3],default_bezier[bezier_index][4]

                trans1 = math.floor(trans1 * 100) / 100
                trans2 = math.floor(trans2 * 100) / 100
                trans3 = math.floor(trans3 * 100) / 100
                trans4 = math.floor(trans4 * 100) / 100
                chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].trans = {trans1,trans2,trans3,trans4}
            
        end
    end,
    textinput = function(input)

    end
}