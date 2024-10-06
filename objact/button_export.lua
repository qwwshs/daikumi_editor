
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_export = love.graphics.newImage("asset/ui_export.png")
local function will_draw()
    return the_room_pos('select')
end
local function will_do()
    if not chart_tab[select_music_pos] then
        return
    end
    local file_tab = love.filesystem.getDirectoryItems("chart/"..chart_tab[select_music_pos]) --导出
    local file_name = ""
    for i,v in ipairs(file_tab) do
        local info = love.filesystem.read("chart/"..chart_tab[select_music_pos].."/"..v)
        if v:sub(1,1) == "-" then --防读不了
            v = v:sub(2,#v)
        end
        v = 'export_'..v
        local file = io.open(v, "wb")
        file:write(info)
        file:close()
        file_name = file_name.. " ".. v
    end
    local err = os.execute("7z a "..chart_tab[select_music_pos]..".zip"..file_name)  --导出 调用7zip
    objact_message_box.message("export")
    if err ~= 0 then
        log("export error:"..err,chart_tab[select_music_pos]..".zip", file_name)
    end
    for i,v in ipairs(file_tab) do
        if v:sub(1,1) == "-" then
            v = v:sub(2,#v)
        end
        for i = 1,#v do --去空格
            if v:sub(i,i) == " " then
                v = v:sub(1,i-1)v:sub(i+1,#v)
                break
            end
        end
        v = 'export_'..v
        os.remove(v)  --删除
    end
end

objact_export = { --分度改变用的
load = function(x1,y1,r1,w1,h1)
    x= x1 --初始化
    y = y1
    w = w1
    h = h1
    r = r1
    button_new("export",will_do,x,y,w,h,ui_export,{will_draw = will_draw})
end,
draw = function()

end,
mousepressed = function( x1, y1, button, istouch, presses )

end,
}