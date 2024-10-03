local x = 0
local y = 0
local r = 0
local w = 0
local h = 0
objact_event = {
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
    end,
    draw = function()

    end,
    keyboard = function(key)
        if not(mouse.x >= 1000 and mouse.x <= 1175 and mouse.y >= 100) then --不在轨道范围内
            return
        end
        if key == "e" and mouse.x >= 1000 and mouse.x <= 1100 then -- x
            event_place("x",mouse.y)
            objact_message_box.message("event x place")
        elseif key == "e" and mouse.x >= 1100 and mouse.x <= 1175 then -- w
            event_place("w",mouse.y)
            objact_message_box.message("event w place")

        elseif key == "d" and mouse.x >= 1000 and mouse.x <= 1100 then -- x delete
                event_delete("x",mouse.y)
                objact_message_box.message("event x place")
        elseif key == "d" and mouse.x >= 1100 and mouse.x <= 1175 then -- w delete
                event_delete("w",mouse.y)
                objact_message_box.message("event w place")
        end
        if key == "c" and isalt == true then --裁切
            if string.sub(displayed_content,1,5) == "event" and
            chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))] then
                local temp_event = {} -- 临时event表
                temp_event = copyTable(chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))])
                local temp_event_int = {}--得到每个位置的event数值
                for i = 0, --算每个长条的form to值
                math.ceil((thebeat(chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].beat2) -  
                thebeat(chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].beat)) * (denom.denom * 2)) + 1
                do
                    local isnow_beat = (i/(denom.denom * 2)) + 
                    thebeat(chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].beat)
                    local temp_now = {event_get(chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].track,
                    isnow_beat)}
                    temp_event_int[i] = temp_now[1]
                    if temp_event.type == "w" then
                        temp_event_int[i] = temp_now[2]
                    end
                end

                for i = 0, 
                math.floor((thebeat(chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].beat2) -  
                thebeat(chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].beat)) * (denom.denom * 2))
                do
                    local isnow_beat =  (i /(denom.denom * 2)) +
                    thebeat(chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].beat)
                    local event_min_denom = 0 --假设0最近
                    for k = 0, denom.denom*2 do --取分度 哪个近取哪个
                        if math.abs(isnow_beat - (math.floor(isnow_beat) + k / (denom.denom*2))) < 
                        math.abs(isnow_beat - (math.floor(isnow_beat) + event_min_denom / (denom.denom*2))) then
                            event_min_denom = k
                        end
                    end
                    local local_event = {
                        type = temp_event.type,
                        track = temp_event.track,
                        beat = {math.floor(isnow_beat),event_min_denom ,denom.denom*2},
                        beat2 = {math.floor(isnow_beat),event_min_denom + 1 ,denom.denom*2},
                        form = temp_event_int[i],
                        to = temp_event_int[i + 1],
                        trans = {[1] = 0,[2] = 0,[3] = 1,[4] = 1}
                    }
                    if isnow_beat > thebeat(chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].beat2) then
                        local_event.beat2 = temp_event.beat2
                    end
                    chart.event[#chart.event + 1] = local_event --添加
                    objact_redo.write_revoke("event place",local_event)
                    copy_add(local_event,'event')
                end
                objact_redo.write_revoke("event delete",chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))])
                    table.remove(chart.event,tonumber(string.sub(displayed_content,6,#displayed_content))) --删除    
                event_sort()
                displayed_content = "multiple_events_edit" --界面清除
            end
        end
    end,
    mousepressed = function(x,y)
        if not(mouse.x >= 1000 and mouse.x <= 1175 and mouse.y >= 100) then --不在轨道范围内
            return
        end
        if  mouse.x >= 1000 and mouse.x <= 1100 then -- x
            event_click("x",mouse.y)
            objact_message_box.message("event x click")
        elseif  mouse.x >= 1100 and mouse.x <= 1175 then -- w
            event_click("w",mouse.y)
            objact_message_box.message("event w click")
        end
    end
}