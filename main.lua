utf8 = require("utf8")

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
require('objact_button_to_github')
require('objact_chart_info')
require('objact_bpm_list')
require('objact_slider')
require('objact_copy')
require('objact_settings')
require('objact_demo_mode')
require('objact_language')

version = "0.0.2"
beat = {nowbeat = 0,allbeat = 100}
time = {nowtime = 0 ,alltime = 100}
denom = {scale = 1,denom = 4} --分度的缩放和使用的分度
chart = {}
track = {track = 1} -- 第一个轨道
language = {} --语言表
bg = nil
music = nil
music_play = false
mouse  = {x = 0,y = 0,original_x = 0,original_y = 0, down_state = false}--鼠标按下状态
elapsed_time = 0 -- 已运行时间
font = love.graphics.newFont("LXGWNeoXiHei.ttf", 13) -- 字体 
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
local meta_settings = { --设置基本格式 元表
    __index ={
        
        judge_line_y = 700,
        angle = 90,
        music_volume = 100,
        mouse = 0,
        hit_volume = 100,
        hit = 0,
        hit_sound = 0,
        vsync= 0,
        language= 1,
        contact_roller = 1, --鼠标滚动系数
        note_alpha = 100,
        note_height = 75,
    }
}

function love.load()
    --初始化
    love.graphics.setFont(font)
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
    fillMissingElements(chart,meta_chart.__index)

        -- 读取语言
        local language_file = io.open("language.txt", "r")  -- 以只读模式打开文件
        if language_file then
            local content = language_file:read("*a")  -- 读取整个文件内容
            language_file:close()  -- 关闭文件
            language = loadstring("return "..content)()
        end
        if type(language) ~= "table" then
            language = {}
        end


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
    
    fillMissingElements(settings,meta_settings.__index)
    love.window.setVSync( settings.vsync  )

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
    objact_mouse.load()
    log("start")
    objact_message_box.message("start")
    love.keyboard.setKeyRepeat(true) --键重复

    
end
function love.update(dt)
    mouse.original_x, mouse.original_y = love.mouse.getPosition( ) --对缩放进行处理
    mouse.x = mouse.original_x / window_w_scale
    mouse.y = mouse.original_y / window_h_scale
    elapsed_time = elapsed_time + dt
    room_play.update(dt)
    room_sidebar.update(dt)
    objact_message_box.update(dt)
end
function love.draw()
    
    
    love.graphics.scale(window_w_scale, window_h_scale)
    objact_demo_mode.draw()
    room_play.draw()
    room_sidebar.draw()
    objact_message_box.draw()
    objact_mouse.draw()

end

function love.keypressed(key)
    if message_window == true then
        return
    end
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
    if message_window == true then
        return
    end
    if key == "lctrl" or key == "rctrl" then
        isctrl = false
    end 
    iskeyboard[key] = false
    room_play.keyreleased(key)
end
function love.wheelmoved(x, y)
    if message_window == true then
        return
    end
    room_play.wheelmoved(x,y)
    room_sidebar.wheelmoved(x,y)
end

function love.mousepressed( x, y, button, istouch, presses )
    x = mouse.x  --对缩放进行处理
    y = mouse.y
    mouse.down_state = true
    objact_message_box.mousepressed( x, y, button, istouch, presses )
    if message_window == true then
        return
    end
    room_play.mousepressed( x, y, button, istouch, presses )
    room_sidebar.mousepressed( x, y, button, istouch, presses )
    objact_mouse.mousepressed( x, y, button, istouch, presses )
    
end

function love.mousereleased( x, y, button, istouch, presses )
    x = mouse.x  --对缩放进行处理
    y = mouse.y
    mouse.down_state = false
    if message_window == true then
        return
    end
    objact_mouse.mousereleased( x, y, button, istouch, presses )
    room_sidebar.mousereleased( x, y, button, istouch, presses )
    room_play.mousereleased(x, y, button, istouch, presses)
end

function love.textinput(input)
    if message_window == true then
        return
    end
    room_play.textinput(input)
    input_box_textinput(input)
end
function love.quit()
    if message_window == true then
        return true
    end
    local quit = room_play.quit()
    return quit
end

function love.resize( w, h )
    window_w_scale = w / 1600
    window_h_scale = h / 800
end




-- 错误处理


local function error_printer(msg, layer)
	print((debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end

function love.errorhandler(msg)
    save(chart,"chart.txt")
	msg = tostring(msg)
    log("error:"..msg)
	error_printer(msg, 2)

	if not love.window or not love.graphics or not love.event then
		return
	end

	if not love.graphics.isCreated() or not love.window.isOpen() then
		local success, status = pcall(love.window.setMode, 800, 600)
		if not success or not status then
			return
		end
	end

	-- Reset state.
	if love.mouse then
		love.mouse.setVisible(true)
		love.mouse.setGrabbed(false)
		love.mouse.setRelativeMode(false)
		if love.mouse.isCursorSupported() then
			love.mouse.setCursor()
		end
	end
	if love.joystick then
		-- Stop all joystick vibrations.
		for i,v in ipairs(love.joystick.getJoysticks()) do
			v:setVibration()
		end
	end
	if love.audio then love.audio.stop() end

	love.graphics.reset()
	local font = love.graphics.setNewFont(14)

	love.graphics.setColor(1, 1, 1)

	local trace = debug.traceback()

	love.graphics.origin()

	local sanitizedmsg = {}
	for char in msg:gmatch(utf8.charpattern) do
		table.insert(sanitizedmsg, char)
	end
	sanitizedmsg = table.concat(sanitizedmsg)

	local err = {}

	table.insert(err, "Error\n")
	table.insert(err, sanitizedmsg)

	if #sanitizedmsg ~= #msg then
		table.insert(err, "Invalid UTF-8 string in error message.")
	end

	table.insert(err, "\n")

	for l in trace:gmatch("(.-)\n") do
		if not l:match("boot.lua") then
			l = l:gsub("stack traceback:", "Traceback\n")
			table.insert(err, l)
		end
	end

	local p = table.concat(err, "\n")

	p = p:gsub("\t", "")
	p = p:gsub("%[string \"(.-)\"%]", "%1")
	local function draw()
		if not love.graphics.isActive() then return end
		local pos = 70
		love.graphics.clear(89/255, 89/255, 89/255)
		love.graphics.printf(p, pos, pos, love.graphics.getWidth() - pos)
		love.graphics.present()
	end

	local fullErrorText = p
	local function copyToClipboard()
		if not love.system then return end
		love.system.setClipboardText(fullErrorText)
		p = p .. "\nCopied to clipboard!"
	end

	if love.system then
		p = p .. "\n\nPress Ctrl+C or tap to copy this error"
        p = p .. "\n\nDon‘t worry,your chart has been saved"
        p = p.. "\n\nPlease provide error feedback to the software developer as mush as possible"
        p = p.. "\n\nPress Ctrl+g go to github"
	end

	return function()
		love.event.pump()

		for e, a, b, c in love.event.poll() do
			if e == "quit" then
				return 1
			elseif e == "keypressed" and a == "escape" then
				return 1
			elseif e == "keypressed" and a == "c" and love.keyboard.isDown("lctrl", "rctrl") then
				copyToClipboard()
            elseif e == "keypressed" and a == "g" and love.keyboard.isDown("lctrl", "rctrl") then --前往github
                if love.system then
				    love.system.openURL("https://github.com/qwwshs/daikumi_editor/")
                end
			elseif e == "touchpressed" then
				local name = love.window.getTitle()
				if #name == 0 or name == "Untitled" then name = "Game" end
				local buttons = {"OK", "Cancel"}
				if love.system then
					buttons[3] = "Copy to clipboard"
				end
				local pressed = love.window.showMessageBox("Quit "..name.."?", "", buttons)
				if pressed == 1 then
					return 1
				elseif pressed == 3 then
					copyToClipboard()
				end
			end
		end

		draw()

		if love.timer then
			love.timer.sleep(0.1)
		end
	end

end