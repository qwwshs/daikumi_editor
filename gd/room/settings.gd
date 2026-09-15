extends Control
## Touch-friendly settings screen. Controls only edit Setting and delegate file
## access to Storage; the same Playfield and Skins renderer provide live preview.
## 安卓没有滚轮：整屏（含预览、标题栏）上下拖动都能滚动当前页，
## 手势处理在 gd/ui/touch_scroll.gd（选曲与结算界面共用同一套）；
## 页里的 ScrollContainer 特意设成 IGNORE，拖拽只由根节点处理。

const SlicePreview = preload("res://gd/ui/nine_slice_preview.gd")
const ImGuiTheme = preload("res://gd/ui/imgui_theme.gd")
const TouchScroll = preload("res://gd/ui/touch_scroll.gd")
const UI = preload("res://gd/ui/song_screen.gd")
const IMAGE_FILTERS: PackedStringArray = ["*.png,*.jpg,*.jpeg,*.webp ; 图片"]
const AUDIO_FILTERS: PackedStringArray = ["*.wav,*.ogg,*.mp3 ; 音频"]
const KINDS := ["tap", "hold", "slide"]
const KIND_NAMES := ["Tap · 单点", "Hold · 长按", "Slide · 滑动"]
## 谱面偏移滑条的粗调范围（毫秒）；它的数值框不受量程限制，可以键入任意值。
## 时间偏移则是有范围的（Setting.OFFSET_LIMIT），滑条与数值框同量程。
const CHART_OFFSET_SLIDER_RANGE := 2000.0
## 判定反馈的素材槽位与显示名；游玩时的判定名（just+ / just / good / ok / miss）见 Skins.GRADE_SLOTS。
const GRADE_SLOTS := [
	["judge_just_plus", "Just+ · 最精准"],
	["judge_just", "Just · 精准"],
	["judge_good", "Good · 良好"],
	["judge_ok", "Ok · 一般"],
	["judge_miss", "Miss · 漏判"],
]

var _body: BoxContainer
var _preview_panel: PanelContainer
var _preview_area: Control
var _preview: Node2D
var _editor: VBoxContainer
var _pages: Array[ScrollContainer] = []
var _tabs: Array[Button] = []
var _refreshers: Array[Callable] = []
var _status: Label
var _storage_status: Label
var _plugin_list: VBoxContainer
var _save_timer: Timer
var _source_files: Dictionary = {"chart": "", "audio": "", "background": "", "folder": ""}


func _ready() -> void:
	get_tree().auto_accept_quit = false
	theme = ImGuiTheme.build()
	var background := ColorRect.new()
	background.color = ImGuiTheme.APP_BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.6
	_save_timer.timeout.connect(Setting.save_settings)
	add_child(_save_timer)
	_build_screen()
	TouchScroll.pass_through(self)
	Setting.changed.connect(_refresh_values)
	Storage.storage_changed.connect(_update_storage_status)
	resized.connect(_adapt_layout)
	call_deferred("_adapt_layout")
	_refresh_values()


## 安卓端起主要作用：在界面上任意非交互区域上下拖动，滚动当前页。
## 滚轮在桌面端等效（页里的 ScrollContainer 是 IGNORE，不参与滚动，避免重复处理）。
func _gui_input(event: InputEvent) -> void:
	if TouchScroll.handle(self, event, _current_page):
		accept_event()


func _current_page() -> ScrollContainer:
	for page in _pages:
		if page.visible:
			return page
	return null


func _build_screen() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 16)
	margin.add_child(shell)
	var header := HBoxContainer.new()
	shell.add_child(header)
	_button(header, "‹ 返回", _leave)
	var title := _label(header, "设置 / 自定义游玩", 31)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "保存", func():
		Setting.save_settings()
		_message("设置已保存。"))
	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation", 20)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(_body)
	_build_preview()
	_build_editor()
	_status = _label(shell, "拖动即可预览，修改自动保存。", 19)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 28


func _build_preview() -> void:
	_preview_panel = PanelContainer.new()
	_preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_panel.size_flags_stretch_ratio = 0.85
	_body.add_child(_preview_panel)
	var content := VBoxContainer.new()
	_preview_panel.add_child(content)
	var row := HBoxContainer.new()
	content.add_child(row)
	_label(row, "实时预览", 25).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selector := OptionButton.new()
	selector.custom_minimum_size.y = 46
	for item in ["全部音符", "Tap", "Hold", "Slide"]:
		selector.add_item(item)
	selector.item_selected.connect(func(index: int):
		if is_instance_valid(_preview):
			_preview.set("preview_kind", ["all", "tap", "hold", "slide"][index]))
	row.add_child(selector)
	_preview_area = Control.new()
	_preview_area.clip_contents = true
	_preview_area.custom_minimum_size = Vector2(220, 210)
	_preview_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_preview_area)
	# Loaded at runtime to keep the screen decoupled from gameplay scene creation.
	var preview_script: Script = load("res://gd/gameplay/playfield.gd")
	if preview_script != null:
		_preview = preview_script.new()
		_preview_area.add_child(_preview)
		_preview.call("set_preview", true)
		_preview_area.resized.connect(func(): _preview.call("configure", _preview_area.size))
	var sound := CheckBox.new()
	sound.text = "预览自动播放打击音"
	sound.custom_minimum_size.y = 48
	sound.toggled.connect(func(enabled: bool):
		if is_instance_valid(_preview):
			_preview.set("preview_sound", enabled))
	content.add_child(sound)
	var hint := _label(content, "实际游玩使用同一套渲染。高度与大小按 900 高度等比缩放。", 18)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = ImGuiTheme.TEXT_DISABLED


func _build_editor() -> void:
	_editor = VBoxContainer.new()
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_editor)
	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tabs_scroll.custom_minimum_size.y = 65
	_editor.add_child(tabs_scroll)
	var tab_bar := HBoxContainer.new()
	tabs_scroll.add_child(tab_bar)
	var names := ["布局 / 声音", "Note / 判定线", "Hit / 打击音", "数字 / 判定 / 按钮", "文件 / 扩展"]
	for index in range(names.size()):
		var tab_index := index
		var tab := _button(tab_bar, names[index], func(): _show_page(tab_index))
		tab.toggle_mode = true
		_tabs.append(tab)
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		# 拖拽滚动由根节点统一处理（见 _gui_input），这里不再接收事件：
		# 触摸事件否则会被 ScrollContainer 拦下，落在卡片空白处的拖动就滚不动。
		scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_editor.add_child(scroll)
		_pages.append(scroll)
	_build_layout_page(_page_content(0))
	_build_note_page(_page_content(1))
	_build_hit_page(_page_content(2))
	_build_art_page(_page_content(3))
	_build_files_page(_page_content(4))
	_show_page(0)


func _page_content(index: int) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	_pages[index].add_child(content)
	return content


func _show_page(index: int) -> void:
	for item in range(_pages.size()):
		_pages[item].visible = item == index
		_tabs[item].set_pressed_no_signal(item == index)


func _build_layout_page(parent: VBoxContainer) -> void:
	var judging_card := _card(parent, "空间判定模式")
	var mode := Button.new()
	mode.custom_minimum_size.y = 52
	mode.set_meta("dakumi_setting", "game:judge_position_mode")
	mode.pressed.connect(func():
		Setting.judge_position_mode = Setting.JUDGE_POSITION_NOTE if Setting.judge_position_mode == Setting.JUDGE_POSITION_CURRENT else Setting.JUDGE_POSITION_CURRENT
		Setting.apply_settings()
		_queue_save())
	judging_card.add_child(mode)
	_refreshers.append(func(): mode.text = "当前时刻位置 · 点击切换" if Setting.judge_position_mode == Setting.JUDGE_POSITION_CURRENT else "音符时刻位置 · 点击切换")
	_hint(judging_card, "当前时刻位置：按触摸时音符所在轨道的位置与宽度判定。音符时刻位置：按音符目标时刻的轨道位置与宽度判定。适用于 Tap、Slide 和 Hold 头；Hold 持续按住阶段仍跟随当前轨道。")
	var layout_card := _card(parent, "游玩布局")
	_hint(layout_card, "轨道倾斜是“向内收敛”：像站在马路中间向前看，画面顶端按这个角度向中轴收拢，0° 为平行；负值则向外发散。旋转轴就是判定线所在的水平线，所以判定线中点处的大小与位置始终不变。判定线只横跨游玩区域，两端正好落在左右两条侧线上（跟着“轨道宽度”一起变）。")
	_layout_slider(layout_card, "note_height", "Note 高度", 4, 160, 1, 24, " px")
	_layout_slider(layout_card, "track_angle", "轨道倾斜 / 向内收敛", -45, 70, 0.5, 0, "°")
	_hint(layout_card, "倾斜由 3D 透视实现（越远越小）。相机随角度一起后退，游玩区域因此一直铺到屏幕顶端、不会中途消失，Note 从屏幕顶端进入；代价是角度越大透视越缓。判定线越低、角度越大时两者会互相挤压，此时会自动收窄到安全角度。")
	_layout_slider(layout_card, "track_width", "轨道宽度 / 画面宽度", 0.2, 1.0, 0.01, 0.8)
	_layout_slider(layout_card, "judge_height", "判定线高度", 1, 100, 1, 10, " px")
	_layout_slider(layout_card, "judge_y", "判定线 Y / 画面高度", 0.25, 0.95, 0.01, 0.8)
	_layout_slider(layout_card, "hit_size", "Hit 大小", 16, 400, 1, 100, " px")
	_layout_slider(layout_card, "approach_curve", "接近曲线", 0.25, 3.0, 0.05, 1.0)
	_hint(layout_card, "接近曲线 1 为匀速；大于 1 时，远处更快、靠近判定线时更慢。")
	_hint(layout_card, "轨道背景固定为纯黑、轨道线固定为纯白，这里只调整它们的透明度。宽度不为 0 的轨道都会照画（谱面把宽度当成出场动画），宽度为 0 的轨道只剩一条细线，给音符当立足点。游玩区域左右两侧的侧线（轨道线的四倍宽）跟随轨道线透明度，标出判定线两端的位置。")
	_layout_slider(layout_card, "lane_alpha", "轨道背景透明度", 0, 1, 0.01, 0.5)
	_layout_slider(layout_card, "lane_line_alpha", "轨道线透明度", 0, 1, 0.01, 1.0)
	_button(layout_card, "恢复默认布局", func():
		Setting.reset_layout()
		_queue_save())
	var game_card := _card(parent, "速度 · 音频 · 性能")
	_setting_slider(game_card, "speed", "流速", 1, 20, 0.1, 7.0)
	_hint(game_card, "流速 N：Note 从屏幕顶端落到判定线用 10 / N 秒（N 越大越快、同屏出现的 Note 越少）。拖动滑块的瞬间，左边预览里的下落速度与出现间隔就会跟着变。")
	_offset_controls(game_card)
	_setting_slider(game_card, "master_volume", "总音量", 0, 1, 0.01, 0.8)
	_setting_slider(game_card, "music_volume", "音乐音量", 0, 1, 0.01, 0.7)
	_setting_slider(game_card, "hit_volume", "打击音总音量", 0, 1, 0.01, 0.8)
	var fps := CheckBox.new()
	fps.text = "显示 FPS"
	fps.custom_minimum_size.y = 48
	fps.toggled.connect(func(value: bool):
		Setting.show_fps = value
		Setting.apply_settings()
		_queue_save())
	game_card.add_child(fps)
	_refreshers.append(func(): fps.set_pressed_no_signal(Setting.show_fps))
	_max_fps_row(game_card)


func _build_note_page(parent: VBoxContainer) -> void:
	for index in range(KINDS.size()):
		var kind: String = KINDS[index]
		var slot: String = "note_" + kind
		var card := _card(parent, KIND_NAMES[index] + " 图片")
		_asset_picker(card, slot, IMAGE_FILTERS)
		_slice_controls(card, slot)
		_layout_slider(card, "note_gap_" + kind, "与轨道的横向间隔", 0, 400, 1, float(Setting.DEFAULT_LAYOUT["note_gap_" + kind]), " px")
		_hint(card, "%s 比所在轨道窄出来的总宽度，左右各分一半：0 = 正好铺满轨道，调大则两边留白更多。三种音符各调各的，互不影响。" % KIND_NAMES[index])
	var line_card := _card(parent, "判定线图片")
	_hint(line_card, "图片默认正好铺在实际判定线上，位置（判定线 Y、高度、宽度）在「游玩布局」页统一调。")
	_asset_picker(line_card, "judge_line", IMAGE_FILTERS)
	_slice_controls(line_card, "judge_line")
	_layout_slider(line_card, "judge_image_offset", "图片相对实际判定线的纵向偏移", -300, 300, 1, 0, " px")
	_hint(line_card, "正数把图片往下挪、负数往上挪（布局像素，跟着画布缩放）。只挪这一张图片，判定线本身不动——判定、触摸和倾斜的旋转轴仍在原来那一行，所以图片挪开后画面上就没有东西标出判定位置了。0 = 图片正好压在判定线上（默认）。")


func _build_hit_page(parent: VBoxContainer) -> void:
	for index in range(KINDS.size()):
		var kind: String = KINDS[index]
		var hit_slot := "hit_" + kind
		var card := _card(parent, KIND_NAMES[index] + " · Hit 图片 / 精灵图")
		_asset_picker(card, hit_slot, IMAGE_FILTERS)
		_image_preview(card, hit_slot, false)
		_hint(card, "单图：帧数、行数、列数均为 1。精灵图按从左到右、从上到下播放；起始帧从 0 计数。")
		_skin_number(card, hit_slot, "duration", "单图显示时长", 0.02, 10, 0.01, 0.3, " s")
		_skin_number(card, hit_slot, "frames", "播放帧数", 1, 4096, 1, 1)
		_skin_number(card, hit_slot, "frame_duration", "每帧时长", 0.005, 2, 0.005, 0.05, " s")
		_skin_number(card, hit_slot, "rows", "行数", 1, 256, 1, 1)
		_skin_number(card, hit_slot, "columns", "列数", 1, 256, 1, 1)
		_skin_number(card, hit_slot, "start_frame", "起始帧", 0, 65535, 1, 0)
		if kind == "hold":
			var looping := CheckBox.new()
			looping.text = "循环到 Hold 结束"
			looping.custom_minimum_size.y = 48
			looping.toggled.connect(func(value: bool):
				Setting.set_skin_field("hit_hold", "loop_hold", value)
				_queue_save())
			card.add_child(looping)
			_refreshers.append(func(): looping.set_pressed_no_signal(bool(Setting.get_skin("hit_hold").get("loop_hold", false))))
		_hit_scale_sliders(card, hit_slot)
		_button(card, "播放 " + kind.capitalize() + " Hit 预览", func():
			if is_instance_valid(_preview):
				_preview.set("preview_kind", kind)
				_preview.call("preview_hit", kind))
		var sound_card := _card(parent, KIND_NAMES[index] + " · 打击音")
		var sound_slot := "sound_" + kind
		_asset_picker(sound_card, sound_slot, AUDIO_FILTERS)
		_skin_number(sound_card, sound_slot, "volume", "此音效音量", 0, 1, 0.01, 1.0)
		_button(sound_card, "试听 " + kind.capitalize() + " 打击音", func(): Skins.play_sound(kind))
		if kind == "hold":
			var tail_sound := CheckBox.new()
			tail_sound.text = "按住到结尾时也响一声（尾部打击音）"
			tail_sound.custom_minimum_size.y = 48
			tail_sound.set_meta("dakumi_setting", "game:hold_tail_sound")
			tail_sound.toggled.connect(func(value: bool):
				Setting.hold_tail_sound = value
				Setting.apply_settings()
				_queue_save())
			sound_card.add_child(tail_sound)
			_refreshers.append(func(): tail_sound.set_pressed_no_signal(Setting.hold_tail_sound))
			_hint(sound_card, "勾上（默认）时按满一条 Hold 会响两声：按下头判一声、松手判定成功再一声。取消勾选后只有头判出声，尾判安静——声音素材与音量都还是上面这一份，判定、连击与 Hit 特效完全不受影响。上面的「试听」按钮随时能听到素材本身，与本开关无关。")


func _build_art_page(parent: VBoxContainer) -> void:
	var hud_card := _card(parent, "HUD 高度 · 连击 / 分数 / 判定")
	_hint(hud_card, "三个数字各自独立缩放：连击与分数显示在判定线下方，判定反馈显示在判定线上方。数字素材按这里的高度等比缩放，宽度自适应。")
	_layout_slider(hud_card, "combo_size", "连击数字高度", 8, 200, 1, 40, " px")
	_layout_slider(hud_card, "score_size", "分数数字高度", 8, 200, 1, 28, " px")
	_layout_slider(hud_card, "judge_size", "判定显示高度", 8, 200, 1, 24, " px")
	var score_mode := Button.new()
	score_mode.custom_minimum_size.y = 48
	score_mode.set_meta("dakumi_setting", "game:score_mode")
	score_mode.pressed.connect(func():
		Setting.score_mode = Setting.SCORE_SUB if Setting.score_mode == Setting.SCORE_ADD else Setting.SCORE_ADD
		Setting.apply_settings()
		_queue_save())
	hud_card.add_child(score_mode)
	_refreshers.append(func(): score_mode.text = "分数算法：加算 · 点击切换" if Setting.score_mode == Setting.SCORE_ADD else "分数算法：减算 · 点击切换")
	_hint(hud_card, "加算：分数从 0 往上加（默认）。减算：分数从 %d 满分往下扣，漏判与低判定扣得更多。两种算法对同一局的判定给出的总分一模一样，只是分数数字往上走还是往下走；预览里显示的是这种算法开局的数值。" % roundi(PlaySession.SCORE_TOTAL))
	var judge_card := _card(parent, "判定文字 / 图片")
	var count_button := Button.new()
	count_button.custom_minimum_size.y = 48
	count_button.set_meta("dakumi_setting", "layout:judge_count")
	count_button.pressed.connect(func():
		var count := 2 if int(Setting.layout.judge_count) == 1 else 1
		if count == 2 and is_equal_approx(float(Setting.layout.judge_x), 0.5):
			Setting.set_layout("judge_x", 0.35)
		Setting.set_layout("judge_count", count)
		_queue_save())
	judge_card.add_child(count_button)
	_refreshers.append(func(): count_button.text = "判定显示：单个 · 点击切换" if int(Setting.layout.judge_count) == 1 else "判定显示：双个 · 点击切换")
	_layout_slider(judge_card, "judge_x", "判定横坐标（0 左 / 0.5 中 / 1 右）", 0, 1, 0.01, 0.5)
	_layout_slider(judge_card, "judge_text_y", "判定纵坐标（0 上 / 0.5 中 / 1 下）", 0, 1, 0.01, 0.28)
	_hint(judge_card, "纵坐标控制判定文字或图片的位置，双个模式共用同一高度，不影响判定线位置。")
	_hint(judge_card, "双个模式在 X 和 1−X 处显示相同判定，左右位置关于画面中心镜像、纵坐标相同。文字本身不翻转；自定义判定图片也使用此布局。首次从居中切为双个时，位置设为 0.35 / 0.65。")
	_hint(judge_card, "导入图片后，这个判定改用图片显示（按上面“判定显示高度”等比缩放，宽度自适应）；没有导入的判定仍然显示内置文字。右侧预览会立刻显示效果。")
	for grade in GRADE_SLOTS:
		_label(judge_card, grade[1], 21)
		_asset_picker(judge_card, grade[0], IMAGE_FILTERS, "内置文字")
		_image_preview(judge_card, grade[0], false, 90)
	_build_offset_display(parent)
	_hint(parent, "每个数字可单独替换。退出与重开按钮的点击区域始终保持可触摸大小；预览中能查看外观。")
	for index in range(10):
		var slot := "digit_" + str(index)
		var card := _card(parent, "数字 " + str(index))
		_asset_picker(card, slot, IMAGE_FILTERS)
		_image_preview(card, slot, false, 100)
	for button_info in [["exit", "左上角 · 退出按钮"], ["restart", "右上角 · 重开按钮"]]:
		var card := _card(parent, button_info[1])
		_asset_picker(card, button_info[0], IMAGE_FILTERS)
		_image_preview(card, button_info[0], false, 120)


## 击打延迟显示（元件）：按下 Tap / Hold 判定时出现 FAST（按早了）/ LATE（按晚了）。
## 触发条件用判定文字本身做选项，五个全都在这里；默认只差 just+ 不显示。
func _build_offset_display(parent: VBoxContainer) -> void:
	var card := _card(parent, "击打延迟显示 · FAST / LATE")
	_hint(card, "Tap 与 Hold 被按下去判定的那一刻显示方向：按早了 FAST、按晚了 LATE。选项就是判定文字本身（全部五个），勾上的判定才会出现；没碰到的音符（漏判）、Hold 尾判、Slide 的自动命中都不算按下去，不会显示。")
	for grade in Setting.JUDGE_OFFSET_GRADES:
		var check := CheckBox.new()
		check.text = grade
		check.custom_minimum_size.y = 48
		check.set_meta("dakumi_setting", "offset_grade:" + grade)
		check.toggled.connect(func(enabled: bool):
			Setting.set_judge_offset_grade(grade, enabled)
			_queue_save())
		card.add_child(check)
		var checked_grade := grade
		_refreshers.append(func(): check.set_pressed_no_signal(Setting.judge_offset_enabled(checked_grade)))
	_layout_slider(card, "judge_offset_x", "延迟显示横坐标（0 左 / 0.5 中 / 1 右）", 0, 1, 0.01, 0.5)
	_layout_slider(card, "judge_offset_y", "延迟显示纵坐标（0 上 / 0.5 中 / 1 下）", 0, 1, 0.01, 0.36)
	_layout_slider(card, "judge_offset_size", "延迟显示高度", 8, 200, 1, 20, " px")
	_layout_slider(card, "judge_offset_duration", "延迟显示时长", 0.05, 5, 0.05, 0.7, " s")
	_hint(card, "位置与判定文字的坐标同一套算法：横纵都是画面比例，纵坐标是文字顶部；时长是这一下提示亮多久。上面五个选项、位置、大小、时长都会立刻反映到左边预览里。")
	for word_info in [["judge_fast", "Fast · 按早了"], ["judge_late", "Late · 按晚了"]]:
		_label(card, word_info[1], 21)
		_asset_picker(card, word_info[0], IMAGE_FILTERS, "内置文字")
		_image_preview(card, word_info[0], false, 90)
	_hint(card, "和判定文字一样：导入图片后改用图片显示（按上面的「延迟显示高度」等比缩放，宽度自适应），没导入的仍然是内置文字。")


func _build_files_page(parent: VBoxContainer) -> void:
	var storage_card := _card(parent, "存储位置")
	_storage_status = _label(storage_card, "", 20)
	_storage_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(storage_card, "重新检测公有目录", func():
		Storage.refresh_storage()
		_update_storage_status()
		_message("存储位置检测完成。"))
	_hint(storage_card, "Android 优先尝试公有目录，无法写入时使用应用私有目录。系统文件选择器可导入外部文件；素材会复制到当前用户素材目录。")
	_update_storage_status()
	var files_card := _card(parent, "分散文件导入")
	_hint(files_card, "可以分别选择谱面、音乐、背景。谱面引用其他文件时，请选择包含它们的完整谱面文件夹；Android 需在系统选择器中授予该文件夹访问权。")
	_source_picker(files_card, "chart", "谱面文件", PackedStringArray(["*.json ; JSON 谱面", "* ; 扩展读取器文件"]))
	_source_picker(files_card, "audio", "音乐文件（可选）", AUDIO_FILTERS)
	_source_picker(files_card, "background", "背景图片（可选）", IMAGE_FILTERS)
	_source_picker(files_card, "folder", "谱面文件夹（可选）", PackedStringArray(), true)
	_button(files_card, "导入选中的谱面与资源", _import_selected_files)
	var plugins_card := _card(parent, "外部读取器 / 公共 API")
	_hint(plugins_card, "读取器可自定义谱面、音乐、背景的读取方式，并访问获授权谱面文件夹内的全部文件。仅启用你信任的 .gd 读取器：启用会在应用中执行它的代码。")
	_hint(plugins_card, "内置已支持 TAKANA³ 谱面（V1/V2/V3）：选中它的谱面文件夹或谱面文件即可导入，无需安装扩展。")
	_button(plugins_card, "导入读取器 .gd", func():
		Storage.pick_file(self, PackedStringArray(["*.gd ; GDScript 读取器"]), _import_plugin))
	_plugin_list = VBoxContainer.new()
	plugins_card.add_child(_plugin_list)
	_refresh_plugins()


func _source_picker(parent: VBoxContainer, key: String, title: String, filters: PackedStringArray, directory: bool = false) -> void:
	_label(parent, title, 21)
	var path_label := _label(parent, "未选择", 18)
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buttons := HBoxContainer.new()
	parent.add_child(buttons)
	var selected := func(path: String):
		if path.is_empty():
			return
		_source_files[key] = path
		path_label.text = path
	_button(buttons, "选择文件夹" if directory else "选择文件", func():
		if directory:
			Storage.pick_directory(self, selected)
		else:
			Storage.pick_file(self, filters, selected))
	_button(buttons, "清除", func():
		_source_files[key] = ""
		path_label.text = "未选择")


func _import_selected_files() -> void:
	if String(_source_files.chart).is_empty():
		_message("请先选择谱面文件。", true)
		return
	# The import service owns copying and validation, including folder contents.
	var result: String = ImportAPI.import_files(String(_source_files.chart), String(_source_files.audio), String(_source_files.background), String(_source_files.folder))
	if result.is_empty():
		_message("导入失败：" + ImportAPI.last_error, true)
	else:
		_message("谱面已导入：" + result)


func _import_plugin(path: String) -> void:
	if path.is_empty():
		return
	var installed: String = ImportAPI.import_plugin(path)
	if installed.is_empty():
		_message("读取器导入失败：" + ImportAPI.last_error, true)
	else:
		_message("读取器已导入。确认可信后，可在列表中启用。")
	_refresh_plugins()


func _refresh_plugins() -> void:
	for child in _plugin_list.get_children():
		child.queue_free()
	var plugins: Array = ImportAPI.list_plugins()
	if plugins.is_empty():
		_hint(_plugin_list, "尚未安装外部读取器。开发接口参见项目根目录的 IMPORT_API.md。")
	for plugin in plugins:
		var plugin_id: String = str(plugin.get("id", ""))
		var enabled := CheckBox.new()
		enabled.text = str(plugin.get("name", plugin_id))
		enabled.custom_minimum_size.y = 52
		enabled.set_pressed_no_signal(bool(plugin.get("enabled", false)))
		enabled.toggled.connect(func(value: bool): _set_plugin_enabled(plugin_id, value, enabled))
		_plugin_list.add_child(enabled)


func _set_plugin_enabled(plugin_id: String, enabled: bool, toggle: CheckBox) -> void:
	if not enabled:
		if not ImportAPI.set_plugin_enabled(plugin_id, false):
			_message(ImportAPI.last_error, true)
			_refresh_plugins()
		return
	# Importing is passive; enabling executes user code and therefore has a clear
	# per-plugin trust confirmation rather than being enabled during file import.
	toggle.set_pressed_no_signal(false)
	var confirmation := ConfirmationDialog.new()
	confirmation.title = "启用外部读取器"
	confirmation.dialog_text = "启用后，这个读取器将执行代码，并可读取已授权的谱面文件夹。\n请仅启用你信任的作者提供的文件。"
	confirmation.ok_button_text = "信任并启用"
	confirmation.cancel_button_text = "取消"
	confirmation.confirmed.connect(func():
		if ImportAPI.set_plugin_enabled(plugin_id, true):
			toggle.set_pressed_no_signal(true)
			_message("读取器已启用。")
		else:
			_message("读取器启用失败：" + ImportAPI.last_error, true)
		confirmation.queue_free())
	confirmation.canceled.connect(confirmation.queue_free)
	add_child(confirmation)
	confirmation.popup_centered(Vector2i(620, 260))


func _update_storage_status() -> void:
	# storage_changed 可能在界面搭好之前到达（例如 Android 授权结果），此时先忽略。
	if not is_instance_valid(_storage_status):
		return
	_storage_status.text = ("公有目录" if Storage.is_public else "应用私有目录") + "\n" + Storage.root_path + "\n谱面：" + Storage.chart_dir + "\n素材：" + Storage.users_dir


func _slice_controls(parent: VBoxContainer, slot: String) -> void:
	_image_preview(parent, slot, true)
	_hint(parent, "青色线为原图的九宫格边界，单位是原图像素。画面预览实时显示拉伸结果。")
	var mode := OptionButton.new()
	mode.custom_minimum_size.y = 48
	mode.add_item("中间拉伸 · 左右边缘固定")
	mode.add_item("左右拉伸 · 中间区域固定")
	mode.item_selected.connect(func(index: int):
		Setting.set_skin_field(slot, "stretch_mode", "center" if index == 0 else "sides")
		_queue_save())
	parent.add_child(mode)
	_refreshers.append(func(): mode.select(0 if Setting.get_skin(slot).get("stretch_mode", "center") == "center" else 1))
	for edge in [["left", "左边界"], ["right", "右边界"], ["top", "上边界"], ["bottom", "下边界"]]:
		_skin_number(parent, slot, "margin_" + edge[0], edge[1], 0, 8192, 1, 0, " px")


func _image_preview(parent: VBoxContainer, slot: String, guides: bool, height: float = 150) -> void:
	var preview: Control = SlicePreview.new()
	preview.set("slot", slot)
	preview.set("show_guides", guides)
	preview.custom_minimum_size.y = height
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(preview)
	var resolution := _label(parent, "", 17)
	resolution.modulate = ImGuiTheme.TEXT_DISABLED
	_refreshers.append(func():
		var tex: Texture2D = Skins.texture(slot)
		resolution.text = "原图：%d × %d px" % [tex.get_width(), tex.get_height()] if tex != null else "使用默认绘制")


func _asset_picker(parent: VBoxContainer, slot: String, filters: PackedStringArray, fallback_name: String = "内置素材") -> void:
	var filename := _label(parent, "", 18)
	filename.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	filename.modulate = ImGuiTheme.TEXT
	_refreshers.append(func():
		var path: String = str(Setting.get_skin(slot).get("path", ""))
		filename.text = fallback_name if path.is_empty() else path.get_file()
		filename.tooltip_text = path)
	var actions := HBoxContainer.new()
	parent.add_child(actions)
	_button(actions, "导入文件", func():
		Storage.pick_file(self, filters, func(path: String):
			if path.is_empty():
				return
			var destination: String = Storage.import_asset(path)
			if destination.is_empty():
				_message("素材导入失败：" + Storage.last_error, true)
				return
			Setting.set_skin_field(slot, "path", destination)
			_queue_save()
			_message("已导入 " + destination.get_file())))
	_button(actions, "恢复内置", func():
		Setting.set_skin_field(slot, "path", "")
		_queue_save())
	_button(actions, "重置此项", func():
		Setting.reset_skin(slot)
		_queue_save())


func _layout_slider(parent: VBoxContainer, key: String, title: String, minimum: float, maximum: float, step: float, default_value: float, suffix: String = "") -> void:
	_number_control(parent, title, minimum, maximum, step, suffix,
		func(): return float(Setting.layout.get(key, default_value)),
		func(value: float):
			Setting.set_layout(key, value)
			_queue_save(), default_value, true, "layout:" + key)


func _setting_slider(parent: VBoxContainer, key: String, title: String, minimum: float, maximum: float, step: float, default_value: float, suffix: String = "") -> void:
	_number_control(parent, title, minimum, maximum, step, suffix,
		func(): return float(Setting.get(key)),
		func(value: float):
			Setting.set(key, value)
			Setting.apply_settings()
			_queue_save(), default_value, true, "game:" + key)


## 两个偏移旋钮（时间偏移 / 谱面偏移）与共用的一行实时读数。
## 最终延迟 = 单曲延迟 + 时间偏移 - 谱面偏移 + 谱面自带的 offset（见 ChartLoader.total_offset_seconds）。
## 时间偏移限死在 ±Setting.OFFSET_LIMIT（数值框与滑条同量程，键入越界值会被夹到端点）；
## 谱面偏移不设上限（谱面 offset 有大有小），数值框用 allow_greater / allow_lesser，
## 滑条只覆盖 ±CHART_OFFSET_SLIDER_RANGE 的常用范围用于粗调。
func _offset_controls(parent: VBoxContainer) -> void:
	# 先把 getter / setter 存成变量再传：多行 lambda 直接写在参数表里容易把后面的参数吃掉。
	var get_audio := func() -> float: return Setting.offset
	var set_audio := func(value: float):
		Setting.set("offset", value)
		Setting.apply_settings()
	_offset_knob(parent, "音频延迟 / 时间偏移", "game:offset", get_audio, set_audio, Setting.OFFSET_LIMIT, true)
	var get_chart := func() -> float: return Setting.chart_offset
	var set_chart := func(value: float):
		Setting.set("chart_offset", value)
		Setting.apply_settings()
	_offset_knob(parent, "谱面偏移 / 与时间偏移反向", "game:chart_offset", get_chart, set_chart, CHART_OFFSET_SLIDER_RANGE, false)
	var readout := _label(parent, "", 18)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readout.modulate = ImGuiTheme.TEXT_DISABLED
	readout.set_meta("dakumi_setting", "game:offset_readout")
	_refreshers.append(func(): readout.text = _offset_readout())
	_hint(parent, "最终延迟 = 单曲延迟 + 时间偏移 - 谱面偏移 + 谱面自带的 offset。时间偏移填的是你那边声音比谱面晚多少毫秒：正值让谱面整体推后去等声音（听起来音频相对谱面提前），负值让音频相对谱面推后（声音比谱面晚）。谱面偏移方向相反——填 +100 与把时间偏移填 -100 完全等效，读数里已经换成取反后的贡献值。时间偏移限制在 ±%d ms 以内（键入越界值会夹到端点）；谱面偏移不设上限，多大的值都能直接键入，滑条只覆盖 ±%d ms 的常用范围用于粗调。这两个偏移对每首歌都一样，想单独调某一首请到选曲界面的「单曲延迟」。改动立即生效，进入游玩时按下方的最终延迟对齐声音与谱面。" % [int(Setting.OFFSET_LIMIT), int(CHART_OFFSET_SLIDER_RANGE)])


## 单个偏移旋钮：数值框 + 滑条 + 归零按钮，三处写的是同一个设置项，
## 都由 getter / setter 决定（实时预览靠 Setting.changed 回到这里刷新显示值）。
## limit 是滑条量程；bounded 为真时数值框也用这个量程（超出的输入夹到端点），
## 为假时数值框打开 allow_greater / allow_lesser，可以键入量程外的值。
func _offset_knob(parent: VBoxContainer, title: String, tag: String, getter: Callable, setter: Callable, limit: float, bounded: bool) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(row, title, 21)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var number := SpinBox.new()
	number.min_value = -limit
	number.max_value = limit
	number.allow_greater = not bounded
	number.allow_lesser = not bounded
	number.step = 1.0
	number.suffix = " ms"
	number.custom_minimum_size = Vector2(170, 48)
	number.set_meta("dakumi_setting", tag)
	row.add_child(number)
	var apply := func(value: float):
		setter.call(value)
		_queue_save()
	number.value_changed.connect(apply)
	var reset := _button(row, "↺", func(): apply.call(0.0))
	reset.tooltip_text = "恢复默认值（0 ms）"
	var slider := HSlider.new()
	slider.min_value = -limit
	slider.max_value = limit
	slider.step = 1.0
	slider.custom_minimum_size.y = 40
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.set_meta("dakumi_setting", tag)
	slider.value_changed.connect(apply)
	parent.add_child(slider)
	_refreshers.append(func():
		number.set_value_no_signal(float(getter.call()))
		slider.set_value_no_signal(float(getter.call())))


## 最高帧率：五个档位各一个按钮，按下去立刻生效（Engine.max_fps，见 Setting.set_max_fps）。
## 用一排开关而不是下拉框：安卓上没有滚轮，一次点选比展开菜单少一次操作，还能一眼看出当前档位。
func _max_fps_row(parent: VBoxContainer) -> void:
	_label(parent, "最高帧率", 21)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	for choice in Setting.FPS_CHOICES:
		var fps: int = choice
		var button := _button(row, "无上限" if fps <= 0 else str(fps), func(): _choose_max_fps(fps))
		button.toggle_mode = true
		button.custom_minimum_size.x = 76
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("dakumi_setting", "game:max_fps:" + str(fps))
		_refreshers.append(func(): button.set_pressed_no_signal(Setting.max_fps == fps))
	_hint(parent, "限制渲染帧率的上限，用来省电或让帧率更稳：30 / 60 / 120 / 240 帧，或「无上限」交给屏幕刷新率。改完立刻生效，不用重开游戏；显示 FPS 打开后能在游玩界面左上角看到实际帧率。")


func _choose_max_fps(fps: int) -> void:
	Setting.set_max_fps(fps)
	_queue_save()


## 实时读数：当前谱面（若已加载）的 offset、这张谱的单曲延迟与两个偏移相加，得到一个最终值。
## 格式与选曲界面共用 gd/ui/song_screen.gd 的 offset_breakdown，两边读数不会各说各话。
func _offset_readout() -> String:
	var loaded := ChartLoader.chart_data != null
	var chart_offset := ChartLoader.chart_data.offset if loaded else 0.0
	var song := Setting.song_offset_of(ChartLoader.selected_folder)
	return UI.offset_breakdown(song, Setting.offset, Setting.chart_offset, chart_offset) if loaded else \
		UI.offset_breakdown(song, Setting.offset, Setting.chart_offset, 0.0) + "（当前未加载谱面，谱面 offset 先按 0 计；游玩时用实际谱面重算）"


func _skin_number(parent: VBoxContainer, slot: String, key: String, title: String, minimum: float, maximum: float, step: float, default_value: float, suffix: String = "") -> void:
	_number_control(parent, title, minimum, maximum, step, suffix,
		func(): return float(Setting.get_skin(slot).get(key, default_value)),
		func(value: float):
			Setting.set_skin_field(slot, key, int(value) if step >= 1 else value)
			_queue_save(), default_value, maximum <= 400, "skin:" + slot + ":" + key)


func _number_control(parent: VBoxContainer, title: String, minimum: float, maximum: float, step: float, suffix: String, getter: Callable, setter: Callable, default_value: float, with_slider: bool = true, tag: String = "") -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(row, title, 21)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var number := SpinBox.new()
	number.min_value = minimum
	number.max_value = maximum
	number.step = step
	number.suffix = suffix.strip_edges()
	number.custom_minimum_size = Vector2(150, 48)
	row.add_child(number)
	number.value_changed.connect(setter)
	var reset := _button(row, "↺", func(): setter.call(default_value))
	reset.tooltip_text = "恢复默认值"
	_refreshers.append(func(): number.set_value_no_signal(float(getter.call())))
	if with_slider:
		var slider := HSlider.new()
		slider.min_value = minimum
		slider.max_value = maximum
		slider.step = step
		slider.custom_minimum_size.y = 40
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(setter)
		parent.add_child(slider)
		_refreshers.append(func(): slider.set_value_no_signal(float(getter.call())))
		# 标签只给自检与定位用：按 meta 查找控件，不必依赖控件的显示文案。
		if not tag.is_empty():
			number.set_meta("dakumi_setting", tag)
			slider.set_meta("dakumi_setting", tag)


func _curve_number(parent: VBoxContainer, slot: String, index: int, title: String, minimum: float, maximum: float, default_value: float) -> void:
	_number_control(parent, title, minimum, maximum, 0.01, "",
		func() -> float:
			var curve: Array = Setting.get_skin(slot).get("scale_curve", Setting.DEFAULT_HIT_CURVE)
			return float(curve[index]) if index < curve.size() else default_value,
		func(value: float):
			var curve: Array = Setting.get_skin(slot).get("scale_curve", Setting.DEFAULT_HIT_CURVE).duplicate()
			while curve.size() < 4:
				curve.append(default_value)
			curve[index] = value
			Setting.set_skin_field(slot, "scale_curve", curve)
			_queue_save(), default_value, true, "curve:" + slot + ":" + str(index))


## 单图打击特效：在显示时长的前 HIT_SCALE_IN_RATIO 段里从 0 缩放到设定大小，
## 缩放过程用三次贝塞尔 (x1, y1) / (x2, y2) 描述——X 是进度，Y 是倍率（可超过 1 做回弹）。
func _hit_scale_sliders(parent: VBoxContainer, slot: String) -> void:
	_hint(parent, "单图 Hit 会在显示时长的前 %d%% 内从 0 缩放到设定大小，过程由下面四个值决定：X 是进度、Y 是倍率，Y 可以大于 1 做出回弹。帧数大于 1 的精灵图按素材逐帧播放，不受这条曲线影响。"
		% int(round(Skins.HIT_SCALE_IN_RATIO * 100.0)))
	var titles := ["曲线 X1（进度）", "曲线 Y1（倍率）", "曲线 X2（进度）", "曲线 Y2（倍率）"]
	var maximums := [1.0, 2.0, 1.0, 2.0]
	for index in 4:
		_curve_number(parent, slot, index, titles[index], 0.0, maximums[index], Setting.DEFAULT_HIT_CURVE[index])
	var presets := HBoxContainer.new()
	parent.add_child(presets)
	for preset in [["线性", [0.0, 0.0, 1.0, 1.0]], ["缓出（默认）", Setting.DEFAULT_HIT_CURVE], ["回弹", [0.34, 1.56, 0.64, 1.0]]]:
		var curve: Array = preset[1]
		_button(presets, preset[0], func():
			Setting.set_skin_field(slot, "scale_curve", curve.duplicate())
			_queue_save())


func _card(parent: VBoxContainer, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	_label(content, title, 24).modulate = ImGuiTheme.TEXT
	return content


func _label(parent: Node, title: String, font_size: int = 22) -> Label:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _hint(parent: Node, title: String) -> void:
	var label := _label(parent, title, 18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = ImGuiTheme.TEXT_DISABLED


func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _refresh_values() -> void:
	for refresh in _refreshers:
		refresh.call()


func _queue_save() -> void:
	_save_timer.start()


func _message(message: String, error: bool = false) -> void:
	_status.text = message
	_status.modulate = ImGuiTheme.ERROR_TEXT if error else ImGuiTheme.TEXT


func _adapt_layout() -> void:
	if not is_instance_valid(_body):
		return
	var portrait := size.x < size.y * 1.15
	_body.vertical = portrait
	if portrait:
		_preview_panel.size_flags_vertical = Control.SIZE_FILL
		_preview_panel.custom_minimum_size = Vector2(0, clampf(size.y * 0.32, 300, 510))
	else:
		_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_preview_panel.custom_minimum_size = Vector2(minf(440, size.x * 0.36), 0)
	if is_instance_valid(_preview):
		_preview.call("configure", _preview_area.size)


func _leave() -> void:
	Setting.save_settings()
	get_tree().change_scene_to_file("res://gd/room/startroom.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_leave()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Setting.save_settings()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED and is_instance_valid(_save_timer):
		Setting.save_settings()
