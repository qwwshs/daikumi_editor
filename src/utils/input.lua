--[[
    模块名: input
    描述: 快捷键管理模块，处理快捷键的注册和检测
    作者: qwwshs
    依赖: nativefs, dkjson, meta_key, iskeyboard, table, PATH
]]

local input = {}
setmetatable(input, input)

--- 注册新的快捷键
-- @tparam string name 快捷键名称
-- @tparam string|table key 按键名称或按键数组
function input:new(name, key)
    name = name or 'noname'
    local keys = {}
    if type(key) == 'string' then
        keys = { key }
    elseif type(key) == 'table' then
        keys = key
    end
    self[name] = { name = name, keys = keys }
end

--- 检测快捷键是否被按下（作为 __call 元方法，可直接调用 input('name')）
-- @tparam string name 快捷键名称
-- @treturn boolean 是否按下
function input:__call(name)
    if not self[name] then
        log('input')
        log(name)
        log('not found')
        return false
    end
    for _, key in ipairs(self[name].keys) do
        if not iskeyboard[key] then
            return false
        end
    end
    --防止同时触发多个快捷键
    for _, key in pairs(iskeyboard) do
        if not table.find(self[name].keys, key) and iskeyboard[key] then
            return false
        end
    end
    return true
end


--快捷键相关
nativefs.mount(PATH.base)

local key_file = nativefs.read(PATH.usersPath.key .. 'key.json') or ''
local key
pcall(function() key = dkjson.decode(key_file) or meta_key.__index end)
if type(key) ~= 'table' then
    key = meta_key.__index
end
table.fill(key, meta_key.__index)
save(dkjson.encode(key, { indent = true }), PATH.usersPath.key .. 'key.json')
for i, v in pairs(key) do
    input:new(i, v)
end
nativefs.unmount(PATH.base)


return input
