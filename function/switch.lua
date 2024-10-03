--开关
local switch_objact = {} --对象
local input_string = ""
local function pass() --默认函数
    --pass
end
local meta_type = {__index ={
    input_ed = pass,  --输入完成处理完成之前的回调函数
    input_ed_finish = pass, --输入完成处理完成之后的回调函数
    will_draw = pass, --确认是否绘画
}}
function switch_new(name,var,x,y,w,h,level,thetype) --名字 与所对应的变量
    local istype = thetype or {}
    if type(thetype) ~= "table" then
        istype = {}
    end
    setmetatable(istype,meta_type)
    fillMissingElements(istype,meta_type.__index)
    local islevel = level
    if not level then
        islevel = 2
    end
    switch_objact[name] = {var = var,x = x,y = y,w = w,h = h,level = islevel,type=thetype} --level是有几种模式的意思
end

function switch_draw(name)
    if not switch_objact[name].type.will_draw() then
        return
    end
    love.graphics.setColor(1,1,1,0.5)
    love.graphics.rectangle("fill",switch_objact[name].x,switch_objact[name].y,switch_objact[name].w,switch_objact[name].h) --内框
    love.graphics.setColor(0.5,0.5,0.5,1) --外框
    love.graphics.rectangle("line",switch_objact[name].x,switch_objact[name].y,switch_objact[name].w,switch_objact[name].h)
    love.graphics.setColor(1,1,1,1) --开关
    love.graphics.circle("fill",
    switch_objact[name].x + switch_objact[name].w * 
    (loadstring("return _G."..switch_objact[name].var)() ) / switch_objact[name].level 
    ,switch_objact[name].y+switch_objact[name].h/2,switch_objact[name].h/2,4)
end
function switch_draw_all()
        for i, v in pairs(switch_objact) do
            switch_draw(i)
        end
end


function switch_mousepressed(x,y) --输入
    for i, v in pairs(switch_objact) do

        if x >= switch_objact[i].x and x <= switch_objact[i].x + switch_objact[i].w 
        and y <= switch_objact[i].y + switch_objact[i].h and y >= switch_objact[i].y and switch_objact[i].type.will_draw() then
            switch_objact[i].type.input_ed(input_string)
            if loadstring("return _G."..switch_objact[i].var)() >= switch_objact[i].level then 
                --大于最大值 回到第一个开关
                loadstring("_G."..switch_objact[i].var.."=".. -1)() --因为后面要＋1 所以重置到0
            end
                loadstring("_G."..switch_objact[i].var.."=".. "_G."..switch_objact[i].var.." + 1")()
                switch_objact[i].type.input_ed_finish(input_string)
        end
    end
end

function switch_delete(name) --删除
    switch_objact[name] = nil
end

function switch_delete_all() --删除 全部
    switch_objact = {}
end

function switch_wheelmoved(x,y,name) --滑轮滚动 使全体位移
    switch_objact[name].y = switch_objact[name].y + y *10
end

function switch_query_type_in() --查询现在所在位置
    for i, v in pairs(switch_objact) do
        if mouse.x >= switch_objact[i].x and mouse.x <= switch_objact[i].x + switch_objact[i].w 
        and mouse.y <= switch_objact[i].y + switch_objact[i].h and mouse.y >= switch_objact[i].y then
            return i
        end
    end
end