displayed_content = "nil" --显示的内容
--侧边栏
function room_type(type) -- 房间状态判定
    return type == displayed_content
end
room_sidebar = {
    load = function()
        objact_button_chart_info.load(1250,100,0,150,50)
        objact_button_settings.load(1250,200,0,150,50)
        objact_button_togithub.load(1250,300,0,150,50)
        objact_button_break.load(1200,40,0,30,30)
        
    end,
    update = function(dt)
        objact_event_edit.update(dt)
    end,
    
    draw = function()
        love.graphics.setColor(0.6,0.6,0.6,0.5)
        love.graphics.rectangle("fill",1200,0,400,800) --背景板
        objact_button_chart_info.draw()
        objact_button_settings.draw()
        objact_chart_info.draw()
        objact_settings.draw()
        objact_event_edit.draw()
        objact_button_togithub.draw()
        if  not room_type("nil") then  --退出
            objact_button_break.draw()
        end
        love.graphics.setColor(1,1,1,1)
        love.graphics.print(objact_language.get_string_in_languages(displayed_content),1250,50)
        love.graphics.setColor(1,1,1,1)
        love.graphics.print(objact_language.get_string_in_languages("version")..version,1200,780)
    end,
    keypressed = function(key)
        objact_chart_info.keypressed(key)
        objact_settings.keypressed(key)
        objact_event_edit.keypressed(key)
        if  not room_type("nil")  then --退出
            objact_button_break.keyboard(key)
        end
    end,
    
    wheelmoved = function(x,y)
        if mouse.x < 1200 then --限制范围
            return
        end
        objact_chart_info.wheelmoved(x,y)
        objact_settings.wheelmoved(x,y)
    end,
    mousepressed = function( x, y, button, istouch, presses )
        objact_button_settings.mousepressed( x, y, button, istouch, presses )
        objact_button_chart_info.mousepressed( x, y, button, istouch, presses )
        objact_chart_info.mousepressed( x, y, button, istouch, presses )
        objact_settings.mousepressed( x, y, button, istouch, presses )
        objact_event_edit.mousepressed( x, y, button, istouch, presses )
        objact_button_togithub.mousepressed(x, y, button, istouch, presses)
        if not room_type("nil") then  --退出
            objact_button_break.mousepressed(x, y, button, istouch, presses)
        end
    end,
    mousereleased = function( x, y, button, istouch, presses )
        objact_event_edit.mousereleased( x, y, button, istouch, presses )
    end,
}