
require("function/save")
require("function/log")
require("function/table")
require("function/string")
require("function/note")
require("function/event")
require("function/beat_and_time")
require("love.timer")
chart = {}
path = ""
local the_save_start = false --减少休眠时间
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
        setmetatable(chart,meta_chart) --防谱报废
        fillMissingElements(chart,meta_chart.__index)

--线程用来保存的

function love.threaderror(thread, message)  
    print("Thread error: " .. message)  
end  

-- 获取主线程传递的频道  
local channel = ...  

-- 从主线程接收消息  
while true do  
    local msg = love.thread.getChannel( 'save' ):pop()  --得到表
    
    if msg and msg[1] == 'start' then  
        path = msg[2]
        log("save:"..msg[1])
        the_save_start = true
    elseif msg and msg[1] == 'end' then
        the_save_start = false
        fillMissingElements(chart,meta_chart.__index)
        if type(path) == "string" and #path > 0 then
            local s = love.filesystem.write(path , tableToString(chart) )
            if s then
                log("save:"..tostring(s))
            end
            love.thread.getChannel( 'save completed' ):push(s)
        end
        log("save:"..msg[1])
        
    elseif msg and msg[1] and msg[2] then
        loadstring("chart."..msg[1].." = "..msg[2])() --执行
    end 
    if not the_save_start then
        love.timer.sleep(1)
    else
        love.timer.sleep(0.001)
    end
end