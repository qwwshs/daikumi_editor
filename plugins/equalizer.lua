--[[
    插件名: equalizer
    描述: 音频均衡器插件，提供 10 段参量均衡器控制面板
    作者: qwwshs
    版本: 1.0.0
    依赖: Nui, i18n, love.audio

    提供低频/低中/高中/高频的增益/频率/带宽控制。
    作为 sidebar 的一个 group 注册。
]]

local love_audio = love.audio

--- 均衡器参数定义
-- 每个参数包含 name（参数名）、default（默认值）、min/max（范围）、step（步长）、scope（显示范围）
local eq_params = {
    { name = "Low Gain",      default = 0, min = -12, max = 12, step = 0.1, scope = 12 },
    { name = "Low Frequency", default = 200, min = 50, max = 500, step = 1, scope = 500 },
    { name = "Low Bandwidth", default = 1, min = 0.1, max = 5, step = 0.1, scope = 5 },
    { name = "Low-Mid Gain",      default = 0, min = -12, max = 12, step = 0.1, scope = 12 },
    { name = "Low-Mid Frequency", default = 800, min = 200, max = 2000, step = 1, scope = 2000 },
    { name = "Low-Mid Bandwidth", default = 1, min = 0.1, max = 5, step = 0.1, scope = 5 },
    { name = "High-Mid Gain",      default = 0, min = -12, max = 12, step = 0.1, scope = 12 },
    { name = "High-Mid Frequency", default = 3000, min = 1000, max = 8000, step = 1, scope = 8000 },
    { name = "High-Mid Bandwidth", default = 1, min = 0.1, max = 5, step = 0.1, scope = 5 },
    { name = "High Gain",      default = 0, min = -12, max = 12, step = 0.1, scope = 12 },
    { name = "High Frequency", default = 8000, min = 4000, max = 16000, step = 1, scope = 16000 },
    { name = "High Bandwidth", default = 1, min = 0.1, max = 5, step = 0.1, scope = 5 },
}

--- 均衡器状态
local eq_values = {}
for i, param in ipairs(eq_params) do
    eq_values[param.name] = param.default
end
local eq_enabled = false

--- 创建均衡器 group（sidebar 子面板）
local Gequalizer = group:new('equalizer')

--- 渲染均衡器 UI 面板
function Gequalizer:Nui()
    -- 开关控制
    if Nui:checkbox(i18n:get("Enable Equalizer"), eq_enabled) then
        eq_enabled = not eq_enabled
        if eq_enabled then
            love_audio.setEffect("equalizer", { type = "eq" })
        else
            love_audio.setEffect("equalizer", false)
        end
    end

    if not eq_enabled then return end

    -- 参数滑块
    for i, param in ipairs(eq_params) do
        local value = eq_values[param.name]
        local label = i18n:get(param.name) .. ": " .. string.format("%.1f", value)

        if Nui:slider(param.scope, value, param.min, param.max, param.step) then
            eq_values[param.name] = Nui:sliderValue()
            love_audio.setEffect("equalizer", {
                type = "eq",
                lowgain = eq_values["Low Gain"],
                lowfrequency = eq_values["Low Frequency"],
                lowbandwidth = eq_values["Low Bandwidth"],
                lowmidgain = eq_values["Low-Mid Gain"],
                lowmidfrequency = eq_values["Low-Mid Frequency"],
                lowmidbandwidth = eq_values["Low-Mid Bandwidth"],
                highmidgain = eq_values["High-Mid Gain"],
                highmidfrequency = eq_values["High-Mid Frequency"],
                highmidbandwidth = eq_values["High-Mid Bandwidth"],
                highgain = eq_values["High Gain"],
                highfrequency = eq_values["High Frequency"],
                highbandwidth = eq_values["High Bandwidth"],
            })
        end
        Nui:label(label)
    end
end

-- 注册为插件
if PluginManager then
    PluginManager:register({
        name = "equalizer",
        version = "1.0.0",
        description = "音频均衡器",
        init = function(ctx)
            -- 检查音频效果支持
            local supported = love_audio.isEffectsSupported()
            log("Equalizer plugin: effects supported = " .. tostring(supported))
        end,
    })
end

return Gequalizer
