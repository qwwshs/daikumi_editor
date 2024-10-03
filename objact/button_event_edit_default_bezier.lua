--预设的bezier表格
local ui_up = nil
local ui_down = nil
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_up = love.graphics.newImage("asset/ui_up.png")
local ui_down = love.graphics.newImage("asset/ui_down.png")
bezier_index = 1 --表格位置索引
local default_bezier = {}
local meta_default_bezier = {
    __index ={
        {1,1,1,1}
    
    }
}
local function will_draw()
    return string.sub(displayed_content,1,5) == "event" and the_room_pos("edit")
end
local function input_ed_finish()
    local trans1,trans2,trans3,trans4 = default_bezier[bezier_index][1],default_bezier[bezier_index][2],
    default_bezier[bezier_index][3],default_bezier[bezier_index][4]

    trans1 = math.floor(trans1 * 100) / 100
    trans2 = math.floor(trans2 * 100) / 100
    trans3 = math.floor(trans3 * 100) / 100
    trans4 = math.floor(trans4 * 100) / 100
    chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].trans = {trans1,trans2,trans3,trans4}
end
objact_event_edit_default_bezier = { --bezier表格的
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
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
    input_box_new("bezier_index","bezier_index",x-50,y + h,50,h,{type = "number",will_draw = will_draw,input_ed_finish = input_ed_finish})
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

    end,
    keyboard = function(key)
        if not(string.sub(displayed_content,1,5) == "event") then -- 太特殊 所以不用type 和roomtype 判断
            return
        end
    end,
    mousepressed = function( x1, y1, button, istouch, presses )
        if not(string.sub(displayed_content,1,5) == "event") then -- 太特殊 所以不用type 和roomtype 判断
            return
        end
        
        if x1 >= x  and x1 <= x + w and y1 <= y + h and y1 >= y then -- 在up的范围内
            bezier_index = bezier_index + 1
            if not default_bezier[bezier_index] then
                bezier_index = 1
            end
            local trans1,trans2,trans3,trans4 = default_bezier[bezier_index][1],default_bezier[bezier_index][2],
            default_bezier[bezier_index][3],default_bezier[bezier_index][4]

            trans1 = math.floor(trans1 * 100) / 100
            trans2 = math.floor(trans2 * 100) / 100
            trans3 = math.floor(trans3 * 100) / 100
            trans4 = math.floor(trans4 * 100) / 100
            chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].trans = {trans1,trans2,trans3,trans4}
        elseif x1 >= x  and x1 <= x + w and y1 <= y + h + h and y1 >= y + h then -- 在down的范围内
            bezier_index = math.abs(bezier_index - 2) + 1--防止非自然数
            if not default_bezier[bezier_index] then
                bezier_index = 1
            end
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