extends Control
## 选曲界面：左侧歌曲信息、右侧谱面库。造型与设置界面共用一套构件
## （gd/ui/song_screen.gd），触屏上整屏都能上下拖动来滚动谱面库。
## 谱面库用 ItemList：它自己不响应手指拖动，所以设成 PASS 让手势上抛给根节点，
## 轻点选中走的仍是引擎生成的模拟鼠标事件。
const UI = preload("res://gd/ui/song_screen.gd")
const TouchScroll = preload("res://gd/ui/touch_scroll.gd")
const ImportButton = preload("res://gd/object/stratroom/ImportZip.button.gd")
## 单曲延迟滑条的粗调范围（毫秒）；数值框不受它限制，可以键入任意值。
const OFFSET_SLIDER_RANGE := 2000.0
## 最佳成绩面板的宽度与字号：它固定在歌曲信息右侧，窄屏时压缩一档（宽度与字号一起变）。
const SCORE_PANEL_WIDTH := 330.0
const SCORE_PANEL_WIDTH_NARROW := 260.0
const SCORE_SIZE := 54
const SCORE_SIZE_NARROW := 40
## 没有成绩时分数位的占位符：一眼能看出不是 0 分。
const SCORE_EMPTY := "-------"
const SCORE_EMPTY_HINT := "通关一次后，这里显示这一首最好的一次分数。"
var _body: BoxContainer
var _song_card: VBoxContainer
var _list: ItemList
var _search: LineEdit
var _art: TextureRect
var _title: Label
var _credits: Label
var _difficulty: Label
var _details: Label
var _status: Label
var _count: Label
var _play: Button
var _offset_box: SpinBox
var _offset_slider: HSlider
var _offset_readout: Label
var _score_panel: VBoxContainer
var _score: Label
var _score_summary: Label
var _score_hint: Label
var _score_grid: GridContainer
var _score_values: Dictionary = {}
var _entries: Array[Dictionary] = []
var _paths: Array[String] = []
var _loaded_folder := ""
var _timer: Timer
var _save_timer: Timer

func _ready() -> void:
	get_tree().auto_accept_quit = false
	var shell := UI.shell(self)
	var header := HBoxContainer.new()
	shell.add_child(header)
	UI.label(header, "DAKUMI / 选曲", 31).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var importer := Button.new()
	importer.set_script(ImportButton)
	importer.custom_minimum_size.y = 48
	header.add_child(importer)
	UI.button(header, "设置", func(): get_tree().change_scene_to_file("res://gd/room/settings.tscn"))
	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 20)
	shell.add_child(_body)
	_song_card = UI.card(_body, "歌曲信息")
	_song_card.get_parent().size_flags_stretch_ratio = 1.35
	_art = UI.artwork(_song_card)
	# 歌曲信息左边一栏、最佳成绩右边一栏：成绩写在歌曲信息的右侧（窄屏时它自己缩一档）。
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 18)
	_song_card.add_child(info_row)
	var info := UI.column(info_row, 8)
	_difficulty = UI.label(info, "等待选择", 21)
	_difficulty.add_theme_color_override("font_color", UI.Style.ACCENT)
	_title = UI.label(info, "选择一首歌，开始游玩", 36)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credits = UI.label(info, "", 21, true)
	_credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details = UI.label(info, "", 19, true)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_score(info_row)
	_build_offset(_song_card)
	var library := UI.card(_body, "谱面库")
	_count = UI.hint(library, "共 0 首谱面")
	_search = LineEdit.new()
	_search.placeholder_text = "搜索曲名或文件夹…"
	_search.custom_minimum_size.y = 48
	_search.text_changed.connect(func(_text: String): _filter())
	library.add_child(_search)
	_list = UI.chart_list(library)
	_list.item_selected.connect(_selected)
	# 底部一行：左边状态提示，右边开始游玩（安卓上拇指最容易够到的位置）。
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	shell.add_child(footer)
	_status = UI.label(footer, "", 19, true)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_play = UI.button(footer, "开始游玩  →", _start)
	_play.name = "PlayChart"
	_play.custom_minimum_size = Vector2(280, 68)
	_play.disabled = true
	TouchScroll.pass_through(self)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.15
	_timer.timeout.connect(_load_selection)
	add_child(_timer)
	# 单曲延迟改一下就写盘，但不要每拖一格都写：用防抖计时器合并成一串改动里的最后一次。
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.6
	_save_timer.timeout.connect(Setting.save_settings)
	add_child(_save_timer)
	Storage.library_changed.connect(_refresh)
	Storage.storage_changed.connect(_refresh)
	Scores.score_changed.connect(func(_folder: String): _sync_score())
	resized.connect(_adapt)
	_adapt()
	_refresh()

## 手指在非交互区域上下拖动时滚动谱面库；桌面端滚轮等效。
## 落在滑块、按钮、输入框上的拖动仍然是控件自己的操作（那些事件不会冒泡到这里）。
func _gui_input(event: InputEvent) -> void:
	if TouchScroll.handle(self, event, func() -> Object: return _list):
		accept_event()

## 最佳成绩：歌曲信息右边一栏。内容与结算界面同一套统计（最高分、最大连击、
## 判定数量、游玩次数），只是在这里压得更小；没有成绩时显示占位符与提示。
func _build_score(parent: Control) -> void:
	_score_panel = VBoxContainer.new()
	_score_panel.add_theme_constant_override("separation", 6)
	# 不参与横向扩展：左侧歌曲信息吃掉剩余宽度，这一栏就贴在它右边。
	_score_panel.size_flags_horizontal = Control.SIZE_FILL
	parent.add_child(_score_panel)
	UI.label(_score_panel, "最佳成绩", 19, true)
	_score = UI.label(_score_panel, SCORE_EMPTY, SCORE_SIZE)
	_score.add_theme_color_override("font_color", UI.Style.ACCENT)
	_score.set_meta("dakumi_setting", "song:score")
	_score_summary = UI.label(_score_panel, "", 19, true)
	_score_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_score_summary.set_meta("dakumi_setting", "song:score_summary")
	_score_grid = GridContainer.new()
	_score_grid.columns = UI.GRADES.size()
	_score_grid.add_theme_constant_override("h_separation", 12)
	_score_grid.add_theme_constant_override("v_separation", 4)
	_score_panel.add_child(_score_grid)
	for index in UI.GRADES.size():
		var grade: String = UI.GRADES[index]
		var cell := UI.column(_score_grid, 0)
		var value := UI.label(cell, "—", 26)
		value.add_theme_color_override("font_color", UI.grade_color(grade))
		value.set_meta("dakumi_setting", "song:score_grade:" + grade)
		_score_values[grade] = value
		UI.label(cell, UI.GRADE_NAMES[index], 15, true)
	_score_hint = UI.hint(_score_panel, SCORE_EMPTY_HINT)
	_score_hint.set_meta("dakumi_setting", "song:score_hint")


## 单曲延迟：只作用于列表里当前这首歌（按文件夹名记住，见 Setting.song_offset_of）。
## 和时间偏移一样不设上限，数值框可以键入任意毫秒值；下面那条滑条只是常用范围里的粗调。
func _build_offset(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := UI.label(row, "单曲延迟", 21)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_offset_box = SpinBox.new()
	_offset_box.min_value = -OFFSET_SLIDER_RANGE
	_offset_box.max_value = OFFSET_SLIDER_RANGE
	_offset_box.allow_greater = true
	_offset_box.allow_lesser = true
	_offset_box.step = 1.0
	_offset_box.suffix = " ms"
	_offset_box.custom_minimum_size = Vector2(170, 48)
	_offset_box.set_meta("dakumi_setting", "song:offset")
	row.add_child(_offset_box)
	_offset_box.value_changed.connect(_apply_offset)
	var reset := UI.button(row, "↺", func(): _apply_offset(0.0))
	reset.tooltip_text = "这首歌的延迟归零"
	_offset_slider = HSlider.new()
	_offset_slider.min_value = -OFFSET_SLIDER_RANGE
	_offset_slider.max_value = OFFSET_SLIDER_RANGE
	_offset_slider.step = 1.0
	_offset_slider.custom_minimum_size.y = 40
	_offset_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offset_slider.set_meta("dakumi_setting", "song:offset")
	_offset_slider.value_changed.connect(_apply_offset)
	parent.add_child(_offset_slider)
	_offset_readout = UI.label(parent, "", 18, true)
	_offset_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_offset_readout.set_meta("dakumi_setting", "song:offset_readout")
	UI.hint(parent, "每首歌各自的延迟，换歌显示各自的数值；最终延迟 = 单曲延迟 + 时间偏移 - 谱面偏移 + 谱面自带的 offset。这里不设上下限（时间偏移限 ±3000 ms，谱面自带 offset 特别大的谱子可以在这一项或谱面偏移里拉回来）。")


func _apply_offset(value: float) -> void:
	var folder := ChartLoader.selected_folder
	if folder.is_empty():
		return
	Setting.set_song_offset(folder, value)
	_sync_offset()
	_save_timer.start()


## 把当前选中歌曲的延迟回填到两个控件与读数上：换歌、清空搜索、谱面读取完成之后都要走一遍。
func _sync_offset() -> void:
	var folder := ChartLoader.selected_folder
	var selectable := not folder.is_empty()
	_offset_box.editable = selectable
	_offset_slider.editable = selectable
	_offset_box.set_value_no_signal(Setting.song_offset_of(folder) if selectable else 0.0)
	_offset_slider.set_value_no_signal(Setting.song_offset_of(folder) if selectable else 0.0)
	_offset_readout.text = _offset_text(folder)


## 读数里的谱面 offset 只在「这张谱已经读完」时计入：选择刚变、还在读取的那 0.15 秒里
## 显示的是上一首歌的 offset，先按 0 算并注明，免得读数与马上开唱的那张谱对不上。
func _offset_text(folder: String) -> String:
	if folder.is_empty():
		return "先选一首歌，再调它的单曲延迟。"
	var fresh := ChartLoader.chart_data != null and _loaded_folder == folder
	var chart_offset := ChartLoader.chart_data.offset if fresh else 0.0
	var text := UI.offset_breakdown(Setting.song_offset_of(folder), Setting.offset, Setting.chart_offset, chart_offset)
	return text if fresh else text + "（这张谱的 offset 读取后计入）"


## 把当前选中歌曲的成绩回填到面板上。成绩只跟文件夹名有关，与谱面读没读完无关，
## 所以和单曲延迟一样在换歌、清空搜索、读取完成的位置各走一遍。
func _sync_score() -> void:
	var entry := Scores.best(ChartLoader.selected_folder)
	var counts: Dictionary = entry.get("counts", {})
	for grade in UI.GRADES:
		(_score_values[grade] as Label).text = str(int(counts.get(grade, 0))) if not entry.is_empty() else "—"
	_score.text = UI.score_text(int(entry.get("score", 0))) if not entry.is_empty() else SCORE_EMPTY
	_score_summary.text = _score_summary_text(entry) if not entry.is_empty() else "还没有成绩"
	_score_hint.text = _score_hint_text(entry)


func _score_summary_text(entry: Dictionary) -> String:
	var parts: Array[String] = ["最大连击 %d" % int(entry.get("max_combo", 0)), "游玩 %d 次" % int(entry.get("plays", 0))]
	# 最好那一局的平均击打延迟（按下 Tap / Hold 的平均偏差）；老成绩没有按点样本就不显示。
	var latency := UI.latency_brief(float(entry.get("average_offset", 0.0)), int(entry.get("offset_samples", 0)))
	if not latency.is_empty():
		parts.append("平均延迟 " + latency)
	var played := UI.date(int(entry.get("time", 0)))
	if not played.is_empty():
		parts.append("最近 " + played)
	return "   ·   ".join(parts)


## 成绩记在另一种判定模式下时说明一句：同一个谱面换模式后难度不一样，分数不宜直接比。
func _score_hint_text(entry: Dictionary) -> String:
	if entry.is_empty():
		return SCORE_EMPTY_HINT
	var mode := str(entry.get("mode", ""))
	if mode.is_empty() or mode == Setting.judge_position_mode:
		return ""
	return "这次成绩记录于「%s」模式，当前设置是「%s」。" % [UI.mode_name(mode), UI.mode_name(Setting.judge_position_mode)]


func _adapt() -> void:
	# 窄屏（竖屏或小窗口）改成上下排列，和设置界面同一套判据。
	var portrait := size.x < size.y * 1.15
	_body.vertical = portrait
	# 封面取一个下限、由布局把余量分给它：屏幕矮的时候卡片不至于顶掉底部按钮。
	_art.custom_minimum_size.y = 110 if portrait else 130
	# 成绩栏在窄屏里瘦一档，把宽度让给左边的歌曲信息；判定数量跟着改成两行。
	_score_panel.custom_minimum_size.x = SCORE_PANEL_WIDTH_NARROW if portrait else SCORE_PANEL_WIDTH
	_score.add_theme_font_size_override("font_size", SCORE_SIZE_NARROW if portrait else SCORE_SIZE)
	_score_grid.columns = 3 if portrait else UI.GRADES.size()

func _refresh(new_path: String = "") -> void:
	if not new_path.is_empty():
		ChartLoader.selected_folder = new_path
	_entries = Storage.library_directories()
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	_loaded_folder = ""
	_search.set_block_signals(true)
	_search.text = ""
	_search.set_block_signals(false)
	_filter()

func _filter() -> void:
	_timer.stop()
	_list.clear()
	_paths.clear()
	var query := _search.text.strip_edges().to_lower()
	for entry in _entries:
		var text := str(entry.get("title", entry.name))
		if not query.is_empty() and not query in (text + " " + str(entry.name)).to_lower():
			continue
		_paths.append(entry.path)
		_list.add_item(text)
	_count.text = ("匹配 %d 首谱面" if not query.is_empty() else "共 %d 首谱面 · 轻点列表选择") % _paths.size()
	if _paths.is_empty():
		_list.add_item("暂无谱面 · 点击上方导入" if _entries.is_empty() else "没有匹配的谱面")
		_list.set_item_disabled(0, true)
		_play.disabled = true
		_art.texture = null
		_title.text = "导入你的第一首歌" if _entries.is_empty() else "换个关键词试试"
		_credits.text = "支持 ZIP 压缩包和谱面文件夹"
		_difficulty.text = "DAKUMI"
		_details.text = ""
		_status.text = Storage.status_message
		if _entries.is_empty():
			ChartLoader.selected_folder = ""
		_sync_offset()
		_sync_score()
		return
	var index := maxi(0, _paths.find(ChartLoader.selected_folder))
	_list.select(index)
	_selected(index)

func _selected(index: int) -> void:
	if index < 0 or index >= _paths.size():
		return
	ChartLoader.selected_folder = _paths[index]
	_play.disabled = true
	_status.text = "正在读取谱面…"
	# 立刻切到这首歌的延迟数值与它的成绩，不用等谱面读完。
	_sync_offset()
	_sync_score()
	_timer.start()

func _load_selection() -> void:
	var folder := ChartLoader.selected_folder
	if folder != _loaded_folder:
		if not ChartLoader.load_from_folder(folder):
			_status.text = "无法读取：" + ChartLoader.last_error
			_title.text = Storage.display_name(folder)
			_art.texture = null
			_credits.text = "请检查谱面文件，或在设置中启用对应读取扩展。"
			_difficulty.text = "读取失败"
			_details.text = ""
			_sync_offset()
			_sync_score()
			return
		_loaded_folder = folder
		_loaded_folder = folder
	var info: Dictionary = ChartLoader.chart_data.info
	_title.text = UI.title(info, Storage.display_name(folder))
	_art.texture = ChartLoader.bg
	_credits.text = UI.credits(info)
	_difficulty.text = UI.difficulty(info)
	_details.text = "%s   /   %d 个音符   /   %d 判定单位" % [UI.duration(ChartLoader.getAlltime()), ChartLoader.chart_data.note.size(), ChartLoader.getAllcombo()]
	for entry in _entries:
		if entry.path == folder:
			entry.title = _title.text + "  ·  " + _difficulty.text
	var index := _paths.find(folder)
	if index >= 0:
		_list.set_item_text(index, _title.text + "  ·  " + _difficulty.text)
	_status.text = "准备就绪 · " + UI.mode_name(Setting.judge_position_mode)
	_play.disabled = false
	# 谱面读完，读数里的谱面 offset 现在可以计入。
	_sync_offset()
	_sync_score()

func _start() -> void:
	if _play.disabled or _loaded_folder != ChartLoader.selected_folder:
		return
	ChartLoader.last_result.clear()
	get_tree().change_scene_to_file("res://gd/room/demo.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _search.has_focus():
		_start()


func _notification(what: int) -> void:
	# 选曲是根界面：安卓返回键在这里就是退出应用（其他界面各自“返回上一级”）。
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
