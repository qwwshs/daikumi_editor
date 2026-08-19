--[[
    模块名: AudioService
    描述: 音频服务层，封装音乐播放状态和音频资源的访问
    作者: qwwshs
    依赖: music (全局), music_data (全局), music_play (全局), time (全局), beat (全局)

    提供统一的音频访问接口，降低其他模块对全局音频变量的直接耦合。
    插件通过 ctx.audio 访问此服务。
]]

local AudioService = {}

--- 获取当前音频源对象
-- @return love.AudioSource|nil 音频源
function AudioService:getSource()
    return music
end

--- 设置音频源
-- @param source love.AudioSource 音频源
function AudioService:setSource(source)
    music = source
end

--- 获取音频波形数据
-- @return SoundData|nil 波形数据
function AudioService:getSoundData()
    return music_data
end

--- 设置音频波形数据
-- @param data SoundData 波形数据
function AudioService:setSoundData(data)
    music_data = data
end

--- 获取音乐播放状态
-- @treturn boolean 是否正在播放
function AudioService:isPlaying()
    return music_play
end

--- 设置音乐播放状态
-- @tparam boolean playing 是否播放
function AudioService:setPlaying(playing)
    music_play = playing
end

--- 获取当前播放时间（秒）
-- @treturn number 当前时间
function AudioService:getCurrentTime()
    return time.nowtime
end

--- 设置当前播放时间
-- @tparam number t 时间（秒）
function AudioService:setCurrentTime(t)
    time.nowtime = t
end

--- 获取音频总时长（秒）
-- @treturn number 总时长
function AudioService:getDuration()
    return time.alltime
end

--- 设置音频总时长
-- @tparam number duration 总时长（秒）
function AudioService:setDuration(duration)
    time.alltime = duration
end

--- 获取当前 beat 值
-- @treturn number 当前 beat
function AudioService:getCurrentBeat()
    return beat.nowbeat
end

--- 设置当前 beat 值
-- @tparam number b beat 值
function AudioService:setCurrentBeat(b)
    beat.nowbeat = b
end

--- 获取总 beat 数
-- @treturn number 总 beat 数
function AudioService:getAllBeat()
    return beat.allbeat
end

--- 设置总 beat 数
-- @tparam number b 总 beat 数
function AudioService:setAllBeat(b)
    beat.allbeat = b
end

--- 暂停音乐播放
function AudioService:pause()
    music_play = false
end

--- 恢复音乐播放
function AudioService:resume()
    music_play = true
end

--- 停止音乐播放并重置
function AudioService:stop()
    music_play = false
    if music then
        music:stop()
    end
end

return AudioService
