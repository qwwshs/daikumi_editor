
require("function/save")
require("function/log")
require("function/table")
require("function/string")
require("function/note")
require("function/event")
require("function/beat_and_time")

chart = {}
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
    if msg and type(msg[1]) == 'table' then  
        chart = msg[1]
        fillMissingElements(chart,meta_chart.__index)
        local path = msg[2] 
        note_sort()
        event_sort()
        if path then
            local s = love.filesystem.write(path , tableToString(chart) )
            if s then
                log("save:"..tostring(s))
            end
            love.thread.getChannel( 'save completed' ):push(s)
        end
    end  
    
end