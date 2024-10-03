--bpmlist表相关的操作 （选择 删除 增加）
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local ui_add = love.graphics.newImage("asset/ui_add.png")
local ui_sub = love.graphics.newImage("asset/ui_sub.png")
local choose_bpm = 0 -- 现在所选择的bpm
objact_bpm_list = {
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
    end,
    draw = function()
        local _width, _height = ui_add:getDimensions( ) -- 得到宽高
        local _scale_w = 1 / _width * w
        local _scale_h = 1 / _height * h
        love.graphics.setColor(1,1,1,1)

        love.graphics.draw(ui_add,x,y,r,_scale_w,_scale_h)
        love.graphics.draw(ui_sub,x+w+20,y,r,_scale_w,_scale_h)
    end,
    keyboard = function(key)

    end,
    mousepressed = function( x1, y1, button, istouch, presses )
        --bpm选择器
        if input_box_query_type_in() and string.sub(input_box_query_type_in(),1,3) == "bpm" and string.sub(input_box_query_type_in(),-1,-1) ~= "1" then --选择
            choose_bpm = tonumber(string.sub(input_box_query_type_in(),-1,-1))
        elseif not (x1 >= x + w + 20 and x1 <= x + w + w + 20 and y1 <= y + h  and y1 >= y) then -- 不在删除的位置
            choose_bpm = 0
        end

        if x1 >= x  and x1 <= x + w and y1 <= y + h and y1 >= y then -- 在add的范围内
            objact_message_box.message("add bpm")

            --反推位置
            local pos_beat = beat.nowbeat
            local pos_min_denom = 1 --假设1最近
            for i = 1, denom.denom do --取分度 哪个近取哪个
                if math.abs(pos_beat - (math.floor(pos_beat) + i / denom.denom)) < math.abs(pos_beat - (math.floor(pos_beat) + pos_min_denom / denom.denom)) then
                    pos_min_denom = i
                end

            end
            --往当前beat位置添加一个bpm
            chart.bpm_list[#chart.bpm_list + 1] = {beat = {math.floor(pos_beat),pos_min_denom,denom.denom},bpm = 120}

            --排序
            objact_chart_info.bpm_list_load()

        elseif x1 >= x + w + 20 and x1 <= x + w + w + 20 and y1 <= y + h  and y1 >= y then -- 在sub的范围内
            objact_message_box.message("delete bpm")
            --删除当前所选择的bpm
            if chart.bpm_list[choose_bpm] and choose_bpm ~= 1 then --不是第一个bpm 和是bpm就删除
                table.remove(chart.bpm_list,choose_bpm)
                input_box_delete_choose() --全部不选择

                input_box_delete("bpm"..choose_bpm) --删除所选择的bpm
                input_box_delete("bpm_beat1"..choose_bpm)
                input_box_delete("bpm_beat2"..choose_bpm)
                input_box_delete("bpm_beat3"..choose_bpm)

                objact_chart_info.bpm_list_load()
            end
        end
    end,
    wheelmoved = function(x,y)
        for i = 1, #chart.bpm_list do
            input_box_wheelmoved(x,y,"bpm"..i)
            input_box_wheelmoved(x,y,"bpm_beat1"..i)
            input_box_wheelmoved(x,y,"bpm_beat2"..i)
            input_box_wheelmoved(x,y,"bpm_beat3"..i)
        end
    end
}