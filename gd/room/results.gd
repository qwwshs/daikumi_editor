extends Control
## 结算界面：歌曲结束后由 demo.gd 写入 ChartLoader.last_result 再切到这里。
## 内容：歌曲背景、曲名、难度、曲师/谱师、分数、最大连击、各判定数量。
## 造型与设置、选曲界面共用一套构件（gd/ui/song_screen.gd）。
const UI = preload("res://gd/ui/song_screen.gd")
const TouchScroll = preload("res://gd/ui/touch_scroll.gd")
## 判定从高到低（UI.GRADES）；数字大、名字小，窄屏时两列换行。
const GRADES := UI.GRADES
const NAMES := UI.GRADE_NAMES
var _page: ScrollContainer
var _body: BoxContainer
var _art: TextureRect
var _title: Label
var _difficulty: Label
var _credits: Label
var _score: Label
var _max_combo: Label
var _average_offset: Label
var _grid: GridContainer
var _grade_values: Dictionary = {}
var _replay: Button

func _ready() -> void:
	get_tree().auto_accept_quit = false
	var result: Dictionary = ChartLoader.last_result
	var info: Dictionary = result.get("info", {})
	var shell := UI.shell(self)
	var header := HBoxContainer.new()
	shell.add_child(header)
	UI.label(header, "DAKUMI / 结算", 31).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(header, "游玩完成" if not result.is_empty() else "暂无成绩", 21, true)
	if result.get("is_best", false):
		var badge := UI.label(header, "新纪录！", 24)
		badge.add_theme_color_override("font_color", UI.Style.ACCENT)
		badge.set_meta("dakumi_setting", "result:record")
	_page = UI.page(shell)
	_body = UI.column(_page, 20)
	var song := UI.card(_body, "本次游玩")
	song.get_parent().size_flags_stretch_ratio = 1.25
	_art = UI.artwork(song)
	_art.texture = result.get("background")
	_difficulty = UI.label(song, UI.difficulty(info), 22)
	_difficulty.add_theme_color_override("font_color", UI.Style.ACCENT)
	_title = UI.label(song, UI.title(info), 38)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credits = UI.label(song, UI.credits(info), 21, true)
	_credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var stats := UI.card(_body, "成绩")
	UI.hint(stats, "SCORE / 分数")
	_score = UI.label(stats, UI.score_text(int(result.get("score", 0))), 68)
	_score.add_theme_color_override("font_color", UI.Style.ACCENT)
	var combo_row := HBoxContainer.new()
	stats.add_child(combo_row)
	UI.label(combo_row, "MAX COMBO / 最大连击", 21, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_max_combo = UI.label(combo_row, str(result.get("max_combo", 0)), 34)
	# 平均击打延迟：按下 Tap / Hold 的那一下离音符时刻的平均偏差（见 PlaySession.average_hit_offset）。
	var offset_row := HBoxContainer.new()
	stats.add_child(offset_row)
	UI.label(offset_row, "平均击打延迟 / TAP · HOLD", 21, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var offset_text := UI.latency_text(float(result.get("average_offset", 0.0)), int(result.get("offset_samples", 0)))
	_average_offset = UI.label(offset_row, offset_text if not offset_text.is_empty() else "—", 30)
	_average_offset.set_meta("dakumi_setting", "result:average_offset")
	# 判定数量：横排一列一个（窄屏两列），数字大、判定名小，颜色沿用游玩内的判定色。
	var counts: Dictionary = result.get("counts", {})
	_grid = GridContainer.new()
	_grid.columns = GRADES.size()
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 10)
	stats.add_child(_grid)
	var hits := 0
	for index in GRADES.size():
		var grade: String = GRADES[index]
		var value := int(counts.get(grade, 0))
		if grade != "miss":
			hits += value
		var cell := UI.column(_grid, 2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var number := UI.label(cell, str(value), 34)
		number.add_theme_color_override("font_color", UI.grade_color(grade))
		_grade_values[grade] = number
		UI.label(cell, NAMES[index], 19, true)
	UI.hint(stats, "命中 %d / %d 个判定单位 · Hold 头尾分别计数，假音符不计入 · %s"
		% [hits, int(result.get("total_units", 0)), UI.mode_name(str(result.get("position_mode", "")))])
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	shell.add_child(footer)
	UI.button(footer, "← 返回选曲", _back).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replay = UI.button(footer, "再来一次  ↻", _retry)
	_replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replay.disabled = result.is_empty() or ChartLoader.chart_data == null
	TouchScroll.pass_through(self)
	resized.connect(_adapt)
	_adapt()

## 手指上下拖动滚动本页（窄屏时内容比屏幕高）；桌面端滚轮等效。
func _gui_input(event: InputEvent) -> void:
	if TouchScroll.handle(self, event, func() -> Object: return _page):
		accept_event()

func _adapt() -> void:
	# 页里的 BoxContainer 不能换方向（父级是 ScrollContainer，Godot 会直接报错），
	# 所以结算页始终是「卡片竖排 + 整页滚动」，只调整字号、图高与判定列数。
	var portrait := size.x < size.y * 1.15
	_grid.columns = 2 if portrait else GRADES.size()
	_score.add_theme_font_size_override("font_size", 48 if portrait else 68)
	_art.custom_minimum_size.y = 150 if portrait else 200

func _back() -> void:
	get_tree().change_scene_to_file("res://gd/room/startroom.tscn")

func _retry() -> void:
	if _replay.disabled:
		return
	ChartLoader.last_result.clear()
	get_tree().change_scene_to_file("res://gd/room/demo.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
