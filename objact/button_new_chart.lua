
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_new = love.graphics.newImage("asset/ui_new_chart.png")
objact_new_chart = { --分度改变用的
load = function(x1,y1,r1,w1,h1)
    x= x1 --初始化
    y = y1
    w = w1
    h = h1
    r = r1
end,
draw = function()
    local _width, _height = ui_new:getDimensions( ) -- 得到宽高
    local _scale_w = 1 / _width * w
    local _scale_h = 1 / _height * h
    love.graphics.setColor(1,1,1,1)

    love.graphics.draw(ui_new,x,y,r,_scale_w,_scale_h)
end,
mousepressed = function( x1, y1, button, istouch, presses )
    if x1 >= x  and x1 <= x + w and y1 <= y + h and y1 >= y then -- 在范围内
        objact_message_box.message("new_chart")
        local name = "chart/"..chart_tab[select_music_pos].."/new_chart"
        while love.filesystem.getInfo( name..".txt" )  do
            name = name .."_new"
        end

        local file = love.filesystem.newFile(name..".txt")
        file:open("w") --为了创建谱面
        file:close()
        chart_info.chart_name =  {}
        local file_tab = love.filesystem.getDirectoryItems("chart/"..chart_tab[select_music_pos]) --得到谱面文件夹下的所有谱面
        for i,v in ipairs(file_tab) do
            if string.find(v,".txt") then --谱面文件
                local info = love.filesystem.read("chart/"..chart_tab[select_music_pos].."/"..v)
                pcall(function() info = loadstring("return "..info)() end)
                if type(info) ~= "table" then
                    log("It is "..type(info))
                    info = {}
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
end,
}