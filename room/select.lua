--选择的歌曲的房间
local pos = "select"
chart_tab = {} --所有谱面的文件夹
local music_pos = 0 --移动显示的位置
local chart_pos = 0 --移动显示的位置
select_music_pos = 1 --选择的歌曲
select_chart_pos = 1 --选择的谱面
chart_info = {song_name = nil,bg = nil,chart_name = {},song = nil} --谱面的信息
local ui_edit = love.graphics.newImage("asset/ui_edit.png")
animation_new("select_music_pos_x",1080,1080,0,0,{1,1,1,1})
room_select = {
    load = function()
        chart_tab = {} --所有谱面的文件夹
        chart_info = {song_name = nil,bg = nil,chart_name = {},song = nil} --谱面的信息
        love.audio.stop( ) --停止上一个歌曲

        local dir = love.filesystem.getIdentity() --文件的写入目录
        local is_chart,is_chart_type = love.filesystem.getInfo( "chart" ) --得到chart文件夹是否存在
        if not (is_chart) or is_chart_type ~= 'directory' then
            love.filesystem.createDirectory("chart" )
        end
        chart_tab = love.filesystem.getDirectoryItems("chart" ) --得到谱面文件夹下的所有谱面
        
        local is_temporary,is_temporary_type = love.filesystem.getInfo( "temporary" ) --得到local文件夹是否存在
        if not (is_temporary) or is_temporary_type ~= 'directory' then
            love.filesystem.createDirectory("temporary" )
        end
        local temporary_tab = love.filesystem.getDirectoryItems("temporary" ) --得到文件夹下的所有文件
        for i ,v in ipairs(temporary_tab) do
            love.filesystem.remove("temporary".."/"..v)
        end

        

        if chart_tab[select_music_pos] then
            chart_info = {song_name = nil,bg = nil,chart_name = {},song = nil} --谱面的信息
            --输出选择到的谱面的谱面信息
            local file_tab = love.filesystem.getDirectoryItems("chart/"..chart_tab[select_music_pos]) --得到谱面文件夹下的谱面
            for i,v in ipairs(file_tab) do
                if string.find(v,".txt") then --谱面文件
                    local info = love.filesystem.read("chart/"..chart_tab[select_music_pos].."/"..v)
                    pcall(function() info = loadstring("return "..info)() end)
                    if type(info) ~= "table" then
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
                if string.find(v,".jpg") or string.find(v,".png") then --bg
                    chart_info.bg = love.graphics.newImage("chart/"..chart_tab[select_music_pos].."/"..v)

                    bg = love.graphics.newImage("chart/"..chart_tab[select_music_pos].."/"..v)
                end
                
            end
            for i,v in ipairs(file_tab) do --因为一些数据在chart里面 所以分开读
                if string.find(v,".mp3") or string.find(v,".ogg") or string.find(v,".wav") then --歌曲
                    love.audio.stop( ) --停止上一个歌曲
                    chart_info.song = love.audio.newSource("chart/"..chart_tab[select_music_pos].."/"..v, "stream")
                    love.audio.setVolume( settings.music_volume / 100 ) --设置音量大小
                    chart_info.song:play()
    
                    --读取音频信息
                    music = love.audio.newSource("chart/"..chart_tab[select_music_pos].."/"..v, "stream")
                    music_data.soundData = love.sound.newSoundData("chart/"..chart_tab[select_music_pos].."/"..v)
    
                    music_data.count = music_data.soundData:getSampleCount() --用来显示音频图
                    time.alltime = music:getDuration() + chart.offset / 1000 -- 得到音频总时长
                    beat.allbeat = time_to_beat(chart.bpm_list,time.alltime)
                end
            end

            if not chart_info.song then
                love.audio.stop( ) --停止上一个歌曲
            end
        end
            objact_edit_chart.load(0,750,0,100,50)
            objact_delete_chart.load(100,750,0,100,50)
            objact_new_chart.load(200,750,0,100,50)
            objact_open_chart_list.load(1500,0,0,100,50)
            objact_select_file.load(1400,0,0,100,50)
            objact_delete_music.load(1300,0,0,100,50)
            objact_export.load(1200,0,0,100,50)
            objact_selector.load(500,50,0,1100,800)
    end,
    draw = function()
        if not the_room_pos(pos) then
            return
        end
        love.graphics.setFont(font_plus)
        love.graphics.setColor(0.6,0.6,0.6,0.3)
        love.graphics.rectangle("fill",0,0,1600,800) --背景板
        love.graphics.print(
        objact_language.get_string_in_languages('You can drag the chart or folder containing the chart or song to the window for import.')
        ,0,720)

        --输出所有歌曲
        
        local the_music_pos = 1 --用来当做i的
        for i,v in ipairs(chart_tab) do
            if the_music_pos == select_music_pos then
                love.graphics.setColor(1,1,1,1)
                love.graphics.print(v,animation.select_music_pos_x + 20 ,20+ (the_music_pos +music_pos)*100)
                love.graphics.setColor(0,0,0,0.5)
                love.graphics.rectangle("fill",animation.select_music_pos_x,(the_music_pos +music_pos)*100,600,100)
                love.graphics.setColor(1,1,1,1)
                love.graphics.rectangle("line",animation.select_music_pos_x,(the_music_pos +music_pos)*100,600,100)
            else
                love.graphics.setColor(1,1,1,1)
                love.graphics.print(v,1220 ,20+ (the_music_pos +music_pos)*100)
                love.graphics.setColor(0,0,0,0.5)
                love.graphics.rectangle("fill",1200,(the_music_pos +music_pos)*100,400,100)
                love.graphics.setColor(1,1,1,1)
                love.graphics.rectangle("line",1200,(the_music_pos +music_pos)*100,400,100)
            end
            the_music_pos = the_music_pos + 1
            
        end

        --选择到的歌曲
        love.graphics.setColor(0,1,1,0.7)
        love.graphics.rectangle("fill",animation.select_music_pos_x - 20 ,(select_music_pos +music_pos)*100,10,100) 
        love.graphics.setColor(1,1,1,1)
        love.graphics.rectangle("line",animation.select_music_pos_x - 20,(select_music_pos +music_pos)*100,10,100)

        
        love.graphics.setColor(1,1,1,1)
        --歌曲信息展示

        --曲绘
        if chart_info.bg then
            local bg_width, bg_height = chart_info.bg:getDimensions( ) -- 得到宽高
            local bg_scale_h = 1 / bg_height * 300 
            local bg_scale_w = 1 / bg_height * 300 / (window_w_scale / window_h_scale)
            if 1 / bg_height * 300 / (window_h_scale / window_w_scale) < 1 / bg_width * 900 / (window_w_scale / window_h_scale) then
                bg_scale_h = 1 / bg_width * 300 / (window_h_scale / window_w_scale)
                bg_scale_w = 1 / bg_width * 300
            end
            love.graphics.draw(chart_info.bg,0,0,0,bg_scale_w,bg_scale_h)
        end

        love.graphics.setFont(font_plus)
        if type(chart_info.song_name) == "string" then --曲名
            love.graphics.print("music: "..chart_info.song_name,0,300)
        end

        
        --选择到的谱面
        if #chart_info.chart_name > 0 then
            love.graphics.setColor(1,1,1,0.3)
            love.graphics.rectangle("fill",300 ,330+ (select_chart_pos +chart_pos)*30,300,30) 
        end

        love.graphics.setFont(font)
        for i = 1,#chart_info.chart_name do --谱面名
            love.graphics.print("chart"..i..": "..chart_info.chart_name[i].name,300,330 + (i+chart_pos) *30)
        end


        objact_delete_chart.draw()
        objact_new_chart.draw()
        objact_edit_chart.draw()
        objact_export.draw()
        objact_delete_music.draw()
        objact_open_chart_list.draw()
        objact_select_file.draw()
        objact_selector.draw()

        love.graphics.setFont(font)
        love.graphics.setColor(1,1,1,1)

    end,
    keypressed = function(key)
        if not the_room_pos(pos) then
            return
        end
        objact_selector.keyboard(key)
        if selector_file_open == true then
            return
        end

    end,
    wheelmoved = function(x,y)
        if not the_room_pos(pos) then
            return
        end
        objact_selector.wheelmoved(x,y)
        if selector_file_open == true then
            return
        end
        if mouse.x > 800 and mouse.x < 1600 then
            if y > 0 then
                music_pos = music_pos + 1
            else
                music_pos = music_pos - 1
            end
        elseif mouse.x > 300 and mouse.x < 600 then
            if y > 0 then
                chart_pos = chart_pos + 1
            else
                chart_pos = chart_pos - 1
            end
        end
        while 330+ (#chart_info.chart_name +chart_pos)*30 < 0 do
            chart_pos = chart_pos + 1
        end
        while 330+ (1 +chart_pos)*30 > 800 do
            chart_pos = chart_pos - 1
        end
        while 20+ (#chart_tab +music_pos)*100 < 0 do
            music_pos = music_pos + 1
        end
        while 20+ (1 +music_pos)*100 > 800 do
            music_pos = music_pos - 1
        end
    end,
    mousepressed = function( x, y, button, istouch, presses )
        if not the_room_pos(pos) then
            return
        end
        objact_selector.mousepressed(x,y,button,istouch,presses)
        if selector_file_open == true then
            return
        end

        --点击选择谱面
        if x > 1000 and x < 1600 and y > 50 and y < 750 then
            select_music_pos = math.floor(y/100) - music_pos
            if select_music_pos < 1 then
                select_music_pos = 1
            end
            if select_music_pos > #chart_tab then
                select_music_pos = #chart_tab
            end
            --输出选择到的谱面的谱面信息
            chart_info =  {song_name = nil,bg = nil,chart_name = {},song = nil}
            local file_tab = love.filesystem.getDirectoryItems("chart/"..chart_tab[select_music_pos]) --得到谱面文件夹下的所有谱面
            chart = {} --重置
            setmetatable(chart,meta_chart) --防谱报废

            fillMissingElements(chart,meta_chart.__index)
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
                if string.find(v,".jpg") or string.find(v,".png") then --bg
                    chart_info.bg = love.graphics.newImage("chart/"..chart_tab[select_music_pos].."/"..v)

                    bg = love.graphics.newImage("chart/"..chart_tab[select_music_pos].."/"..v)
                end
                
            end
            for i,v in ipairs(file_tab) do --因为一些数据在chart里面 所以分开读
                if string.find(v,".mp3") or string.find(v,".ogg") or string.find(v,".wav") then --歌曲
                    love.audio.stop( ) --停止上一个歌曲
                    chart_info.song = love.audio.newSource("chart/"..chart_tab[select_music_pos].."/"..v, "stream")
                    love.audio.setVolume( settings.music_volume / 100 ) --设置音量大小
                    chart_info.song:play()
    
                    --读取音频信息
                    music = love.audio.newSource("chart/"..chart_tab[select_music_pos].."/"..v, "stream")
                    music_data.soundData = love.sound.newSoundData("chart/"..chart_tab[select_music_pos].."/"..v)
    
                    music_data.count = music_data.soundData:getSampleCount() --用来显示音频图
                    time.alltime = music:getDuration() + chart.offset / 1000 -- 得到音频总时长
                    beat.allbeat = time_to_beat(chart.bpm_list,time.alltime)
                end
            end
            if not chart_info.song then
                love.audio.stop( ) --停止上一个歌曲
            end

            animation_new("select_music_pos_x",1200,1080,0,0.6,{0.7,0.7,1,1})

        elseif x >= 300 and x <= 600 then --选择谱面
            select_chart_pos = math.floor((y -330)/30) - chart_pos
            if select_chart_pos < 1 then
                select_chart_pos = 1
            end
            if select_chart_pos > #chart_info.chart_name then
                select_chart_pos = #chart_info.chart_name
            end

        end
        objact_delete_music.mousepressed(x,y,button,istouch,presses)
        objact_delete_chart.mousepressed(x,y,button,istouch,presses)
        objact_edit_chart.mousepressed(x,y,button,istouch,presses)
        objact_new_chart.mousepressed(x,y,button,istouch,presses)
        
        objact_open_chart_list.mousepressed(x,y,button,istouch,presses)
        objact_export.mousepressed(x,y,button,istouch,presses)
        objact_select_file.mousepressed(x,y,button,istouch,presses)


    end,

    mousereleased = function( x, y, button, istouch, presses )
        if not the_room_pos(pos) then
            return
        end
    end,
    update = function(dt)
        if not the_room_pos(pos) then
            return
        end
        objact_selector.update(dt)
        if selector_file_open == true then
            return
        end

    end,
    directorydropped = function(path ,iszip)
        love.filesystem.mount( path, "local_path",true)
        local local_path_tab = love.filesystem.getDirectoryItems("local_path" ) --得到文件夹下的所有内容
        for i,v in ipairs(local_path_tab) do
            if string.find(v,".ogg") or string.find(v,".mp3") or string.find(v,".wav") then --音频文件
                --先确定文件夹是否存在 存在就更改后缀
                local lastSlashIndex = string.find(path, "/[^/]*$") --找到最后一个斜杠的位置
                if not lastSlashIndex then
                    lastSlashIndex = string.find(path, "\\[^\\]*$") --找到最后一个斜杠的位置
                end
                if not lastSlashIndex then
                    lastSlashIndex = 0
                end
                local path_name = string.sub(path, lastSlashIndex + 1)

                if iszip and iszip == 'zip' then
                    path_name = string.sub(path_name,1, string.find(path_name, ".[^.]*$") - 1)   --删除后缀
                end

                while love.filesystem.getInfo("chart/"..path_name ) do --防止撞名
                    path_name = path_name.."_"
                end

                love.filesystem.createDirectory("chart/"..path_name ) --创建新的文件夹
                for k,a in ipairs(local_path_tab) do --复制到新目录
                    love.filesystem.newFile("chart/"..path_name.."/"..a,"w")
                    love.filesystem.write("chart/"..path_name.."/"..a,
                    love.filesystem.read("local_path/"..a)) --复制到新的文件夹
                end
                love.filesystem.unmount("local_path") --卸载

                break
            end
        end
        room_select.load() --重新加载
    end,
    filedropped = function(file) -- 文件拖入
        file:open("r")
        local flie_name = file:getFilename()   
        local lastSlashIndex = string.find(flie_name, "/[^/]*$") --找到最后一个斜杠的位置
        if not lastSlashIndex then
            lastSlashIndex = string.find(flie_name, "\\[^\\]*$") --找到最后一个斜杠的位置
        end
        if not lastSlashIndex then
            lastSlashIndex = 0 --找到最后一个斜杠的位置
        end
        local flie_name = string.sub(flie_name, lastSlashIndex + 1)
        if string.find(flie_name,"hit_sound") then
            love.filesystem.newFile(flie_name,"w")
            love.filesystem.write(flie_name,
            file:read()) --复制到目录
            return
        

        elseif string.find(flie_name,".jpg") or string.find(flie_name,".png") or string.find(flie_name,".txt") then --bg/谱面文件
            love.filesystem.newFile("chart/"..chart_tab[select_music_pos].."/"..flie_name,"w") --复制到当前文件夹下
            love.filesystem.write("chart/"..chart_tab[select_music_pos].."/"..flie_name,
            file:read()) --复制到新的文件夹
        elseif string.find(flie_name,".mc") then --mc文件
            local txt_name= string.sub(flie_name,1, string.find(flie_name, ".[^.]*$")).."txt" --更改后缀
            love.filesystem.newFile("chart/"..chart_tab[select_music_pos].."/"..txt_name,"w") --复制到当前文件夹下
            love.filesystem.write("chart/"..chart_tab[select_music_pos].."/"..txt_name,
            tableToString(mc_to_takumi(file:read()))) --复制到新的文件夹


        elseif string.find(flie_name,".ogg") or string.find(flie_name,".mp3") or string.find(flie_name,".wav") then --音频文件
            --创建新文件夹
            local path_name = flie_name --文件夹名

            path_name= string.sub(path_name,1, string.find(path_name, ".[^.]*$"))   --删除后缀

            while love.filesystem.getInfo("chart/"..path_name ) do --防止撞名
                path_name = path_name.."_"
            end
            love.filesystem.createDirectory("chart/"..path_name ) --创建新的文件夹
            love.filesystem.newFile("chart/"..path_name.."/"..flie_name,"w")
            love.filesystem.write("chart/"..path_name.."/"..flie_name,file:read()) --复制到新的文件夹
        elseif string.find(flie_name,".zip") then
            room_select.directorydropped(file:getFilename(),'zip') --当文件读
        end
        room_select.load() --重新加载
    end
}