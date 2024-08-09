local r = 20 --鼠标半径
objact_mouse = { -- 鼠标
    load = function()
        --鼠标不可见
        if settings.mouse == 0 then
            love.mouse.setVisible( false )
        end
    end,
    update = function(dt)
        if demo_mode == true  then
            love.mouse.setVisible( false )
        else
            love.mouse.setVisible( true )
        end
    end,  
    draw = function()
        if demo_mode == false and settings.mouse == 0 then
            love.graphics.setColor(1,1,1,1)
            love.graphics.circle("line",mouse.x,mouse.y,r,4)
        end
    end,
    mousepressed = function( x, y, button, istouch, presses )
        r = 10 
        if settings.mouse == 1 then
            --love.mouse.setVisible( true )
        elseif settings.mouse == 0 then
            --love.mouse.setVisible( false )
        end
        
    end,
    mousereleased = function( x, y, button, istouch, presses )
        r = 20
    end,
}
