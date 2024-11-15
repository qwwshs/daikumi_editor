
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
                music_speed = 1
            end
            demo_mode = not demo_mode
            objact_music_speed.update()
            objact_mouse.update()
        end
    end
}