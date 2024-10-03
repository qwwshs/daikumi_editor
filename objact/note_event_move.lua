--用于移动note和event的
objact_note_event_move = {
    keyboard = function(key)
        if not isalt then
            return
        end
        if key == 'z' then --拖头
            if string.sub(displayed_content,1,4) == "note" then
                chart.note[tonumber(string.sub(displayed_content,5,#displayed_content))].beat = to_nearby_Beat(y_to_beat(mouse.y))
                note_sort()
            end
            if string.sub(displayed_content,1,5) == "event" then
                chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].beat = to_nearby_Beat(y_to_beat(mouse.y))
                event_sort()
            end
        elseif key == 'x' then --拖尾
            if string.sub(displayed_content,1,4) == "note" and chart.note[tonumber(string.sub(displayed_content,5,#displayed_content))].beat2 then
                chart.note[tonumber(string.sub(displayed_content,5,#displayed_content))].beat2 = to_nearby_Beat(y_to_beat(mouse.y))
                note_sort()
            end
            if string.sub(displayed_content,1,5) == "event" then
                chart.event[tonumber(string.sub(displayed_content,6,#displayed_content))].beat2 = to_nearby_Beat(y_to_beat(mouse.y))
                event_sort()
            end
        end
    end
}