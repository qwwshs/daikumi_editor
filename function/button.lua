--按钮函数
local button_objact = {} --对象
local input_string = ""

function button_new(name,func,x,y,w,h,style,style2) --名字 与所对应的变量 还有样式
    if style2 then
        button_objact[name] = {func = func,x = x,y = y,w = w,h = h,style = style,style2 = style2}
    else
        button_objact[name] = {func = func,x = x,y = y,w = w,h = h,style = style}
    end
end

function button_draw(name)
    love.graphics.setColor(1,1,1,1)
    local style_width, style_height = button_objact[name].style:getDimensions( ) -- 得到宽高
    local style_scale_h = 1 / style_height * button_objact[name].h
    local style_scale_w = 1 / style_height * button_objact[name].w
    love.graphics.draw(button_objact[name].style,button_objact[name].x,button_objact[name].y,0,style_scale_w,style_scale_h)
    local pos = button_query_type_in()
    if pos then
        if button_objact[name].style2 then
            love.graphics.setColor(1,1,1,1)
            local style_width, style_height = button_objact[name].style:getDimensions( ) -- 得到宽高
            local style_scale_h = 1 / style_height * button_objact[name].h
            local style_scale_w = 1 / style_height * button_objact[name].w
            love.graphics.draw(button_objact[name].style2,button_objact[name].x,button_objact[name].y,0,style_scale_w,style_scale_h)
        else
            love.graphics.setColor(0.5,0.5,0.5,1)
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
        and y <= button_objact[i].y + button_objact[i].h and y >= button_objact[i].y then
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

function button_wheelmoved(x,y) --滑轮滚动 使全体位移
    for i, v in pairs(button_objact) do
        button_objact[i].y = button_objact[i].y + y *10
    end
end

function button_query_type_in() --查询现在所在位置
    for i, v in pairs(button_objact) do
        if mouse.x >= button_objact[i].x and mouse.x <= button_objact[i].x + button_objact[i].w 
        and mouse.y <= button_objact[i].y + button_objact[i].h and mouse.y >= button_objact[i].y then
            return i
        end
    end
end