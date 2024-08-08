
function tableToString(tbl, indent) -- 表转字符串
    indent = indent or 0
    local str = "{\n"
    for k, v in pairs(tbl) do
        local key = type(k) == "number" and "" or k
        local k1 = type(k) == "number" and "" or "="
        local indentStr = ""
        for i = 1, indent do
            indentStr = indentStr .. "  "
        end
        if type(v) == "table" then
            str = str .. indentStr .. key ..k1 .. tableToString(v, indent + 1) .. ",\n"
        elseif type(v) == "string" then
            str = str .. indentStr .. key .. k1.."'" .. v .. "',\n"
        else
            str = str .. indentStr .. key .. k1 .. tostring(v) .. ",\n"
        end
    end
    local finalIndentStr = ""
    for i = 1, indent - 1 do
        finalIndentStr = finalIndentStr .. "  "
    end
    str = str .. finalIndentStr .. "}"
    return str
end
