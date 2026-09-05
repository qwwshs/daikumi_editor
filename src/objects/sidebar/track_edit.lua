--编辑track属性
local ChartService = require("src.services.chartService")
local GtrackEdit = group:new('track edit')
GtrackEdit.breakroom = 'track'
GtrackEdit.type = "track edit"
GtrackEdit.layout = require 'config.layouts.sidebar'.track_edit
GtrackEdit.track = 0
GtrackEdit.trackName = {value = ''}
GtrackEdit.w0thenShow = {value = false}
GtrackEdit.parentTrack = {value = 0} --为0时无父轨道
GtrackEdit.scale_with_parent = {value = false}
GtrackEdit.zindex = {value = 0}
function GtrackEdit:to(istrack)
    self.track = istrack
    ChartService:ensureTrack(istrack)
    self.trackName.value = ChartService:getTrackField(istrack, 'name')
    self.parentTrack.value = ChartService:getTrackField(istrack, 'parent')

    if ChartService:getTrackField(istrack, 'w0thenShow') == 0 then
        self.w0thenShow.value = false
    else
        self.w0thenShow.value = true
    end

    if ChartService:getTrackField(istrack, 'scale_with_parent') == 0 then
        self.scale_with_parent.value = false
    else
        self.scale_with_parent.value = true
    end
end
function GtrackEdit:Nui()
    Nui:layoutRow('dynamic', self.layout.uiH, self.layout.cols)
    Nui:label("track:"..self.track)

    Nui:layoutRow('dynamic', self.layout.uiH, self.layout.cols)

    Nui:label(i18n:get('track_name'))
    ui:edit('field', self.trackName)

    Nui:layoutRow('dynamic', self.layout.uiH, self.layout.cols)
    Nui:checkbox(i18n:get('do_not_hide'), self.w0thenShow)

    Nui:layoutRow('dynamic', self.layout.uiH, self.layout.cols)
    Nui:label(i18n:get('parent'))
    ui:edit('field', self.parentTrack)
    
    Nui:layoutRow('dynamic', self.layout.uiH, self.layout.cols)
    Nui:checkbox(i18n:get('Scale with parent'), self.scale_with_parent)

    Nui:layoutRow('dynamic', self.layout.uiH, self.layout.cols)
    Nui:label(i18n:get('zindex'))
    ui:edit('field', self.zindex)

end
function GtrackEdit:NuiNext()
    local istrack = self.track
    ChartService:setTrackField(istrack, 'name', self.trackName.value)
    
    if self.w0thenShow.value then
        ChartService:setTrackField(istrack, 'w0thenShow', 1)
    else
        ChartService:setTrackField(istrack, 'w0thenShow', 0)
    end

    if self.scale_with_parent.value then
        ChartService:setTrackField(istrack, 'scale_with_parent', 1)
    else
        ChartService:setTrackField(istrack, 'scale_with_parent', 0)
    end

    ChartService:setTrackField(istrack, 'parent', tonumber(self.parentTrack.value) or 0)
    ChartService:setTrackField(istrack, 'zindex', tonumber(self.zindex.value) or 0)

end

return GtrackEdit