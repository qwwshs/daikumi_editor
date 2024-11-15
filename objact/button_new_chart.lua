
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local function draw_this_button()
    ui_style:button(x,y,w,h,objact_language.get_string_in_languages("new chart"))
end
local function will_draw()
    return the_room_pos('select')
end
local function will_do()
        objact_message_box.message("new_chart")
        local name = "chart/"..chart_tab[select_music_pos].."/new_chart"
        while love.filesystem.getInfo( name..".d3" )  do
            name = name .."_new"
        end

        local file = love.filesystem.newFile(name..".d3")
        file:open("w") --为了创建谱面
        love.filesystem.write("chart/"..chart_tab[select_music_pos].."/"..name..".d3",tableToString(meta_chart.__index)) --初始化
        file:close()
        chart_info.chart_name =  {}
        local file_tab = love.filesystem.getDirectoryItems("chart/"..chart_tab[select_music_pos]) --得到谱面文件夹下的所有谱面
        for i,v in ipairs(file_tab) do
            if string.find(v,".d3") then --谱面文件
                local info = love.filesystem.read("chart/"..chart_tab[select_music_pos].."/"..v)
                pcall(function() info = loadstring("return "..info)() end)
                if type(info) ~= "table" then
                    info = {}
                    love.filesystem.write("chart/"..chart_tab[select_music_pos].."/"..v,tableToString(meta_chart.__index))
                end
                setmetatable(info,meta_chart) --防谱报废
                fillMissingElements(info,meta_chart.__index)

                chart = copyTable(info) --读取谱面
                setmetatable(chart,meta_chart) --防谱报废

                fillMissingElements(chart,meta_chart.__index)
                chart_info.song_name = info.info.song_name
                chart_info.chart_name[#chart_info.chart_name + 1] = {name = info.info.chart_name,
                path = "chart/"..chart_tab[select_music_pos].."/"..v}
                
            end
        end
end

objact_new_chart = { --分度改变用的
load = function(x1,y1,r1,w1,h1)
    x= x1 --初始化
    y = y1
    w = w1
    h = h1
    r = r1
    button_new("new_chart",will_do,x,y,w,h,draw_this_button,{will_draw = will_draw})
end,
draw = function()
end,
mousepressed = function( x1, y1, button, istouch, presses )
    
end,
}
