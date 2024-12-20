--动画计算函数
--elapsed_time
animation = {}

animation_renew = {} --更新用的

local animation_thread = love.thread.newThread('thread/animation.lua') --线程 计算动画数值的 
-- 通信的频道  
animation_thread:start() --启动

function animation_new(name,from,to,startime,endtime,trans)
    if (not from and to and startime and endtime) and name then
        animation[name] = 0
    elseif from and to and startime and endtime and name then
        animation[name] = 0
        local the_trans = {0,0,1,1}
        if trans then
            trans = trans
        end
        animation_renew[name] = {from = from ,to = to,startime = startime + elapsed_time,endtime = endtime + elapsed_time,trans = the_trans}
    end
end
function animation_update(dt)
    local pop = love.thread.getChannel( 'animation_to_main' ):pop()
    if pop then
        animation = pop
    end
    local local_tab = {animation,animation_renew,elapsed_time}
    love.thread.getChannel( 'animation' ):push(tableToString(local_tab))
end