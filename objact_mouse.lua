local r = 20 --鼠标半径
objact_mouse = { -- 鼠标
    load = function()
        --鼠标不可见
        love.mouse.setVisible( false )
    end,
    update = function(dt)

    end,
    draw = function()
        if demo_mode == false then
            love.graphics.setColor(1,1,1,1)
            love.graphics.circle("line",mouse.x,mouse.y,r,4)
        end
    end,
    mousepressed = function( x, y, button, istouch, presses )
        r = 10 
    end,
    mousereleased = function( x, y, button, istouch, presses )
        r = 20
    end,
}
