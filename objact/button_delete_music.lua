
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_delete_music = love.graphics.newImage("asset/ui_delete_music.png")
local function will_draw()
    return the_room_pos('select')
end
local function will_do()
    --找到谱面文件夹然后删除
    local yes_func = function()
        pcall(function() 
            local file_tab = love.filesystem.getDirectoryItems("chart/"..chart_tab[select_music_pos]) --得到谱面文件夹下的所有文件
            for i,v in ipairs(file_tab) do
    
                local s = love.filesystem.remove( "chart/"..chart_tab[select_music_pos].."/"..v ) --删除谱面文件夹下的所有文件 
            end
            love.filesystem.remove( "chart/"..chart_tab[select_music_pos] ) --删除谱面文件夹
        end)
        room_select.load()
    end
    objact_message_box.message_window_dlsplay(objact_language.get_string_in_languages("delete?"),yes_func,function() end)
end
objact_delete_music = { --分度改变用的
load = function(x1,y1,r1,w1,h1)
    x= x1 --初始化
    y = y1
    w = w1
    h = h1
    r = r1
    button_new("delete_music",will_do,x,y,w,h,ui_delete_music,{will_draw = will_draw})
end,
draw = function()
end,
mousepressed = function( x1, y1, button, istouch, presses )
end,
}