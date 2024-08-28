
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_delete_music = love.graphics.newImage("asset/ui_delete_music.png")
objact_delete_music = { --分度改变用的
load = function(x1,y1,r1,w1,h1)
    x= x1 --初始化
    y = y1
    w = w1
    h = h1
    r = r1
end,
draw = function()
    local _width, _height = ui_delete_music:getDimensions( ) -- 得到宽高
    local _scale_w = 1 / _width * w
    local _scale_h = 1 / _height * h
    love.graphics.setColor(1,1,1,1)

    love.graphics.draw(ui_delete_music,x,y,r,_scale_w,_scale_h)
end,
mousepressed = function( x1, y1, button, istouch, presses )
    if x1 >= x  and x1 <= x + w and y1 <= y + h and y1 >= y then -- 在范围内
        --找到谱面文件夹然后删除
        local yes_func = function()

            
            pcall(function() 
                local file_tab = love.filesystem.getDirectoryItems("chart/"..chart_tab[select_music_pos]) --得到谱面文件夹下的所有文件
                for i,v in ipairs(file_tab) do

                    local s = love.filesystem.remove( "chart/"..chart_tab[select_music_pos].."/"..v ) --删除谱面文件夹下的所有文件 
                    log(s)
                end
                love.filesystem.remove( "chart/"..chart_tab[select_music_pos] ) --删除谱面文件夹
            end)
            room_select.load()
        end
        objact_message_box.message_window_dlsplay(objact_language.get_string_in_languages("delete?"),yes_func,function() end)

    end
end,
}