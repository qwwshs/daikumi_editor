function to_play_track(x,w)
    x = x or 0
    w = w or 0
    return (x-w/2) *8.5 + 25,w*8.5
end
function to_play_track_original_x(x)
    x = x or 0
    return x*8.5 + 25
end
function to_play_track_original_w(w)
    w = w or 0
    return w*8.5
end
function track_get_max_track() --得到最大的轨道
    local max_track = 0
    for i = 1, #chart.event do
        if chart.event[i].track > max_track then
            max_track = chart.event[i].track
        end
    end
    return max_track
end
function track_get_near_fence() --得到附近的栅栏
    local min = 1
    for i = 1,track.fence do
        if math.abs((900 / track.fence * min)  - mouse.x)> math.abs((900 / track.fence * i)  - mouse.x) then
            min = i
        end
    end
    return min
end