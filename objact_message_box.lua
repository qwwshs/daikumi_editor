local message = {} -- 消息列表
--消息框
objact_message_box = {
    draw = function()
        for i = 1,#message do
            local alpha = bezier(message[i][2],message[i][2]+3,0.75,0,{0.12,0.54,0.283,0.83},elapsed_time) --透明度变换
            local x = bezier(message[i][2],message[i][2]+0.5,-100,0,{0.12,0.54,0.283,0.83},elapsed_time)  --x坐标 出现
            if elapsed_time - message[i][2] > 2.5 then
                x = bezier(message[i][2]+1.5,message[i][2]+3,00,-100,{0.12,0.54,0.283,0.83},elapsed_time) --x坐标 返回
            end

            love.graphics.setColor(0.5,0.5,0.5,alpha)  -- 背景板
            love.graphics.rectangle("fill",x,300 +  (#message - i) * 35,#message[i][1]*10 + 20,25)
            love.graphics.setColor(1,1,1,alpha)  -- 背景板
            love.graphics.rectangle("line",x,295 +  (#message - i) * 35,#message[i][1]*10 + 10 + 20,35)

            love.graphics.setColor(1,1,1,alpha)  --文字
            love.graphics.print(message[i][1],x + 20,300 + (#message - i) * 35)
        end
    end,
    message = function(mess) -- 增加信息
        message[#message + 1] = {tostring(mess),elapsed_time}

        for i = 1,#message do
            if message[i] and message[i][2] - elapsed_time <= -3 then --时间超过三秒
                table.remove(message,i)
            end
        end
        
    end
}