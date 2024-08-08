local local_hold = {} -- 局部hold表
local hold_type = 0 --长条状态 0没放 1头 2尾

function hold_clean_up() --长条清除
    local_hold = {}
    hold_type = 0
end
-- note函数

function note_delete(pos)
    --删除检测区间
    local pos_interval = 20 * denom.scale
    --根据距离反推出beat
    local note_beat_up = y_to_beat(pos - pos_interval)
    local note_beat_down = y_to_beat(pos + pos_interval)
    for i = 1,#chart.note do
        if chart.note[i].track == track.track and 
        ((thebeat(chart.note[i].beat) >= note_beat_down and thebeat(chart.note[i].beat) <= note_beat_up)
        or (chart.note[i].beat2 and -- 长条
        (thebeat(chart.note[i].beat) <= note_beat_down and thebeat(chart.note[i].beat2) >= note_beat_down)
        or (thebeat(chart.note[i].beat) <= note_beat_up and thebeat(chart.note[i].beat2) >= note_beat_up))) then
            table.remove(chart.note, i)
            return
        end
    end
end

function note_place(note_type,pos)
    --根据距离反推出beat
    local note_beat = y_to_beat(pos)
    local note_min_denom = 1 --假设1最近
    for i = 1, denom.denom do --取分度 哪个近取哪个
        if math.abs(note_beat - (math.floor(note_beat) + i / denom.denom)) < math.abs(note_beat - (math.floor(note_beat) + note_min_denom / denom.denom)) then
            note_min_denom = i
        end
    end
    if note_type ~= "hold" then --不是长条
        --查表 如果重叠不给放
        local note_correct_beat = {math.floor(note_beat),note_min_denom,denom.denom}
        for i = 1,#chart.note do --重叠
            if chart.note[i].track == track.track and thebeat(chart.note[i].beat) == thebeat(note_correct_beat) then
                objact_message_box.message("overlap")
                return false
            end
        end
        chart.note[#chart.note + 1] = {
            type = note_type,
            track = track.track,
            beat = {math.floor(note_beat),note_min_denom,denom.denom}
        }
    else
        if hold_type == 0 then --放置头
            local_hold = {
                type = note_type,
                track = track.track,
                beat = {math.floor(note_beat),note_min_denom,denom.denom}
            }
            hold_type = 1
        elseif hold_type == 1 then
            local_hold.beat2 = {math.floor(note_beat),note_min_denom,denom.denom} 
            if thebeat(local_hold.beat2) <= thebeat(local_hold.beat) then --尾巴比头早或重叠
                objact_message_box.message("illegal operation")
                hold_clean_up()
                return false
            else -- 合法操作
                chart.note[#chart.note + 1] = local_hold
                hold_type = 2

            end
        end
    end
    if note_type ~= "hold" or hold_type == 2 then --长条尾放置完成
        note_sort()
    end
end
function note_sort()
        --对note进行排序
        local thetable = {} --临时note表
    
        while #chart.note > 0 do
            local min = 1 --设1 note大小最小
            for i = 1 ,#chart.note do
                if thebeat(chart.note[i].beat) < thebeat(chart.note[min].beat) then
                    min = i
                end
            end
            thetable[#thetable + 1] = chart.note[min]
            table.remove(chart.note,min)
        end
        chart.note = thetable
        hold_clean_up()
end
function get_hold_table()
    return local_hold
end