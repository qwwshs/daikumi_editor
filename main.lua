require("function_beat_and_time")
require("function_log")
require("function_string")
require("function_table")
require("function_save")
require("function_RGB")
require("function_input_box")
require("function_bezier")
require("function_math")
require("function_switch")
require("function_note")
require("function_event")
require("room_play")
require("room_sidebar")
require("objact_button_denom")
require("objact_button_music_speed")
require('objact_button_track_scale')
require('objact_button_save')
require("objact_mouse")
require("objact_music_play")
require('objact_message_box')
require("objact_note")
require("objact_note_edit_inplay")
require("objact_event")
require("objact_hit")
require('objact_event_edit')
require('objact_event_edit_bezier')
require('objact_button_track')
require('objact_button_chart_info')
require('objact_button_event_edit_default_bezier')
require('objact_button_break')
require('objact_button_settings')
require('objact_chart_info')
require('objact_bpm_list')
require('objact_slider')
require('objact_copy')
require('objact_settings')
require('objact_demo_mode')
version = "0.0.1"
beat = {nowbeat = 0,allbeat = 100}
time = {nowtime = 0 ,alltime = 100}
denom = {scale = 1,denom = 4} --分度的缩放和使用的分度
chart = {}
track = {track = 1} -- 第一个轨道
bg = nil
music = nil
music_play = false
mouse  = {x = 0,y = 0,down_state = false}--鼠标按下状态
elapsed_time = 0 -- 已运行时间
font = 12 -- 字体大小
isctrl  = false --ctrl按下状态
iskeyboard = {} --key的按下状态
note_occurrence_point = -1000 --note出现点 （斜轨用的）
music_speed = 1 --播放速度
demo_mode = false --演示状态
window_w_scale = 1
window_h_scale = 1
local meta_chart = { --谱面基本格式 元表
    __index ={
        bpm_list = {
            {beat = {0,0,1},bpm = 120},
        },
        note = {},
        event = {},
        effect = {},
        offset = 0 ,
        info = {
            song_name = [[]],
            chart_name = [[]],
            chartor = [[]],
            artist = [[]],
        }
    }
}
meta_settings = { --设置基本格式 元表
    __index ={
        
        judge_line_y = 700,
        angle = 90,
        music_volume = 100,
        hit_volume = 100,
        hit = 0,
        hit_sound = 0,
        note_alpha = 100,
        note_height = 75,
    }
}

function love.load()
    --初始化
    objact_mouse.load()
    love.graphics.setFont(love.graphics.newFont(font))
    -- 读取文本文件
    local chart_file = io.open("chart.txt", "r")  -- 以只读模式打开文件
    if chart_file then
        local content = chart_file:read("*a")  -- 读取整个文件内容
        chart_file:close()  -- 关闭文件
        chart = loadstring("return "..content)()
    end
    if type(chart) ~= "table" then
        chart = {}
    end
    setmetatable(chart,meta_chart) --防谱报废
    function fillMissingElements(tbl, metatable) --补充元素
        for key, value in pairs(metatable) do
            if type(value) == "table" then
                tbl[key] = tbl[key] or {}
                fillMissingElements(tbl[key], value)
            else
                tbl[key] = tbl[key] or value
            end
        end
    end
    fillMissingElements(chart,meta_chart.__index)

    -- 读取设置文件
    local settings_file = io.open("settings.txt", "r")  -- 以只读模式打开文件
    if settings_file then
        local content = settings_file:read("*a")  -- 读取整个文件内容
        settings_file:close()  -- 关闭文件
        settings = loadstring("return "..content)()
    end
    if type(settings) ~= "table" then
        settings = {}
    end
    setmetatable(settings,meta_settings) --防谱报废
    function fillMissingElements(tbl, metatable) --补充元素
        for key, value in pairs(metatable) do
            if type(value) == "table" then
                tbl[key] = tbl[key] or {}
                fillMissingElements(tbl[key], value)
            else
                tbl[key] = tbl[key] or value
            end
        end
    end
    fillMissingElements(settings,meta_settings.__index)
        local music_esist = false
        music_error = ""
        -- 读取音频文件
        local music_file = io.open("music.wav", "r")  -- 以只读模式打开文件
        local music_file2 = io.open("music.ogg", "r")  -- 以只读模式打开文件
        local music_file3 = io.open("music.mp3", "r")  -- 以只读模式打开文件
        if music_file then
            music_esist,music_error = pcall(function() music = love.audio.newSource("music.wav", "stream") end)
        elseif music_file2 then
            music_esist,music_error = pcall(function() music = love.audio.newSource("music.ogg", "stream") end)
        elseif music_file3 then
            music_esist,music_error = pcall(function() music = love.audio.newSource("music.mp3", "stream") end)
        end
        if music_esist then
            
            time.alltime = music:getDuration() + chart.offset/1000 -- 得到音频总时长
            beat.allbeat = time_to_beat(chart.bpm_list,time.alltime)
        end


    local bg_flie = io.open("bg.png", "r")  -- 以只读模式打开文件
    local bg_flie2 = io.open("bg.jpg", "r")  -- 以只读模式打开文件
    bg_esist,bg_error = false,""
    if bg_flie then
    -- 读取图片文件
        bg_esist,bg_error = pcall(function() bg = love.graphics.newImage("bg.png") end)
    elseif bg_flie2 then
        -- 读取图片文件
        bg_esist,bg_error = pcall(function() bg = love.graphics.newImage("bg.jog") end)
    end

	room_play.load()
    room_sidebar.load()
    log("start")
    objact_message_box.message("start")
end
function love.update(dt)

    mouse.x, mouse.y = love.mouse.getPosition( )
    elapsed_time = elapsed_time + dt
    room_play.update(dt)
    room_sidebar.update(dt)
end
function love.draw()
    
    
    love.graphics.scale(window_w_scale, window_h_scale)
    objact_demo_mode.draw()
    room_play.draw()
    room_sidebar.draw()
    objact_message_box.draw()
    objact_mouse.draw()

end
function love.quit()
    log("end")
end

function love.keypressed(key)
    if key == "lctrl" or key == "rctrl" then
        isctrl = true
    end
    iskeyboard[key] = true
    if string.sub(key,1,2) == "kp" then
        key = string.sub(key,3,3)
    end
    room_play.keypressed(key)
    room_sidebar.keypressed(key)
    objact_message_box.message(key)
    input_box_key(key) --所有键入内容都照样读的 直接塞主函数
    objact_demo_mode.keyboard(key)
end
function love.keyreleased(key)
    if key == "lctrl" or key == "rctrl" then
        isctrl = false
    end 
    iskeyboard[key] = false
    room_play.keyreleased(key)
end
function love.wheelmoved(x, y)
    room_play.wheelmoved(x,y)
    room_sidebar.wheelmoved(x,y)
end

function love.mousepressed( x, y, button, istouch, presses )
    mouse.down_state = true
    room_play.mousepressed( x, y, button, istouch, presses )
    room_sidebar.mousepressed( x, y, button, istouch, presses )
    objact_mouse.mousepressed( x, y, button, istouch, presses )
end

function love.mousereleased( x, y, button, istouch, presses )
    mouse.down_state = false
    objact_mouse.mousereleased( x, y, button, istouch, presses )
    room_sidebar.mousereleased( x, y, button, istouch, presses )
    room_play.mousereleased(x, y, button, istouch, presses)
end

function love.textinput(input)
    room_play.textinput(input)
end
function love.quit()
    room_play.quit()
end

function love.resize( w, h )
    window_w_scale = w / 1600
    window_h_scale = h / 800
end