local pos = "edit" --编辑工具
room_tool = {
    load = function()
        objact_hit.load()
        objact_music_speed.load(575,50,0,25,25)
        objact_denom.load(875,50,0,25,25)
        objact_track.load(725,50,0,25,25)
        objact_track_scale.load(800,50,0,25,25)
        objact_track_fence.load(650,50,0,25,25)
        objact_music_play.load(400,50,0,50,50)
        objact_note.load(400,50,0,50,16.6)
        objact_note.load(100,50,0,50,16.6)
        objact_note_edit_inplay.load(100,50,0,50,16.6)
        objact_save.load(50,50,0,50,50)
        objact_slider.load(0,100,0,20,700)
    end,
}