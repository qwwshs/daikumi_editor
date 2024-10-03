function RGBA_hexToRGBA(hex)    -- rgb转换器 
    hex = hex:gsub("#","") 
    local r = tonumber(hex:sub(3, 4), 16) / 255 or 1
    local g = tonumber(hex:sub(5, 6), 16) / 255 or 1
    local b = tonumber(hex:sub(7, 8), 16) / 255 or 1
    local a = tonumber(hex:sub(1, 2), 16) / 255 or 1
    return r, g, b, a 
end
function RGBA_hexToRGB(hex)    -- rgb转换器 
    hex = hex:gsub("#","") 
    local r = tonumber(hex:sub(1, 2), 16) / 255 or 1
    local g = tonumber(hex:sub(3, 4), 16) / 255 or 1
    local b = tonumber(hex:sub(5, 6), 16) / 255 or 1
    return r, g, b
end

