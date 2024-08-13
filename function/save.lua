
function save(tab,name) --谱与设置保存 
    local file = io.open(name, "w")
    if file then
        file:write(tableToString(tab))
        file:close()
    end
end