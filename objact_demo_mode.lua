
objact_demo_mode ={ --演示谱面用的
    draw = function()
        if demo_mode == true then
            love.graphics.translate(0,-150)
            love.graphics.scale( 1600 / 900,1 + 150 / 800)
        end
    end,
    keyboard = function(key)
        if key == "tab"  then
            if demo_mode == false then
                time.nowtime = 0
                music_play = true
                music_speed = 1
                objact_music_speed.update()
            end
            demo_mode = not demo_mode
        end
    end
}