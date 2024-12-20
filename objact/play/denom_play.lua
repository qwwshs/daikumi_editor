--denom播放
objact_denom_play = {
    draw = function()
            for isbeat = 0, beat.allbeat do -- beat和分度的渲染
                local denom_size = 1
                local beat_y = 0
                for isdenom=1,denom.denom - 1 do --分度刷新
                    local denom_beat = (1 / denom.denom)* isdenom 
                    beat_y = beat_to_y(isbeat - denom_beat)
                    if beat_y > 0 and beat_y < 800 then
                        local r,g,b = 1,1,1
                        if denom_size > 0 and denom_size < 10 then
                            r,g,b = RGBA_hexToRGB("#646464")
    
                            if denom.denom % 3 == 0 and denom.denom % 4 ~= 0 then
                                r,g,b = RGBA_hexToRGB("#00FF37")
                            end
    
                            if  isdenom % 2 == 0 and denom.denom % 2 == 0 then
                                r,g,b = RGBA_hexToRGB("#CD37FF")
                            end
    
                            if isdenom  == denom.denom / 2 then --中线
                                r,g,b = RGBA_hexToRGB("#7FFFF4")
                            end
                            love.graphics.setColor(r,g,b,settings.denom_alpha/100)
                            love.graphics.rectangle("fill",0,beat_y,1175,1)
                        end
                    end
                end
                love.graphics.setColor(RGBA_hexToRGBA("#FFFFFFFF"))
                beat_y = beat_to_y(isbeat)
                love.graphics.rectangle("fill",0,beat_y,1175,1) -- 节拍线
                local fontHeight = love.graphics.getFont():getHeight() --字体高度
                love.graphics.printf(isbeat,1180,beat_y-fontHeight/2, 35, "left")
            end
            --鼠标指针所在位置所对应的beat渲染
            if mouse.x < 1200 then--在play里面
                --根据距离反推出beat
                local mouse_beat = y_to_beat(mouse.y)
                local mouse_min_denom = 1 --假设1最近
                for i = 1, denom.denom do --取分度 哪个近取哪个
                    if math.abs(mouse_beat - (math.floor(mouse_beat) + i / denom.denom)) < math.abs(mouse_beat - (math.floor(mouse_beat) + mouse_min_denom / denom.denom)) then
                        mouse_min_denom = i
                    end
                end
                local mouse_y = beat_to_y(math.floor(mouse_beat) + mouse_min_denom / denom.denom)
                love.graphics.setColor(1,1,1,0.5)
                love.graphics.rectangle("fill",0,mouse_y,1175,2)
            end
    
    end
}