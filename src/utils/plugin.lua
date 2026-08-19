--[[
    模块名: PluginManager
    描述: 插件管理器，负责插件的注册、生命周期管理和事件钩子分发
    作者: qwwshs
    架构: 混合模式 - 数据事件用钩子驱动，UI功能用接口实现

    使用方式:
        local PluginManager = require("src.utils.plugin")
        PluginManager:register(myPlugin)
        PluginManager:emit("onNoteAdd", note)
]]

local PluginManager = {}
PluginManager.__index = PluginManager

--- 已注册的插件表 { [name] = plugin }
PluginManager.plugins = {}

--- 事件钩子表 { [eventName] = { {pluginName, callback}, ... } }
PluginManager.hooks = {}

--- 插件上下文，提供给插件的服务访问接口
PluginManager.ctx = nil

--- 初始化插件管理器
-- @tparam table ctx 插件上下文（包含 chartService, coordinateService, audioService 等服务）
function PluginManager:init(ctx)
    self.ctx = ctx or {}
    self.plugins = {}
    self.hooks = {}
end

--- 注册一个插件
-- @tparam table plugin 插件描述表，包含以下字段:
--   - name (string): 插件名称（唯一标识）
--   - version (string): 插件版本号
--   - description (string): 插件描述
--   - init (function, 可选): 初始化回调，参数为 ctx
--   - update (function, 可选): 每帧更新，参数为 ctx, dt
--   - draw (function, 可选): 绘制回调，参数为 ctx
--   - keypressed (function, 可选): 键盘按下，参数为 ctx, key, scancode, isrepeat
--   - keyreleased (function, 可选): 键盘释放，参数为 ctx, key, scancode
--   - mousepressed (function, 可选): 鼠标按下，参数为 ctx, x, y, button, istouch, presses
--   - mousereleased (function, 可选): 鼠标释放，参数为 ctx, x, y, button, istouch, presses
--   - wheelmoved (function, 可选): 鼠标滚轮，参数为 ctx, x, y
--   - settings (function, 可选): 设置面板，参数为 ctx
--   - destroy (function, 可选): 卸载回调，参数为 ctx
--   - hooks (table, 可选): 事件钩子表 { [eventName] = callback }
-- @treturn boolean 是否注册成功
function PluginManager:register(plugin)
    if not plugin or type(plugin) ~= "table" then
        log("[PluginManager] register: plugin must be a table")
        return false
    end
    if not plugin.name or type(plugin.name) ~= "string" then
        log("[PluginManager] register: plugin must have a name")
        return false
    end
    if self.plugins[plugin.name] then
        log("[PluginManager] register: plugin '" .. plugin.name .. "' already registered")
        return false
    end

    -- 注册插件
    self.plugins[plugin.name] = plugin

    -- 注册钩子
    if plugin.hooks then
        for eventName, callback in pairs(plugin.hooks) do
            self:on(eventName, callback, plugin.name)
        end
    end

    -- 调用 init
    if type(plugin.init) == "function" then
        local success, err = pcall(plugin.init, self.ctx)
        if not success then
            log("[PluginManager] init error in '" .. plugin.name .. "': " .. tostring(err))
        end
    end

    log("[PluginManager] plugin '" .. plugin.name .. "' v" .. (plugin.version or "0") .. " registered")
    return true
end

--- 注销一个插件
-- @tparam string pluginName 插件名称
-- @treturn boolean 是否注销成功
function PluginManager:unregister(pluginName)
    local plugin = self.plugins[pluginName]
    if not plugin then
        log("[PluginManager] unregister: plugin '" .. pluginName .. "' not found")
        return false
    end

    -- 调用 destroy
    if type(plugin.destroy) == "function" then
        local success, err = pcall(plugin.destroy, self.ctx)
        if not success then
            log("[PluginManager] destroy error in '" .. pluginName .. "': " .. tostring(err))
        end
    end

    -- 移除钩子
    for eventName, listeners in pairs(self.hooks) do
        for i = #listeners, 1, -1 do
            if listeners[i].pluginName == pluginName then
                table.remove(listeners, i)
            end
        end
    end

    self.plugins[pluginName] = nil
    log("[PluginManager] plugin '" .. pluginName .. "' unregistered")
    return true
end

--- 注册事件钩子
-- @tparam string eventName 事件名称
-- @tparam function callback 回调函数
-- @tparam string pluginName 所属插件名称
function PluginManager:on(eventName, callback, pluginName)
    if type(callback) ~= "function" then return end
    if not self.hooks[eventName] then
        self.hooks[eventName] = {}
    end
    table.insert(self.hooks[eventName], {
        pluginName = pluginName or "anonymous",
        callback = callback,
    })
end

--- 触发事件钩子，所有注册了该事件的回调会被依次调用
-- @tparam string eventName 事件名称
-- @param ... 传递给回调的参数
function PluginManager:emit(eventName, ...)
    local listeners = self.hooks[eventName]
    if not listeners then return end
    for _, listener in ipairs(listeners) do
        local success, err = pcall(listener.callback, self.ctx, ...)
        if not success then
            log("[PluginManager] hook '" .. eventName .. "' error in '" .. listener.pluginName .. "': " .. tostring(err))
        end
    end
end

--- 对所有已注册插件调用指定方法
-- @tparam string methodName 方法名（如 "update", "draw", "keypressed" 等）
-- @param ... 传递给方法的参数
function PluginManager:callAll(methodName, ...)
    for name, plugin in pairs(self.plugins) do
        if type(plugin[methodName]) == "function" then
            local success, err = pcall(plugin[methodName], self.ctx, ...)
            if not success then
                log("[PluginManager] " .. methodName .. " error in '" .. name .. "': " .. tostring(err))
            end
        end
    end
end

--- 获取已注册插件列表
-- @treturn table 插件名称列表
function PluginManager:getPluginNames()
    local names = {}
    for name, _ in pairs(self.plugins) do
        names[#names + 1] = name
    end
    return names
end

--- 获取插件信息
-- @tparam string pluginName 插件名称
-- @treturn table|nil 插件描述表
function PluginManager:getPlugin(pluginName)
    return self.plugins[pluginName]
end

return PluginManager
