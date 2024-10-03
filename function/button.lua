--按钮函数
local button_objact = {} --对象
local input_string = ""

local function pass() --空函数
    --pass
end
local meta_type = {__index ={
    input_ed_finish = pass, --输入完成处理完成之后的回调函数
    will_draw = pass, --确认是否绘画
    style2 = nil, --第二个样式
}}
function button_new(name,func,x,y,w,h,style,thetype) --名字 与所对应的变量 还有样式
    local istype = thetype or {}
    if type(thetype) ~= "table" then
        istype = {}
    end
    setmetatable(istype,meta_type)
    fillMissingElements(istype,meta_type.__index)
    button_objact[name] = {func = func,x = x,y = y,w = w,h = h,style = style,type=thetype}
end

function button_draw(name)
    if not button_objact[name].type.will_draw() then
        return
    end
    love.graphics.setColor(1,1,1,1)
    if type(button_objact[name].style) == 'function' then
        button_objact[name].style()
    else
        local style_width, style_height = button_objact[name].style:getDimensions( ) -- 得到宽高
        local style_scale_h = 1 / style_height * button_objact[name].h
        local style_scale_w = 1 / style_height * button_objact[name].w
        love.graphics.draw(button_objact[name].style,button_objact[name].x,button_objact[name].y,0,style_scale_w,style_scale_h)
    end
    local pos = button_query_type_in()
    if pos == name then
        if button_objact[name].type.style2 then
            if type(button_objact[name].type.style2) == 'function' then
                button_objact[name].type.style2()
            else
                love.graphics.setColor(1,1,1,1)
                local style_width, style_height = button_objact[name].style:getDimensions( ) -- 得到宽高
                local style_scale_h = 1 / style_height * button_objact[name].h
                local style_scale_w = 1 / style_height * button_objact[name].w
                love.graphics.draw(button_objact[name].type.style2,button_objact[name].x,button_objact[name].y,0,style_scale_w,style_scale_h)
            end
        else
            love.graphics.setColor(0.5,0.5,0.5,0.25)
            love.graphics.rectangle("fill",button_objact[name].x,button_objact[name].y,button_objact[name].w,button_objact[name].h)
        end
    end
end
function button_draw_all()
        for i, v in pairs(button_objact) do
            button_draw(i)
        end
end


function button_mousepressed(x,y) --输入
    for i, v in pairs(button_objact) do

        if x >= button_objact[i].x and x <= button_objact[i].x + button_objact[i].w 
        and y <= button_objact[i].y + button_objact[i].h and y >= button_objact[i].y and button_objact[i].type.will_draw() then
            button_objact[i].func()
        end
    end
end

function button_delete(name) --删除
    button_objact[name] = nil
end

function button_delete_all() --删除 全部
    button_objact = {}
end

function button_wheelmoved(x,y,name) --滑轮滚动 使全体位移
        button_objact[name].y = button_objact[name].y + y *10
end

function button_query_type_in() --查询现在所在位置
    for i, v in pairs(button_objact) do
        
        if mouse.x >= button_objact[i].x and mouse.x <= button_objact[i].x + button_objact[i].w 
        and mouse.y <= button_objact[i].y + button_objact[i].h and mouse.y >= button_objact[i].y and button_objact[i].type.will_draw() then
            return i
        end
    end
end