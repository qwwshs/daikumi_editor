
function save(tab,name) --谱与设置保存 
    if name == "chart.txt" then --特殊保存
        pcall(function() love.filesystem.write( chart_info.chart_name[select_chart_pos].path , tableToString(tab) ) end)
        return
    end
    local file = io.open(name, "w")
    if file then
        if type(tab) == "table" then
            file:write(tableToString(tab))
        elseif type(tab) == "string" then
            file:write(tab)
        end
        file:close()
    end
end