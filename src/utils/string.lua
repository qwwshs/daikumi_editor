
function tableToString(tbl, indent,isrecursion) -- 表转字符串
    return serpent.block(tbl)
end

-- Nuklear's text widgets expect well-formed UTF-8.  Chart metadata can come
-- from externally authored JSON (or a clipboard), so never pass arbitrary
-- byte strings to the native widget.  Invalid bytes and embedded NULs are
-- replaced with an ASCII placeholder; valid characters are kept unchanged.
function sanitizeUtf8(value, maxBytes)
    if value == nil then
        return ''
    end
    if type(value) ~= 'string' then
        value = tostring(value)
    end

    maxBytes = math.max(0, math.floor(tonumber(maxBytes) or (1024 * 1024 - 1)))
    local result = {}
    local used = 0
    local index = 1
    local length = #value

    while index <= length do
        local first = value:byte(index)
        local charLength = 1
        local valid = first ~= 0

        if first >= 0x80 then
            if first >= 0xC2 and first <= 0xDF then
                charLength = 2
            elseif first >= 0xE0 and first <= 0xEF then
                charLength = 3
            elseif first >= 0xF0 and first <= 0xF4 then
                charLength = 4
            else
                valid = false
            end

            if valid and index + charLength - 1 <= length then
                local second = value:byte(index + 1)
                valid = second >= 0x80 and second <= 0xBF

                if valid and charLength >= 3 then
                    local third = value:byte(index + 2)
                    valid = third >= 0x80 and third <= 0xBF
                    valid = valid and not (first == 0xE0 and second < 0xA0)
                    valid = valid and not (first == 0xED and second >= 0xA0)
                end

                if valid and charLength == 4 then
                    local fourth = value:byte(index + 3)
                    valid = fourth >= 0x80 and fourth <= 0xBF
                    valid = valid and not (first == 0xF0 and second < 0x90)
                    valid = valid and not (first == 0xF4 and second > 0x8F)
                end
            elseif charLength > 1 then
                valid = false
            end
        end

        local text = valid and value:sub(index, index + charLength - 1) or '?'
        if used + #text > maxBytes then
            break
        end

        result[#result + 1] = text
        used = used + #text
        index = index + (valid and charLength or 1)
    end

    return table.concat(result)
end

function isLastCharChineseOrHalfwidth(str)  
    if str == "" then return false end  
    -- 获取字符串的长度  
    local len = #str  

    -- UTF-8字符长度可能超过1，因此需要找到最后一个字符的起始位置  
    local i = len  
    while i > 0 do  
        local byte = str:byte(i)  
        -- 检查字符的起始字节  
        if byte >= 0 and byte <= 127 then  
            -- ASCII字符，直接返回false  
            return false  
        elseif byte >= 192 and byte <= 223 then  
            -- 2字节字符  
            break  
        elseif byte >= 224 and byte <= 239 then  
            -- 3字节字符  
            break  
        elseif byte >= 240 and byte <= 247 then  
            -- 4字节字符  
            break  
        end  
        i = i - 1  
    end  

    -- 取出最后一个字符  
    local lastChar = str:sub(i)  

    -- 判断最后一个字符是否在中文汉字范围内  
    local codepoint = lastChar:byte(1)
    
    if (codepoint >= 0xe4 and codepoint <= 0xe9) or (codepoint >= 0x30 and codepoint <= 0x39) then  -- 大致范围  
        -- 精确检查  
        local utf8 = require("utf8") -- 加载utf8库  
        
        local charCode = 0x007e  
        pcall(function() charCode = utf8.codepoint(lastChar) or 0x007e end)  
        
        -- 检查是否为中文字符或全角符号  
        return (charCode >= 0x4e00 and charCode <= 0x9fa5)   -- 中文汉字范围  
            or (0x0021 <= charCode and charCode <= 0x007e) -- 半角符号范围  
    end  

    return false  
end  
