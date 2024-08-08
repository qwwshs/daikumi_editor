--设置界面
--子房间 就写成对象了
local x = 0
local y = 0
local w = 0
local h = 0
local r = 0
local input_type = false --输入状态
local type = "settings"
local ui_break = love.graphics.newImage("asset_ui_break.png")
local chart_info_pos_y = 0 --位移
objact_settings = {
    load = function(x1,y1,r1,w1,h1)
        x= x1 --初始化
        y = y1
        w = w1
        h = h1
        r = r1
        chart_info_pos_y = 0

        if not room_type(type) then
            return
        else
            input_box_delete_all()
            switch_delete_all()
            input_box_new("judge_line_y","settings.judge_line_y",x+ w + 10,y+40 + chart_info_pos_y,w,20,"number")
            input_box_new("angle","settings.angle",x+ w + 10,y+80 + chart_info_pos_y,w,20,"number")
            input_box_new("music_vol","settings.music_volume",x+ w + 10,y+120 + chart_info_pos_y,w,20,"number")
            input_box_new("hit_vol","settings.hit_volume",x+ w + 10,y+160 + chart_info_pos_y,w,20,"number")
            switch_new("hit","settings.hit",x+ w + 10,y+200 + chart_info_pos_y,20,20,1)
            switch_new("hit_sound","settings.hit_sound",x+ w + 10,y+240 + chart_info_pos_y,20,20,1)
            input_box_new("note_alpha","settings.note_alpha",x+ w,y + 280 + chart_info_pos_y,w,20,"number")
            input_box_new("note_height","settings.note_height",x+ w,y + 320 + chart_info_pos_y,w,20,"number")

        end

        
    end,
    draw = function()
        if not room_type(type) then
            return
        end
        

        --输入框
        input_box_draw_all()
        switch_draw_all()
        love.graphics.setColor(1,1,1,1)
        love.graphics.print("judge_y",x,y+40 + chart_info_pos_y) 
        love.graphics.print("angle",x,y+80 + chart_info_pos_y) 
        love.graphics.print("music_vol",x,y+120 + chart_info_pos_y) 
        love.graphics.print("hit_vol",x,y+160 + chart_info_pos_y) 
        love.graphics.print("hit",x,y+200 + chart_info_pos_y) 
        love.graphics.print("hit_sound",x,y+240 + chart_info_pos_y) 
        love.graphics.print("note_alpha",x,y +280 + chart_info_pos_y) 
        love.graphics.print("note_height",x,y +320 + chart_info_pos_y) 


    end,
    mousepressed = function( x1, y1, button, istouch, presses )
        if not room_type(type) then
            return
        end
        objact_bpm_list.mousepressed(x1,y1)
        input_box_mousepressed(x1, y1)
        switch_mousepressed(x1,y1)
        bpm_list_sort()
        save(settings,"settings.txt")
    end,
    keypressed = function(key)
        if not room_type(type) then
            return
        end

        
    end,
    wheelmoved = function(x,y)
        if not room_type(type) then
            return
        end
        input_box_wheelmoved(x,y)
        switch_wheelmoved(x,y)
        chart_info_pos_y = chart_info_pos_y + y * 10
    end
}