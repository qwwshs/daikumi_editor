--线程用来计算的
function love.threaderror(thread, message)  
    print("Thread error: " .. message)  
end  
require("function/bezier") --贝塞尔曲线
require("function/log")
require("function/string")
require("function/table")
require("love.timer")
-- 获取主线程传递的频道  
local channel = ...  

-- 从主线程接收消息  
while true do  
    local msg = love.thread.getChannel( 'animation' ):pop()  --得到表
    pcall(function() msg = loadstring("return "..msg)() end)
    if msg and type(msg[1]) == 'table' then  
        
        local animation = msg[1]
        local animation_renew = msg[2]
        local now_time = msg[3]

        if not animation then
            animation = {}
        end
        if not animation_renew then
            animation_renew = {}
        end
        if not now_time then
            now_time = 0
        end
        -- 处理消息并发送回应  
        for i,v in pairs(animation_renew) do
            if now_time >= v.startime and now_time <= v.endtime then
                animation[i] = bezier(v.startime,v.endtime,v.from,v.to,v.trans,now_time)

            elseif now_time > v.endtime then
                animation[i] = v.to
            end

        end
        love.thread.getChannel( 'animation_to_main' ):push(animation)
    end  
    love.timer.sleep(0.001)  
end