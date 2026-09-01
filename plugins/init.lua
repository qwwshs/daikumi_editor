--[[
    模块名: plugins/init
    描述: 内置插件加载器，统一加载和注册所有内置插件
    作者: qwwshs
    依赖: PluginManager

    在 isRequire.lua 或 main.lua 中调用 require("plugins.init") 即可加载所有插件。
    插件加载后会自动注册到 PluginManager。
    插件目录位于项目根目录的 plugins/ 文件夹，打包后仍可访问。
]]

--- 加载所有内置插件并返回插件对象映射
-- @treturn table 插件对象映射 { [name] = pluginObject }
local function loadPlugins()
    local plugins = {}

    -- FFT 频谱分析器插件（menu object）
    success, result = pcall(require, "plugins.fft")
    if success then
        plugins.fft = result
    else
        log("[Plugins] Failed to load fft: " .. tostring(result))
    end

    -- Event 直观编辑插件（play object）
    success, result = pcall(require, "plugins.directEventEditing")
    if success then
        plugins.directEventEditing = result
    else
        log("[Plugins] Failed to load directEventEditing: " .. tostring(result))
    end

    -- 复制/粘贴/框选插件（play object）
    success, result = pcall(require, "plugins.ctrl")
    if success then
        plugins.ctrl = result
    else
        log("[Plugins] Failed to load ctrl: " .. tostring(result))
    end

    -- Alt 快捷操作插件（play object）
    success, result = pcall(require, "plugins.alt")
    if success then
        plugins.alt = result
    else
        log("[Plugins] Failed to load alt: " .. tostring(result))
    end

    -- 撤销/重做插件（play object）
    success, result = pcall(require, "plugins.redo")
    if success then
        plugins.redo = result
    else
        log("[Plugins] Failed to load redo: " .. tostring(result))
    end

    log("[Plugins] Loaded plugins")
    return plugins
end

return loadPlugins()
