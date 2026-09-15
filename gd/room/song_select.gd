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
## 过滤后的歌曲文件夹（列表顺序）；列表行号不等于它的下标，见 _rows。
var _paths: Array[String] = []
## 列表的每一行：kind 是 "song"（歌曲）或 "chart"（选中歌曲展开出来的谱面），
## 下标与 ItemList 的行号一一对应。
var _rows: Array[Dictionary] = []
## 歌曲文件夹 → 扫描到的全部谱面（ImportAPI.list_charts 的结果）；改动库内容后整份丢掉重扫。
var _charts: Dictionary = {}
## 正在删除文件：此时 Storage 广播的刷新先跳过，删完由我们统一刷新一次。
var _deleting := false
## 列表当前已经画成什么样：展开的是哪首歌、圆点标在哪张谱面。轻点同一行时用它判断要不要重排。
var _expanded := ""
var _marked := ""
var _rebuild_queued := false
var _manage: Button
var _loaded_folder := ""
var _loaded_chart := ""
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
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 12)
	library.add_child(toolbar)
	_count = UI.hint(toolbar, "共 0 首歌")
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 管理：删除谱面 / 删除整首歌。放在列表上方，和列表内容不会挤在一起。
	_manage = UI.button(toolbar, "管理  ▾", _open_manage)
	_manage.name = "ManageLibrary"
	_manage.custom_minimum_size = Vector2(150, 40)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索曲名或文件夹…"
	_search.custom_minimum_size.y = 48
	_search.text_changed.connect(func(_text: String): _filter())
	library.add_child(_search)
	_list = UI.chart_list(library)
	_list.item_selected.connect(_item_picked)
	# 轻点已经选中的那一行只会发 item_clicked（选中项没变），而“第一首歌一进来就是选中的”，
	# 所以展开必须两个信号都听；重复通知由 _item_picked 里的闸门挡掉。
	_list.item_clicked.connect(func(index: int, _at: Vector2, _button: int) -> void: _item_picked(index))
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
	Storage.library_changed.connect(func(new_path: String) -> void: _refresh(new_path))
	Storage.storage_changed.connect(func() -> void: _refresh())
	Scores.score_changed.connect(func(_key: String): _sync_score())
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


## 把当前选中谱面的成绩回填到面板上。一个文件夹里有几张谱面就按谱面分记（见 Scores.key_of），
## 只有一张时仍然是这首歌的成绩；与谱面读没读完无关，所以和单曲延迟一样在换歌、
## 换谱面、清空搜索、读取完成的位置各走一遍。
func _sync_score() -> void:
	var entry := Scores.best(ChartLoader.selected_folder, ChartLoader.selected_chart, _charts_of(ChartLoader.selected_folder).size())
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

## 重读谱面库。传入 new_path 时选中它（导入完成后的广播就带着新目录）；
## keep_search 保留搜索词——删除之后列表本来就短了，顺手清空搜索框只会让人找不着北。
## 整份谱面缓存都会作废：库内容变了，扫描结果不再可信。
func _refresh(new_path: String = "", keep_search := false) -> void:
	if _deleting:
		return
	if not new_path.is_empty():
		ChartLoader.selected_folder = new_path
		ChartLoader.selected_chart = ""
	_entries = Storage.library_directories()
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	_charts.clear()
	_loaded_folder = ""
	_loaded_chart = ""
	if not keep_search:
		_search.set_block_signals(true)
		_search.text = ""
		_search.set_block_signals(false)
	_filter()


## 按搜索词重排列表：一首歌一行，当前选中（＝点开）的那首下面再列出它的全部谱面。
## keep_scroll 保留滚动位置：轻点展开会让列表变长，不保留就会跳回顶部。
func _filter(keep_scroll: bool = false) -> void:
	_timer.stop()
	_rebuild_queued = false
	_expanded = ""
	_marked = ChartLoader.selected_chart
	var scroll := _list.get_v_scroll_bar().value if keep_scroll else 0.0
	_list.clear()
	_rows.clear()
	_paths.clear()
	var selected_folder := ChartLoader.selected_folder
	# 选中的谱面可能刚被删掉：对不上这个文件夹里的任何一张就退回默认谱面。
	if not ChartLoader.selected_chart.is_empty() and not _has_chart(selected_folder, ChartLoader.selected_chart):
		ChartLoader.selected_chart = ""
	var query := _search.text.strip_edges().to_lower()
	for entry in _entries:
		var text := str(entry.get("title", entry.name))
		if not query.is_empty() and not query in (text + " " + str(entry.name)).to_lower():
			continue
		_paths.append(entry.path)
		_rows.append({"kind": "song", "folder": entry.path})
		_list.add_item(("▾ " if entry.path == selected_folder else "▸ ") + text)
		if entry.path == selected_folder:
			_append_charts(entry.path)
			_expanded = entry.path
			_marked = ChartLoader.selected_chart
	_count.text = ("匹配 %d 首歌" if not query.is_empty() else "共 %d 首歌 · 轻点展开全部谱面") % _paths.size()
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
			ChartLoader.selected_chart = ""
		_sync_offset()
		_sync_score()
		return
	var index := maxi(0, _row_of_selection())
	_list.set_block_signals(true)
	_list.select(index)
	_list.set_block_signals(false)
	_selected(index)
	if keep_scroll:
		_list.get_v_scroll_bar().value = scroll


## 把一首歌的全部谱面作为子行接在它后面。扫描为空时留一行说明（空文件夹在自检里就是这么用的），
## 免得点开之后看上去什么都没发生。当前要游玩的那张用 ● 标出来。
func _append_charts(folder: String) -> void:
	var charts := _charts_of(folder)
	if charts.is_empty():
		_rows.append({"kind": "note", "folder": folder})
		_list.add_item("      没有找到可读取的谱面")
		_list.set_item_disabled(_rows.size() - 1, true)
		return
	for chart in charts:
		var path := str(chart.chart)
		_rows.append({"kind": "chart", "folder": folder, "chart": path})
		_list.add_item("      %s %s" % ["●" if path == ChartLoader.selected_chart else "○", _chart_text(chart)])


## 一个文件夹里的全部谱面，带缓存：扫描要读目录里的每个 JSON，切歌、搜索时不该反复做。
## 缓存放进普通 Dictionary，取出来只是无类型数组，所以要 assign() 回有类型的变量。
func _charts_of(folder: String) -> Array[Dictionary]:
	var charts: Array[Dictionary] = []
	if folder.is_empty():
		return charts
	if not _charts.has(folder):
		_charts[folder] = ImportAPI.list_charts(folder)
	charts.assign(_charts[folder])
	return charts


func _has_chart(folder: String, chart: String) -> bool:
	for entry in _charts_of(folder):
		if str(entry.chart) == chart:
			return true
	return false


## 谱面的显示名：难度名 + 等级（读取器给的标签，给不出就是文件名）。
static func _chart_text(chart: Dictionary) -> String:
	var label := str(chart.get("label", ""))
	var detail := str(chart.get("detail", ""))
	return label + (" " + detail if not detail.is_empty() else "")


## 当前选中项在列表里的行号：谱面行优先，退回歌曲行，找不到就是 -1。
## 说明行（没有可读谱面的文件夹）两种都不是，只会在所属歌曲那一行上停一下。
func _row_of_selection() -> int:
	var song := -1
	for index in _rows.size():
		var row: Dictionary = _rows[index]
		if str(row.folder) != ChartLoader.selected_folder:
			continue
		match str(row.kind):
			"song":
				song = index
			"chart":
				if str(row.chart) == ChartLoader.selected_chart:
					return index
	return song


## 轻点一行：选中它；选中的歌展开成全部谱面，选中的谱面成为要游玩的那张。
## 展开要重排列表，而重排不能在 ItemList 发信号的过程中做，所以放到本帧末尾。
func _item_picked(index: int) -> void:
	_selected(index)
	# 展开的那首没变、标中的谱面也没变，就不必重排
	#（点同一行会连着来两次通知，见 _ready 里的连接）。
	if _rebuild_queued or (ChartLoader.selected_folder == _expanded and ChartLoader.selected_chart == _marked):
		return
	_rebuild_queued = true
	_filter.call_deferred(true)


## 选中一行：谱面行选那张谱面，歌曲行回到这首歌的默认（第一张）谱面。
## 选中的歌就是展开的那首，所以这里同时决定了列表里展开的是谁。
func _selected(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	var row: Dictionary = _rows[index]
	var folder := str(row.folder)
	ChartLoader.selected_folder = folder
	if str(row.kind) == "chart":
		ChartLoader.selected_chart = str(row.chart)
	else:
		var charts := _charts_of(folder)
		ChartLoader.selected_chart = str(charts[0].chart) if not charts.is_empty() else ""
	_play.disabled = true
	_status.text = "正在读取谱面…"
	# 立刻切到这首歌的延迟数值与它的成绩，不用等谱面读完。
	_sync_offset()
	_sync_score()
	_timer.start()


func _load_selection() -> void:
	var folder := ChartLoader.selected_folder
	var chart := ChartLoader.selected_chart
	if folder != _loaded_folder or chart != _loaded_chart:
		if not ChartLoader.load_from_folder(folder, chart):
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
		_loaded_chart = chart
	var info: Dictionary = ChartLoader.chart_data.info
	_title.text = UI.title(info, Storage.display_name(folder))
	_art.texture = ChartLoader.bg
	_credits.text = UI.credits(info)
	_difficulty.text = UI.difficulty(info)
	_details.text = "%s   /   %d 个音符   /   %d 判定单位" % [UI.duration(ChartLoader.getAlltime()), ChartLoader.chart_data.note.size(), ChartLoader.getAllcombo()]
	_status.text = "准备就绪 · " + UI.mode_name(Setting.judge_position_mode)
	_play.disabled = false
	# 谱面读完，读数里的谱面 offset 现在可以计入。
	_sync_offset()
	_sync_score()


func _start() -> void:
	if _play.disabled or _loaded_folder != ChartLoader.selected_folder or _loaded_chart != ChartLoader.selected_chart:
		return
	ChartLoader.last_result.clear()
	get_tree().change_scene_to_file("res://gd/room/demo.tscn")

# ---------------------------------------------------------------- 管理：删除谱面 / 歌曲

## 管理菜单：删掉当前这张谱面，或删掉整首歌。两条都要再确认一次（见 _confirm_delete）。
func _open_manage() -> void:
	var folder := ChartLoader.selected_folder
	var chart := _active_chart(folder)
	var menu := PopupMenu.new()
	menu.name = "LibraryMenu"
	if folder.is_empty() or chart.is_empty():
		var reason := "先选中一首歌" if folder.is_empty() else "这个文件夹里没有可删除的谱面"
		menu.add_item(reason, 0)
		menu.set_item_disabled(0, true)
	else:
		menu.add_item("删除谱面 %s…" % _chart_text(chart), 0)
		menu.add_item("删除整首歌…", 1)
	menu.id_pressed.connect(func(id: int) -> void:
		menu.queue_free()
		if id == 0:
			_ask_delete_chart(folder, chart)
		else:
			_ask_delete_song(folder))
	add_child(menu)
	menu.popup_centered()


## 菜单与删除操作针对的那张谱面：选中了谱面行就是它，否则是这个文件夹的默认谱面。
func _active_chart(folder: String) -> Dictionary:
	var charts := _charts_of(folder)
	for chart in charts:
		if str(chart.chart) == ChartLoader.selected_chart:
			return chart
	return charts[0] if not charts.is_empty() else {}


func _ask_delete_chart(folder: String, chart: Dictionary) -> void:
	var song := Storage.display_name(folder)
	# 只剩一张谱面时删掉它，这首歌就没有谱面了：整个文件夹一起删，免得库里留下一个点不开的空条目。
	if _charts_of(folder).size() <= 1:
		_confirm_delete("删除谱面", "《%s》只剩这一张谱面（%s）。\n\n删除后整个文件夹——包括音频、封面、这首歌的成绩与单曲延迟——都会一并删除，且无法撤销。" % [song, _chart_text(chart)],
			func() -> void: _delete_song(folder))
		return
	_confirm_delete("删除谱面", "删除《%s》的 %s？\n\n只删掉这张谱面文件（含编辑中的同名谱面），歌曲、音频与其余谱面都保留。" % [song, _chart_text(chart)],
		func() -> void: _delete_chart(folder, str(chart.chart), _chart_text(chart)))


func _ask_delete_song(folder: String) -> void:
	_confirm_delete("删除整首歌", "删除《%s》？\n\n整个文件夹以及其中的音频、封面都会被删除，这首歌的成绩与单曲延迟也一起清掉。无法撤销。" % Storage.display_name(folder),
		func() -> void: _delete_song(folder))


## 二次确认：删除按钮标成错误色，焦点留在「取消」上（弹出后抢回焦点），
## 免得手指还停在原处、或者顺手一个回车就把整首歌点没了。
func _confirm_delete(title: String, message: String, action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "DeleteConfirm"
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = "删除"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		action.call())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.get_ok_button().add_theme_color_override("font_color", UI.Style.ERROR_TEXT)
	dialog.popup_centered()
	dialog.get_cancel_button().call_deferred("grab_focus")


## 删除一张谱面：连它的 .editing 同名谱面一起删（同一个身份，见 ImportAPI.chart_identity）。
## 在谱面自己所在的目录里找同身份的文件——谱面可能不在文件夹顶层（ZIP 常见的嵌套目录）。
func _delete_chart(folder: String, chart: String, label: String) -> void:
	var identity := ImportAPI.chart_identity(chart)
	var directory := Storage.base_directory(chart)
	_deleting = true
	var failure := ""
	for entry in Storage.list_directory(directory if not directory.is_empty() else folder):
		if entry.is_dir or ImportAPI.chart_identity(str(entry.path)) != identity:
			continue
		if not Storage.delete_file(entry.path):
			failure = Storage.last_error
	_deleting = false
	if not failure.is_empty():
		_message("删除失败", failure)
		return
	Scores.forget_chart(folder, chart)
	_after_delete(folder, "已删除谱面 %s" % label)


## 删除整首歌：整个文件夹连同音频、封面一起删，并清掉它的成绩与单曲延迟。
func _delete_song(folder: String) -> void:
	_deleting = true
	var removed := Storage.delete_tree(folder)
	_deleting = false
	if not removed:
		_message("删除失败", Storage.last_error)
		return
	Scores.forget_song(folder)
	Setting.set_song_offset(folder, 0.0)
	_charts.erase(folder)
	if ChartLoader.selected_folder == folder:
		ChartLoader.selected_folder = ""
		ChartLoader.selected_chart = ""
	_after_delete(folder, "已删除整首歌：%s" % Storage.display_name(folder))


## 删除后重新读库：缓存与选中项都可能已经失效，交给 _refresh 收拾。
func _after_delete(folder: String, message: String) -> void:
	_charts.erase(folder)
	_refresh("", true)
	_status.text = message


func _message(title: String, message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message if not message.is_empty() else "未知错误。"
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _search.has_focus():
		_start()


func _notification(what: int) -> void:
	# 选曲是根界面：安卓返回键在这里就是退出应用（其他界面各自“返回上一级”）。
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
