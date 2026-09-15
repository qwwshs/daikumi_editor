extends Node
## 项目自检：不依赖人工操作，直接验证判定、时间轴、几何、皮肤、存储与导入链路。
##
##   godot --headless --path . res://tests/self_check.tscn      # 逻辑检查
##   godot --path . res://tests/self_check.tscn                 # 额外覆盖绘制探针
##
## 全部检查都会还原被修改的设置与临时文件；退出码 0 表示通过，1 表示有失败项。

const TAP_CHART := """
{
  "version": 1, "offset": 0,
  "bpm_list": [{"beat": [0,0,1], "bpm": 120}],
  "note": [
    {"type": "note", "beat": [1,0,1], "track": 1},
    {"type": "hold", "beat": [2,0,1], "beat2": [3,0,1], "track": 1},
    {"type": "wipe", "beat": [4,0,1], "track": 1},
    {"type": "note", "beat": [5,0,1], "track": 2, "fake": 1}
  ],
  "event": [{"type":"x","track":1,"beat":0,"from":50,"to":50},{"type":"w","track":1,"beat":0,"from":100,"to":100},{"type":"x","track":2,"beat":0,"from":50,"to":50},{"type":"w","track":2,"beat":0,"from":100,"to":100}],
  "track": {"1": {}, "2": {}},
  "preference": {"x_offset": 0, "event_scale": 100}
}
"""

## 事件谱面：轨道 1 在 beat 4 以宽度 0 出现并在 beat 6 长到 50（event_scale 100 ⇒ 半幅），
## 轨道 2 有音符但没有事件（默认居中全宽），轨道 3 既没有音符也没有事件（不可见），
## 轨道 4 的首个事件在 beat 8 且起始宽度非 0（事件开始前不显示），
## 轨道 5 是 w0thenShow 的线状轨道、事件同样从 beat 8 开始。
const EVENT_CHART := """
{
  "version": 1, "offset": 0,
  "bpm_list": [{"beat": [0,0,1], "bpm": 120}],
  "note": [
    {"type": "note", "beat": [1,0,1], "track": 1},
    {"type": "note", "beat": [1,0,1], "track": 2}
  ],
  "event": [
    {"type": "x", "beat": [4,0,1], "beat2": [4,0,1], "track": 1, "from": 50, "to": 50},
    {"type": "w", "beat": [4,0,1], "beat2": [6,0,1], "track": 1, "from": 0, "to": 50},
    {"type": "x", "beat": [8,0,1], "beat2": [8,0,1], "track": 4, "from": 25, "to": 25},
    {"type": "w", "beat": [8,0,1], "beat2": [8,0,1], "track": 4, "from": 30, "to": 30},
    {"type": "w", "beat": [8,0,1], "beat2": [8,0,1], "track": 5, "from": 0, "to": 0}
  ],
  "track": {"1": {}, "2": {}, "3": {}, "4": {}, "5": {"w0thenShow": 1}},
  "preference": {"x_offset": 0, "event_scale": 100}
}
"""

var _passed: int = 0
var _failures: Array[String] = []
var _probe: Node2D

## 选曲 / 结算界面自检用的谱面夹具：曲名、难度、曲师、谱师都写全，背景用固定颜色。
const SONG_CHART := """
{
  "version": 1, "offset": 0,
  "bpm_list": [{"beat": [0,0,1], "bpm": 120}],
  "note": [{"type": "note", "beat": [1,0,1], "track": 1}],
  "event": [],
  "track": {"1": {}},
  "preference": {"x_offset": 0, "event_scale": 100},
  "info": {"song_name": "自检曲目", "chart_name": "Master", "artist": "自检曲师", "chartor": "自检谱师", "level": "12"}
}
"""
## 夹具背景色：像素断言要在这个颜色上量，所以要挑一个不会被主题色撞上的蓝。
const FIXTURE_ART := Color(0.10, 0.40, 0.80, 1.0)
## 谱面库夹具的文件夹名：前缀相同，保证自然排序时“真谱面”排在假文件夹前面。
const FIXTURE_SONG := "user://chart/__self_check_a_song__"
const FIXTURE_FILLER := "user://chart/__self_check_b_filler_%02d__"
const FIXTURE_PIXELS := "user://chart/__self_check_pixels__"
## 一目录多谱面的夹具：同一个文件夹里放 chart.json（默认）与 extra.json（第二张谱面）。
## 两张谱面的音符数不同，界面上选中哪一张可以直接从加载结果认出来。
const MULTI_SONG := "user://chart/__self_check_multi__"
const MULTI_CHART := """
{
  "version": 1, "offset": 0,
  "bpm_list": [{"beat": [0,0,1], "bpm": 150}],
  "note": [
    {"type": "note", "beat": [1,0,1], "track": 1},
    {"type": "note", "beat": [2,0,1], "track": 1}
  ],
  "event": [],
  "track": {"1": {}},
  "preference": {"x_offset": 0, "event_scale": 100},
  "info": {"song_name": "自检多谱面", "chart_name": "Insane", "artist": "自检曲师", "chartor": "自检谱师", "level": "15"}
}
"""
## 自检期间成绩册写到这个临时文件：玩家真实的 user://scores.cfg 全程不动。
const SCORES_TEMP := "user://__self_check_scores__.cfg"
## 选曲 / 结算界面共用的主题构件：像素断言要拿它的取色当期望值。
const ImGuiTheme = preload("res://gd/ui/imgui_theme.gd")
const UI = preload("res://gd/ui/song_screen.gd")


func _ready() -> void:
	var original_settings := _read_optional(Setting.SETTINGS_PATH)
	Scores.file_path = SCORES_TEMP
	Scores.scores.clear()
	_check_timeline()
	_check_geometry()
	_check_settings()
	_check_skin()
	_check_judging()
	_check_takana_judge()
	_check_hit_offset()
	_check_offset_display()
	_check_shared_holds_and_slide_feedback()
	_check_position_modes()
	_check_curve_fast_path()
	_check_judge_layout()
	_check_result_statistics()
	_check_score_modes()
	_check_hit_sound()
	_check_tracks()
	_check_love_reference()
	_check_event_boundaries()
	_check_storage()
	_check_import_roundtrip()
	_check_takana_import()
	_check_takana_multi()
	_check_offset()
	_check_song_offset()
	_check_max_fps()
	_check_scores()
	await _check_draw_probe()
	await _check_stage_pixels()
	await _check_offset_display_pixels()
	await _check_note_overflow()
	await _check_hold_slices_and_lane_layers()
	await _check_scenes()
	await _check_multi_charts()
	await _check_result_scene()
	await _check_ui_pixels()
	# 还原磁盘设置与内存状态，避免自检影响真实游玩。
	if original_settings.is_empty():
		DirAccess.remove_absolute(Setting.SETTINGS_PATH)
	else:
		Storage.write_bytes(Setting.SETTINGS_PATH, original_settings)
	Setting.load_settings()
	# 成绩册同理：删掉临时文件，把路径指回玩家的成绩并重新读进内存。
	DirAccess.remove_absolute(SCORES_TEMP)
	Scores.file_path = Scores.SCORES_PATH
	Scores.load_scores()
	_finish_ok()


# ---------------------------------------------------------------- 时间轴

func _check_timeline() -> void:
	var timeline := BeatTimeline.new([{"beat": 0.0, "bpm": 120.0, "linear_ramp": 0}])
	_expect_close(timeline.to_time(1.0), 0.5, "时间轴：120 BPM 一小节 = 0.5 秒")
	_expect_close(timeline.to_beat(0.5), 1.0, "时间轴：时间 0.5 秒 = 第 1 拍")
	_expect_close(timeline.to_beat(timeline.to_time(7.25)), 7.25, "时间轴：正反转换一致")
	var ramp := BeatTimeline.new([
		{"beat": 0.0, "bpm": 120.0, "linear_ramp": 1},
		{"beat": 4.0, "bpm": 240.0, "linear_ramp": 0},
	])
	# 线性变化 BPM 的积分：t = 60/slope · ln(bpm_end / bpm_start)
	_expect_close(ramp.to_time(4.0), 60.0 / 30.0 * log(240.0 / 120.0), "时间轴：渐变 BPM 积分")
	_expect_close(ramp.to_beat(ramp.to_time(2.5)), 2.5, "时间轴：渐变 BPM 正反一致")
	var empty := BeatTimeline.new([])
	_expect_close(empty.to_time(1.0), 0.5, "时间轴：缺少 BPM 时按 120 处理")


# ---------------------------------------------------------------- 几何与倾斜

func _check_geometry() -> void:
	Setting.reset_layout()
	var geometry := PlayfieldGeometry.new()
	var layout := Setting.DEFAULT_LAYOUT.duplicate(true)
	layout.track_angle = 30.0
	layout.approach_curve = 1.0
	geometry.configure(Vector2(1600, 900), layout)
	_expect_close(geometry.x(0.5), 800.0, "几何：归一化 0.5 位于画面中心")
	_expect_close(geometry.x(1.0) - geometry.x(0.0), geometry.width, "几何：轨道宽度")
	_expect_close(geometry.y(0.0, 10.0), geometry.judge_y, "几何：到判定时刻落在判定线上")
	# 下落幅度取“判定线到屏幕顶端的画布距离”，所以“到达顶端”要在屏幕行上核对：
	# 走完完整前瞻距离时正好投影到第 0 行（0° 时该画布行同样是 0，两种说法一致）。
	_expect_near(geometry.project_row(geometry.judge_y - geometry.y(10.0, 10.0)), 0.0, 0.5,
		"几何：完整前瞻距离到达屏幕顶端")
	_expect_close(geometry.y(10.0, 10.0), geometry.judge_y - geometry.row_offset_for_screen(0.0),
		"几何：下落幅度 = 判定线到屏幕顶端的画布距离")
	_expect(geometry.y(5.0, 10.0) < geometry.judge_y and geometry.y(-5.0, 10.0) > geometry.judge_y, "几何：判定线两侧方向相反")
	# 倾斜用真 3D 实现，几何侧的可验证结论：判定线所在行严格 1:1（旋转轴过判定线中点），
	# 判定线上方 u 像素处横向缩放 row_scale(u)、纵向按它的平方压缩（所以 Hold 不再被拉长）。
	for angle in [0.0, 30.0, 45.0, 70.0, -20.0, -45.0]:
		layout.track_angle = angle
		geometry.configure(Vector2(1600, 900), layout)
		_expect_close(geometry.tilt_degrees(), angle, "几何：%.1f° 倾角被采用" % angle)
		_expect_close(geometry.row_scale(0.0), 1.0, "几何：%.1f° 判定线所在行不缩放" % angle)
		_expect_close(geometry.project_row(0.0), geometry.judge_y, "几何：%.1f° 判定线仍落在 judge_y" % angle)
		# project_row / row_offset_for_screen 必须互为逆运算：HUD 与触摸都依赖它。
		# 采样点取画布顶行的比例，任何角度都落在画布内、且在相机前方。
		var span := geometry.judge_y - geometry.canvas_top
		var inverted := true
		var scales: Array[float] = []
		for fraction in [0.15, 0.4, 0.75]:
			var u := span * float(fraction)
			scales.append(geometry.row_scale(u))
			if absf(geometry.row_offset_for_screen(geometry.project_row(u)) - u) > 0.01:
				inverted = false
		_expect(inverted, "几何：%.1f° 的投影与反算一致" % angle)
		# 判定线上方越远越窄；向外倾斜时反过来（内容被放大）。
		if angle > 0.0:
			_expect(scales[0] < 1.0 and scales[1] < scales[0] and scales[2] < scales[1],
				"几何：%.1f° 越远越窄（%.3f → %.3f）" % [angle, scales[0], scales[2]])
		elif angle < 0.0:
			_expect(scales[0] > 1.0 and scales[1] > scales[0] and scales[2] > scales[1],
				"几何：%.1f° 越远越大（%.3f → %.3f）" % [angle, scales[0], scales[2]])
		else:
			_expect_close(scales[0], 1.0, "几何：0° 时是恒等变换")
		# 画布必须盖满画面、又不让平面伸到相机后面（否则光栅化会出问题）。
		var top_depth := 1.0 + (geometry.judge_y - geometry.canvas_top) * geometry.row_factor
		var bottom_depth := 1.0 + (geometry.judge_y - geometry.canvas_bottom) * geometry.row_factor
		_expect(top_depth >= geometry.DEPTH_FLOOR and bottom_depth >= geometry.DEPTH_FLOOR,
			"几何：%.1f° 画布两端都在相机前方（%.3f / %.3f）" % [angle, top_depth, bottom_depth])
		_expect(geometry.project_row(geometry.judge_y - geometry.canvas_bottom) >= geometry.size.y,
			"几何：%.1f° 平面一直铺到画面底端以下" % angle)
		# 游玩区域必须一直延伸到画面顶端（玩家要求：不能在中途消失）：画布顶行在画面顶端之上。
		var top_screen := geometry.project_row(geometry.judge_y - geometry.canvas_top)
		_expect(top_screen <= 0.0, "几何：%.1f° 的游玩区域一直延伸到画面顶端（顶端落在第 %.1f 行）" % [angle, top_screen])
		_expect(geometry.judge_y - geometry.canvas_top <= geometry.size.y * 3.5,
			"几何：%.1f° 的画布高度有上限（判定线上方 %.0f 行）" % [angle, geometry.judge_y - geometry.canvas_top])
		# Note 的出现点必须是屏幕顶端（玩家要求）：下落幅度取“判定线到屏幕顶端的画布距离”，
		# 所以走完整段前瞻（until = lookahead）时正好落在第 0 行，与倾角无关。
		var entry_row := geometry.project_row(geometry.judge_y - geometry.y(10.0, 10.0))
		_expect_near(entry_row, 0.0, 0.5, "几何：%.1f° 的 Note 正好从屏幕顶端出现（第 %.2f 行）" % [angle, entry_row])
		# 向内倾斜时相机后退：灭线（平面上最远一行）必须落在画面顶端之上，Note 才能从顶端进入。
		if angle > 0.0:
			_expect_close(geometry.camera_distance, geometry.judge_y * (1.0 + tan(geometry.tilt_angle)),
				"几何：%.1f° 相机随角度后退（%.0f）" % [angle, geometry.camera_distance])
			var vanishing := geometry.judge_y - geometry.camera_distance / tan(geometry.tilt_angle)
			_expect(vanishing < 0.0, "几何：%.1f° 的灭线在画面顶端之上（第 %.0f 行）" % [angle, vanishing])
	# 判定线所在高度不缩放，所以触摸换算与倾斜无关：屏幕位置必须能准确反算回归一化 x。
	for angle in [0.0, 30.0, -45.0, 12.5]:
		layout.track_angle = angle
		geometry.configure(Vector2(1600, 900), layout)
		for normalized in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var touch := Vector2(geometry.x(normalized), geometry.judge_y)
			_expect_close(geometry.normalized_x(touch), normalized, "几何：%.1f° 倾斜下 %.2f 的触摸反算" % [angle, normalized])
	# 判定线高度很小又配很大角度时，实际角度会被收窄到安全值，而不是把画面弄坏。
	layout.track_angle = 70.0
	layout.judge_y = 0.2
	geometry.configure(Vector2(1600, 900), layout)
	_expect(geometry.tilt_degrees() < 70.0 and geometry.tilt_degrees() > 0.0,
		"几何：低判定线 + 70° 被收窄到安全角度（实际 %.2f°）" % geometry.tilt_degrees())
	layout.judge_y = Setting.DEFAULT_LAYOUT.judge_y
	# 接近曲线必须保持单调且端点准确。
	for curve in [0.25, 1.0, 2.0, 4.0]:
		layout.track_angle = 0.0
		layout.approach_curve = curve
		geometry.configure(Vector2(1600, 900), layout)
		_expect_close(geometry.y(0.0, 10.0), geometry.judge_y, "几何：曲线 %.2f 的零点" % curve)
		var previous := geometry.judge_y
		var monotonic := true
		for step in range(1, 21):
			var value := geometry.y(step * 0.5, 10.0)
			if value > previous + 0.0001:
				monotonic = false
			previous = value
		_expect(monotonic, "几何：曲线 %.2f 在靠近判定线时单调下降" % curve)
		_expect_close(geometry.y(10.0, 10.0), 0.0, "几何：曲线 %.2f 的终点" % curve)
		# 接近曲线只改变下落节奏，不改变入口：任何角度下入口都在屏幕顶端。
		for angle in [45.0, 70.0, -45.0]:
			layout.track_angle = angle
			geometry.configure(Vector2(1600, 900), layout)
			var entry := geometry.project_row(geometry.judge_y - geometry.y(10.0, 10.0))
			_expect_near(entry, 0.0, 0.5, "几何：曲线 %.2f / %.0f° 的 Note 从屏幕顶端出现（第 %.2f 行）" % [curve, angle, entry])
	# “流速 N = Note 从屏幕顶端落到判定线的时间为 10 / N 秒”：完整前瞻距离永远对应屏幕顶端，
	# 所以换算出的落点就是屏幕上的一条固定线，速度可核对、不再是无从验证的手感。
	layout.approach_curve = 1.0
	layout.track_angle = 45.0
	geometry.configure(Vector2(1600, 900), layout)
	for speed in [3.0, 7.0, 15.0]:
		var lookahead: float = 10.0 / float(speed)
		var entry := geometry.project_row(geometry.judge_y - geometry.y(lookahead, lookahead))
		_expect_near(entry, 0.0, 0.5, "几何：流速 %.0f 时 Note 从屏幕顶端起落（%.2f 秒后到判定线）" % [speed, lookahead])
	# 预览排程：每个类型各自记住判定时刻，改“流速”只改变落速与出现间隔，
	# 已在屏幕上的 Note 不会跳到别的位置（旧实现按 fposmod 取相位，一拉流速就跳）。
	var preview_field := Playfield.new()
	add_child(preview_field)
	preview_field.set_preview(true)
	var slow_judge: float = preview_field._preview_judge_time("tap", 0, 10.0 / 7.0)
	var fast_judge: float = preview_field._preview_judge_time("tap", 0, 10.0 / 2.0)
	_expect_close(fast_judge, slow_judge, "预览：改流速不会改变已排好的判定时刻（Note 不跳位置）")
	var next_judge: float = preview_field._preview_advance("tap", 10.0 / 2.0)
	_expect_close(next_judge - fast_judge, 10.0 / 2.0 + Playfield.PREVIEW_GAP, "预览：下一颗的间隔 = 10/流速 + 间隔")
	preview_field.queue_free()
	# 倾斜参数要真正送进 3D 舞台，否则设置界面预览会与正式游玩不一致。
	Setting.set_layout("track_angle", 30.0)
	var field := Playfield.new()
	add_child(field)
	field.configure(Vector2(1600, 900))
	var stage: Dictionary = field.stage_parameters()
	_expect(bool(stage.stage_ready), "几何：3D 舞台（相机 / 平面 / 显示层）已建立")
	_expect(int(stage.projection) == Camera3D.PROJECTION_FRUSTUM, "几何：相机使用偏心视锥投影")
	_expect(int(stage.keep_aspect) == Camera3D.KEEP_HEIGHT, "几何：视锥高度决定缩放（保持竖直比例）")
	_expect_close(float(stage.frustum_size), field.geometry.frustum_size, "几何：视锥尺寸与几何一致")
	_expect_close((stage.frustum_offset as Vector2).y, field.geometry.frustum_offset.y, "几何：视锥垂直偏移与几何一致")
	_expect_close(float(stage.camera_distance), field.geometry.camera_distance, "几何：相机距离与几何一致（随角度后退）")
	_expect_close(float(stage.tilt_degrees), 30.0, "几何：30° 倾角送进舞台")
	_expect_close((stage.plane_position as Vector3).z, -field.geometry.camera_distance, "几何：平面位于相机正前方")
	_expect_close(float(stage.plane_rotation_x), -field.geometry.tilt_angle, "几何：平面绕判定线旋转")
	_expect_close((stage.plane_center_offset as Vector3).y, field.geometry.plane_center_offset(), "几何：判定线那一行落在旋转轴上")
	_expect_close(float(stage.plane_size.y), field.geometry.plane_world_size().y, "几何：平面高度按 1/cos 预拉伸")
	# 判定线只横跨游玩区域：左右两端正好落在两侧的侧线上（轨道区域的左右边缘）。
	var line := field.judge_line_rect()
	_expect_close(line.position.x, field.geometry.x(0.0), "几何：判定线左端落在游玩区域左侧线")
	_expect_close(line.end.x, field.geometry.x(1.0), "几何：判定线右端落在游玩区域右侧线")
	_expect_close(line.size.x, field.geometry.width, "几何：判定线宽度等于游玩区域宽度")
	_expect_close(line.get_center().y, field.geometry.judge_y, "几何：判定线以 judge_y 为中心")
	# 判定线图片的纵向偏移只挪图片层：图片矩形平移，判定线矩形（旋转轴 / 判定基准）不动。
	_expect_close(field.judge_line_image_rect().position.y, line.position.y, "几何：偏移为 0 时图片正好压在判定线上")
	_expect_close(field.judge_line_image_rect().size.y, line.size.y, "几何：图片偏移不改变图片高度")
	Setting.set_layout("judge_image_offset", 40.0)
	_expect_close(field.judge_line_image_rect().position.y, line.position.y + 40.0 * field.geometry.pixel_scale,
		"几何：图片按设置纵向平移（布局像素 × 画布缩放）")
	_expect_close(field.judge_line_rect().position.y, line.position.y, "几何：图片挪开后判定线本身不动")
	Setting.set_layout("judge_image_offset", -40.0)
	_expect_close(field.judge_line_image_rect().position.y, line.position.y - 40.0 * field.geometry.pixel_scale,
		"几何：负值把图片往上挪")
	Setting.set_layout("judge_image_offset", 0.0)
	# 三种音符与轨道的横向间隔：宽度 = 轨道宽度 − 该类型的间隔，各类型互不影响。
	var half := 0.5 * field.geometry.width
	_expect_close(field.note_width(0.5, "tap"), half - float(Setting.layout.note_gap_tap) * field.geometry.pixel_scale,
		"Note：宽度减去本类型的横向间隔")
	Setting.set_layout("note_gap_hold", 60.0)
	_expect_close(field.note_width(0.5, "hold"), half - 60.0 * field.geometry.pixel_scale, "Note：Hold 的间隔可以单独调")
	_expect_close(field.note_width(0.5, "tap"), half - float(Setting.layout.note_gap_tap) * field.geometry.pixel_scale,
		"Note：改 Hold 的间隔不影响 Tap")
	Setting.set_layout("note_gap_slide", 0.0)
	_expect_close(field.note_width(0.5, "slide"), half, "Note：间隔为 0 时音符铺满轨道")
	_expect_close(field.note_width(10.0 / field.geometry.width, "tap"), 10.0, "Note：窄轨道不被间隔吞成负宽度")
	Setting.reset_layout()
	_expect_close(field.geometry.lane_stroke(), 2.0, "绘制：轨道线笔画宽度为两像素")
	# 游玩区域左右各一条侧线：宽度是轨道线的四倍，贴在区域外侧、纵向铺满画布。
	_expect_close(field.geometry.side_line_stroke(), field.geometry.lane_stroke() * 4.0, "绘制：侧线宽度是轨道线的四倍")
	for edge in [[0.0, "左"], [1.0, "右"]]:
		var normalized := float(edge[0])
		var side := field.geometry.side_line_rect(normalized)
		# 左侧线的内边是它的右边、右侧线的内边是它的左边。
		var inner: float = side.end.x if normalized < 0.5 else side.position.x
		_expect_close(side.size.x, field.geometry.side_line_stroke(), "几何：%s侧线宽度等于侧线笔画宽度" % edge[1])
		_expect_close(inner, field.geometry.x(normalized), "几何：%s侧线贴在游玩区域边界外侧" % edge[1])
		_expect_near(side.position.y, field.geometry.canvas_top, 0.001, "几何：%s侧线顶端铺到画布顶（一直延伸到屏幕顶端）" % edge[1])
		_expect_near(side.end.y, field.geometry.canvas_bottom, 0.001, "几何：%s侧线底端铺到画布底" % edge[1])
	# HUD 高度可以分别调整：连击 / 分数 / 判定各自独立。
	_expect(Setting.layout.has("combo_size") and Setting.layout.has("score_size"), "几何：连击与分数有独立高度设置")
	field.queue_free()
	Setting.reset_layout()


# ---------------------------------------------------------------- 设置

func _check_settings() -> void:
	Setting.reset_layout()
	var emit_count := [0]
	var counter := func() -> void: emit_count[0] += 1
	Setting.changed.connect(counter)
	Setting.set_layout("note_height", 999.0)
	_expect_close(float(Setting.layout.note_height), 160.0, "设置：note 高度按上限截断")
	Setting.set_layout("track_angle", -999.0)
	_expect_close(float(Setting.layout.track_angle), -45.0, "设置：轨道倾斜按下限截断")
	Setting.set_layout("judge_size", 9999.0)
	_expect_close(float(Setting.layout.judge_size), 200.0, "设置：判定显示高度按上限截断")
	Setting.set_layout("combo_size", 9999.0)
	_expect_close(float(Setting.layout.combo_size), 200.0, "设置：连击高度按上限截断")
	Setting.set_layout("score_size", 0.0)
	_expect_close(float(Setting.layout.score_size), 8.0, "设置：分数高度按下限截断")
	Setting.set_layout("track_angle", 9999.0)
	_expect_close(float(Setting.layout.track_angle), 70.0, "设置：轨道倾斜按新上限截断")
	Setting.set_layout("不存在的键", 1.0)
	_expect(not Setting.layout.has("不存在的键"), "设置：未知布局键被忽略")
	# 判定线图片的纵向偏移回来了：它只挪图片层，所以范围给得比较宽，越界值夹到端点。
	_expect(Setting.DEFAULT_LAYOUT.has("judge_image_offset") and Setting.LAYOUT_RANGES.has("judge_image_offset"),
		"设置：判定线图片 Y 偏移在布局表里")
	Setting.set_layout("judge_image_offset", 9999.0)
	_expect_close(float(Setting.layout.judge_image_offset), 300.0, "设置：图片偏移按上限截断")
	Setting.set_layout("judge_image_offset", -9999.0)
	_expect_close(float(Setting.layout.judge_image_offset), -300.0, "设置：图片偏移按下限截断")
	# 三种音符与所在轨道的横向间隔：0 = 铺满轨道，四种类型各自独立。
	for kind in ["tap", "hold", "slide"]:
		Setting.set_layout("note_gap_" + kind, -5.0)
		_expect_close(float(Setting.layout["note_gap_" + kind]), 0.0, "设置：%s 与轨道的间隔按下限截断" % kind)
		Setting.set_layout("note_gap_" + kind, 9999.0)
		_expect_close(float(Setting.layout["note_gap_" + kind]), 400.0, "设置：%s 与轨道的间隔按上限截断" % kind)
	_expect(emit_count[0] > 0, "设置：布局变更会发出 changed（实时预览依赖它）")
	Setting.changed.disconnect(counter)
	Setting.reset_layout()
	_expect_close(float(Setting.layout.note_height), float(Setting.DEFAULT_LAYOUT.note_height), "设置：恢复默认布局")
	# 存盘会把旧配置里没人再读的布局键删掉（删设置项后不留垃圾键）。
	var backup := _read_optional(Setting.SETTINGS_PATH)
	var stale := ConfigFile.new()
	stale.load(Setting.SETTINGS_PATH)
	stale.set_value("layout", "removed_layout_key", 150.0)
	stale.save(Setting.SETTINGS_PATH)
	Setting.save_settings()
	var reloaded := ConfigFile.new()
	reloaded.load(Setting.SETTINGS_PATH)
	_expect(not reloaded.has_section_key("layout", "removed_layout_key"), "设置：存盘清掉已删除的布局键")
	_expect(reloaded.has_section_key("layout", "judge_image_offset") and reloaded.has_section_key("layout", "note_gap_tap"),
		"设置：存盘写进判定线图片偏移与音符间隔")
	_expect(reloaded.has_section_key("layout", "note_height"), "设置：存盘保留仍然有效的布局键")
	_expect_close(float(reloaded.get_value("layout", "note_height", 0.0)), float(Setting.layout.note_height),
		"设置：存盘写的是当前布局值")
	if backup.is_empty():
		DirAccess.remove_absolute(Setting.SETTINGS_PATH)
	else:
		Storage.write_bytes(Setting.SETTINGS_PATH, backup)
	Setting.load_settings()
	# 皮肤字段校验
	Setting.set_skin_field("note_tap", "margin_left", -20.0)
	_expect_close(float(Setting.get_skin("note_tap").margin_left), 0.0, "设置：九宫格边距不能为负")
	Setting.set_skin_field("note_tap", "stretch_mode", "乱填")
	_expect(str(Setting.get_skin("note_tap").stretch_mode) == "center", "设置：拉伸模式非法值回落到中间拉伸")
	Setting.set_skin_field("hit_tap", "rows", 2)
	Setting.set_skin_field("hit_tap", "columns", 3)
	Setting.set_skin_field("hit_tap", "start_frame", 1)
	Setting.set_skin_field("hit_tap", "frames", 999)
	_expect(int(Setting.get_skin("hit_tap").frames) == 5, "设置：精灵图帧数不超过 行×列 − 起始帧")
	Setting.set_skin_field("hit_tap", "start_frame", 99)
	_expect(int(Setting.get_skin("hit_tap").start_frame) == 5, "设置：起始帧按总帧数截断")
	Setting.set_skin_field("sound_tap", "volume", 5.0)
	_expect_close(float(Setting.get_skin("sound_tap").volume), 1.0, "设置：打击音音量限定在 0–1")
	# 单图打击特效的缩放曲线：四个数的三阶贝塞尔，x 夹在 0~1，y 允许大于 1 的回弹。
	var curve: Array = Setting._curve([0.2, 1.4, -1.0, 0.6])
	_expect(curve.size() == 4, "设置：缩放曲线固定四个数")
	_expect_close(float(curve[0]), 0.2, "设置：缩放曲线保留 x1")
	_expect_close(float(curve[1]), 1.4, "设置：缩放曲线保留 y1（允许大于 1 的回弹）")
	_expect_close(float(curve[2]), 0.0, "设置：缩放曲线 x2 夹在 0~1")
	_expect_close(float(curve[3]), 0.6, "设置：缩放曲线保留 y2")
	_expect(Setting._curve(["乱填", 1, 2, 3]) == Setting.DEFAULT_HIT_CURVE, "设置：非法缩放曲线回落到默认值")
	_expect(Setting._curve([1, 2, 3]) == Setting.DEFAULT_HIT_CURVE, "设置：长度不对的缩放曲线回落到默认值")
	Setting.set_skin_field("hit_tap", "scale_curve", [0.1, 0.9, 0.2, 0.5])
	_expect_close(float(Setting.get_skin("hit_tap").scale_curve[3]), 0.5, "设置：缩放曲线可以逐字段写入")
	for slot in ["note_tap", "hit_tap", "sound_tap"]:
		Setting.reset_skin(slot)
	# 存盘 / 读盘往返
	Setting.set_layout("judge_y", 0.66)
	Setting.set_skin_field("judge_line", "margin_top", 7.0)
	Setting.save_settings()
	Setting.set_layout("judge_y", 0.1)
	Setting.set_skin_field("judge_line", "margin_top", 0.0)
	Setting.load_settings()
	_expect_close(float(Setting.layout.judge_y), 0.66, "设置：布局改动可以存盘并读回")
	_expect_close(float(Setting.get_skin("judge_line").margin_top), 7.0, "设置：皮肤改动可以存盘并读回")
	Setting.reset_layout()
	Setting.reset_skin("judge_line")


# ---------------------------------------------------------------- 皮肤与素材

func _check_skin() -> void:
	for slot in Setting.SKIN_SLOTS:
		# 打击音是音效、判定反馈默认画文字，这两类没有内置图片素材。
		if String(slot).begins_with("sound_") or (String(slot).begins_with("judge_") and String(slot) != "judge_line"):
			continue
		var texture := Skins.texture(slot)
		_expect(texture != null, "皮肤：槽位 %s 有可绘制素材" % slot)
		if texture != null:
			_expect(texture.get_width() > 0 and texture.get_height() > 0, "皮肤：槽位 %s 的素材尺寸有效" % slot)
	for kind in ["tap", "hold", "slide"]:
		_expect(Skins.sound(kind) != null, "皮肤：%s 打击音已加载" % kind)
	# 自定义素材读不到时必须回退到内置素材，游玩不中断。
	var fallback := Skins.texture("note_tap")
	Setting.set_skin_field("note_tap", "path", "user://__missing_asset__.png")
	_expect(Skins.texture("note_tap") == fallback, "皮肤：自定义素材丢失时回退内置素材")
	Setting.reset_skin("note_tap")
	_expect(Skins.texture("note_tap") == fallback, "皮肤：重置后恢复内置素材")
	_expect(Skins.texture("并不存在的槽位") == null, "皮肤：未知槽位返回 null")
	# 判定反馈：默认没有图片（画文字），导入图片后改画图片，判定名到槽位的映射必须稳定。
	for grade in ["just+", "just", "good", "ok", "miss"]:
		_expect(Skins.grade_texture(grade) == null, "皮肤：判定 %s 默认绘制文字" % grade)
	_expect(Skins.grade_slot("just+") == "judge_just_plus", "皮肤：just+ 使用 judge_just_plus 槽位")
	_expect(Skins.grade_slot("miss") == "judge_miss", "皮肤：miss 使用 judge_miss 槽位")
	_expect(Skins.grade_texture("perfected") == null and not Setting.skin.has("judge_perfected"), "皮肤：未知判定名回退文字且不写入设置")
	var grade_probe := "user://__grade_probe__.png"
	var grade_image := Image.create(12, 6, false, Image.FORMAT_RGBA8)
	grade_image.fill(Color(0.9, 0.4, 0.2, 1.0))
	Storage.write_bytes(grade_probe, grade_image.save_png_to_buffer())
	Setting.set_skin_field("judge_just", "path", grade_probe)
	_expect(Skins.grade_texture("just") != null, "皮肤：判定导入图片后改用图片")
	_expect(Skins.grade_texture("good") == null, "皮肤：未导入的判定仍然绘制文字")
	Setting.reset_skin("judge_just")
	_expect(Skins.grade_texture("just") == null, "皮肤：重置判定素材后回到文字")
	DirAccess.remove_absolute(grade_probe)
	# 缓存必须跟随路径变化，否则实时预览会看到旧素材。
	var temporary := "user://__skin_cache_probe__.png"
	var image := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.9, 0.4, 1.0))
	Storage.write_bytes(temporary, image.save_png_to_buffer())
	Setting.set_skin_field("note_tap", "path", temporary)
	var custom := Skins.texture("note_tap")
	_expect(custom != null and not custom == fallback, "皮肤：导入的自定义素材替换内置素材")
	_expect(Skins.texture("note_tap") == custom, "皮肤：同一路径命中缓存")
	Setting.reset_skin("note_tap")
	DirAccess.remove_absolute(temporary)
	# 单图打击特效：从 0 放大到当前大小，过程由槽位的三阶贝塞尔曲线控制。
	var hit: Dictionary = Setting.get_skin("hit_tap")
	_expect_close(Skins.hit_scale_curve(hit, 0.0, 0.3), 0.0, "皮肤：单图打击特效从缩放 0 开始")
	_expect_close(Skins.hit_scale_curve(hit, 0.3, 0.3), 1.0, "皮肤：显示时长结束时到达当前大小")
	_expect_close(Skins.hit_scale_curve(hit, 9.0, 0.3), 1.0, "皮肤：超过显示时长后保持当前大小")
	var middle := Skins.hit_scale_curve(hit, 0.3 * Skins.HIT_SCALE_IN_RATIO * 0.5, 0.3)
	_expect(middle > 0.0 and middle < 1.0, "皮肤：放大过程是渐进的（实际 %.3f）" % middle)
	var overshoot := Setting._normalize_skin("hit_tap", {"scale_curve": [0.5, 2.0, 0.5, 2.0]})
	_expect(Skins.hit_scale_curve(overshoot, 0.3 * Skins.HIT_SCALE_IN_RATIO * 0.5, 0.3) > 1.0,
		"皮肤：缩放曲线可以做出大于 1 的回弹")
	var late := Skins.hit_scale_curve(Setting._normalize_skin("hit_tap", {"scale_curve": [1.0, 0.0, 1.0, 0.0]}),
		0.3 * Skins.HIT_SCALE_IN_RATIO * 0.9, 0.3)
	_expect(late < middle, "皮肤：缩放曲线真的会改变过程（缓入 %.3f < 默认 %.3f）" % [late, middle])
	_expect_close(Skins.hit_scale_curve({}, 0.1, 0.3), 1.0, "皮肤：没有曲线的槽位按当前大小绘制")


# ---------------------------------------------------------------- 判定

func _check_judging() -> void:
	var chart := ChartData.new(TAP_CHART)
	_expect(chart.error_message.is_empty(), "判定：测试谱面可以加载")
	var session := PlaySession.new(chart)
	_expect(session.notes.size() == 4, "判定：音符数量正确")
	# 计分单位：Tap 1 + Hold 头尾 2 + Slide 1 = 4；fake 音符不参与。
	_expect(session.total_units == 4, "判定：假音符不计入总分（1 + 2 + 1 = 4，实际 %d）" % session.total_units)
	var grades: Array[String] = []
	var phases: Array[String] = []
	var judged: Array[int] = []
	session.judged.connect(func(index: int, grade: String, phase: String) -> void:
		grades.append(grade)
		phases.append(phase)
		judged.append(index))
	# Tap：正好在判定时刻按下
	session.update(0.5, {0: {"x": 0.5, "pressed": true}})
	_expect(grades == ["just+"], "判定：Tap 在判定时刻命中为 just+")
	_expect(session.combo == 1 and session.states[0] == PlaySession.State.DONE, "判定：Tap 命中后状态完成")
	# Hold：按住在轨道内，直到尾判
	session.update(1.0, {0: {"x": 0.5, "pressed": true}})
	_expect(session.states[1] == PlaySession.State.HOLDING, "判定：Hold 头判进入保持状态")
	session.update(1.5, {0: {"x": 0.5, "pressed": false}})
	_expect(phases.count("tail") == 1 and grades[-1] == "just+", "判定：Hold 保持到结尾为 just+")
	_expect(session.active_holds.is_empty(), "判定：Hold 结束后清空保持状态")
	# Slide：手指停留在轨道内即命中
	session.update(2.0, {1: {"x": 0.5, "pressed": false}})
	_expect(grades[-1] == "just+", "判定：Slide 在窗口内自动命中")
	# 假音符永远不会被判中
	session.update(2.5, {2: {"x": 0.5, "pressed": true}})
	_expect(not judged.has(3), "判定：假音符不产生判定记录")
	_expect(not grades.has(""), "判定：不存在空判定")
	_expect(judged == [0, 1, 1, 2], "判定：只有非假音符产生判定（index 顺序 %s）" % str(judged))
	_expect(session.combo == 4, "判定：连续命中累计连击（Tap + Hold 头尾 + Slide，实际 %d）" % session.combo)
	# 漏判：时间越过判定窗口后记 miss
	var missed := PlaySession.new(chart)
	var miss_grades: Array[String] = []
	missed.judged.connect(func(_index: int, grade: String, _phase: String) -> void: miss_grades.append(grade))
	missed.update(0.8, {})
	_expect(miss_grades.has("miss"), "判定：超出窗口记为 miss")
	_expect(missed.combo == 0, "判定：miss 打断连击")
	# Hold 提前松手
	var released := PlaySession.new(chart)
	var released_grades: Array[String] = []
	released.judged.connect(func(_index: int, grade: String, phase: String) -> void:
		if phase == "tail":
			released_grades.append(grade))
	released.update(1.0, {0: {"x": 0.5, "pressed": true}})
	released.update(1.3, {})
	_expect(released_grades == ["miss"], "判定：Hold 提前松手尾判为 miss")
	# 可见音符游标
	var visible := PlaySession.new(chart)
	visible.update(0.5, {})
	_expect(visible.visible_notes(1.0).size() >= 1, "判定：可见音符列表包含当前音符")


# ---------------------------------------------------------------- TAKANA 判定移植

## 从 TAKANA_Cubic 的判定系统移植过来的三条：判定框余量（ExtraRange）、
## Slide 的非对称窗口（T3SlideJudgeConfig）、以及扫描范围带来的早按 Miss。
## 谱面：轨道 1 固定 x = 50 / w = 10（event_scale 100 ⇒ 半宽 0.05），
## Tap 在 1.0 s、Hold 2.0 → 4.0 s、Slide 在 6.0 s（120 BPM）。
## x / w 事件都要带 beat2：只写一个拍点的话，同拍的两种事件会走 LOVE 的同拍配对规则
## （x 与不存在的 lpos 配成一对），宽度会变成 2×x。真实谱面的事件一律带范围。
const TAKANA_JUDGE_CHART := """
{
  "version": 1, "offset": 0,
  "bpm_list": [{"beat": [0,0,1], "bpm": 120}],
  "note": [
    {"type": "note", "beat": [2,0,1], "track": 1},
    {"type": "hold", "beat": [4,0,1], "beat2": [8,0,1], "track": 1},
    {"type": "wipe", "beat": [12,0,1], "track": 1}
  ],
  "event": [{"type":"x","track":1,"beat":0,"beat2":[16,0,1],"from":50,"to":50},{"type":"w","track":1,"beat":0,"beat2":[16,0,1],"from":10,"to":10}],
  "preference": {"x_offset": 0, "event_scale": 100}
}
"""

func _check_takana_judge() -> void:
	var chart := ChartData.new(TAKANA_JUDGE_CHART)
	_expect(chart.error_message.is_empty(), "TAKANA 判定：测试谱面可以加载")
	_expect(is_equal_approx(PlaySession.EXTRA_RANGE, 0.1 / 9.0), "TAKANA 判定：判定框余量 = 0.1 舞台单位 ÷ 舞台宽 9")
	# Tap 的判定框比轨道本身两边各宽 0.1 舞台单位（半宽 0.05 → 0.0611）。
	var tap := PlaySession.new(chart)
	tap.update(1.0, {0: {"x": 0.555, "pressed": true}})
	_expect(tap.states[0] == PlaySession.State.DONE and tap.last_grade == "just+", "TAKANA 判定：Tap 在轨道外一点点仍然命中")
	var tap_far := PlaySession.new(chart)
	tap_far.update(1.0, {0: {"x": 0.565, "pressed": true}})
	_expect(tap_far.states[0] == PlaySession.State.PENDING, "TAKANA 判定：加宽范围之外仍然打不中")
	# Hold 头把这份加宽减了回去：同样的一点 Tap 命中、Hold 不命中。
	var hold := PlaySession.new(chart)
	hold.update(2.0, {0: {"x": 0.555, "pressed": true}})
	_expect(hold.states[1] == PlaySession.State.PENDING, "TAKANA 判定：Hold 头按轨道原宽，不跟着加宽")
	# 按住过程中反而加宽：手指飘出轨道一点点不会开始算离开。
	var body := PlaySession.new(chart)
	body.update(2.0, {0: {"x": 0.5, "pressed": true}})
	body.update(2.2, {0: {"x": 0.555, "pressed": false}})
	body.update(2.4, {0: {"x": 0.555, "pressed": false}})
	_expect(body.states[1] == PlaySession.State.HOLDING and body.active_holds.has(1), "TAKANA 判定：按住过程同样有判定框余量")
	# 对照：挪到加宽范围之外照旧算离开轨道，超过宽限即 miss。
	var left := PlaySession.new(chart)
	left.update(2.0, {0: {"x": 0.5, "pressed": true}})
	left.update(2.2, {0: {"x": 0.6, "pressed": false}})
	_expect(left.states[1] == PlaySession.State.DONE and left.judgement_counts.miss == 2, "TAKANA 判定：离开加宽范围后仍按漏判处理")
	# Slide：提前 140 ms 命中、160 ms 不碰、延后 90 ms 也命中（窗口 −100 ~ +150 ms）。
	var slide_early := PlaySession.new(chart)
	slide_early.update(5.86, {0: {"x": 0.5, "pressed": false}})
	_expect(slide_early.states[2] == PlaySession.State.SLIDE_WAITING, "TAKANA 判定：Slide 提前 140 ms 命中（旧窗口 ±85 ms 不行）")
	var slide_too_early := PlaySession.new(chart)
	slide_too_early.update(5.84, {0: {"x": 0.5, "pressed": false}})
	_expect(slide_too_early.states[2] == PlaySession.State.PENDING, "TAKANA 判定：Slide 提前 160 ms 完全不碰音符")
	var slide_late := PlaySession.new(chart)
	slide_late.update(6.09, {0: {"x": 0.5, "pressed": false}})
	_expect(slide_late.states[2] == PlaySession.State.DONE and slide_late.judgement_counts["just+"] == 1, "TAKANA 判定：Slide 延后 90 ms 仍然命中")
	# 扫描范围到 +150 ms 只是为了 Slide，提前 100~150 ms 的按下不碰 Tap/Hold：不做 TAKANA 的
	# EarlyMiss 消费，否则按早的那一下会打死玩家马上要按的音符。
	var early_press := PlaySession.new(chart)
	early_press.update(0.86, {0: {"x": 0.5, "pressed": true}})
	_expect(early_press.states[0] == PlaySession.State.PENDING and early_press.judgement_counts.miss == 0, "TAKANA 判定：按早 140 ms 不算命中也不记 Miss，音符留着")
	early_press.update(1.0, {0: {"x": 0.5, "pressed": true}})
	_expect(early_press.states[0] == PlaySession.State.DONE and early_press.last_grade == "just+", "TAKANA 判定：按早的那次不影响音符自己那次按下")
	var untouched := PlaySession.new(chart)
	untouched.update(0.84, {0: {"x": 0.5, "pressed": true}})
	_expect(untouched.states[0] == PlaySession.State.PENDING, "TAKANA 判定：按早 160 ms 不碰音符")
	untouched.update(1.0, {0: {"x": 0.5, "pressed": true}})
	_expect(untouched.states[0] == PlaySession.State.DONE and untouched.last_grade == "just+", "TAKANA 判定：更早的那次按下不影响之后的正常命中")


# ---------------------------------------------------------------- 平均击打延迟

## 平均击打延迟只统计「按下 Tap / Hold 头」的那一刻：漏判、Hold 尾判、Slide 的自动命中
## 都不算按点。偏差的正数 = 按晚了（见 PlaySession.average_hit_offset）。
func _check_hit_offset() -> void:
	var chart := ChartData.new(TAP_CHART)
	var session := PlaySession.new(chart)
	_expect(session.hit_offset_count == 0 and not session.last_hit_from_press, "延迟：开局没有按点样本")
	_expect_close(session.average_hit_offset(), 0.0, "延迟：一次都没按下时平均延迟是 0（不会除以零）")
	# 按早 40 ms：偏差 = 按下时刻 − 音符时刻，是负数；方向词是 FAST。
	session.update(0.46, {0: {"x": 0.5, "pressed": true}})
	_expect(session.last_grade == "just+" and session.last_hit_from_press, "延迟：按点被标记为「真的按下去」")
	_expect_close(session.last_hit_offset, -0.04, "延迟：偏差 = 按下时刻 − 音符时刻（按早为负）")
	_expect(session.hit_offset_count == 1, "延迟：Tap 头判计入一次样本")
	_expect(Skins.offset_word(session.last_hit_offset) == "fast", "延迟：按早的方向词是 FAST")
	# Hold 头判同样算按点（按晚 30 ms，方向词 LATE）。
	session.update(1.03, {0: {"x": 0.5, "pressed": true}})
	_expect_close(session.last_hit_offset, 0.03, "延迟：Hold 头判也算按点（按晚为正）")
	_expect(session.hit_offset_count == 2, "延迟：Hold 头判计入一次样本")
	_expect(Skins.offset_word(session.last_hit_offset) == "late", "延迟：按晚的方向词是 LATE")
	_expect_close(session.average_hit_offset(), -0.005, "延迟：平均 = 两次按点的平均值（(-0.04 + 0.03) / 2）")
	# Hold 尾判不是按点：不加样本。
	session.update(1.5, {0: {"x": 0.5, "pressed": false}})
	_expect(session.judgement_counts["just+"] == 3 and session.hit_offset_count == 2, "延迟：Hold 尾判不计入样本")
	# Slide 是停留即命中，没有「按下的时刻」：既不标记按下、也不进平均。
	var before_slide := session.hit_offset_count
	session.update(2.0, {1: {"x": 0.5, "pressed": false}})
	_expect(session.judgement_counts["just+"] == 4 and session.hit_offset_count == before_slide, "延迟：Slide 的自动命中不计入样本")
	# 漏判（时间到了没碰）更没有按点：标记被清掉，样本不变。
	var missed := PlaySession.new(chart)
	missed.update(0.7, {})
	_expect(missed.judgement_counts.miss == 1 and not missed.last_hit_from_press, "延迟：漏判不标记成按下")
	_expect(missed.hit_offset_count == 0 and is_zero_approx(missed.average_hit_offset()), "延迟：漏判不进平均")
	# 结算快照带上平均延迟与样本数（结算界面直接读这两个键）。
	var summary := session.result_summary()
	_expect(summary.has("average_offset") and summary.has("offset_samples"), "延迟：结算快照带上平均延迟与样本数")
	_expect_close(float(summary.average_offset), session.average_hit_offset(), "延迟：快照里的平均延迟就是读取方法的值")
	_expect(int(summary.offset_samples) == session.hit_offset_count, "延迟：快照里的样本数 = 按点次数（实际 %d）" % int(summary.offset_samples))
	# 读数格式：没有样本时整行不显示，正负号与方向词各说各话。
	_expect(UI.latency_text(0.0, 0).is_empty(), "延迟：没有按点样本时读数为空（界面显示占位符）")
	var early_text := UI.latency_text(-0.0123, 214)
	_expect(early_text.begins_with("-12.3 ms") and early_text.contains("偏早") and early_text.contains("214 次按下"),
		"延迟：按早的读数是负数 + 偏早（%s）" % early_text)
	var late_text := UI.latency_text(0.05, 8)
	_expect(late_text.begins_with("+50.0 ms") and late_text.contains("偏晚"), "延迟：按晚的读数是正数 + 偏晚（%s）" % late_text)
	_expect(UI.latency_text(0.0002, 8).contains("几乎没有偏差"), "延迟：几乎无偏差时读数如实说（%s）" % UI.latency_text(0.0002, 8))
	_expect(UI.latency_brief(0.0123, 8) == "+12.3 ms · 偏晚" and UI.latency_brief(0.0, 0).is_empty(),
		"延迟：短读数省掉样本数、没有样本时同样为空")


# ---------------------------------------------------------------- 击打延迟显示（元件）

## 元件在「按下 Tap / Hold 判定」且该判定在名单里时出现，只显示方向词 FAST / LATE。
## 选项就是判定文字本身，五个全都在（见 Setting.JUDGE_OFFSET_GRADES）。
func _check_offset_display() -> void:
	# 选项名单必须与判定文字一模一样，而且是全部五个。
	_expect(Setting.JUDGE_OFFSET_GRADES == Scores.GRADES, "延迟显示：选项与判定文字完全一致（%s）" % str(Setting.JUDGE_OFFSET_GRADES))
	_expect(Setting.JUDGE_OFFSET_GRADES == PlaySession.GRADES + ["miss"], "延迟显示：五个判定一个不缺")
	_expect(Setting.layout.has("judge_offset_x") and Setting.layout.has("judge_offset_duration"), "延迟显示：位置 / 大小 / 时长都是布局键（设置里能调、能存）")
	_expect(Setting.SKIN_SLOTS.has("judge_fast") and Setting.SKIN_SLOTS.has("judge_late"), "延迟显示：两个方向各有素材槽位")
	_expect(Skins.OFFSET_WORDS == ["fast", "late"], "延迟显示：方向词只有 FAST / LATE（不带毫秒数）")
	_expect(Skins.OFFSET_TEXTS["fast"] == "FAST" and Skins.OFFSET_TEXTS["late"] == "LATE", "延迟显示：默认文字是 FAST / LATE")
	_expect(Skins.offset_word(-0.001) == "fast" and Skins.offset_word(0.0) == "late" and Skins.offset_word(0.08) == "late",
		"延迟显示：偏差为负是 FAST、为零或正是 LATE")
	_expect(Skins.offset_color("fast") != Skins.offset_color("late"), "延迟显示：两个方向用不同颜色")
	_expect(Skins.texture("judge_fast") == null and Skins.texture("judge_late") == null, "延迟显示：默认没有图片，画内置文字")
	# 名单：默认「判定不为 just+ 时触发」，勾选实时生效，判定文字以外的名字一律忽略。
	Setting.judge_offset_grades = Setting.DEFAULT_JUDGE_OFFSET_GRADES.duplicate()
	_expect(Setting.judge_offset_enabled("just") and Setting.judge_offset_enabled("miss") and Setting.judge_offset_enabled("ok"),
		"延迟显示：默认勾上 just / good / ok / miss")
	_expect(not Setting.judge_offset_enabled("just+"), "延迟显示：默认不显示 just+")
	var emit_count := [0]
	var counter := func() -> void: emit_count[0] += 1
	Setting.changed.connect(counter)
	Setting.set_judge_offset_grade("just+", true)
	_expect(Setting.judge_offset_enabled("just+") and emit_count[0] == 1, "延迟显示：勾上 just+ 立刻写进设置（发出 changed）")
	Setting.set_judge_offset_grade("just+", true)
	_expect(emit_count[0] == 1, "延迟显示：重复勾同一个判定不重复发出 changed")
	Setting.set_judge_offset_grade("并不存在的判定", true)
	_expect(Setting.judge_offset_grades.size() == 5 and emit_count[0] == 1, "延迟显示：判定文字以外的名字一律忽略")
	Setting.set_judge_offset_grade("just+", false)
	_expect(Setting.judge_offset_grades == Setting.DEFAULT_JUDGE_OFFSET_GRADES, "延迟显示：取消勾选回到默认名单")
	# 名单始终按判定顺序排列，与勾选先后无关；全不勾也是合法值。
	Setting.judge_offset_grades = ["miss", "just"]
	Setting.set_judge_offset_grade("good", true)
	_expect(Setting.judge_offset_grades == ["just", "good", "miss"], "延迟显示：名单按判定顺序排列（与写入顺序无关）")
	for grade in Setting.JUDGE_OFFSET_GRADES:
		Setting.set_judge_offset_grade(grade, false)
	_expect(Setting.judge_offset_grades.is_empty(), "延迟显示：可以一个判定都不显示")
	Setting.set_judge_offset_grade("miss", true)
	_expect(Setting.judge_offset_grades == ["miss"], "延迟显示：空名单里也能再勾回来")
	Setting.changed.disconnect(counter)
	# 存盘 / 读盘：名单原样回来；坏配置（不认识的名字、重复、不是列表）都要收拾干净。
	Setting.save_settings()
	Setting.judge_offset_grades = []
	Setting.load_settings()
	_expect(Setting.judge_offset_grades == ["miss"], "延迟显示：勾选名单可以存盘并读回")
	var config := ConfigFile.new()
	config.load(Setting.SETTINGS_PATH)
	config.set_value("game", "judge_offset_grades", ["乱填", "just", "just"])
	config.save(Setting.SETTINGS_PATH)
	Setting.load_settings()
	_expect(Setting.judge_offset_grades == ["just"], "延迟显示：坏配置里只认判定文字，重复的只留一次")
	config.load(Setting.SETTINGS_PATH)
	config.set_value("game", "judge_offset_grades", "不是列表")
	config.save(Setting.SETTINGS_PATH)
	Setting.load_settings()
	_expect(Setting.judge_offset_grades == Setting.DEFAULT_JUDGE_OFFSET_GRADES, "延迟显示：不是列表就回落到默认名单")
	# 布局：位置 / 大小 / 时长都按范围夹紧，也能存盘读回。
	Setting.reset_layout()
	_expect_close(float(Setting.layout.judge_offset_y), 0.36, "延迟显示：默认纵坐标在判定文字下方")
	Setting.set_layout("judge_offset_size", 9999.0)
	_expect_close(float(Setting.layout.judge_offset_size), 200.0, "延迟显示：显示高度按上限截断")
	Setting.set_layout("judge_offset_duration", 0.0)
	_expect_close(float(Setting.layout.judge_offset_duration), 0.05, "延迟显示：显示时长按下限截断")
	Setting.set_layout("judge_offset_x", 0.72)
	Setting.save_settings()
	Setting.reset_layout()
	Setting.load_settings()
	_expect_close(float(Setting.layout.judge_offset_x), 0.72, "延迟显示：位置可以存盘并读回")
	# 触发条件：按下的 Tap / Hold 头 + 名单里的判定，三者缺一不可。
	var chart := ChartData.new(TAP_CHART)
	var field := Playfield.new()
	add_child(field)
	field.configure(Vector2(1600, 900))
	field.attach_session(PlaySession.new(chart))
	Setting.judge_offset_grades = Setting.DEFAULT_JUDGE_OFFSET_GRADES.duplicate()
	var session := field.session
	# 按早 50 ms = just（默认在名单里）→ 立刻亮起 FAST。
	session.update(0.45, {0: {"x": 0.5, "pressed": true}})
	_expect(session.last_grade == "just", "延迟显示：按早 50 ms 判为 just（实际 %s）" % session.last_grade)
	_expect(field._offset_word == "fast", "延迟显示：按下 Tap 判为 just 时显示 FAST（实际「%s」）" % field._offset_word)
	# 显示时长内一直亮着，到点自己消失（HUD 只在它亮着的时候逐帧重绘）。
	field._process(float(Setting.layout.judge_offset_duration) * 0.5)
	_expect(field._offset_word == "fast", "延迟显示：显示时长内一直亮着")
	field._process(float(Setting.layout.judge_offset_duration))
	_expect(field._offset_word.is_empty(), "延迟显示：到点后自己消失")
	# just+ 默认不在名单里：正中按下也不显示。
	var perfect := PlaySession.new(chart)
	field.attach_session(perfect)
	perfect.update(0.5, {0: {"x": 0.5, "pressed": true}})
	_expect(perfect.last_grade == "just+", "延迟显示：正好按下判为 just+（实际 %s）" % perfect.last_grade)
	_expect(field._offset_word.is_empty(), "延迟显示：默认不显示 just+（判定不为 just+ 才触发）")
	# 勾上 just+ 之后它也显示；Hold 尾判则永远不显示（尾判不是按点）。
	Setting.set_judge_offset_grade("just+", true)
	var again := PlaySession.new(chart)
	field.attach_session(again)
	again.update(0.5, {0: {"x": 0.5, "pressed": true}})
	_expect(again.last_grade == "just+" and field._offset_word == "late",
		"延迟显示：勾上 just+ 后正好按下的那一下也显示（偏差 0 算 LATE，实际「%s」）" % field._offset_word)
	again.update(1.03, {0: {"x": 0.5, "pressed": true}})
	again.update(1.5, {0: {"x": 0.5, "pressed": false}})
	_expect(again.judgement_counts["just+"] == 3 and not field._offset_visible(1, "just+", "tail"),
		"延迟显示：Hold 尾判永远不显示（哪怕名单里有）")
	Setting.set_judge_offset_grade("just+", false)
	# 漏判：没有按点，不显示。
	var missed_field := Playfield.new()
	add_child(missed_field)
	missed_field.configure(Vector2(1600, 900))
	var missed := PlaySession.new(chart)
	missed_field.attach_session(missed)
	missed.update(0.7, {})
	_expect(missed.judgement_counts.miss == 1 and missed_field._offset_word.is_empty(), "延迟显示：漏判不显示方向词")
	_expect(not missed_field._offset_visible(0, "miss", "head"), "延迟显示：漏判判定 miss 也不显示")
	# Slide 的自动命中不是按点，永远不显示。
	var slide := PlaySession.new(chart)
	missed_field.attach_session(slide)
	slide.update(0.5, {0: {"x": 0.5, "pressed": true}})
	slide.update(2.0, {1: {"x": 0.5, "pressed": false}})
	_expect(not missed_field._offset_visible(2, "just+", "head"), "延迟显示：Slide 自动命中不显示（类型不对）")
	# 名单空着时，就算按得正好也不显示。
	for grade in Setting.JUDGE_OFFSET_GRADES:
		Setting.set_judge_offset_grade(grade, false)
	var silent := PlaySession.new(chart)
	missed_field.attach_session(silent)
	silent.update(0.45, {0: {"x": 0.5, "pressed": true}})
	_expect(silent.last_grade == "just" and missed_field._offset_word.is_empty(), "延迟显示：名单空着时一直不显示")
	_expect(not missed_field._offset_visible(0, "just", "head"), "延迟显示：名单空着时触发条件为假")
	# 重开（换会话）清掉上一次的方向词，避免新一局刚开局就挂着上一局的提示。
	Setting.set_judge_offset_grade("just", true)
	var restart := PlaySession.new(chart)
	missed_field.attach_session(restart)
	restart.update(0.45, {0: {"x": 0.5, "pressed": true}})
	_expect(missed_field._offset_word == "fast", "延迟显示：勾回来之后按早又显示 FAST")
	missed_field.attach_session(PlaySession.new(chart))
	_expect(missed_field._offset_word.is_empty(), "延迟显示：重开清掉上一次的方向词")
	# 预览用同一套位置算法：横纵都是画面比例，第二行是第一行下面一行。
	Setting.reset_layout()
	var preview_field := Playfield.new()
	add_child(preview_field)
	preview_field.configure(Vector2(1600, 900))
	var preview_height := preview_field._offset_height()
	var first := preview_field._offset_position()
	var second := preview_field._offset_position(preview_height + 6.0 * preview_field.geometry.pixel_scale)
	_expect_close(first.x, 1600 * float(Setting.layout.judge_offset_x), "延迟显示：预览的横坐标 = 画面宽度 × 设置值")
	_expect_close(first.y, 900 * float(Setting.layout.judge_offset_y), "延迟显示：预览的纵坐标 = 画面高度 × 设置值（文字顶部）")
	_expect(second.y > first.y, "延迟显示：预览的第二行在第一行下面（FAST 在上、LATE 在下）")
	Setting.set_layout("judge_offset_size", 100.0)
	_expect_close(preview_field._offset_height(), 100.0 * preview_field.geometry.pixel_scale, "延迟显示：显示高度跟着设置走")
	for extra in [field, missed_field, preview_field]:
		extra.queue_free()
	Setting.reset_layout()
	Setting.judge_offset_grades = Setting.DEFAULT_JUDGE_OFFSET_GRADES.duplicate()
	Setting.save_settings()


# ---------------------------------------------------------------- 轨道取值

func _check_tracks() -> void:
	var chart := ChartData.new(EVENT_CHART)
	_expect(chart.error_message.is_empty(), "轨道：事件谱面可以加载")
	var evaluator := TrackEvaluator.new(chart)
	# 事件开始之前四种事件均取零，不能提前读取未来的 from。
	var before := evaluator.at(1, 0.0)
	_expect_close(before.x, 0.0, "轨道：事件开始前 x 为零（实际 %.3f）" % before.x)
	_expect_close(before.y, 0.0, "轨道：以宽度 0 出现的轨道在事件开始前不可见（实际 %.3f）" % before.y)
	# beat 4 → 6 由 0 渐变到 50（event_scale 100）。
	var middle := evaluator.at(1, 5.0)
	_expect_close(middle.y, 0.25, "轨道：宽度事件按进度插值（实际 %.3f）" % middle.y)
	# 事件结束后保持终值。
	var after := evaluator.at(1, 12.0)
	_expect_close(after.x, 0.5, "轨道：事件结束后保持终值 x（实际 %.3f）" % after.x)
	_expect_close(after.y, 0.5, "轨道：事件结束后保持终值 w（实际 %.3f）" % after.y)
	# 完全没有事件的轨道按“居中、整幅宽度”处理；没有音符的轨道保持不可见。
	var plain := evaluator.at(2, 0.0)
	_expect_close(plain.x, 0.0, "轨道：没有事件的轨道位置为零（实际 %.3f）" % plain.x)
	_expect_close(plain.y, 0.0, "轨道：没有事件的轨道不凭空生成宽度（实际 %.3f）" % plain.y)
	var silent := evaluator.at(3, 0.0)
	_expect_close(silent.y, 0.0, "轨道：没有事件也没有音符的轨道不可见（实际 %.3f）" % silent.y)
	var lane := evaluator.sample(0.0)[0]
	_expect(lane.has("x") and lane.has("w") and lane.has("visible") and lane.has("touch") and lane.has("zindex"), "轨道：采样结果字段完整")
	# 事件开始前轨道还不存在：首个事件的 from 只是过渡起点（转换器常把“隐形”写成 0.1），
	# 照它把轨道画出来，歌一开始就会凭空多出几条本不该存在的轨道。
	var lanes := {}
	for item in evaluator.sample(0.0):
		lanes[item.track] = item
	_expect(not lanes[1].visible, "轨道：以宽度 0 出现的轨道在事件开始前不显示")
	_expect(not lanes[4].visible, "轨道：首个事件还没开始时整条轨道不显示（起始宽度非 0 也一样）")
	_expect(lanes[5].visible, "轨道：w0thenShow 按编辑器规则显示零宽线")
	_expect(not lanes[2].visible and is_zero_approx(float(lanes[2].w)), "轨道：无事件不自动显示全宽轨道")
	_expect(not lanes.has(3), "轨道：没有事件也没有音符的轨道不参与显示")
	var begun := {}
	for item in evaluator.sample(8.0):
		begun[item.track] = item
	_expect(begun[4].visible and is_equal_approx(float(begun[4].w), 0.3),
		"轨道：事件开始后按时段的起始值显示（实际 %.3f）" % float(begun[4].w))
	_expect(begun[5].visible and is_zero_approx(float(begun[5].w)), "轨道：w0thenShow 在宽度 0 时仍然可见（线状轨道）")


# ---------------------------------------------------------------- 存储

func _check_storage() -> void:
	_expect(DirAccess.dir_exists_absolute(Storage.chart_dir), "存储：谱面目录已创建（%s）" % Storage.chart_dir)
	_expect(DirAccess.dir_exists_absolute(Storage.users_dir), "存储：素材目录已创建（%s）" % Storage.users_dir)
	var probe := Storage.chart_dir.path_join("__self_check__.bin")
	var payload := PackedByteArray([1, 2, 3, 4, 5])
	_expect(Storage.write_bytes(probe, payload), "存储：可以写入谱面目录")
	_expect(Storage.read_bytes(probe) == payload, "存储：写入内容可以读回")
	_expect(Storage.unique_path(Storage.chart_dir, "__self_check__.bin") != probe, "存储：重名文件自动改名而不是覆盖")
	DirAccess.remove_absolute(probe)
	_expect(Storage.resolve_path("user://chart", "a/b.json") == "user://chart/a/b.json", "存储：普通路径拼接")
	_expect(Storage.resolve_path("content://tree/root#song", "bg.png") == "content://tree/root#song/bg.png", "存储：SAF 子树路径拼接")
	_expect(Storage.resolve_path("content://tree/root#song", "bg.png") != "content://tree/root/song/bg.png", "存储：SAF 子路径不是斜杠拼接")
	_expect(Storage.base_directory("content://tree/root#song/bg.png") == "content://tree/root#song", "存储：SAF 目录反查")
	_expect(Storage.display_name("content://tree/root#song%20name/bg.png") == "bg.png", "存储：从 URI 取显示名")
	_expect(Storage._valid_relative_path("a/b.png") and not Storage._valid_relative_path("../x") and not Storage._valid_relative_path("a/b:c"), "存储：越界相对路径被拒绝")


# ---------------------------------------------------------------- 导入链路

func _check_import_roundtrip() -> void:
	var source := "user://__self_check_src__"
	_remove_tree(source)
	DirAccess.make_dir_recursive_absolute(source)
	var chart_path := source.path_join("chart.json")
	var audio_path := source.path_join("tone.wav")
	var background_path := source.path_join("bg.png")
	Storage.write_bytes(chart_path, TAP_CHART.to_utf8_buffer())
	Storage.write_bytes(audio_path, _make_wav())
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.4, 0.8, 1.0))
	Storage.write_bytes(background_path, image.save_png_to_buffer())
	# 直接读取（不经过导入）也要能用。
	var direct := ImportAPI.load_audio(audio_path)
	_expect(direct != null, "导入：可以直接解码 WAV（%s）" % ImportAPI.last_error)
	var direct_bg := ImportAPI.load_background(background_path)
	_expect(direct_bg != null, "导入：可以直接解码 PNG（%s）" % ImportAPI.last_error)
	# 分散文件导入：谱面 + 音乐 + 背景分别选择，写入清单后仍能整体读回。
	var loose := ImportAPI.import_files(chart_path, audio_path, background_path)
	_expect(not loose.is_empty(), "导入：分散文件导入成功（%s）" % ImportAPI.last_error)
	if not loose.is_empty():
		_expect(FileAccess.file_exists(loose.path_join(ImportAPI.MANIFEST_NAME)), "导入：分散文件生成清单")
		var bundle := ImportAPI.resolve_directory(loose)
		_expect(bundle.get("ok", false), "导入：按文件夹读回分散文件（%s）" % bundle.get("error", ""))
		_expect(bundle.get("music") != null, "导入：清单中的音乐被读取")
		_expect(bundle.get("bg") != null, "导入：清单中的背景被读取")
		_expect(bundle.get("data") is Dictionary and bundle.data.has("note"), "导入：清单中的谱面被解析")
		var loaded := ChartLoader.accept_chart(bundle.get("data"))
		_expect(loaded and ChartLoader.chart_data.note.size() == 4, "导入：读回的谱面可以进入游玩")
		_remove_tree(loose)
	# 整文件夹导入：只选文件夹，目录树原样复制，谱面自行被发现。
	var folder := ImportAPI.import_files("", "", "", source)
	_expect(not folder.is_empty(), "导入：整文件夹导入成功（%s）" % ImportAPI.last_error)
	if not folder.is_empty():
		var bundle := ImportAPI.resolve_directory(folder)
		_expect(bundle.get("ok", false), "导入：整文件夹可被解析（%s）" % bundle.get("error", ""))
		_expect(bundle.get("music") != null, "导入：整文件夹中的音乐被自动识别")
		_expect(bundle.get("bg") != null, "导入：整文件夹中的背景被自动识别")
		_remove_tree(folder)
	# 缺少谱面时必须给出明确错误，而不是静默失败。
	var empty_folder := "user://__self_check_empty__"
	_remove_tree(empty_folder)
	DirAccess.make_dir_recursive_absolute(empty_folder)
	var broken := ImportAPI.resolve_directory(empty_folder)
	_expect(not broken.get("ok", true) and not ImportAPI.last_error.is_empty(), "导入：空文件夹报错可读")
	_remove_tree(empty_folder)
	_remove_tree(source)


# ---------------------------------------------------------------- TAKANA 谱面导入

## 文件夹式的 TAKANA 谱面：既没有 dakumi.bundle.json，谱面也不叫 chart.json，
## 全靠读取器认出格式、找齐谱面/音乐/封面（后两者由 TAKANA 的工程文件指名）。
const TAKANA_FOLDER_CHART := """
{
  "version": 3,
  "properties": {"offset": {"value": 120, "type": "offset"}},
  "components": [
    {"id": 0, "model": {"type": "line"}, "children": [
      {"id": 7, "name": "lane",
       "model": {"type": "track", "timeStart": 0, "timeEnd": 9000,
         "movement": {"type": "trackDirectMovement",
           "position": {"type": "position", "list": {"0": "v1e_(0, u)"}},
           "width": {"type": "position", "list": {"0": "v1e_(4.5, u)"}}}},
       "children": [
         {"id": 8, "model": {"type": "hit", "timeJudge": 1000}},
         {"id": 9, "model": {"type": "hold", "timeJudge": 2000, "timeEnd": 3000}}]}]}
  ]
}
"""

## TAKANA 的曲目信息：难度用文件名（normal/hard/master/insanity/ravage）对号。
const TAKANA_SONGINFO := """
title:
  zh-Hans: 自检 TAKANA
  en: self check takana
composer: 自检曲师
difficulties:
  "3":
    levelDisplay: "12"
    charter: 自检谱师
"""

## 曲目工程文件：只用来指名音乐与封面，扫描顺序挑不出正确文件时要靠它。
const TAKANA_PROJECT := """
musicFileName: tone.wav
coverFileName: bg.png
"""

## 多难度的 TAKANA 曲目信息：等级按难度编号（1=normal … 5=ravage）对号。
const TAKANA_MULTI_SONGINFO := """
title:
  zh-Hans: 自检 TAKANA 多难度
composer: 自检曲师
difficulties:
  "1":
    levelDisplay: "5"
  "2":
    levelDisplay: "9"
  "3":
    levelDisplay: "12"
"""

## 多难度的曲目工程文件：难度名 → 谱面文件名（不带后缀），大小写与文件名不一致也要认；
## 最后两个难度指了名却没有文件，扫描时应该跳过它们。
const TAKANA_MULTI_PROJECT := """
musicFileName: tone.wav
coverFileName: bg.png
normalChartFileName: normal
hardChartFileName: hard
masterChartFileName: MASTER
insanityChartFileName: insanity
ravageChartFileName: ravage
"""

## TAKANA 谱面走玩家真实点击导入的那条链路：文件夹导入 → 读取器找谱面 → 进游玩。
func _check_takana_import() -> void:
	var source := "user://__self_check_takana__"
	_remove_tree(source)
	DirAccess.make_dir_recursive_absolute(source)
	Storage.write_bytes(source.path_join("master.json"), TAKANA_FOLDER_CHART.to_utf8_buffer())
	Storage.write_bytes(source.path_join("songinfo.yaml"), TAKANA_SONGINFO.to_utf8_buffer())
	Storage.write_bytes(source.path_join("self_check.t3proj"), TAKANA_PROJECT.to_utf8_buffer())
	Storage.write_bytes(source.path_join("tone.wav"), _make_wav())
	Storage.write_bytes(source.path_join("decoy.wav"), _make_wav())
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(FIXTURE_ART)
	Storage.write_bytes(source.path_join("bg.png"), image.save_png_to_buffer())
	# 点名一个谱面文件时也要认：外部读取器就是走这条路。
	var direct := ChartData.new(JSON.stringify(ImportAPI.load_chart(source.path_join("master.json"), source)))
	_expect(direct.mode == "takana" and direct.note.size() == 2, "TAKANA 导入：直接读谱面文件认得出 TAKANA 模式（%s）" % direct.error_message)
	_expect_close(direct.offset, -120.0, "TAKANA 导入：offset 取负号（TAKANA 与 dakumi 相反）")
	var folder := ImportAPI.import_files("", "", "", source)
	_expect(not folder.is_empty(), "TAKANA 导入：整文件夹导入成功（%s）" % ImportAPI.last_error)
	if not folder.is_empty():
		var bundle := ImportAPI.resolve_directory(folder)
		_expect(bundle.get("ok", false), "TAKANA 导入：读取器自己找到了谱面（%s）" % bundle.get("error", ""))
		_expect(str(bundle.get("audio_path", "")).ends_with("tone.wav"), "TAKANA 导入：音乐按工程文件指名取，不按扫描顺序（实际 %s）" % str(bundle.get("audio_path", "")))
		_expect(str(bundle.get("background_path", "")).ends_with("bg.png"), "TAKANA 导入：封面按工程文件指名取（实际 %s）" % str(bundle.get("background_path", "")))
		var data: Variant = bundle.get("data")
		_expect(data is Dictionary and str(data.get("mode", "")) == "takana", "TAKANA 导入：谱面被认成 TAKANA 模式")
		if data is Dictionary:
			var parsed := ChartData.new(JSON.stringify(data))
			_expect(parsed.info.song_name == "自检 TAKANA", "TAKANA 导入：曲名取自 songinfo.yaml（实际「%s」）" % parsed.info.song_name)
			_expect(parsed.info.artist == "自检曲师", "TAKANA 导入：曲师取自 songinfo.yaml（实际「%s」）" % parsed.info.artist)
			_expect(parsed.info.chart_name == "MASTER 12", "TAKANA 导入：难度按文件名与等级显示（实际「%s」）" % parsed.info.chart_name)
			_expect(parsed.info.chartor == "自检谱师", "TAKANA 导入：谱师取自 songinfo.yaml（实际「%s」）" % parsed.info.chartor)
			_expect(ChartLoader.accept_chart(data) and ChartLoader.chart_data.mode == "takana", "TAKANA 导入：可以直接进入游玩（%s）" % ChartLoader.last_error)
			var session := PlaySession.new(ChartLoader.chart_data)
			session.update(1.0, {0: {"x": 0.5, "pressed": true}})
			_expect(session.states[0] == PlaySession.State.DONE and session.last_grade == "just+", "TAKANA 导入：轨道落在 TAKANA 舞台坐标换算出的位置")
		_remove_tree(folder)
	_remove_tree(source)


## 一个 TAKANA 文件夹里有多个难度：按 normal → ravage 的顺序列全，缺文件的难度跳过，
## 编辑中的同名谱面与正式谱算同一张，工程文件里的大小写与文件名不一致也要认。
func _check_takana_multi() -> void:
	var source := "user://__self_check_takana_multi__"
	_remove_tree(source)
	DirAccess.make_dir_recursive_absolute(source)
	# 音符数各不相同：加载完看音符数就知道读的是哪一张（master.editing.json 多一个，用来验证没被选中）。
	Storage.write_bytes(source.path_join("normal.json"), _takana_chart(1).to_utf8_buffer())
	Storage.write_bytes(source.path_join("hard.json"), _takana_chart(3).to_utf8_buffer())
	Storage.write_bytes(source.path_join("master.json"), _takana_chart(5).to_utf8_buffer())
	Storage.write_bytes(source.path_join("master.editing.json"), _takana_chart(7).to_utf8_buffer())
	Storage.write_bytes(source.path_join("songinfo.yaml"), TAKANA_MULTI_SONGINFO.to_utf8_buffer())
	Storage.write_bytes(source.path_join("proj.t3proj"), TAKANA_MULTI_PROJECT.to_utf8_buffer())
	Storage.write_bytes(source.path_join("tone.wav"), _make_wav())
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(FIXTURE_ART)
	Storage.write_bytes(source.path_join("bg.png"), image.save_png_to_buffer())
	var folder := ImportAPI.import_files("", "", "", source)
	_expect(not folder.is_empty(), "TAKANA 多谱面：整文件夹导入成功（%s）" % ImportAPI.last_error)
	var charts := ImportAPI.list_charts(folder)
	_expect(charts.size() == 3, "TAKANA 多谱面：按难度列出全部谱面（实际 %d 张）" % charts.size())
	if charts.size() == 3:
		var names: Array[String] = []
		for chart in charts:
			names.append(Storage.display_name(str(chart.chart)))
		_expect(", ".join(names) == "normal.json, hard.json, master.json",
			"TAKANA 多谱面：难度顺序 normal → ravage，指了名却没有文件的难度跳过（%s）" % ", ".join(names))
		_expect(str(charts[0].label) == "NORMAL" and str(charts[1].label) == "HARD" and str(charts[2].label) == "MASTER",
			"TAKANA 多谱面：标签就是难度名（%s）" % _chart_labels(charts))
		_expect(str(charts[0].detail) == "5" and str(charts[1].detail) == "9" and str(charts[2].detail) == "12",
			"TAKANA 多谱面：等级取自 songinfo.yaml（%s）" % _chart_labels(charts))
		_expect(str(charts[2].chart).ends_with("master.json"),
			"TAKANA 多谱面：编辑中的同名谱面不算另一张，正式谱优先（%s）" % str(charts[2].chart))
		_expect(ChartLoader.load_from_folder(folder, str(charts[1].chart)), "TAKANA 多谱面：可以按路径加载指定难度（%s）" % ChartLoader.last_error)
		_expect(str(ChartLoader.chart_data.info.chart_name).begins_with("HARD") and ChartLoader.chart_data.note.size() == 3,
			"TAKANA 多谱面：加载的是 HARD 那张（%s / %d 个音符）" % [str(ChartLoader.chart_data.info.chart_name), ChartLoader.chart_data.note.size()])
		_expect(ChartLoader.score_key() == Setting.song_key(folder) + "#hard", "TAKANA 多谱面：成绩按难度分记（%s）" % ChartLoader.score_key())
		_expect(ChartLoader.load_from_folder(folder) and ChartLoader.chart_data.note.size() == 1,
			"TAKANA 多谱面：不给谱面路径时读第一张（NORMAL）")
	_remove_tree(folder)
	_remove_tree(source)


## 造一张 TAKANA 谱面：一条轨道上放 hits 个单点音符，音符数就是它的身份。
func _takana_chart(hits: int) -> String:
	var notes: Array[String] = []
	for index in hits:
		notes.append("{\"id\": %d, \"model\": {\"type\": \"hit\", \"timeJudge\": %d}}" % [100 + index, 1000 + 1000 * index])
	return """
{
  "version": 3,
  "properties": {"offset": {"value": 0, "type": "offset"}},
  "components": [
    {"id": 0, "model": {"type": "line"}, "children": [
      {"id": 7, "name": "lane",
       "model": {"type": "track", "timeStart": 0, "timeEnd": 9000,
         "movement": {"type": "trackDirectMovement",
           "position": {"type": "position", "list": {"0": "v1e_(0, u)"}},
           "width": {"type": "position", "list": {"0": "v1e_(4.5, u)"}}}},
       "children": [%s]}]}
  ]
}
""" % ", ".join(notes)


## 扫描结果里每条谱面的「难度 等级」，拼成一行给断言当失败信息。
func _chart_labels(charts: Array[Dictionary]) -> String:
	var labels: Array[String] = []
	for chart in charts:
		labels.append(("%s %s" % [str(chart.label), str(chart.detail)]).strip_edges())
	return ", ".join(labels)


# ---------------------------------------------------------------- 绘制探针

func _check_draw_probe() -> void:
	_probe = DrawProbe.new()
	add_child(_probe)
	_probe.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _probe.executed:
		_note("绘制探针：当前环境没有渲染帧（headless），跳过绘制检查")
		return
	_expect(_probe.panels_drawn > 0, "绘制：九宫格面板调用了 %d 次" % _probe.panels_drawn)
	_expect(_probe.hits_drawn > 0, "绘制：打击特效可以绘制")
	_expect(_probe.numbers_drawn > 0, "绘制：数字可以绘制")
	_expect(_probe.grades_drawn > 0, "绘制：判定反馈可以绘制（文字与图片两条路径）")
	_expect(_probe.offset_words_drawn > 0, "绘制：击打延迟显示可以绘制（文字与图片两条路径）")
	# 绘制返回值即“是否继续显示”，是打击特效生命周期的唯一判据。
	_expect(not _probe.hit_expired, "绘制：单图打击特效在显示时长后结束")
	_expect(_probe.hit_looping, "绘制：Hold 循环精灵图在保持期间持续显示")
	_probe.queue_free()


# ---------------------------------------------------------------- 音频延迟

## 时间偏移限制在 ±Setting.OFFSET_LIMIT 内（谱面偏移与单曲延迟仍不设限），且最终延迟 =
## 时间偏移 + 谱面自带 offset；两者都在 ChartLoader.total_offset_seconds() 里相加，游玩时钟只读这一个出口。
## 方向约定（改文字或改公式前先读这里）：游玩时钟是 chart_time = 音频位置 - 最终延迟（gd/room/demo.gd），
## 所以最终延迟为正 = 音符要等音频再多走这么久才判定 = 音频相对谱面提前。设置页提示与 ChartLoader 的注释都按这个方向写。
func _check_offset() -> void:
	var original_offset: float = Setting.offset
	var original_chart_shift: float = Setting.chart_offset
	var original_chart: ChartData = ChartLoader.chart_data
	# 可调范围 ±3000 ms：超出端点的值一律夹住，范围里的值原样保留（滑条与数值框同量程）。
	_expect_close(Setting.OFFSET_LIMIT, 3000.0, "音频延迟：可调范围是 3000 ms")
	for value in [123456.0, 3600000.0, 3000.5]:
		Setting.set("offset", value)
		Setting.apply_settings()
		_expect_close(Setting.offset, Setting.OFFSET_LIMIT, "音频延迟：%s ms 夹到上限" % str(value))
	for value in [-98765.5, -3600000.0, -3000.5]:
		Setting.set("offset", value)
		Setting.apply_settings()
		_expect_close(Setting.offset, -Setting.OFFSET_LIMIT, "音频延迟：%s ms 夹到下限" % str(value))
	for value in [2999.5, -2999.5, 0.0]:
		Setting.set("offset", value)
		Setting.apply_settings()
		_expect_close(Setting.offset, value, "音频延迟：范围里的 %s ms 原样保留" % str(value))
	# 非有限值无法参与运算，退回默认值而不是写坏配置。
	Setting.set("offset", INF)
	Setting.apply_settings()
	_expect_close(Setting.offset, 0.0, "音频延迟：无穷大退回默认值")
	Setting.set("offset", NAN)
	Setting.apply_settings()
	_expect_close(Setting.offset, 0.0, "音频延迟：NaN 退回默认值")
	# 存盘读回：范围内的值不丢精度；手改配置留下的越界值读回来也要夹住。
	Setting.set("offset", 1234.5)
	Setting.apply_settings()
	Setting.save_settings()
	Setting.load_settings()
	_expect_close(Setting.offset, 1234.5, "音频延迟：保存后读回不丢精度")
	var out_of_range := ConfigFile.new()
	out_of_range.load(Setting.SETTINGS_PATH)
	out_of_range.set_value("game", "offset", 9999.0)
	out_of_range.save(Setting.SETTINGS_PATH)
	Setting.load_settings()
	_expect_close(Setting.offset, Setting.OFFSET_LIMIT, "音频延迟：旧配置里的越界值读回来夹到上限")
	# 最终延迟 = 单曲延迟 + 时间偏移 + 谱面 offset。
	ChartLoader.accept_chart('{"offset": 250, "note": [{"beat": 1, "track": 1}]}')
	Setting.set("offset", -100.0)
	Setting.apply_settings()
	_expect_close(ChartLoader.total_offset_seconds(), 0.15, "音频延迟：最终延迟 = 时间偏移 + 谱面 offset（-100 + 250 ms）")
	_expect_close(ChartLoader.getStartTime(), -0.15 - ChartLoader.wait_time, "音频延迟：开唱时间与最终延迟一致")
	# 方向：正值让谱面推后去等声音（同一时刻听到的已经是更靠后的音乐）。
	Setting.set("offset", 100.0)
	Setting.apply_settings()
	_expect_close(ChartLoader.total_offset_seconds(), 0.35, "音频延迟：正值把谱面推后 100 ms（100 + 250 ms）")
	Setting.set("offset", 2000.0)
	Setting.apply_settings()
	_expect_close(ChartLoader.total_offset_seconds(), 2.25, "音频延迟：大偏移同样参与求和（2000 + 250 ms）")
	# 没有谱面时只算玩家偏移，不会因为没有谱面而丢掉设置。
	ChartLoader.accept_chart('{"note": []}')
	_expect_close(ChartLoader.total_offset_seconds(), 2.0, "音频延迟：未标注 offset 的谱面按 0 计")
	ChartLoader.chart_data = null
	_expect_close(ChartLoader.total_offset_seconds(), 2.0, "音频延迟：没有谱面时仍按时间偏移计")
	# 谱面偏移：与时间偏移是同一个位移的反方向写法，数值同样不设上限。
	for value in [123456.0, -98765.5, 3600000.0]:
		Setting.set("chart_offset", value)
		Setting.apply_settings()
		_expect_close(Setting.chart_offset, value, "谱面偏移：%s ms 不被夹住" % str(value))
	Setting.set("chart_offset", INF)
	Setting.apply_settings()
	_expect_close(Setting.chart_offset, 0.0, "谱面偏移：无穷大退回默认值")
	Setting.set("chart_offset", NAN)
	Setting.apply_settings()
	_expect_close(Setting.chart_offset, 0.0, "谱面偏移：NaN 退回默认值")
	Setting.set("chart_offset", -125.5)
	Setting.apply_settings()
	Setting.save_settings()
	Setting.load_settings()
	_expect_close(Setting.chart_offset, -125.5, "谱面偏移：保存后读回不丢精度也不被夹住")
	# 反号：谱面偏移 +100 与时间偏移 -100 得到完全一样的最终延迟，两者都只影响这一个出口。
	ChartLoader.accept_chart('{"offset": 250, "note": [{"beat": 1, "track": 1}]}')
	Setting.set("offset", -100.0)
	Setting.set("chart_offset", 0.0)
	Setting.apply_settings()
	var with_audio: float = ChartLoader.total_offset_seconds()
	Setting.set("offset", 0.0)
	Setting.set("chart_offset", 100.0)
	Setting.apply_settings()
	_expect_close(ChartLoader.total_offset_seconds(), with_audio, "谱面偏移：+100 与时间偏移 -100 完全等效")
	_expect_close(ChartLoader.total_offset_seconds(), 0.15, "谱面偏移：最终延迟 = 谱面自带 offset - 谱面偏移（250 - 100 ms）")
	_expect_close(ChartLoader.getStartTime(), -0.15 - ChartLoader.wait_time, "谱面偏移：开唱时间跟着最终延迟走")
	# 读数四项都在，谱面偏移按取反后的贡献值打印（填 +100 就显示 -100，四个数直接相加）。
	var breakdown := UI.offset_breakdown(-80.0, 100.0, 100.0, 250.0)
	_expect(breakdown.contains("单曲 -80 ms") and breakdown.contains("时间偏移 +100 ms")
		and breakdown.contains("谱面偏移（反向）-100 ms") and breakdown.contains("谱面自带 offset +250 ms")
		and breakdown.contains("= +170 ms"),
		"谱面偏移：读数把四项与最终值写全（%s）" % breakdown)
	# 还原：先还原谱面，再还原设置，最后让磁盘上的配置回到进入自检前的样子。
	ChartLoader.chart_data = original_chart
	Setting.set("offset", original_offset)
	Setting.set("chart_offset", original_chart_shift)
	Setting.apply_settings()


## 单曲延迟：按谱面文件夹记住，三项相加才是最终延迟。
func _check_song_offset() -> void:
	var original_offset: float = Setting.offset
	var original_song: Dictionary = Setting.song_offsets.duplicate()
	var original_folder := ChartLoader.selected_folder
	var original_chart: ChartData = ChartLoader.chart_data
	Setting.song_offsets.clear()
	# 身份用文件夹名：路径写法不同（结尾斜杠、反斜杠、URL 编码）也要对到同一首歌。
	var folder := "user://chart/自检曲目"
	for spelling in [folder, folder + "/", "user://chart\\自检曲目", "user://chart/" + "自检曲目".uri_encode()]:
		Setting.set_song_offset(spelling, 250.0)
		_expect_close(Setting.song_offset_of(folder), 250.0, "单曲延迟：%s 与 %s 是同一首歌" % [spelling, folder])
	_expect(Setting.song_offsets.size() == 1, "单曲延迟：同一首歌只留一个键（实际 %d 个）" % Setting.song_offsets.size())
	_expect_close(Setting.song_offset_of("user://chart/别的歌"), 0.0, "单曲延迟：没调过的歌是 0")
	_expect_close(Setting.song_offset_of(""), 0.0, "单曲延迟：空路径不参与（没有当前谱面时是 0）")
	Setting.set_song_offset("", 500.0)
	_expect(Setting.song_offsets.size() == 1, "单曲延迟：空路径写不进去")
	# 不设上下限，只拒绝非有限值；归零就把键删掉。
	for value in [123456.0, -98765.5, 3600000.0]:
		Setting.set_song_offset(folder, value)
		_expect_close(Setting.song_offset_of(folder), value, "单曲延迟：%s ms 不被夹住" % str(value))
	Setting.set_song_offset(folder, INF)
	Setting.set_song_offset(folder, NAN)
	_expect_close(Setting.song_offset_of(folder), 0.0, "单曲延迟：非有限值退回 0")
	_expect(not Setting.song_offsets.has("自检曲目"), "单曲延迟：归零后不留在配置里")
	# 存盘 / 读盘往返：单曲延迟跟着这首歌一起回来。
	Setting.set_song_offset(folder, -80.0)
	Setting.set_song_offset("user://chart/另一首", 45.0)
	Setting.save_settings()
	Setting.song_offsets.clear()
	Setting.load_settings()
	_expect_close(Setting.song_offset_of(folder), -80.0, "单曲延迟：存盘后按谱面读回")
	_expect_close(Setting.song_offset_of("user://chart/另一首"), 45.0, "单曲延迟：另一首各自的数值也在")
	# 三项相加：最终延迟 = 单曲延迟 + 时间偏移 + 谱面自带 offset。
	ChartLoader.accept_chart('{"offset": 250, "note": [{"beat": 1, "track": 1}]}')
	ChartLoader.selected_folder = folder
	Setting.set("offset", 100.0)
	Setting.apply_settings()
	_expect_close(ChartLoader.total_offset_seconds(), 0.27, "单曲延迟：最终延迟 = 单曲 -80 + 时间偏移 100 + 谱面 250 ms")
	_expect_close(ChartLoader.getStartTime(), -0.27 - ChartLoader.wait_time, "单曲延迟：开唱时间跟着最终延迟走")
	Setting.set_song_offset(folder, 0.0)
	_expect_close(ChartLoader.total_offset_seconds(), 0.35, "单曲延迟：单曲归零后只剩时间偏移与谱面 offset")
	ChartLoader.selected_folder = ""
	_expect_close(ChartLoader.total_offset_seconds(), 0.35, "单曲延迟：没有选中谱面时单曲项按 0 计")
	# 读数：四个数与它们的和都要出现在同一行文字里（谱面偏移这里取 0，等价于不设）。
	var text := UI.offset_breakdown(-80.0, 100.0, 0.0, 250.0)
	_expect(text.contains("单曲 -80 ms") and text.contains("时间偏移 +100 ms") and text.contains("谱面自带 offset +250 ms") and text.contains("= +270 ms"),
		"单曲延迟：读数把四项与最终值写全（%s）" % text)
	_expect(UI.ms(1234.0) == "+1234" and UI.ms(-1.5) == "-1.5" and UI.ms(0.0) == "0" and UI.ms(-0.0) == "0",
		"单曲延迟：毫秒读数整数不带小数尾巴、正数带 +、负零按 0（%s / %s / %s / %s）" % [UI.ms(1234.0), UI.ms(-1.5), UI.ms(0.0), UI.ms(-0.0)])
	# 还原内存状态（磁盘由 _ready 统一还原）。
	Setting.song_offsets = original_song
	ChartLoader.selected_folder = original_folder
	ChartLoader.chart_data = original_chart
	Setting.set("offset", original_offset)
	Setting.apply_settings()


# ---------------------------------------------------------------- 最高帧率

## 最高帧率只认 30 / 60 / 120 / 240 / 无上限（0）五个档位，改完立刻写进引擎。
func _check_max_fps() -> void:
	var original: int = Setting.max_fps
	_expect(Setting.FPS_CHOICES == [30, 60, 120, 240, 0], "帧率：档位就是 30 / 60 / 120 / 240 / 无上限（%s）" % str(Setting.FPS_CHOICES))
	_expect(Setting.DEFAULT_MAX_FPS == 0, "帧率：默认不限制（和项目一直以来的行为一致）")
	for fps in Setting.FPS_CHOICES:
		Setting.set_max_fps(fps)
		_expect(Setting.max_fps == fps, "帧率：切到 %s 档" % ("无上限" if fps <= 0 else str(fps)))
		_expect(Engine.max_fps == fps, "帧率：%s 档立刻交给引擎（Engine.max_fps）" % str(fps))
	# 档位以外的值一律忽略：既不写进设置，也不去动引擎。
	for value in [0.5, 45, 144, 1000, -60, "120", null, INF, NAN]:
		var before: int = Setting.max_fps
		Setting.set_max_fps(value)
		_expect(Setting.max_fps == before, "帧率：%s 不是档位，被忽略" % str(value))
	# 非有限值 / 越界值读盘时回落到默认档，配置被改坏也不会让引擎收到奇怪的值。
	_expect(Setting._fps(INF, -1) == -1 and Setting._fps(1e9, -1) == -1 and Setting._fps("60", -1) == -1,
		"帧率：非法输入回落到兜底值")
	_expect(Setting._fps(240.0, -1) == 240, "帧率：读盘时浮点档位按整数认（240.0 → 240）")
	# 存盘 / 读盘往返：档位原样回来，并且重新交给引擎。
	Setting.set_max_fps(120)
	Setting.save_settings()
	Setting.set_max_fps(30)
	Setting.load_settings()
	_expect(Setting.max_fps == 120, "帧率：存盘后读回原档位（实际 %d）" % Setting.max_fps)
	_expect(Engine.max_fps == 120, "帧率：读盘后重新应用到引擎")
	Setting.set_max_fps(original)


## 成绩册：每首歌只留最好的一次（按分数比大小），键与单曲延迟同一套（文件夹名）。
func _check_scores() -> void:
	var folder := "user://chart/自检曲目"
	Scores.scores.clear()
	_expect(Scores.best(folder).is_empty() and Scores.plays(folder) == 0, "成绩：没打过的歌没有成绩")
	var first := {"score": 500000, "max_combo": 100, "total_units": 200, "position_mode": Setting.JUDGE_POSITION_CURRENT,
		"counts": {"just+": 180, "just": 10, "good": 5, "ok": 3, "miss": 2}}
	_expect(Scores.record(folder, first), "成绩：第一次通关就是最好成绩")
	# 身份与单曲延迟同一套键：路径写法不同也要记到同一首歌上。
	for spelling in [folder + "/", "user://chart\\自检曲目", "user://chart/" + "自检曲目".uri_encode()]:
		_expect(int(Scores.best(spelling).get("score", 0)) == 500000, "成绩：%s 与 %s 是同一首歌" % [spelling, folder])
	_expect(Scores.scores.size() == 1, "成绩：同一首歌只留一条（实际 %d 条）" % Scores.scores.size())
	_expect(Scores.plays(folder) == 1, "成绩：记一次游玩")
	_expect(int(Scores.best(folder).get("max_combo", 0)) == 100 and int(Scores.best(folder).counts["just+"]) == 180,
		"成绩：最大连击与判定数量一起存下来")
	# 打得更差：照样算一次游玩，但快照不换（分数低的那局的连击也不能顶掉纪录）。
	var worse := first.duplicate(true)
	worse.score = 400000
	worse.max_combo = 300
	_expect(not Scores.record(folder, worse), "成绩：分数更低不刷新纪录")
	_expect(int(Scores.best(folder).get("score", 0)) == 500000 and int(Scores.best(folder).get("max_combo", 0)) == 100,
		"成绩：低分那局的数据不会顶掉纪录")
	_expect(Scores.plays(folder) == 2, "成绩：打得更差也计一次游玩")
	_expect(not Scores.record(folder, first), "成绩：同分不算刷新")
	var better := first.duplicate(true)
	better.score = 968420
	better.max_combo = 328
	_expect(Scores.record(folder, better), "成绩：分数更高刷新纪录")
	_expect(int(Scores.best(folder).get("score", 0)) == 968420 and Scores.plays(folder) == 4,
		"成绩：刷新后分数与游玩次数都对")
	# 没有选中谱面、空快照都不写。
	_expect(not Scores.record("", first) and Scores.scores.size() == 1, "成绩：没有选中谱面时不记")
	_expect(not Scores.record(folder, {}), "成绩：空快照不记")
	# 坏值：超范围分数按上限截断，坏判定数归零，缺的判定补 0。
	_expect(Scores.record("user://chart/坏数据", {"score": 99999999, "max_combo": -5, "counts": {"just+": "多", "miss": 2.7}}),
		"成绩：坏快照也能记一次")
	var bad: Dictionary = Scores.best("user://chart/坏数据")
	_expect(int(bad.score) == Scores.MAX_SCORE, "成绩：超范围分数按上限截断")
	_expect(int(bad.max_combo) == 0 and int(bad.counts["just+"]) == 0 and int(bad.counts.miss) == 3 and int(bad.counts.ok) == 0,
		"成绩：坏判定数量归零、缺的判定补 0（小数四舍五入）")
	# 存盘 / 读盘：两首歌一起回来，判定数量的键（带 +）也不走样。
	Scores.save_scores()
	Scores.scores.clear()
	Scores.load_scores()
	_expect(int(Scores.best(folder).get("score", 0)) == 968420 and int(Scores.best(folder).counts["just+"]) == 180,
		"成绩：存盘后按谱面读回（含判定数量）")
	_expect(Scores.plays(folder) == 4 and int(Scores.best("user://chart/坏数据").get("score", 0)) == Scores.MAX_SCORE,
		"成绩：另一首与坏数据那条一起读回")
	_expect(str(Scores.best(folder).get("mode", "")) == Setting.JUDGE_POSITION_CURRENT, "成绩：记下这一局用的判定模式")
	# 平均击打延迟跟着成绩一起存：坏值归零 / 按上限截断，不让配置里的坏数据决定读数。
	var latency_run := first.duplicate(true)
	latency_run.score = 990000
	latency_run["average_offset"] = -0.0123
	latency_run["offset_samples"] = 214
	Scores.record("user://chart/延迟数据", latency_run)
	var latency: Dictionary = Scores.best("user://chart/延迟数据")
	_expect_close(float(latency.average_offset), -0.0123, "成绩：平均击打延迟跟着成绩一起记")
	_expect(int(latency.offset_samples) == 214, "成绩：按点样本数一起记")
	Scores.record("user://chart/延迟坏数据", {"score": 1, "average_offset": "多", "offset_samples": -3})
	var bad_latency: Dictionary = Scores.best("user://chart/延迟坏数据")
	_expect_close(float(bad_latency.average_offset), 0.0, "成绩：坏的平均延迟归零")
	_expect(int(bad_latency.offset_samples) == 0, "成绩：坏的样本数归零")
	Scores.record("user://chart/延迟越界", {"score": 1, "average_offset": 99.0, "offset_samples": Scores.MAX_UNITS})
	_expect_close(float(Scores.best("user://chart/延迟越界").average_offset), Scores.MAX_OFFSET, "成绩：超范围的平均延迟按上限截断")
	Scores.load_scores()
	_expect_close(float(Scores.best("user://chart/延迟数据").average_offset), -0.0123, "成绩：平均击打延迟存盘后读回")
	# 配置被改坏时读成空成绩册，不让坏数据决定界面显示什么。
	Storage.write_bytes(SCORES_TEMP, "[score]
坏=不是字典
不对={\"连击\": 3}
".to_utf8_buffer())
	Scores.load_scores()
	_expect(Scores.scores.is_empty(), "成绩：配置文件坏掉时读成空成绩册")
	Scores.record(folder, first)
	_expect(not Scores.scores.is_empty(), "成绩：读坏文件后仍然可以继续记成绩")
	Scores.clear()
	Scores.load_scores()
	_expect(Scores.scores.is_empty(), "成绩：清空后磁盘上也不留成绩")


class DrawProbe:
	extends Node2D
	var executed: bool = false
	var panels_drawn: int = 0
	var hits_drawn: int = 0
	var numbers_drawn: int = 0
	var grades_drawn: int = 0
	var offset_words_drawn: int = 0
	var hit_expired: bool = true
	var hit_looping: bool = false

	func _draw() -> void:
		executed = true
		# 九宫格：中间拉伸与左右拉伸、含边距与无边距都要能画。
		for spec in [{"margin_left": 8.0, "margin_right": 8.0, "margin_top": 6.0, "margin_bottom": 6.0, "stretch_mode": "center"},
				{"margin_left": 8.0, "margin_right": 8.0, "margin_top": 6.0, "margin_bottom": 6.0, "stretch_mode": "sides"},
				{}]:
			var previous: Dictionary = Setting.skin["note_tap"].duplicate(true)
			Setting.skin["note_tap"] = Setting._normalize_skin("note_tap", spec)
			Skins.draw_panel(self, "note_tap", Rect2(10, 10, 220, 28))
			panels_drawn += 1
			Setting.skin["note_tap"] = previous
		Skins.draw_panel(self, "judge_line", Rect2(0, 300, 640, 12))
		Skins.draw_panel(self, "exit", Rect2(0, 0, 48, 48))
		Skins.draw_panel(self, "不存在的槽位", Rect2(0, 0, 48, 48))
		# 单图：显示时长内继续，超时结束
		hit_expired = not Skins.draw_hit(self, "tap", Vector2(100, 100), 0.1)
		Skins.draw_hit(self, "tap", Vector2(100, 100), 0.05, false, 1.0)
		Skins.draw_hit(self, "tap", Vector2(100, 100), 5.0, false, 1.0)
		hits_drawn += 1
		# 精灵图：2×2 共 4 帧，按行优先取帧；循环到 Hold 结束时一直显示
		var sheet := {"path": "", "duration": 0.3, "frames": 4, "frame_duration": 0.05,
			"rows": 2, "columns": 2, "start_frame": 0, "loop_hold": true}
		var previous_hit: Dictionary = Setting.skin["hit_hold"].duplicate(true)
		Setting.skin["hit_hold"] = Setting._normalize_skin("hit_hold", sheet)
		hit_looping = Skins.draw_hit(self, "hold", Vector2(120, 120), 3.7, true, 1.0)
		for step in 6:
			Skins.draw_hit(self, "hold", Vector2(120, 120), step * 0.04, false, 1.0)
		Setting.skin["hit_hold"] = previous_hit
		# 数字：素材与字体回退都要覆盖
		Skins.draw_number(self, "0123456789", Vector2(320, 40), 40.0)
		Skins.draw_number(self, "-12.5", Vector2(320, 120), 24.0)
		Skins.draw_number(self, "", Vector2(320, 200), 24.0)
		numbers_drawn += 1
		# 判定反馈：默认画文字，导入图片后画图片，空判定名不画。
		Skins.draw_grade(self, "just+", Vector2(320, 240), 40.0)
		var previous_grade: Dictionary = Setting.skin["judge_just"].duplicate(true)
		Setting.set_skin_field("judge_just", "path", "res://assets/img/hit.png")
		Skins.draw_grade(self, "just", Vector2(320, 300), 40.0)
		Setting.skin["judge_just"] = previous_grade
		Skins.draw_grade(self, "", Vector2(320, 360), 40.0)
		grades_drawn += 1
		# 击打延迟显示：两个方向各一行，文字与图片两条路径都要能画，坏名字不画。
		Skins.draw_offset_word(self, "fast", Vector2(320, 420), 40.0)
		Skins.draw_offset_word(self, "late", Vector2(320, 470), 40.0)
		var previous_fast: Dictionary = Setting.skin["judge_fast"].duplicate(true)
		Setting.set_skin_field("judge_fast", "path", "res://assets/img/hit.png")
		Skins.draw_offset_word(self, "fast", Vector2(320, 520), 40.0)
		Setting.skin["judge_fast"] = previous_fast
		Skins.draw_offset_word(self, "early", Vector2(320, 570), 40.0)
		Skins.draw_offset_word(self, "late", Vector2(320, 620), 0.0)
		offset_words_drawn += 1


# ---------------------------------------------------------------- 3D 舞台像素检查

## 用真实渲染结果核对 3D 倾斜：StageProbe 继承 Playfield，走同一套
## 画布 → 相机 / 平面 / 视锥管线，只把轨道内容换成已知的白黑分带，
## 于是可以把渲染像素和几何模型的预测逐项对照：
##   · 判定线所在行 1:1（旋转轴过判定线中点，判定线上大小不变）；
##   · 判定线横跨游玩区域，两端落在两侧的侧线上；
##   · 判定线上方横向收敛 k = row_scale(u)、纵向按 k² 压缩；
##   · 贴图采样是透视正确的（分带边界落在模型预测的行上）——这正是 Hold 拉伸的根因。
func _check_stage_pixels() -> void:
	if DisplayServer.get_name() == "headless":
		_note("3D 舞台像素检查：headless 没有渲染帧，跳过")
		return
	Setting.reset_layout()
	Setting.set_layout("track_angle", 30.0)
	var probe := StageProbe.new()
	add_child(probe)
	probe.configure(get_viewport().get_visible_rect().size)
	await get_tree().process_frame
	await get_tree().process_frame
	if not probe.executed:
		_note("3D 舞台像素检查：这一帧没有绘制内容，跳过")
		probe.queue_free()
		Setting.reset_layout()
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var transform := get_viewport().get_final_transform()
	var tolerance := 2.5 * maxf(maxf(transform.get_scale().x, transform.get_scale().y), 1.0)
	var geometry := probe.geometry
	var line := probe.judge_line_rect()
	# 游玩区域两侧各一条侧线：宽度是轨道线的四倍，贴在区域外侧。
	# 先在判定线上方量它们（判定线所在行会跟判定线连成一条白线，量不准宽度）。
	var side_stroke := geometry.side_line_stroke()
	var side_u := 100.0
	var side_k := geometry.row_scale(side_u)
	var side_row := int(roundf((transform * Vector2(0.0, geometry.project_row(side_u))).y))
	for edge in [[0.0, "左"], [1.0, "右"]]:
		var normalized := float(edge[0])
		var side := geometry.side_line_rect(normalized)
		var middle := side.get_center().x
		var center := int(roundf((transform * Vector2(probe.screen_x(middle, side_u), 0.0)).x))
		var run := _row_run(image, side_row, center - 24, center + 24)
		_expect(run.x >= 0.0, "舞台：游玩区域%s侧画出了侧线" % edge[1])
		_expect_near(run.y - run.x + 1.0, side_stroke * side_k * maxf(transform.get_scale().x, 1.0),
			tolerance + 2.0, "舞台：%s侧线宽度是轨道线的四倍" % edge[1])
		# 侧线贴在区域外侧：区域里紧挨边界的地方不该有白线。
		var inside := int(roundf((transform * Vector2(probe.screen_x(geometry.x(normalized) + (3.0 if normalized < 0.5 else -3.0), side_u), 0.0)).x))
		_expect(image.get_pixel(inside, side_row).r < 0.5, "舞台：%s侧线没有压到游玩区域里" % edge[1])
	# 判定线：只横跨游玩区域，两端落在侧线上；上下边缘正好落在 judge_y ± 高度 / 2。
	# 只扫判定线自己那一段：侧线贴在它的两端，扫出去就会连成一条。
	var line_row := int(roundf((transform * Vector2(0.0, line.get_center().y)).y))
	var full := _row_run(image, line_row,
		int(roundf((transform * Vector2(line.position.x, 0.0)).x)),
		int(roundf((transform * Vector2(line.end.x, 0.0)).x)))
	_expect(full.x >= 0.0, "舞台：judge_y 那一行画到了内容")
	_expect_near(full.x - 0.5, (transform * Vector2(line.position.x, 0.0)).x, tolerance, "舞台：判定线左端落在游玩区域左侧线上")
	_expect_near(full.y + 0.5, (transform * Vector2(line.end.x, 0.0)).x, tolerance, "舞台：判定线右端落在游玩区域右侧线上")
	# 侧线与判定线之外必须是底色，否则说明判定线又铺到画面边缘去了。
	var outside := int(roundf((transform * Vector2(line.position.x - side_stroke - 4.0, 0.0)).x))
	if outside >= 0:
		_expect(image.get_pixel(outside, line_row).r < 0.5, "舞台：判定线没有越过游玩区域左侧线")
	# 取游玩区域左侧的一条竖线（在轨道块之外）：判定线的高度不被透视改写。
	var column := int(roundf((transform * Vector2(geometry.x(0.25), 0.0)).x))
	var band := _column_run(image, column,
		int(roundf((transform * Vector2(0.0, line.position.y - 40.0)).y)),
		int(roundf((transform * Vector2(0.0, line.end.y + 40.0)).y)))
	_expect_near(band.x - 0.5, (transform * Vector2(0.0, line.position.y)).y, tolerance, "舞台：判定线顶边在模型预测的行上")
	_expect_near(band.y + 0.5, (transform * Vector2(0.0, line.end.y)).y, tolerance, "舞台：判定线底边在模型预测的行上")
	# 横向收敛：在亮分带的中线上量轨道块的左右边缘。
	var center_column := int(roundf((transform * Vector2(geometry.size.x * 0.5, 0.0)).x))
	var half_window := int(roundf(120.0 * maxf(transform.get_scale().x, 1.0)))
	for index in [0, 2, 4, 6]:
		var u := probe.band_center_u(index)
		var row := int(roundf((transform * Vector2(0.0, geometry.project_row(u))).y))
		var measured := _row_run(image, row, center_column - half_window, center_column + half_window)
		_expect(measured.x >= 0.0, "舞台：u=%.0f 处量到轨道块" % u)
		var k := geometry.row_scale(u)
		_expect_near(measured.x - 0.5, (transform * Vector2(probe.screen_x(probe.BLOCK_LEFT, u), 0.0)).x, tolerance,
			"舞台：u=%.0f 处左边缘按 k=%.3f 收敛" % [u, k])
		_expect_near(measured.y + 0.5, (transform * Vector2(probe.screen_x(probe.BLOCK_LEFT + probe.BLOCK_WIDTH, u), 0.0)).x, tolerance,
			"舞台：u=%.0f 处右边缘按 k=%.3f 收敛" % [u, k])
	# 纵向压缩 + 贴图采样：分带边界必须落在 project_row 预测的行上，
	# 均匀分布（旧的仿射拉伸）会差出十几个像素。
	var top_row := int(roundf((transform * Vector2(0.0, geometry.project_row(probe.BLOCK_U_TOP))).y))
	var bottom_row := int(roundf((transform * Vector2(0.0, geometry.project_row(probe.BLOCK_U_BOTTOM))).y))
	var transitions := _column_transitions(image, center_column, top_row + 1, bottom_row - 1)
	_expect(transitions.size() == probe.BANDS - 1,
		"舞台：中心竖线上量到 %d 条分带边界（期望 %d）" % [transitions.size(), probe.BANDS - 1])
	if transitions.size() == probe.BANDS - 1:
		var worst := 0.0
		for index in transitions.size():
			var u := probe.BLOCK_U_TOP - probe.band_span() * float(index + 1)
			var expected := (transform * Vector2(0.0, geometry.project_row(u))).y
			worst = maxf(worst, absf(transitions[index] - expected))
		_expect(worst <= tolerance, "舞台：全部分带边界都与透视模型一致（最大偏差 %.1f px）" % worst)
	# 背景是普通 2D、铺满整个屏幕：平面盖不到的角落、画布没画到的地方露出的都是背景色。
	_expect_color(image.get_pixel(2, 2), probe.BACK_COLOR, "舞台：画面左上角是 2D 背景（背景铺满整个屏幕）")
	_expect_color(image.get_pixel(image.get_width() - 3, image.get_height() - 3), probe.BACK_COLOR, "舞台：画面右下角也是 2D 背景")
	# 游玩区域必须一直延伸到画面顶端（玩家要求：不能在中途消失 / 溶解）。
	# 角度覆盖 0°（恒等投影）、30°（默认）与 70°（最大，旧的固定画布到 70° 就缩进画面里了）。
	var left_side := geometry.side_line_rect(0.0)
	for angle in [0.0, 30.0, 70.0]:
		Setting.set_layout("track_angle", angle)
		probe.configure(get_viewport().get_visible_rect().size)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		image = get_viewport().get_texture().get_image()
		_expect_color(_sample_row(image, transform, geometry, probe, probe.top_block_center(), 1.0), Color.WHITE,
			"舞台：%.0f° 时游玩区域铺满到画面顶端（内容的第 1 行）" % angle)
		# 侧线是四条边的第一条：顶端那几行里也要量到它（顶端的行按同一层的 u 折算横坐标）。
		var top_u := geometry.row_offset_for_screen(2.0)
		var top_x := int(roundf((transform * Vector2(probe.screen_x(left_side.get_center().x, top_u), 0.0)).x))
		_expect(_row_run(image, int(roundf((transform * Vector2(0.0, 2.0)).y)), top_x - 16, top_x + 16).x >= 0.0,
			"舞台：%.0f° 时左侧线一直画到画面顶端" % angle)
	Setting.set_layout("track_angle", 30.0)
	probe.configure(get_viewport().get_visible_rect().size)
	# 宽度不为 0 的轨道必须照画：谱面把宽度当动画量，阈值化会让“出现 / 消失”变成跳变。
	probe.lane_mode = true
	probe.configure(get_viewport().get_visible_rect().size)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	image = get_viewport().get_texture().get_image()
	# 行的取法与 x 的取法要配套：都按判定线上方 300 像素那一层算。
	var lane_u := 300.0
	var lane_row := int(roundf((transform * Vector2(0.0, geometry.project_row(lane_u))).y))
	# 0.4% 宽的轨道在屏幕上只有几个像素，但两条白描边必须画出来。
	var thin_x := int(roundf((transform * Vector2(probe.screen_x(geometry.x(0.2), lane_u), 0.0)).x))
	var thin := _row_run(image, lane_row, thin_x - 8, thin_x + 8)
	_expect(thin.x >= 0.0, "舞台：宽度 0.4%% 的窄轨道照样绘制（白色跨 %d 像素）" % (int(thin.y - thin.x) + 1 if thin.x >= 0.0 else 0))
	# 宽度为 0 的轨道：两侧描边重合，最多剩下一两条描边线，连填充都不该有（半透明黑会比背景暗）。
	var zero_x := int(roundf((transform * Vector2(probe.screen_x(geometry.x(0.5), lane_u), 0.0)).x))
	var zero := _row_run(image, lane_row, zero_x - 8, zero_x + 8)
	_expect(zero.x < 0.0 or zero.y - zero.x <= 4.0, "舞台：宽度为 0 的轨道只剩描边（白色跨 %d 像素）" % (int(zero.y - zero.x) + 1 if zero.x >= 0.0 else 0))
	_expect(image.get_pixel(zero_x, lane_row).r >= probe.BACK_COLOR.r - 0.02,
		"舞台：宽度为 0 的轨道没有填充（实际红通道 %.2f）" % image.get_pixel(zero_x, lane_row).r)
	var wide_middle := int(roundf((transform * Vector2(probe.screen_x(geometry.x(0.8), lane_u), 0.0)).x))
	var wide_edge := int(roundf((transform * Vector2(probe.screen_x(geometry.x(0.8) - geometry.width * 0.125, lane_u), 0.0)).x))
	_expect(_row_run(image, lane_row, wide_edge - 6, wide_edge + 6).x >= 0.0, "舞台：普通轨道的侧线照常绘制")
	var wide_fill := image.get_pixel(wide_middle, lane_row)
	_expect(wide_fill.r < 0.5, "舞台：普通轨道中间是半透明黑填充（实际红通道 %.2f）" % wide_fill.r)
	probe.queue_free()
	Setting.reset_layout()


## 击打延迟显示真的画在设置的位置上：预览里 FAST 在上、LATE 在下，各用各的颜色。
## 预览与游玩共用 draw_hud → _draw_numbers 这条绘制路径（设置界面的预览就是同一个开关）。
func _check_offset_display_pixels() -> void:
	if DisplayServer.get_name() == "headless":
		_note("延迟显示像素检查：headless 没有渲染帧，跳过")
		return
	Setting.reset_layout()
	Setting.set_layout("judge_offset_x", 0.5)
	Setting.set_layout("judge_offset_y", 0.30)
	Setting.set_layout("judge_offset_size", 60.0)
	var field := Playfield.new()
	add_child(field)
	field.configure(get_viewport().get_visible_rect().size)
	field.preview = true
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var transform := get_viewport().get_final_transform()
	var height := float(field._offset_height())
	var step := height + 6.0 * field.geometry.pixel_scale
	for index in Skins.OFFSET_WORDS.size():
		var word: String = Skins.OFFSET_WORDS[index]
		var other: String = Skins.OFFSET_WORDS[1 - index]
		var top := field._offset_position(index * step)
		var area := Rect2(top.x - height * 2.0, top.y - 2.0, height * 4.0, height + 6.0)
		var hits := _region_count(image, transform, area, Skins.offset_color(word), 0.06)
		_expect(hits >= 15, "延迟显示：预览把 %s 画在设置的位置上（%d 像素匹配）" % [str(Skins.OFFSET_TEXTS[word]), hits])
		_expect(_region_count(image, transform, area, Skins.offset_color(other), 0.06) < hits,
			"延迟显示：%s 那一行不会串成另一个方向的颜色" % str(Skins.OFFSET_TEXTS[word]))
	field.queue_free()
	await get_tree().process_frame
	Setting.reset_layout()


## 取“轨道层里某个画布 x、某条设计行”在画面上的实际颜色：先按透视把 x 折到屏幕上。
func _sample_row(image: Image, transform: Transform2D, geometry: PlayfieldGeometry, probe: Playfield, field_x: float, design_row: float) -> Color:
	var u := geometry.row_offset_for_screen(design_row)
	var position := transform * Vector2(probe.screen_x(field_x, u), design_row)
	return image.get_pixel(
		clampi(roundi(position.x), 0, image.get_width() - 1),
		clampi(roundi(position.y), 0, image.get_height() - 1))


class StageProbe:
	extends Playfield
	## 轨道层里画出的“已知内容”：一块横向分带的贴图，覆盖判定线上方 u ∈ [20, 660]。
	const BANDS := 8
	const BLOCK_LEFT := 700.0
	const BLOCK_WIDTH := 200.0
	const BLOCK_U_TOP := 660.0
	const BLOCK_U_BOTTOM := 20.0
	## 背景色：一个不会被误认成内容或底色的颜色，用来验证背景层铺满整个画面。
	## 红通道保持在 0.5 以下，侧线之外的“不是判定线”断言才能继续用 r < 0.5。
	const BACK_COLOR := Color(0.06, 0.55, 0.25)
	## 顶端内容块：从分带块上方一直铺到画布顶，用来验证游玩区域铺满到屏幕顶端。
	## x 取在左侧线与分带块之间，纵向与分带块留出空隙，避免干扰分带边界断言。
	const TOP_BLOCK_LEFT := 420.0
	const TOP_BLOCK_RIGHT := 690.0
	const TOP_BLOCK_GAP := 20.0

	var executed: bool = false
	## 第二阶段：不画分带块，改画三条合成轨道，检查“宽度不为 0 就照画”。
	var lane_mode: bool = false
	var _bands: ImageTexture

	func _ready() -> void:
		super()
		_bands = ImageTexture.create_from_image(_make_bands())

	## 背景铺满整个画面：角落、平面够不到的地方露出的都该是它。
	func draw_background(canvas: CanvasItem) -> void:
		canvas.draw_rect(Rect2(Vector2.ZERO, _view_size), BACK_COLOR)

	## 每条分带在轨道层里占多少行。
	func band_span() -> float:
		return (BLOCK_U_TOP - BLOCK_U_BOTTOM) / float(BANDS)

	func band_center_u(index: int) -> float:
		return BLOCK_U_TOP - (float(index) + 0.5) * band_span()

	## 顶端内容块的中心列（轨道层坐标），断言“铺到画面顶端”时采样它。
	func top_block_center() -> float:
		return (TOP_BLOCK_LEFT + TOP_BLOCK_RIGHT) * 0.5

	## 轨道层里已知内容的某一列，经过横向收敛后落在画面的哪一列。
	func screen_x(field_x: float, u: float) -> float:
		return geometry.size.x * 0.5 + (field_x - geometry.size.x * 0.5) * geometry.row_scale(u)

	func draw_field(canvas: CanvasItem) -> void:
		executed = true
		super(canvas)
		if lane_mode:
			# 三条合成轨道走的是正式绘制路径：0.4% 宽的窄轨道、0 宽的线状轨道、25% 宽的普通轨道。
			_draw_lane(canvas, {"x": 0.2, "w": 0.004, "visible": true})
			_draw_lane(canvas, {"x": 0.5, "w": 0.0, "visible": true})
			_draw_lane(canvas, {"x": 0.8, "w": 0.25, "visible": true})
			return
		var top := geometry.judge_y - BLOCK_U_TOP
		canvas.draw_texture_rect(_bands, Rect2(BLOCK_LEFT, top, BLOCK_WIDTH, BLOCK_U_TOP - BLOCK_U_BOTTOM), false)
		# 顶端内容块：从分带块上方一直铺到画布顶（画布顶在画面顶端之上，所以内容一直铺出屏幕）。
		var top_block_bottom := top - TOP_BLOCK_GAP
		canvas.draw_rect(Rect2(TOP_BLOCK_LEFT, geometry.canvas_top,
			TOP_BLOCK_RIGHT - TOP_BLOCK_LEFT, top_block_bottom - geometry.canvas_top), Color.WHITE)

	# 判定线图片用同一个矩形、纯白填充：素材本身的颜色不参与像素断言。
	# 图片层现在与实际判定线完全重合（原先的「图片 Y 偏移」设置项已删除）。
	func _draw_judge_line(canvas: CanvasItem) -> void:
		canvas.draw_rect(judge_line_rect(), Color.WHITE)

	## 分带贴图：黑白交替，边界正好落在 1 / BANDS 的整数倍处。
	func _make_bands() -> Image:
		var image := Image.create(4, 256, false, Image.FORMAT_RGBA8)
		for y in 256:
			image.fill_rect(Rect2i(0, y, 4, 1), Color.WHITE if (y * BANDS / 256) % 2 == 0 else Color.BLACK)
		return image


# ---------------------------------------------------------------- 场景冒烟测试

func _check_scenes() -> void:
	# 设置界面：构建整屏 UI，并让预览 Playfield 用真实绘制跑一帧。
	var settings_scene: PackedScene = load("res://gd/room/settings.tscn")
	if settings_scene == null:
		_expect(false, "场景：设置界面可以加载")
		return
	var settings := settings_scene.instantiate()
	add_child(settings)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(is_instance_valid(settings.get("_preview")), "场景：设置界面的实时预览已创建")
	_expect(bool(settings.get("_preview").get("preview")), "场景：设置界面的预览走的就是游玩那套绘制")
	var mode_button: Node
	var mode_buttons: Array[Node] = []
	_collect_mode_buttons(settings, mode_buttons)
	_expect(mode_buttons.size() == 1, "设置：提供空间判定模式切换按钮")
	if mode_buttons.size() == 1:
		var old_mode: String = Setting.judge_position_mode
		mode_button = mode_buttons[0]
		mode_button.emit_signal("pressed")
		_expect(Setting.judge_position_mode != old_mode, "设置：点击按钮切换判定模式")
		mode_button.emit_signal("pressed")
		_expect(Setting.judge_position_mode == old_mode, "设置：再次点击恢复另一种判定模式")
	# 控件用 meta 标签定位，不依赖显示文案：改文案不会让测试失效。
	var tags := {}
	_collect_tags(settings, tags)
	for key in ["track_angle", "combo_size", "score_size", "judge_size", "hit_size"]:
		_expect(tags.has("layout:" + key), "场景：设置界面提供 %s 选项" % key)
	# 判定线图片的纵向偏移与三种音符各自的横向间隔都在界面上（各类型互不影响）。
	_expect(tags.has("layout:judge_image_offset"), "场景：设置界面提供判定线图片 Y 偏移")
	for kind in ["tap", "hold", "slide"]:
		_expect(tags.has("layout:note_gap_" + kind), "场景：设置界面提供 %s 与轨道的横向间隔" % kind)
	_expect(tags.has("game:score_mode"), "场景：设置界面提供分数算法切换")
	_expect(tags.has("game:hold_tail_sound"), "场景：设置界面提供 Hold 尾部打击音开关")
	# Hold 尾部打击音：勾选框直接写设置，实时生效（游玩时读的是同一个字段）。
	var tail_box := _find_tag(settings, "game:hold_tail_sound", "CheckBox") as CheckBox
	if tail_box == null:
		_expect(false, "场景：Hold 尾部打击音勾选框可以定位")
	else:
		var old_tail: bool = Setting.hold_tail_sound
		tail_box.button_pressed = not old_tail
		await get_tree().process_frame
		_expect(Setting.hold_tail_sound == (not old_tail), "场景：点击勾选框切换 Hold 尾部打击音")
		tail_box.button_pressed = old_tail
		await get_tree().process_frame
		_expect(Setting.hold_tail_sound == old_tail, "场景：再点一次勾回原来的状态")
	# 分数算法按钮：点一下换算法，再点一下换回来（预览里的起始分数跟着变）。
	var score_button := _find_tag(settings, "game:score_mode", "Button") as Button
	if score_button == null:
		_expect(false, "场景：分数算法切换按钮可以定位")
	else:
		var old_score_mode: String = Setting.score_mode
		score_button.emit_signal("pressed")
		_expect(Setting.score_mode != old_score_mode, "场景：点击按钮切换分数算法")
		score_button.emit_signal("pressed")
		_expect(Setting.score_mode == old_score_mode, "场景：再次点击切回原来的算法")
	# 音符与轨道的横向间隔滑条必须真的写进布局（实时预览靠 Setting.changed 重画）。
	var gap_slider := _find_tagged(settings, "layout:note_gap_tap")
	if gap_slider is HSlider:
		(gap_slider as HSlider).value = 55.0
		await get_tree().process_frame
		_expect_close(float(Setting.layout.note_gap_tap), 55.0, "场景：拖动音符间隔滑条写入布局")
		Setting.set_layout("note_gap_tap", float(Setting.DEFAULT_LAYOUT.note_gap_tap))
	else:
		_expect(false, "场景：音符间隔滑条可以定位")
	for kind in ["tap", "hold", "slide"]:
		var missing: Array[String] = []
		for index in 4:
			if not tags.has("curve:hit_%s:%d" % [kind, index]):
				missing.append(str(index))
		_expect(missing.is_empty(), "场景：%s 提供贝塞尔缩放曲线的 4 个控制值（缺少 %s）" % [kind, str(missing)])
	# 拖滑条必须真的写进设置，否则「实时预览」只是摆设。
	var curve_slider := _find_tagged(settings, "curve:hit_tap:1")
	if curve_slider is HSlider:
		(curve_slider as HSlider).value = 1.75
		await get_tree().process_frame
		_expect_close(float(Setting.get_skin("hit_tap").scale_curve[1]), 1.75, "场景：拖动缩放曲线滑条写入设置")
		Setting.reset_skin("hit_tap")
	else:
		_expect(false, "场景：缩放曲线滑条可以定位")
	# 击打延迟显示：五个判定文字选项 + 位置 / 大小 / 时长 + 两个方向的素材槽位。
	for key in ["judge_offset_x", "judge_offset_y", "judge_offset_size", "judge_offset_duration"]:
		_expect(tags.has("layout:" + key), "场景：设置界面提供 %s 选项" % key)
	for grade in Setting.JUDGE_OFFSET_GRADES:
		_expect(tags.has("offset_grade:" + grade), "场景：击打延迟显示提供「%s」选项" % grade)
	var offset_check := _find_tag(settings, "offset_grade:just+", "CheckBox") as CheckBox
	if offset_check == null:
		_expect(false, "场景：击打延迟显示的判定勾选框可以定位")
	else:
		Setting.judge_offset_grades = Setting.DEFAULT_JUDGE_OFFSET_GRADES.duplicate()
		settings.call("_refresh_values")
		_expect(not offset_check.button_pressed, "场景：默认不勾 just+（面板显示了默认名单）")
		offset_check.set_pressed(true)
		await get_tree().process_frame
		_expect(Setting.judge_offset_enabled("just+"), "场景：勾上判定勾选框立刻写进设置")
		Setting.set_judge_offset_grade("just+", false)
		settings.call("_refresh_values")
		await get_tree().process_frame
		_expect(not offset_check.button_pressed, "场景：取消后勾选框跟着刷新（不靠重建界面）")
	var offset_slider := _find_tagged(settings, "layout:judge_offset_x")
	if offset_slider is HSlider:
		(offset_slider as HSlider).value = 0.8
		await get_tree().process_frame
		_expect_close(float(Setting.layout.judge_offset_x), 0.8, "场景：拖动延迟显示位置滑条写入设置")
		Setting.reset_layout()
		settings.call("_refresh_values")
	else:
		_expect(false, "场景：延迟显示位置滑条可以定位")
	# 音频延迟 / 谱面偏移：前者的数值框与滑条同量程（±Setting.OFFSET_LIMIT，键入越界值夹到端点），
	# 后者仍不设上限；两者共用一行实时读数。
	_expect(tags.has("game:offset") and tags.has("game:offset_readout"), "场景：设置界面提供音频延迟选项与实时读数")
	_expect(tags.has("game:chart_offset"), "场景：设置界面提供谱面偏移选项")
	var offset_box := _find_tag(settings, "game:offset", "SpinBox") as SpinBox
	var chart_offset_box := _find_tag(settings, "game:chart_offset", "SpinBox") as SpinBox
	var audio_slider := _find_tagged(settings, "game:offset")
	var readout := _find_tag(settings, "game:offset_readout", "Label") as Label
	if offset_box == null or chart_offset_box == null or readout == null:
		_expect(false, "场景：音频延迟 / 谱面偏移数值框与读数可以定位")
	else:
		_expect_close(offset_box.min_value, -Setting.OFFSET_LIMIT, "场景：音频延迟数值框下限是 -3000 ms")
		_expect_close(offset_box.max_value, Setting.OFFSET_LIMIT, "场景：音频延迟数值框上限是 3000 ms")
		_expect(not offset_box.allow_greater and not offset_box.allow_lesser, "场景：音频延迟数值框不许超出范围")
		_expect(audio_slider != null and is_equal_approx(audio_slider.min_value, -Setting.OFFSET_LIMIT) and is_equal_approx(audio_slider.max_value, Setting.OFFSET_LIMIT),
			"场景：音频延迟滑条与数值框同量程（±3000 ms）")
		_expect(chart_offset_box.allow_greater and chart_offset_box.allow_lesser, "场景：谱面偏移数值框允许超出量程（无上限）")
		var before_offset: float = Setting.offset
		var before_shift: float = Setting.chart_offset
		offset_box.value = 123456.0
		await get_tree().process_frame
		_expect_close(Setting.offset, Setting.OFFSET_LIMIT, "场景：音频延迟键入越界值夹到上限")
		chart_offset_box.value = -250.0
		await get_tree().process_frame
		_expect_close(Setting.chart_offset, -250.0, "场景：键入谱面偏移直接写入设置而不被夹住")
		var chart_offset := ChartLoader.chart_data.offset if ChartLoader.chart_data != null else 0.0
		var song := Setting.song_offset_of(ChartLoader.selected_folder)
		# 期望值直接用界面自己的毫秒格式与四项和格式，避免测试重复一份格式化逻辑。
		var expected := UI.offset_breakdown(song, Setting.offset, Setting.chart_offset, chart_offset)
		_expect(readout.text.begins_with(expected), "场景：偏移读数显示最终延迟（%s）" % readout.text)
		offset_box.value = before_offset
		chart_offset_box.value = before_shift
		await get_tree().process_frame
		_expect_close(Setting.offset, before_offset, "场景：音频延迟可以恢复原值")
		_expect_close(Setting.chart_offset, before_shift, "场景：谱面偏移可以恢复原值")
	# 最高帧率：五个档位各一个按钮，点一下写进设置并立刻交给引擎。
	var fps_buttons: Array[Node] = []
	for fps in Setting.FPS_CHOICES:
		var button := _find_tag(settings, "game:max_fps:" + str(fps), "Button")
		if button is Button:
			fps_buttons.append(button)
		else:
			_expect(false, "场景：最高帧率 %s 档按钮可以定位" % str(fps))
	_expect(fps_buttons.size() == Setting.FPS_CHOICES.size(), "场景：最高帧率提供全部 %d 个档位" % Setting.FPS_CHOICES.size())
	if fps_buttons.size() == Setting.FPS_CHOICES.size():
		var before_fps: int = Setting.max_fps
		for index in fps_buttons.size():
			(fps_buttons[index] as Button).pressed.emit()
			await get_tree().process_frame
			var choice: int = Setting.FPS_CHOICES[index]
			_expect(Setting.max_fps == choice and Engine.max_fps == choice,
				"场景：点击 %s 档按钮写进设置并交给引擎" % ("无上限" if choice <= 0 else str(choice)))
		# 按钮状态跟着设置走：同一时刻只有一个档位是按下态。
		var pressed := 0
		for button in fps_buttons:
			if (button as Button).button_pressed:
				pressed += 1
		_expect(pressed == 1, "场景：最高帧率同一时刻只有一个档位处于选中态（实际 %d 个）" % pressed)
		Setting.set_max_fps(before_fps)
		await get_tree().process_frame
		_expect(Setting.max_fps == before_fps, "场景：最高帧率可以恢复原值")
	# 安卓端没有滚轮，要靠拖拽滚动设置页：在卡片等非交互区域上下拖动必须让当前页滚动。
	var pages: Array = settings.get("_pages")
	var page: ScrollContainer = pages[0] if not pages.is_empty() else null
	if page == null:
		_expect(false, "场景：设置页存在")
	else:
		var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		var visible_rect := page.get_global_rect().intersection(viewport_rect)
		if visible_rect.size.y < 40.0:
			visible_rect = Rect2(page.get_global_rect().position + Vector2(40, 20), Vector2(160, 60))
		# 起点必须落在卡片这类「被动」区域：滑条、按钮、输入框是 STOP，会吃掉按下事件，
		# 从那里开始的手势本来就不该被根节点当成滚动（那是控件自己的拖动）。
		var origin := _passive_point(settings, visible_rect)
		# 一次连续手势：往上拖 → 页面下移，再往下拖 → 回到顶部（并且不越界）。
		_push_touch(origin, true)
		for step in 6:
			_push_drag(origin + Vector2(0, -20.0 * (step + 1)), Vector2(0, -20.0))
		var scrolled: int = page.scroll_vertical
		_expect(scrolled > 0, "场景：在设置页上拖动可以滚动（scroll_vertical = %d）" % scrolled)
		for step in 12:
			_push_drag(origin + Vector2(0, -120.0 + 20.0 * (step + 1)), Vector2(0, 20.0))
		_push_touch(origin + Vector2(0, 120.0), false)
		await get_tree().process_frame
		_expect(page.scroll_vertical == 0, "场景：反向拖动回到顶部且不越界（scroll_vertical = %d）" % page.scroll_vertical)
		# 桌面滚轮同样可用（页里的 ScrollContainer 是 IGNORE，滚轮由根节点接住）。
		_push_wheel(origin, MOUSE_BUTTON_WHEEL_DOWN)
		await get_tree().process_frame
		_expect(page.scroll_vertical > 0, "场景：滚轮可以滚动设置页（scroll_vertical = %d）" % page.scroll_vertical)
		for step in 2:
			_push_wheel(origin, MOUSE_BUTTON_WHEEL_UP)
		await get_tree().process_frame
		_expect(page.scroll_vertical == 0, "场景：滚轮向上回到顶部且不越界（scroll_vertical = %d）" % page.scroll_vertical)
	settings.queue_free()
	await get_tree().process_frame
	# 游玩界面：使用内置示例谱面，确认会话、音频时钟与绘制器协作正常。
	var demo_scene: PackedScene = load("res://gd/room/demo.tscn")
	if demo_scene == null:
		_expect(false, "场景：游玩界面可以加载")
		return
	var demo := demo_scene.instantiate()
	add_child(demo)
	await get_tree().process_frame
	await get_tree().process_frame
	var session: PlaySession = demo.get("session")
	_expect(session != null, "场景：游玩界面建立判定会话")
	if session != null:
		var before: float = session.time
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(session.time >= before, "场景：游玩时间单调推进")
		_check_chart_clock(demo)
		_expect(is_instance_valid(demo.get("_exit_button")) and is_instance_valid(demo.get("_restart_button")), "场景：退出与重开按钮已创建")
		# 一局结束（finish_run）要写快照并记成绩；直接调用免得切场景。
		# 成绩键从 ChartLoader 的选中项算出来，所以这里连谱面列表一起摆成“这一首只有一张谱面”。
		var run_folder := "user://chart/自检游玩记录"
		var original_folder := ChartLoader.selected_folder
		var original_chart := ChartLoader.selected_chart
		var original_charts := ChartLoader.charts
		var original_result: Dictionary = ChartLoader.last_result
		ChartLoader.selected_folder = run_folder
		ChartLoader.selected_chart = ""
		ChartLoader.charts = [] as Array[Dictionary]
		session.score = 968420.0
		session.max_combo = 328
		session.judgement_counts = {"just+": 300, "just": 10, "good": 3, "ok": 1, "miss": 2}
		demo.call("finish_run")
		_expect(int(Scores.best(run_folder).get("score", 0)) == 968420 and Scores.plays(run_folder) == 1,
			"场景：一局结束把成绩写进成绩册")
		_expect(bool(ChartLoader.last_result.get("is_best", false)), "场景：第一次成绩算新纪录")
		_expect(ChartLoader.last_result.background == ChartLoader.bg and not ChartLoader.last_result.info.is_empty(),
			"场景：结算快照仍然带着背景与歌曲信息")
		demo.call("finish_run")
		_expect(not bool(ChartLoader.last_result.get("is_best", false)) and Scores.plays(run_folder) == 2,
			"场景：同样分数再来一局不算新纪录，但计一次游玩")
		ChartLoader.selected_folder = original_folder
		ChartLoader.selected_chart = original_chart
		ChartLoader.charts = original_charts
		ChartLoader.last_result = original_result
	demo.queue_free()
	await get_tree().process_frame
	# 开始界面：谱面库为空时列表也必须留一行不可点的提示，否则玩家会看到彻底空白的界面。
	var start_scene: PackedScene = load("res://gd/room/startroom.tscn")
	if start_scene == null:
		_expect(false, "场景：开始界面可以加载")
		return
	var startroom := start_scene.instantiate()
	add_child(startroom)
	await get_tree().process_frame
	await get_tree().process_frame
	var chart_list: ItemList = startroom.find_child("ChartList", true, false)
	_expect(chart_list != null, "场景：开始界面存在谱面列表")
	if chart_list != null:
		_expect(chart_list.get_item_count() >= 1, "场景：空谱面库时列表给出提示行")
		var empty_library: bool = Storage.library_directories().is_empty()
		_expect(not empty_library or chart_list.is_item_disabled(0), "场景：空谱面库时提示行不可开始游玩")
	_expect(startroom.find_child("PlayChart", true, false) != null, "场景：开始界面存在开始游玩按钮")
	startroom.queue_free()
	await get_tree().process_frame
	# 选曲界面：谱面库是 ItemList，它自己不响应手指拖动，靠 mouse_filter = PASS 把手势
	# 上抛给根节点；轻点选中走的仍是引擎生成的模拟鼠标事件。
	# 用一批夹具文件夹把列表撑高，再放进固定尺寸的宿主里，量“拖动滚动 + 轻点读取”。
	_write_song_fixture(FIXTURE_SONG, SONG_CHART, FIXTURE_ART)
	for index in 13:
		DirAccess.make_dir_recursive_absolute(FIXTURE_FILLER % index)
	var host := Control.new()
	# 矮一点的宿主：谱面库一定装不下 14 行，"拖动滚动"才有意义（真机横屏也就这么高）。
	host.size = Vector2(900, 520)
	add_child(host)
	var select := start_scene.instantiate()
	host.add_child(select)
	await get_tree().process_frame
	await get_tree().process_frame
	var picker: ItemList = select.find_child("ChartList", true, false)
	if picker == null:
		_expect(false, "选曲：谱面库列表存在")
	else:
		_expect(picker.mouse_filter == Control.MOUSE_FILTER_PASS, "选曲：谱面库把手势让给根节点（PASS 才能拖动滚动）")
		# 先用搜索框把列表过滤成夹具那 14 个文件夹：数量和行序都确定，不受玩家已有谱面影响。
		(select.get("_search") as LineEdit).text = "__self_check"
		select.call("_filter")
		await get_tree().process_frame
		_expect(picker.get_item_count() == 14, "选曲：搜索框按文件夹名过滤谱面库（实际 %d 项）" % picker.get_item_count())
		var paths: Array = select.get("_paths")
		var row: int = paths.find(FIXTURE_SONG)
		_expect(row == 0, "选曲：夹具谱面排在过滤结果第一行（实际第 %d 行）" % row)
		# 一次连续手势：手指按在列表上往上拖 → 列表滚动，再往下拖 → 回到顶部（并且不越界）。
		var bar := picker.get_v_scroll_bar() as ScrollBar
		_expect(bar.max_value > picker.size.y, "选曲：谱面库内容比可视区域高（可滚动）")
		var area := picker.get_global_rect()
		area.size.x = maxf(80.0, area.size.x - 30.0)   # 避开右侧滚动条
		var origin := _passive_point(select, area)
		_push_touch(origin, true)
		for step in 6:
			_push_drag(origin + Vector2(0, -20.0 * (step + 1)), Vector2(0, -20.0))
		await get_tree().process_frame
		_expect(bar.value > 0.0, "选曲：在谱面库上拖动可以滚动列表（value = %.0f）" % bar.value)
		for step in 12:
			_push_drag(origin + Vector2(0, -120.0 + 20.0 * (step + 1)), Vector2(0, 20.0))
		_push_touch(origin + Vector2(0, 120.0), false)
		await get_tree().process_frame
		_expect(bar.value == 0.0, "选曲：反向拖动回到顶部且不越界（value = %.0f）" % bar.value)
		# 先点一个空文件夹（读取必然失败），再点回夹具：这样“轻点”才是唯一让状态变化的原因。
		# 展开会把谱面行插进列表，ItemList 的行号不再等于 _paths 的下标，所以每次现查行号。
		var play: Button = select.get("_play")
		var empty_row := _song_row(select, FIXTURE_FILLER % 1)
		_tap_item(picker, empty_row)
		await get_tree().create_timer(0.25).timeout
		_expect(picker.get_selected_items() == PackedInt32Array([_song_row(select, FIXTURE_FILLER % 1)]),
			"选曲：轻点可以选中条目（选中 %s）" % str(picker.get_selected_items()))
		_expect(play.disabled, "选曲：读取失败的谱面不能开始游玩")
		# 轻点夹具那一首：这一首展开出它的谱面行，选中的是展开出来的第一张谱面。
		row = _song_row(select, FIXTURE_SONG)
		_tap_item(picker, row)
		await get_tree().create_timer(0.25).timeout
		row = _song_row(select, FIXTURE_SONG)
		_expect(picker.get_item_count() == 15, "选曲：轻点歌曲行展开出全部谱面（实际 %d 项）" % picker.get_item_count())
		_expect(picker.get_selected_items() == PackedInt32Array([row + 1]),
			"选曲：展开后选中它的第一张谱面（选中 %s）" % str(picker.get_selected_items()))
		_expect(picker.get_item_text(row + 1).contains("●"),
			"选曲：展开的谱面行标出当前选中的那张（%s）" % picker.get_item_text(row + 1))
		_expect((select.get("_title") as Label).text == "自检曲目", "选曲：读取谱面后显示曲名（实际 %s）" % (select.get("_title") as Label).text)
		_expect((select.get("_difficulty") as Label).text == "Master · 12", "选曲：显示难度与等级（实际 %s）" % (select.get("_difficulty") as Label).text)
		_expect((select.get("_credits") as Label).text.contains("自检曲师"), "选曲：显示曲师（实际 %s）" % (select.get("_credits") as Label).text)
		_expect(not play.disabled, "选曲：读取完成后可以开始游玩")
		# 单曲延迟：控件按选中的这首歌读写，换歌各自独立，读数给出三项之和。
		var song_tags := {}
		_collect_tags(select, song_tags)
		_expect(song_tags.has("song:offset") and song_tags.has("song:offset_readout"), "选曲：提供单曲延迟选项与实时读数")
		var song_box := _find_tag(select, "song:offset", "SpinBox") as SpinBox
		var song_readout := _find_tag(select, "song:offset_readout", "Label") as Label
		if song_box == null or song_readout == null:
			_expect(false, "选曲：单曲延迟数值框与读数可以定位")
		else:
			_expect(song_box.allow_greater and song_box.allow_lesser, "选曲：单曲延迟不设上下限（可键入任意值）")
			_expect_close(Setting.song_offset_of(FIXTURE_SONG), 0.0, "选曲：这首歌一开始没有单曲延迟")
			_expect(song_readout.text.begins_with(UI.offset_breakdown(0.0, Setting.offset, Setting.chart_offset, ChartLoader.chart_data.offset)),
				"选曲：读数 = 单曲 + 时间偏移 + 谱面 offset（%s）" % song_readout.text)
			song_box.value = 220.0
			await get_tree().process_frame
			_expect_close(Setting.song_offset_of(FIXTURE_SONG), 220.0, "选曲：改数值框写进这首歌的单曲延迟")
			_expect(song_readout.text.begins_with(UI.offset_breakdown(220.0, Setting.offset, Setting.chart_offset, ChartLoader.chart_data.offset)),
				"选曲：读数把这首的单曲延迟一起算进去（%s）" % song_readout.text)
			# 换一首歌：显示的是那一首的数值（0），夹具那首不受影响。
			_tap_item(picker, _song_row(select, FIXTURE_FILLER % 1))
			await get_tree().create_timer(0.25).timeout
			_expect_close(song_box.value, 0.0, "选曲：换歌显示那一首各自的单曲延迟")
			_expect_close(Setting.song_offset_of(FIXTURE_SONG), 220.0, "选曲：换歌不会改到别的歌的数值")
			_tap_item(picker, _song_row(select, FIXTURE_SONG))
			await get_tree().create_timer(0.25).timeout
			_expect_close(song_box.value, 220.0, "选曲：切回夹具显示回它自己的 220 ms")
			# ↺ 归零：键被删掉，读数回到 0。
			var reset_button: Button = null
			for child in song_box.get_parent().get_children():
				if child is Button:
					reset_button = child
			if reset_button == null:
				_expect(false, "选曲：单曲延迟有归零按钮")
			else:
				reset_button.emit_signal("pressed")
				await get_tree().process_frame
				_expect_close(Setting.song_offset_of(FIXTURE_SONG), 0.0, "选曲：单曲延迟可以归零")
				_expect(song_readout.text.begins_with(UI.offset_breakdown(0.0, Setting.offset, Setting.chart_offset, ChartLoader.chart_data.offset)),
					"选曲：归零后读数回到只剩时间偏移与谱面 offset（%s）" % song_readout.text)
		# 最佳成绩：写在歌曲信息右侧的一栏，内容与结算界面同一套统计。
		var score_tags := {}
		_collect_tags(select, score_tags)
		_expect(score_tags.has("song:score") and score_tags.has("song:score_summary") and score_tags.has("song:score_grade:miss"),
			"选曲：提供最佳成绩面板（分数、概要、各判定数量）")
		var score_label := _find_tag(select, "song:score", "Label") as Label
		var score_summary := _find_tag(select, "song:score_summary", "Label") as Label
		if score_label == null or score_summary == null or song_box == null:
			_expect(false, "选曲：最佳成绩面板可以定位")
		else:
			# 先切回夹具：上面那段改过选中项。
			_tap_item(picker, _song_row(select, FIXTURE_SONG))
			await get_tree().create_timer(0.25).timeout
			_expect(score_label.text == "-------" and score_summary.text.contains("还没有成绩"),
				"选曲：没打过的歌显示占位符（%s / %s）" % [score_label.text, score_summary.text])
			# 记一局之后面板要立刻反映出来（不重进界面）。
			Scores.record(FIXTURE_SONG, {"score": 968420, "max_combo": 328, "total_units": 500,
				"position_mode": Setting.judge_position_mode,
				"counts": {"just+": 480, "just": 12, "good": 4, "ok": 2, "miss": 2}})
			select.call("_sync_score")
			await get_tree().process_frame
			_expect(score_label.text == "0968420", "选曲：显示七位最高分（实际 %s）" % score_label.text)
			_expect(score_summary.text.contains("最大连击 328") and score_summary.text.contains("游玩 1 次"),
				"选曲：概要显示最大连击与游玩次数（%s）" % score_summary.text)
			_expect((_find_tag(select, "song:score_grade:just+", "Label") as Label).text == "480"
				and (_find_tag(select, "song:score_grade:miss", "Label") as Label).text == "2", "选曲：面板列出各判定数量")
			_expect((_find_tag(select, "song:score_grade:miss", "Label") as Label).get_theme_color("font_color") == UI.Style.ERROR_TEXT
				and (_find_tag(select, "song:score_grade:just+", "Label") as Label).get_theme_color("font_color") == Skins.GRADE_COLOR,
				"选曲：判定数量沿用游玩内的判定配色")
			_expect((_find_tag(select, "song:score_hint", "Label") as Label).text.is_empty(),
				"选曲：当前模式下的成绩不再多嘴提示")
			# 换歌：那一首没有成绩，面板回到占位符；切回来成绩还在。
			_tap_item(picker, _song_row(select, FIXTURE_FILLER % 1))
			await get_tree().create_timer(0.25).timeout
			_expect(score_label.text == "-------", "选曲：换到没打过的歌显示没有成绩")
			_tap_item(picker, _song_row(select, FIXTURE_SONG))
			await get_tree().create_timer(0.25).timeout
			_expect(score_label.text == "0968420", "选曲：切回夹具显示它自己的成绩")
			# 位置：成绩栏在歌曲信息右侧（与曲名同一行、不压住它），而不是另起一行。
			var title: Label = select.get("_title")
			var score_rect := score_label.get_global_rect()
			var title_rect := title.get_global_rect()
			var panel_rect := (select.get("_score_panel") as Control).get_global_rect()
			_expect(panel_rect.position.x >= title_rect.end.x - 1.0 and panel_rect.position.x > title_rect.position.x,
				"选曲：成绩写在歌曲信息右侧（成绩 x=%.0f / 曲名右缘 x=%.0f）" % [panel_rect.position.x, title_rect.end.x])
			_expect(score_rect.position.y < title_rect.end.y, "选曲：成绩与歌曲信息同一行")
			var card := (select.get("_song_card") as Control)
			_expect(card.get_global_rect().encloses(panel_rect), "选曲：成绩栏在歌曲信息卡片内")
			# 成绩记在另一种判定模式下时提醒一句；换回来就不提示。
			var other_mode: String = Setting.JUDGE_POSITION_CURRENT if Setting.judge_position_mode == Setting.JUDGE_POSITION_NOTE else Setting.JUDGE_POSITION_NOTE
			Scores.record(FIXTURE_SONG, {"score": 990000, "max_combo": 500, "total_units": 500,
				"position_mode": other_mode, "counts": {}})
			select.call("_sync_score")
			var mode_hint := (_find_tag(select, "song:score_hint", "Label") as Label).text
			_expect(mode_hint.contains(UI.mode_name(other_mode)) and mode_hint.contains(UI.mode_name(Setting.judge_position_mode)),
				"选曲：成绩来自另一种判定模式时提醒一句（%s）" % mode_hint)
			Scores.record(FIXTURE_SONG, {"score": 1100000, "max_combo": 500, "total_units": 500,
				"position_mode": Setting.judge_position_mode, "counts": {}})
			select.call("_sync_score")
			var back_hint := (_find_tag(select, "song:score_hint", "Label") as Label).text
			_expect(back_hint.is_empty(), "选曲：模式换回来就不提示了（实际「%s」）" % back_hint)
	host.queue_free()
	await get_tree().process_frame
	_remove_tree(FIXTURE_SONG)
	for index in 13:
		_remove_tree(FIXTURE_FILLER % index)
	ChartLoader.selected_folder = ""


# ---------------------------------------------------------------- 一目录多谱面

## 一个谱面文件夹里有不止一张谱面：枚举、指定加载、成绩分记、界面展开、
## 删除谱面 / 删除整首歌（连带二次确认与安全边界）整条链路。
func _check_multi_charts() -> void:
	_write_song_fixture(MULTI_SONG, SONG_CHART, FIXTURE_ART)
	Storage.write_bytes(MULTI_SONG.path_join("extra.json"), MULTI_CHART.to_utf8_buffer())
	var base := Setting.song_key(MULTI_SONG)
	var charts := ImportAPI.list_charts(MULTI_SONG)
	_expect(charts.size() == 2, "多谱面：一个文件夹里读出两张谱面（实际 %d 张）" % charts.size())
	if charts.size() != 2:
		_remove_tree(MULTI_SONG)
		_expect(false, "多谱面：夹具没读出来，后面几项跳过")
		return
	_expect(str(charts[0].chart).ends_with("chart.json"), "多谱面：chart.json 是默认的那张，排在最前（%s）" % Storage.display_name(str(charts[0].chart)))
	_expect(str(charts[1].chart).ends_with("extra.json"), "多谱面：同目录里的其它谱面跟在后面（%s）" % Storage.display_name(str(charts[1].chart)))
	_expect(str(charts[1].label) == "Insane" and str(charts[1].detail) == "15",
		"多谱面：标签取谱面自报的难度与等级（%s %s）" % [str(charts[1].label), str(charts[1].detail)])
	# 加载指定的那一张：读进来的确实是 extra.json（音符数 2，与默认谱面的 1 不同）。
	_expect(ChartLoader.load_from_folder(MULTI_SONG, str(charts[1].chart)), "多谱面：可以按路径加载指定谱面（%s）" % ChartLoader.last_error)
	_expect(ChartLoader.selected_chart == str(charts[1].chart) and ChartLoader.chart_data.note.size() == 2,
		"多谱面：加载的是指定的那张，不是默认谱面")
	_expect(ChartLoader.load_from_folder(MULTI_SONG), "多谱面：不给谱面路径时读默认谱面")
	_expect(ChartLoader.selected_chart == str(charts[0].chart) and ChartLoader.chart_data.note.size() == 1,
		"多谱面：默认就是第一张（%s）" % Storage.display_name(ChartLoader.selected_chart))
	_expect(ChartLoader.score_key() == base + "#chart", "多谱面：成绩键带上谱面（%s）" % ChartLoader.score_key())
	# 成绩按谱面分记：两张谱面各记各的，存盘读回也还在。
	Scores.record(MULTI_SONG, {"score": 700000, "counts": {"just+": 10}}, str(charts[0].chart), 2)
	Scores.record(MULTI_SONG, {"score": 300000, "counts": {"miss": 4}}, str(charts[1].chart), 2)
	_expect(int(Scores.best(MULTI_SONG, str(charts[0].chart), 2).get("score", 0)) == 700000
		and int(Scores.best(MULTI_SONG, str(charts[1].chart), 2).get("score", 0)) == 300000,
		"多谱面：同一首歌的两张谱面各记各的成绩")
	_expect(Scores.best(MULTI_SONG).is_empty(), "多谱面：没指定谱面时不算整首歌的成绩")
	Scores.save_scores()
	Scores.scores.clear()
	Scores.load_scores()
	_expect(int(Scores.best(MULTI_SONG, str(charts[1].chart), 2).get("counts", {}).get("miss", 0)) == 4,
		"多谱面：按谱面分记的成绩存盘后读得回来")
	# 删掉一张谱面的成绩：另一张不受影响，文件夹仍然按谱面分记（不回落到整首歌的键）。
	_expect(Scores.forget_chart(MULTI_SONG, str(charts[1].chart)), "多谱面：删除谱面时能清掉它的成绩")
	_expect(Scores.best(MULTI_SONG, str(charts[1].chart), 2).is_empty()
		and int(Scores.best(MULTI_SONG, str(charts[0].chart), 1).get("score", 0)) == 700000,
		"多谱面：剩下那张谱面的成绩还在")
	_expect(Scores.key_of(MULTI_SONG, str(charts[0].chart), 1) == base + "#chart",
		"多谱面：成绩册里还有按谱面分记的键，文件夹就不回落到整首歌的键")
	# 删除的安全边界：库根、库外路径、带 .. 的路径一律拒绝。
	_expect(not Storage.delete_tree("res://") and not Storage.delete_tree("") and not Storage.delete_tree("user://chart")
		and not Storage.delete_file("user://chart/../scores.cfg") and not Storage.delete_file("res://project.godot"),
		"删除：只删谱面库里的内容（库根 / 库外 / 带 .. 的路径都拒绝）")
	# 界面：歌曲行展开出全部谱面，谱面行可以单独选中，删谱面 / 删整首歌都要再确认一次。
	Scores.record(MULTI_SONG, {"score": 300000, "counts": {"miss": 4}}, str(charts[1].chart), 2)
	# 先当作没选中任何歌：列表一开始是收起的，展开要由轻点触发。
	ChartLoader.selected_folder = ""
	ChartLoader.selected_chart = ""
	var start_scene: PackedScene = load("res://gd/room/startroom.tscn")
	var host := Control.new()
	host.size = Vector2(900, 520)
	add_child(host)
	var select := start_scene.instantiate()
	host.add_child(select)
	await get_tree().process_frame
	await get_tree().process_frame
	var picker: ItemList = select.find_child("ChartList", true, false)
	if picker == null:
		_expect(false, "多谱面：选曲界面的谱面库可以定位")
		host.queue_free()
		_remove_tree(MULTI_SONG)
		return
	(select.get("_search") as LineEdit).text = "__self_check_multi"
	select.call("_filter")
	await get_tree().process_frame
	_expect(picker.get_item_count() == 1, "多谱面：没展开时列表里只有歌曲行（实际 %d 项）" % picker.get_item_count())
	_tap_item(picker, 0)
	await get_tree().create_timer(0.25).timeout
	var song_row := _song_row(select, MULTI_SONG)
	_expect(picker.get_item_count() == 3, "多谱面：轻点歌曲行展开出它的全部谱面（实际 %d 项）" % picker.get_item_count())
	_expect(picker.get_item_text(song_row + 1).contains("●") and picker.get_item_text(song_row + 2).contains("○"),
		"多谱面：展开的谱面行标出当前选中的那张（%s / %s）" % [picker.get_item_text(song_row + 1), picker.get_item_text(song_row + 2)])
	_expect(picker.get_item_text(song_row + 2).contains("Insane") and picker.get_item_text(song_row + 2).contains("15"),
		"多谱面：谱面行写出难度与等级（%s）" % picker.get_item_text(song_row + 2))
	# 选中第二张：加载的是它，标记跟着换，可以开始游玩。
	_tap_item(picker, song_row + 2)
	await get_tree().create_timer(0.25).timeout
	_expect(ChartLoader.selected_chart == str(charts[1].chart), "多谱面：轻点谱面行选中那一张（%s）" % Storage.display_name(ChartLoader.selected_chart))
	_expect(ChartLoader.chart_data.note.size() == 2, "多谱面：选中的谱面真的被读进来了（%d 个音符）" % ChartLoader.chart_data.note.size())
	_expect(picker.get_item_text(song_row + 1).contains("○") and picker.get_item_text(song_row + 2).contains("●"),
		"多谱面：选中标记跟着换（%s / %s）" % [picker.get_item_text(song_row + 1), picker.get_item_text(song_row + 2)])
	var play: Button = select.get("_play")
	_expect(not play.disabled, "多谱面：展开出来的谱面可以开始游玩")
	# 管理菜单：两条删除都在里面。
	select.call("_open_manage")
	await get_tree().process_frame
	var menu := select.find_child("LibraryMenu", true, false) as PopupMenu
	_expect(menu != null and menu.item_count == 2 and menu.get_item_text(0).contains("删除谱面") and menu.get_item_text(1).contains("删除整首歌"),
		"删除：管理菜单提供删除谱面与删除整首歌两条")
	if menu != null:
		menu.queue_free()
	# 删除谱面：先取消（什么都不动），再确认（只删这一张，另一张与其他素材都留着）。
	select.call("_ask_delete_chart", MULTI_SONG, charts[1])
	await get_tree().process_frame
	var dialog := select.find_child("DeleteConfirm", true, false) as ConfirmationDialog
	_expect(dialog != null, "删除：删谱面前弹出二次确认框")
	if dialog != null:
		_expect(dialog.ok_button_text == "删除" and dialog.cancel_button_text == "取消",
			"删除：确认框的按钮是「删除 / 取消」（%s / %s）" % [dialog.ok_button_text, dialog.cancel_button_text])
		_expect(dialog.dialog_text.contains("Insane") and dialog.dialog_text.contains("__self_check_multi__"),
			"删除：确认框说清删的是哪首歌的哪张谱面")
		dialog.get_cancel_button().emit_signal("pressed")
	await get_tree().process_frame
	_expect(FileAccess.file_exists(MULTI_SONG.path_join("extra.json")), "删除：点取消什么都不删")
	select.call("_ask_delete_chart", MULTI_SONG, charts[1])
	await get_tree().process_frame
	dialog = select.find_child("DeleteConfirm", true, false) as ConfirmationDialog
	if dialog != null:
		dialog.get_ok_button().emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not FileAccess.file_exists(MULTI_SONG.path_join("extra.json")), "删除：确认后这张谱面的文件没了")
	_expect(FileAccess.file_exists(MULTI_SONG.path_join("chart.json")) and FileAccess.file_exists(MULTI_SONG.path_join("tone.wav")),
		"删除：同一首歌的另一张谱面与音频都留着")
	_expect(ImportAPI.list_charts(MULTI_SONG).size() == 1, "删除：文件夹里只剩另一张谱面（实际 %d 张）" % ImportAPI.list_charts(MULTI_SONG).size())
	_expect(picker.get_item_count() == 2, "删除：列表跟着刷新成歌曲行 + 一张谱面（实际 %d 项）" % picker.get_item_count())
	_expect(Scores.best(MULTI_SONG, str(charts[1].chart), 2).is_empty(), "删除：被删谱面的成绩一起清掉")
	_expect(int(Scores.best(MULTI_SONG, str(charts[0].chart), 1).get("score", 0)) == 700000, "删除：另一张谱面的成绩留着")
	# 只剩一张谱面时删谱面：确认框要提醒整首歌都没了。
	select.call("_ask_delete_chart", MULTI_SONG, charts[0])
	await get_tree().process_frame
	dialog = select.find_child("DeleteConfirm", true, false) as ConfirmationDialog
	_expect(dialog != null and dialog.dialog_text.contains("只剩这一张谱面"), "删除：最后一张谱面的确认框提醒整首歌都会没")
	if dialog != null:
		dialog.get_cancel_button().emit_signal("pressed")
	await get_tree().process_frame
	# 删除整首歌：文件夹（含音频、封面）、成绩与单曲延迟一起清掉。
	Setting.set_song_offset(MULTI_SONG, 180.0)
	Scores.record(MULTI_SONG, {"score": 500000}, str(charts[0].chart), 2)
	select.call("_ask_delete_song", MULTI_SONG)
	await get_tree().process_frame
	dialog = select.find_child("DeleteConfirm", true, false) as ConfirmationDialog
	_expect(dialog != null and dialog.dialog_text.contains("__self_check_multi__"), "删除：删整首歌也要二次确认")
	if dialog != null:
		dialog.get_ok_button().emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not DirAccess.dir_exists_absolute(MULTI_SONG), "删除：整首歌的文件夹被整个删掉")
	_expect(not FileAccess.file_exists(MULTI_SONG.path_join("tone.wav")) and not FileAccess.file_exists(MULTI_SONG.path_join("bg.png")),
		"删除：音频与封面一起删掉")
	_expect_close(Setting.song_offset_of(MULTI_SONG), 0.0, "删除：整首歌的单曲延迟一起清掉")
	var leftovers := 0
	for key: String in Scores.scores.keys():
		if key == base or key.begins_with(base + "#"):
			leftovers += 1
	_expect(leftovers == 0, "删除：整首歌的成绩一起清掉（还剩 %d 条）" % leftovers)
	_expect(picker.get_item_count() == 1 and picker.is_item_disabled(0), "删除：列表里不再有这首歌")
	host.queue_free()
	await get_tree().process_frame
	_remove_tree(MULTI_SONG)
	ChartLoader.selected_folder = ""
	ChartLoader.selected_chart = ""
	Setting.set_song_offset(FIXTURE_SONG, 0.0)


# ---------------------------------------------------------------- 工具

## 一行里的亮区范围（像素索引，含端点）；没有亮像素时返回 (-1, -1)。
func _row_run(image: Image, row: int, from_x: int, to_x: int) -> Vector2:
	var left := -1.0
	var right := -1.0
	for x in range(maxi(from_x, 0), mini(to_x, image.get_width() - 1) + 1):
		if image.get_pixel(x, row).r > 0.5:
			if left < 0.0:
				left = float(x)
			right = float(x)
	return Vector2(left, right)


## 一列里的亮区范围（像素索引，含端点）；没有亮像素时返回 (-1, -1)。
func _column_run(image: Image, column: int, from_y: int, to_y: int) -> Vector2:
	var top := -1.0
	var bottom := -1.0
	for y in range(maxi(from_y, 0), mini(to_y, image.get_height() - 1) + 1):
		if image.get_pixel(column, y).r > 0.5:
			if top < 0.0:
				top = float(y)
			bottom = float(y)
	return Vector2(top, bottom)


## 一列上亮 / 暗翻转的位置（像素边界，精度 0.5）。
func _column_transitions(image: Image, column: int, from_y: int, to_y: int) -> Array[float]:
	var transitions: Array[float] = []
	var low := maxi(from_y, 0)
	var high := mini(to_y, image.get_height() - 1)
	if high <= low:
		return transitions
	var bright := image.get_pixel(column, low).r > 0.5
	for y in range(low + 1, high + 1):
		var value := image.get_pixel(column, y).r > 0.5
		if value != bright:
			transitions.append(float(y) - 0.5)
			bright = value
	return transitions


func _make_wav(samples: int = 128) -> PackedByteArray:
	var data := PackedByteArray()
	var data_size := samples * 2
	data.resize(44 + data_size)
	data.encode_u32(0, 0x46464952)          # "RIFF"
	data.encode_u32(4, 36 + data_size)
	data.encode_u32(8, 0x45564157)          # "WAVE"
	data.encode_u32(12, 0x20746d66)         # "fmt "
	data.encode_u32(16, 16)
	data.encode_u16(20, 1)                  # PCM
	data.encode_u16(22, 1)                  # 单声道
	data.encode_u32(24, 8000)
	data.encode_u32(28, 8000 * 2)
	data.encode_u16(32, 2)
	data.encode_u16(34, 16)
	data.encode_u32(36, 0x61746164)         # "data"
	data.encode_u32(40, data_size)
	for index in samples:
		data.encode_s16(44 + index * 2, int(12000.0 * sin(index * 0.3)))
	return data


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)


func _read_optional(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


## 收集设置界面里带 dakumi_setting 标签的控件（含滑条）。
func _collect_tags(node: Node, found: Dictionary) -> void:
	if node.has_meta("dakumi_setting"):
		found[str(node.get_meta("dakumi_setting"))] = true
	for child in node.get_children():
		_collect_tags(child, found)


func _find_tagged(node: Node, tag: String) -> Node:
	if node.has_meta("dakumi_setting") and str(node.get_meta("dakumi_setting")) == tag and node is HSlider:
		return node
	for child in node.get_children():
		var found := _find_tagged(child, tag)
		if found != null:
			return found
	return null


## 按 dakumi_setting 标签找控件，可限定类型；用于读取界面上的实时读数。
func _find_tag(node: Node, tag: String, kind: String = "") -> Node:
	if node.has_meta("dakumi_setting") and str(node.get_meta("dakumi_setting")) == tag and (kind.is_empty() or node.is_class(kind)):
		return node
	for child in node.get_children():
		var found := _find_tag(child, tag, kind)
		if found != null:
			return found
	return null


## 模拟触屏：位置按视口坐标（与 Control.get_global_rect 同一套），安卓拖拽走的就是这条路径。
func _push_touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	get_viewport().push_input(event, true)


func _push_drag(position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = position
	event.relative = relative
	get_viewport().push_input(event, true)


func _push_wheel(position: Vector2, button_index: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	event.position = position
	get_viewport().push_input(event, true)


## 在区域里找一个「被动」点：它上面没有被 STOP 的控件盖住（滑条、按钮、输入框都会吃掉
## 按下事件，手势也就不再冒泡到根节点）。拖拽滚动只应该在被动区域生效，所以测试也必须
## 从这里起手，否则断言的是控件自己的行为，不是界面的滚动。
func _passive_point(root: Control, area: Rect2) -> Vector2:
	var columns := 5
	var rows := 9
	for row in rows:
		for column in columns:
			var point := area.position + Vector2(area.size.x * (column + 0.5) / columns, area.size.y * (row + 0.5) / rows)
			if not _blocked_point(root, point):
				return point
	return area.get_center()


func _blocked_point(root: Control, point: Vector2) -> bool:
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control == root or not control.is_visible_in_tree():
			continue
		if control.mouse_filter != Control.MOUSE_FILTER_STOP:
			continue
		if control.get_global_rect().has_point(point):
			return true
	return false


## 轻点列表的某一项：安卓上引擎会把屏幕触摸转成模拟鼠标事件，ItemList 的选中走的就是
## 这条路；push_input 不会触发引擎的这份模拟，所以要在这里显式补上按下与抬起。
## 选曲列表里某一首歌曲行的行号：谱面行会插在展开的歌曲行后面，ItemList 的行号与 _paths
## 的下标不再一一对应（见 song_select._rows），所以自检要按 _rows 现查。
func _song_row(select: Node, folder: String) -> int:
	var rows: Array = select.get("_rows")
	for index in rows.size():
		var row: Dictionary = rows[index]
		if str(row.kind) == "song" and str(row.folder) == folder:
			return index
	return -1


func _tap_item(list: ItemList, index: int) -> void:
	var point := list.get_global_rect().position + list.get_item_rect(index).get_center()
	_push_touch(point, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		get_viewport().push_input(event, true)
	_push_touch(point, false)


## 写一个自检用谱面夹具：清单 + 音频 + 背景，素材写法与导入链路一致。
func _write_song_fixture(folder: String, chart: String, art: Color) -> void:
	_remove_tree(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	Storage.write_bytes(folder.path_join("chart.json"), chart.to_utf8_buffer())
	Storage.write_bytes(folder.path_join("tone.wav"), _make_wav())
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(art)
	Storage.write_bytes(folder.path_join("bg.png"), image.save_png_to_buffer())


func _expect(condition: bool, title: String) -> void:
	if condition:
		_passed += 1
		print("  ✓ %s" % title)
	else:
		_failures.append(title)
		print("  ✗ %s" % title)


func _expect_close(value: float, expected: float, title: String) -> void:
	var close := absf(value - expected) <= maxf(0.0005, absf(expected) * 0.0005)
	_expect(close, "%s（实际 %f / 期望 %f）" % [title, value, expected])


## 像素级比较：容差按设备像素给，不能用 _expect_close 的相对容差。
func _expect_near(value: float, expected: float, tolerance: float, title: String) -> void:
	_expect(absf(value - expected) <= tolerance,
		"%s（实际 %.1f / 期望 %.1f ± %.1f）" % [title, value, expected, tolerance])


## 颜色比较：逐通道容差。贴图采样、MUL 溶解与设备缩放都会带来一点偏差。
func _expect_color(actual: Color, expected: Color, title: String) -> void:
	var worst := maxf(maxf(absf(actual.r - expected.r), absf(actual.g - expected.g)), absf(actual.b - expected.b))
	_expect(worst <= 0.08, "%s（实际 (%.2f, %.2f, %.2f) / 期望 (%.2f, %.2f, %.2f)，最大偏差 %.2f）"
		% [title, actual.r, actual.g, actual.b, expected.r, expected.g, expected.b, worst])


func _note(message: String) -> void:
	print("  · %s" % message)


func _finish_ok() -> void:
	if _failures.is_empty():
		print("\n自检通过：%d 项全部成功。" % _passed)
		get_tree().quit(0)
		return
	print("\n自检失败：%d 项通过，%d 项失败。" % [_passed, _failures.size()])
	for failure in _failures:
		print("  - %s" % failure)
	get_tree().quit(1)


func _check_event_boundaries() -> void:
	var data := {"event": [], "track": {}}
	for id in range(0, 9):
		data.track[str(id)] = {}
		data.event.append({"track": id, "type": "x", "beat": 1, "from": 50, "to": 50})
		data.event.append({"track": id, "type": "w", "beat": 1, "from": 40, "to": 40})
	data.track["1"] = {"boundary_type": "pos", "left_boundary": 0, "right_boundary": 0}
	data.track["2"] = {"boundary_type": "pos", "left_boundary": 80, "right_boundary": 100}
	data.track["3"] = {"boundary_type": "pos", "left_boundary": 0, "right_boundary": 20}
	data.track["4"] = {"parent": 8, "boundary_type": "track", "left_boundary": 5, "left_reference": "x", "right_boundary": 999}
	data.track["5"] = {"parent": 8}
	data.track["6"] = {"boundary_type": "track", "left_boundary": 0, "left_reference": "x", "right_boundary": 999}
	data.track["7"] = {"boundary_type": "track", "left_boundary": 999, "right_boundary": 999}
	var evaluator := TrackEvaluator.new(ChartData.new(JSON.stringify(data)))
	_expect(evaluator.at(1, 1).is_equal_approx(Vector2.ZERO), "event：pos 两侧零是合法边界")
	_expect(evaluator.at(2, 1).is_equal_approx(Vector2(0.8, 0)), "event：完全在左侧时收缩到左边界")
	_expect(evaluator.at(3, 1).is_equal_approx(Vector2(0.2, 0)), "event：完全在右侧时收缩到右边界")
	_expect(evaluator.at(4, 1).is_equal_approx(Vector2(1.1, 0.2)), "event：边界与当前轨道共享父轨道仍完整偏移")
	_expect(evaluator.at(6, 1).is_equal_approx(Vector2(0.6, 0.2)), "event：编号零的边界轨道可解析")
	_expect(evaluator.at(7, 1).is_equal_approx(Vector2(0.5, 0.4)), "event：不存在的边界轨道跳过")
	# 每种引用单独验证，包括宽度作为边界坐标。
	for reference in ["x", "w", "lpos", "rpos"]:
		data.track["6"].left_reference = reference
		var probe := TrackEvaluator.new(ChartData.new(JSON.stringify(data)))
		var expected: Dictionary = {"x": Vector2(0.6, 0.2), "w": Vector2(0.55, 0.3), "lpos": Vector2(0.5, 0.4), "rpos": Vector2(0.7, 0)}
		_expect(probe.at(6, 1).is_equal_approx(expected[reference]), "event：边界引用 " + reference)
	# 未来事件不能抢占已开始的 x/w。
	data.event.append({"track": 7, "type": "lpos", "beat": 8, "from": 90, "to": 90})
	evaluator = TrackEvaluator.new(ChartData.new(JSON.stringify(data)))
	_expect(evaluator.at(7, 2).is_equal_approx(Vector2(0.5, 0.4)), "event：未来事件不参与当前合并")
	_expect(evaluator.at(7, 9).is_equal_approx(Vector2(0.5, 0.8)), "event：无边界时反向宽度保留绝对值")
	_expect(evaluator.at(7, 2).is_equal_approx(Vector2(0.5, 0.4)), "event：倒退采样清空缓存")
	data.track["4"] = {"parent": 5}
	data.track["5"] = {"parent": 4}
	evaluator = TrackEvaluator.new(ChartData.new(JSON.stringify(data)))
	var a := evaluator.at(4, 1)
	var b := evaluator.at(5, 1)
	var reverse := TrackEvaluator.new(ChartData.new(JSON.stringify(data)))
	_expect(b.is_equal_approx(reverse.at(5, 1)) and a.is_equal_approx(reverse.at(4, 1)), "event：父链环不污染其他根轨道缓存")
	data.track["4"] = {"boundary_type": "track", "left_boundary": 5, "right_boundary": 999}
	data.track["5"] = {"boundary_type": "track", "left_boundary": 4, "right_boundary": 999}
	evaluator = TrackEvaluator.new(ChartData.new(JSON.stringify(data)))
	_expect(is_finite(evaluator.at(4, 1).x) and is_finite(evaluator.at(5, 1).x), "event：边界环安全终止")
	_expect_close(evaluator._transition({"type": "unknown"}, 0), 1, "event：未知过渡类型直接取终值")

	data.track["4"] = {"parent": 8, "scale_with_parent": 1}
	evaluator = TrackEvaluator.new(ChartData.new(JSON.stringify(data)))
	_expect(evaluator.at(4, 1).is_equal_approx(Vector2(0.5, 0.16)), "event：随父轨道缩放位置和宽度")
	data.event.append({"track": 7, "type": "x", "beat": 1, "from": 25, "to": 25})
	evaluator = TrackEvaluator.new(ChartData.new(JSON.stringify(data)))
	_expect_close(evaluator.at(7, 2).x, 0.25, "event：同轨同拍最后一条事件优先")
	data.event.append({"track": 7, "type": "w", "beat": 1, "beat2": 10, "from": 40, "to": 40})
	evaluator = TrackEvaluator.new(ChartData.new(JSON.stringify(data)))
	_expect(evaluator.at(7, 9).is_equal_approx(Vector2(1.1, 0.4)), "event：活动事件以当前拍参与最近两项合并")
	var session := PlaySession.new(ChartData.new(TAP_CHART))
	session.update(0, {})
	var visible := session.visible_notes(3).duplicate()
	_expect(visible.size() == 4, "性能：可见窗口包含前瞻范围内音符")
	session.update(0.7, {})
	_expect(session.visible_notes(3) == [1, 2, 3], "性能：原地压缩移除完成音符并保持顺序")


func _check_shared_holds_and_slide_feedback() -> void:
	var slide_chart := _note_fixture(JSON.stringify({"note": [{"type": "wipe", "beat": 2, "track": 1}]}))
	var early := PlaySession.new(slide_chart)
	var feedback: Array[int] = []
	early.feedback_ready.connect(func(index: int, _grade: String, _phase: String) -> void: feedback.append(index))
	var field := Playfield.new()
	field.attach_session(early)
	var sound_cursor: int = Skins._next_player
	early.update(0.92, {0: {"x": 0.5, "pressed": false}})
	_expect(early.states[0] == PlaySession.State.SLIDE_WAITING and early.combo == 1, "Slide：提前命中立即完成判定计分")
	_expect(early.visible_notes(2.0) == [0], "Slide：提前命中后保留音符直到目标时间")
	_expect(Skins._next_player == sound_cursor and field._display_grade.is_empty(), "Slide：提前命中时实际音效播放器和判定文字均不触发")
	_expect(feedback.is_empty() and field._hits.is_empty(), "Slide：提前命中不播放动画和打击音反馈")
	early.update(0.999, {})
	_expect(feedback.is_empty(), "Slide：手指离开后仍等待音符时间")
	early.update(1.0, {})
	_expect(Skins._next_player == (sound_cursor + 1) % Skins.SOUND_POOL_SIZE and field._display_grade == "just+", "Slide：到目标时间才实际播放打击音并显示判定文字")
	_expect(early.visible_notes(2.0).is_empty() and early.states[0] == PlaySession.State.DONE, "Slide：反馈播放时才移除音符")
	_expect(feedback == [0] and field._hits.size() == 1, "Slide：到达音符时间触发一次动画和打击音反馈")
	early.update(1.1, {})
	_expect(feedback == [0], "Slide：后续帧不重复播放")
	field.free()
	var late := PlaySession.new(slide_chart)
	var late_feedback: Array[int] = []
	late.feedback_ready.connect(func(index: int, _grade: String, _phase: String) -> void: late_feedback.append(index))
	late.update(1.06, {0: {"x": 0.5, "pressed": false}})
	_expect(late_feedback == [0], "Slide：音符时间后命中立即播放反馈")
	var skipped := PlaySession.new(slide_chart)
	var skipped_feedback: Array[int] = []
	skipped.feedback_ready.connect(func(index: int, _grade: String, _phase: String) -> void: skipped_feedback.append(index))
	skipped.update(0.94, {0: {"x": 0.5, "pressed": false}})
	skipped.update(1.04, {})
	_expect(skipped_feedback == [0], "Slide：跨过目标时间也会播放反馈")
	var fresh := PlaySession.new(slide_chart)
	_expect(fresh._pending_slide_feedback.is_empty(), "Slide：重开会话无遗留反馈")
	# 交替安排 Tap 的轨道排序，验证 Hold 在前或 Tap 在前都不互相消费。
	for tap_track in [1, 3]:
		var data := {"note": [], "event": []}
		for track_id in range(1, 4):
			data.note.append({"type": "note" if track_id == tap_track else "hold", "track": track_id, "beat": 2, "beat2": 4})
		# 第二颗 Tap、不同时间的 Hold、触摸范围外的 Hold 均不应同时命中。
		data.note.append({"type": "note", "track": tap_track, "beat": 2})
		data.note.append({"type": "hold", "track": 1, "beat": 2.1, "beat2": 4})
		data.note.append({"type": "hold", "track": 4, "beat": 2, "beat2": 4})
		data.event = [{"type": "x", "track": 4, "beat": 0.01, "from": 95, "to": 95}, {"type": "w", "track": 4, "beat": 0.01, "from": 4, "to": 4}]
		for id in [1, 2, 3]:
			data.event.append({"type": "x", "track": id, "beat": 0, "from": 50, "to": 50})
			data.event.append({"type": "w", "track": id, "beat": 0, "from": 100, "to": 100})
		var shared := PlaySession.new(ChartData.new(JSON.stringify(data)))
		shared.update(1.0, {7: {"x": 0.5, "pressed": true}})
		# 一次按下只判一颗 Tap 加一根长条：同刻的另一根长条挂起等手指，范围外的那根完全不碰。
		_expect(shared.active_holds.size() == 1 and shared.deferred_holds.size() == 1 and shared.combo == 2, "Hold：一指只认领一颗 Tap 加一根长条（Tap 轨 %d）" % tap_track)
		var pending_taps := 0
		var pending_holds := 0
		for index in shared.notes.size():
			if shared.states[index] == PlaySession.State.PENDING:
				if shared.notes[index].type == "Tap":
					pending_taps += 1
				else:
					pending_holds += 1
		_expect(pending_taps == 1 and pending_holds == 3, "Hold：不额外命中第二颗 Tap、其他时刻或范围外 Hold（待判 Tap %d / Hold %d）" % [pending_taps, pending_holds])
		for hold in shared.active_holds.values():
			_expect(hold.finger == 7, "Hold：认领的长条绑在按下的手指上")
		shared.update(1.05, {7: {"x": 0.5, "pressed": false}})
		_expect(shared.active_holds.size() == 1 and shared.deferred_holds.size() == 1, "Hold：持续按住不会触发后续 Hold 头")
		# 一直没手指来认领：快判漏的那一刻（1.0 + 头判窗口 100 ms）归给按下它的手指，沿用那一次按下的判定。
		shared.update(1.12, {7: {"x": 0.5, "pressed": false}})
		_expect(shared.deferred_holds.is_empty() and shared.active_holds.size() == 2, "Hold：没人认领的挂起长条在判漏前归位")
		for hold in shared.active_holds.values():
			_expect(hold.finger == 7, "Hold：挂起的长条归给按下它的那根手指")
		_expect(shared.judgement_counts["just+"] == 3 and shared.hit_offset_count == 3, "Hold：归位用那次按下的判定，且只算一次按点")
		shared.update(2.0, {7: {"x": 0.5, "pressed": false}})
		_expect(shared.active_holds.is_empty(), "Hold：保持到尾完成全部长条")
	# 挂起的长条被别的手指认领：用的是认领那次按下的判定（按晚 60 ms = just，不是原先的 just+）。
	var pair := {"note": [
		{"type": "hold", "track": 1, "beat": 2, "beat2": 4},
		{"type": "hold", "track": 2, "beat": 2, "beat2": 4},
	], "event": []}
	for id in [1, 2]:
		pair.event.append({"type": "x", "track": id, "beat": 0, "from": 50, "to": 50})
		pair.event.append({"type": "w", "track": id, "beat": 0, "from": 100, "to": 100})
	var claimed := PlaySession.new(ChartData.new(JSON.stringify(pair)))
	claimed.update(1.0, {7: {"x": 0.5, "pressed": true}})
	_expect(claimed.active_holds.size() == 1 and claimed.deferred_holds.size() == 1, "Hold：两根同刻长条先认领一根、挂起一根")
	claimed.update(1.05, {8: {"x": 0.5, "pressed": true}})
	_expect(claimed.deferred_holds.is_empty() and claimed.active_holds.size() == 2, "Hold：第二根手指按下来认领挂起的长条")
	_expect(claimed.active_holds.values()[0].finger == 7 and claimed.active_holds.values()[1].finger == 8, "Hold：两根长条各归按下的那根手指")
	_expect(claimed.judgement_counts["just+"] == 1 and claimed.judgement_counts["just"] == 1, "Hold：挂起的长条采用认领那次按下的判定（按晚 50 ms = just，不是挂起时的 just+）")
	# 按 Tap 不能顺手判掉它后面那颗 Hold（反过来也一样）：那颗音符要等属于它自己的那次按下。
	var chain := {"note": [
		{"type": "note", "track": 1, "beat": 2},
		{"type": "hold", "track": 1, "beat": 2.1, "beat2": 4},
	], "event": []}
	for id in [1, 2]:
		chain.event.append({"type": "x", "track": id, "beat": 0, "from": 50, "to": 50})
		chain.event.append({"type": "w", "track": id, "beat": 0, "from": 100, "to": 100})
	var queued := PlaySession.new(ChartData.new(JSON.stringify(chain)))
	queued.update(1.0, {7: {"x": 0.5, "pressed": true}})
	_expect(queued.states[0] == PlaySession.State.DONE and queued.states[1] == PlaySession.State.PENDING, "Tap→Hold：按 Tap 不判它后面的 Hold")
	queued.update(1.05, {7: {"x": 0.5, "pressed": true}})
	_expect(queued.states[1] == PlaySession.State.HOLDING and queued.judgement_counts["just+"] == 2, "Tap→Hold：后面的 Hold 等自己那次按下才判")
	var flipped := {"note": [
		{"type": "hold", "track": 1, "beat": 2, "beat2": 4},
		{"type": "note", "track": 1, "beat": 2.1},
	], "event": []}
	for id in [1, 2]:
		flipped.event.append({"type": "x", "track": id, "beat": 0, "from": 50, "to": 50})
		flipped.event.append({"type": "w", "track": id, "beat": 0, "from": 100, "to": 100})
	var reversed_session := PlaySession.new(ChartData.new(JSON.stringify(flipped)))
	reversed_session.update(1.0, {7: {"x": 0.5, "pressed": true}})
	_expect(reversed_session.states[0] == PlaySession.State.HOLDING and reversed_session.states[1] == PlaySession.State.PENDING, "Hold→Tap：按 Hold 不判它后面的 Tap")
	reversed_session.update(1.05, {7: {"x": 0.5, "pressed": true}})
	_expect(reversed_session.states[1] == PlaySession.State.DONE and reversed_session.judgement_counts["just+"] == 2, "Hold→Tap：后面的 Tap 等自己那次按下才判")
	# 视听反馈跟着判定走：挂起的长条在按下那一刻不亮特效、不出判定文字，
	# 等它真的判完（别的手指认领、或判漏前归位）才补上。
	var pair_field := Playfield.new()
	var pair_session := PlaySession.new(ChartData.new(JSON.stringify(pair)))
	pair_field.attach_session(pair_session)
	pair_session.update(1.0, {7: {"x": 0.5, "pressed": true}})
	_expect(pair_field._hold_hits.size() == 1 and pair_field._hits.is_empty(), "Hold：同刻第二根长条按下时不亮打击特效")
	_expect(pair_session.deferred_holds.size() == 1 and pair_field._display_grade == "just+", "Hold：那一刻只出了一次判定文字")
	pair_session.update(1.06, {7: {"x": 0.5, "pressed": false}})
	_expect(pair_field._hold_hits.size() == 1, "Hold：挂起期间一直不亮特效")
	pair_session.update(1.12, {7: {"x": 0.5, "pressed": false}})
	_expect(pair_field._hold_hits.size() == 2 and pair_field._display_grade == "just+", "Hold：判漏前归位时才补上特效与判定文字")
	pair_field.free()
	var claim_field := Playfield.new()
	var claim_session := PlaySession.new(ChartData.new(JSON.stringify(pair)))
	claim_field.attach_session(claim_session)
	claim_session.update(1.0, {7: {"x": 0.5, "pressed": true}})
	_expect(claim_field._hold_hits.size() == 1, "Hold：同刻只亮被认领那一根")
	claim_session.update(1.05, {8: {"x": 0.5, "pressed": true}})
	_expect(claim_field._hold_hits.size() == 2, "Hold：别的手指认领时才补上第二根的特效")
	claim_field.free()


## 谱面时钟：音频时刻是 10 ms 一跳的台阶，时钟（demo.clock_step）必须把它抹平——
## 直接拿音频时刻当谱面时钟时，240 fps 下约 6% 的帧原地不动、4% 的帧跳两倍，画面就会抖。
## 这里喂一段模拟时间序列，确认步进均匀、不倒退、不漂，且真的跳转（暂停/换设备）会直接对齐。
func _check_chart_clock(demo: Node) -> void:
	var frame := 1.0 / 240.0
	var step := 0.0104
	var clock := 0.0
	var low := INF
	var high := 0.0
	for index in 2400:
		if index == 0:
			clock = demo.clock_step(clock, 0.0, frame)
			continue
		var now := float(index) * frame
		var next: float = demo.clock_step(clock, floorf(now / step) * step, frame)
		var advance := next - clock
		low = minf(low, advance)
		high = maxf(high, advance)
		clock = next
	# 台阶有 10.4 ms，帧只有 4.17 ms：抹平之后每帧都该往前走，且速度不能忽快忽慢。
	_expect(low > 0.0, "时钟：混音台阶被抹平，没有原地不动的帧")
	_expect(high < low * 1.5, "时钟：每帧步进均匀（%.3f ~ %.3f ms）" % [low * 1000.0, high * 1000.0])
	# floor 台阶本身就落后真实时间半个台阶，时钟跟台阶走，误差不该超过这个量级。
	_expect(absf(clock - 2400.0 * frame) < step, "时钟：跟得住音频，不积累漂移（差 %.1f ms）" % [(clock - 2400.0 * frame) * 1000.0])
	_expect(is_equal_approx(demo.clock_step(clock, clock + 1.0, frame), clock + 1.0), "时钟：真实跳转（暂停/换设备）直接对齐")
	_expect(demo.clock_step(clock, clock - 1.0, frame) == clock - 1.0, "时钟：向后跳转（重开）也直接对齐，不会冻结")


func _collect_mode_buttons(node: Node, result: Array[Node]) -> void:
	if node.get_meta("dakumi_setting", "") == "game:judge_position_mode":
		result.append(node)
	for child in node.get_children():
		_collect_mode_buttons(child, result)

func _check_position_modes() -> void:
	var original_mode: String = Setting.judge_position_mode
	for kind in ["note", "wipe", "hold"]:
		var chart := ChartData.new(JSON.stringify({
			"note": [{"type": kind, "track": 1, "beat": 2, "beat2": 4}],
			"event": [
				{"type": "x", "track": 1, "beat": 0, "beat2": 4, "from": 0, "to": 100},
				{"type": "w", "track": 1, "beat": 0.01, "from": 2, "to": 2}]}))
		# 120 BPM，0.94 秒的当前位置为 0.47，目标 1 秒的位置为 0.50。
		for mode in [Setting.JUDGE_POSITION_CURRENT, Setting.JUDGE_POSITION_NOTE]:
			Setting.judge_position_mode = mode
			var current_finger := PlaySession.new(chart)
			current_finger.update(0.94, {0: {"x": 0.47, "pressed": true}})
			_expect((current_finger.states[0] != PlaySession.State.PENDING) == (mode == Setting.JUDGE_POSITION_CURRENT), "空间判定：%s / %s 当前位置命中结果正确" % [kind, mode])
			var target_finger := PlaySession.new(chart)
			target_finger.update(0.94, {0: {"x": 0.50, "pressed": true}})
			_expect((target_finger.states[0] != PlaySession.State.PENDING) == (mode == Setting.JUDGE_POSITION_NOTE), "空间判定：%s / %s 音符时刻位置命中结果正确" % [kind, mode])
			_expect_close(target_finger.evaluator._beat, target_finger.beat, "空间判定：目标位置读取不清空当前时刻采样缓存")
			if kind == "hold" and mode == Setting.JUDGE_POSITION_NOTE:
				target_finger.update(1.0, {0: {"x": 0.50, "pressed": false}})
				target_finger.update(1.2, {0: {"x": 0.60, "pressed": false}})
				_expect(target_finger.states[0] == PlaySession.State.HOLDING, "空间判定：Hold 持续阶段跟随当前轨道")
		# 运行中切换也使用同一份预计算位置。
		var switching := PlaySession.new(chart)
		Setting.judge_position_mode = Setting.JUDGE_POSITION_CURRENT
		switching.update(0.94, {0: {"x": 0.50, "pressed": true}})
		Setting.judge_position_mode = Setting.JUDGE_POSITION_NOTE
		switching.update(0.94, {0: {"x": 0.50, "pressed": true}})
		_expect(switching.states[0] != PlaySession.State.PENDING, "空间判定：%s 切换后生效" % kind)
	# 目标时刻的宽度也必须使用目标值，不能混用当前中心/宽度。
	var width_chart := ChartData.new(JSON.stringify({"note": [{"type": "note", "beat": 2}], "event": [
		{"type": "x", "beat": 0, "from": 50, "to": 50},
		{"type": "w", "beat": 0, "beat2": 2, "from": 0, "to": 100}]}))
	Setting.judge_position_mode = Setting.JUDGE_POSITION_CURRENT
	var current_width := PlaySession.new(width_chart)
	current_width.update(0.94, {0: {"x": 0.99, "pressed": true}})
	Setting.judge_position_mode = Setting.JUDGE_POSITION_NOTE
	var target_width := PlaySession.new(width_chart)
	target_width.update(0.94, {0: {"x": 0.99, "pressed": true}})
	_expect(current_width.states[0] == PlaySession.State.PENDING and target_width.states[0] == PlaySession.State.DONE, "空间判定：两种模式各自使用对应时刻的宽度")
	Setting.judge_position_mode = Setting.JUDGE_POSITION_NOTE
	Setting.save_settings()
	Setting.judge_position_mode = Setting.JUDGE_POSITION_CURRENT
	Setting.load_settings()
	_expect(Setting.judge_position_mode == Setting.JUDGE_POSITION_NOTE, "设置：判定模式可保存并读回")
	var config := ConfigFile.new()
	config.load(Setting.SETTINGS_PATH)
	config.set_value("game", "judge_position_mode", "invalid")
	config.save(Setting.SETTINGS_PATH)
	Setting.load_settings()
	_expect(Setting.judge_position_mode == Setting.JUDGE_POSITION_CURRENT, "设置：未知判定模式回退当前时刻")
	config.erase_section_key("game", "judge_position_mode")
	config.save(Setting.SETTINGS_PATH)
	Setting.load_settings()
	_expect(Setting.judge_position_mode == Setting.JUDGE_POSITION_CURRENT, "设置：旧配置默认当前时刻模式")
	Setting.judge_position_mode = original_mode
	Setting.save_settings()

func _check_curve_fast_path() -> void:
	var curves := [[0.15, 0.85, 0.3, 1.0], [0, 0, 1, 1], [0.8, -0.4, 0.2, 1.8], [0, 1, 0, 1], [1, 0, 1, 0]]
	var largest := 0.0
	for curve in curves:
		var points: Array[Vector2] = [Vector2.ZERO, Vector2(curve[0], curve[1]), Vector2(curve[2], curve[3]), Vector2.ONE]
		for index in 201:
			var progress := float(index) / 200.0
			var low := 0.0
			var high := 1.0
			var mid := 0.5
			while high - low > 0.005:
				mid = (low + high) / 2.0
				var x: float = Bezier.evaluate(points, mid).x
				if x < progress:
					low = mid
				elif x > progress:
					high = mid
				else:
					break
			var expected: float = progress if index in [0, 200] else Bezier.evaluate(points, mid).y
			largest = maxf(largest, absf(Bezier.bezier(0, 1, 0, 1, curve, progress) - expected))
	_expect(largest < 0.00001, "性能：三阶曲线与原算法一致（最大偏差 %.8f）" % largest)
	_expect(absf(Bezier.bezier(0, 1, 0, 1, [0.2, 0.2, 0.4, 0.4, 0.8, 0.8], 0.5) - 0.5) <= 0.005, "性能：高阶贝塞尔保留通用路径和原精度")
	Skins.prepare_gameplay()
	_expect(Skins._players.size() == Skins.SOUND_POOL_SIZE and Skins._streams.size() >= 3, "性能：游玩前完成音效池和声音预热")


class OverflowProbe:
	extends Playfield
	func draw_field(canvas: CanvasItem) -> void:
		var row := geometry.size.y * 0.25
		var u := geometry.row_offset_for_screen(row)
		var k := geometry.row_scale(u)
		var height := float(Setting.layout.note_height) * geometry.pixel_scale
		for screen_ratio in [0.04, 0.96]:
			var field_x: float = geometry.size.x * 0.5 + (screen_ratio - 0.5) * geometry.size.x / k
			var x := geometry.normalized_x(Vector2(field_x, 0))
			_draw_note(canvas, "tap", x, 0.2, geometry.judge_y - u + height * 0.5, 0)

func _check_note_overflow() -> void:
	_expect(Storage.PUBLIC_CANDIDATES == ["/storage/emulated/0/data/dakumi"], "存储：新文件只写入 data 公有目录")
	if DisplayServer.get_name() == "headless":
		return
	Setting.reset_layout()
	var white := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var old_texture: Dictionary = Skins._textures.get("note_tap", {}).duplicate()
	Skins._textures["note_tap"] = {"path": Setting.get_skin("note_tap").path, "texture": ImageTexture.create_from_image(white)}
	var probe := OverflowProbe.new()
	add_child(probe)
	probe.configure(get_viewport().get_visible_rect().size)
	for angle in [0.0, 30.0, 70.0]:
		Setting.set_layout("track_angle", angle)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		var transform := get_viewport().get_final_transform()
		for side in [0.04, 0.96]:
			var pixel := transform * Vector2(probe.geometry.size.x * side, probe.geometry.size.y * 0.25)
			var color := screenshot.get_pixel(clampi(roundi(pixel.x), 0, screenshot.get_width() - 1), clampi(roundi(pixel.y), 0, screenshot.get_height() - 1))
			_expect(color.r > 0.8, "Note：倾斜 %.0f° 时区域外 %.0f%% 处仍可见" % [angle, side * 100])
	probe.queue_free()
	await get_tree().process_frame
	if old_texture.is_empty():
		Skins._textures.erase("note_tap")
	else:
		Skins._textures["note_tap"] = old_texture
	Setting.reset_layout()


func _check_judge_layout() -> void:
	Setting.reset_layout()
	var field := Playfield.new()
	field.configure(Vector2(1600, 900))
	_expect(field.judge_positions(252) == PackedVector2Array([Vector2(800, 252)]), "判定布局：旧配置默认单个居中")
	Setting.set_layout("judge_x", 0.3)
	_expect(field.judge_positions(252) == PackedVector2Array([Vector2(480, 252)]), "判定布局：单个横坐标可以调整")
	Setting.set_layout("judge_count", 2)
	_expect(field.judge_positions(252) == PackedVector2Array([Vector2(480, 252), Vector2(1120, 252)]), "判定布局：双个横坐标镜像且纵坐标一致")
	field.configure(Vector2(2400, 1080))
	var positions := field.judge_positions(302.4)
	_expect_close(positions[0].x + positions[1].x, 2400, "判定布局：改变分辨率后仍关于屏幕中心对称")
	Setting.save_settings()
	Setting.reset_layout()
	Setting.load_settings()
	_expect(int(Setting.layout.judge_count) == 2 and is_equal_approx(float(Setting.layout.judge_x), 0.3), "判定布局：数量和横坐标保存后可读回")
	Setting.set_layout("judge_x", -5)
	_expect_close(Setting.layout.judge_x, 0, "判定布局：横坐标下界校验")
	Setting.set_layout("judge_count", 7)
	_expect_close(Setting.layout.judge_count, 2, "判定布局：最多两个")
	field.free()
	Setting.reset_layout()
	Setting.save_settings()


func _check_result_statistics() -> void:
	var chart := ChartData.new(TAP_CHART)
	var session := PlaySession.new(chart)
	session.update(0.5, {0: {"x": 0.5, "pressed": true}})
	session.update(1.0, {0: {"x": 0.5, "pressed": true}})
	session.update(1.5, {0: {"x": 0.5, "pressed": false}})
	session.update(2.2, {})
	_expect(session.max_combo == 3 and session.combo == 0, "结算：Miss 后最大连击保留")
	_expect(session.judgement_counts["just+"] == 3 and session.judgement_counts.miss == 1, "结算：Tap、Hold 头尾、Slide 漏判各计一次")
	session.update(3.0, {})
	_expect(session.judged_units == session.total_units and session.judged_units == 4, "结算：假音符不影响判定数量")
	_expect(session.is_finished(), "结算：谱面全部完成后允许进入结算")
	var result := session.result_summary()
	_expect(result.score == 750000 and result.max_combo == 3, "结算：分数与最大连击快照正确")
	result.counts.miss = 99
	_expect(session.judgement_counts.miss == 1, "结算：统计快照不修改会话")
	var long_hold := PlaySession.new(ChartData.new(JSON.stringify({"note": [
		{"type": "hold", "beat": 1, "beat2": 20}, {"type": "note", "beat": 2}]})))
	long_hold.update(3.0, {})
	_expect(not long_hold.is_finished() and is_equal_approx(long_hold.end_time, 10.0), "结算：较早开始的长 Hold 不导致提前结束")
	var fresh := PlaySession.new(chart)
	_expect(fresh.max_combo == 0 and fresh.judged_units == 0 and fresh.judgement_counts["just+"] == 0, "结算：重开清空本局统计")
	for index in range(4):
		var timed := PlaySession.new(_note_fixture('{"note":[{"beat":2}]}'))
		timed.update(1.0 + [0.0, 0.05, 0.075, 0.095][index], {0: {"x": 0.5, "pressed": true}})
		_expect(timed.judgement_counts[PlaySession.GRADES[index]] == 1, "结算：%s 计数独立" % PlaySession.GRADES[index])

## 分数算法：加算从 0 往上加、减算从满分往下扣，两种算法对同一局判定给出同一个总分。
func _check_score_modes() -> void:
	var original: String = Setting.score_mode
	# 开局数值：加算 0 分起步，减算一上来就是满分。
	var starts: Array[int] = []
	for mode in [Setting.SCORE_ADD, Setting.SCORE_SUB]:
		Setting.score_mode = mode
		Setting.apply_settings()
		starts.append(roundi(PlaySession.new(ChartData.new(TAP_CHART)).score))
	_expect(starts == [0, roundi(PlaySession.SCORE_TOTAL)], "分数：加算 0 分起步、减算满分开局（实际 %s）" % str(starts))
	# 单个音符的谱面：一个计分单位值满分。减算扣的是「丢掉的权重」。
	Setting.score_mode = Setting.SCORE_SUB
	Setting.apply_settings()
	var single := '{"note":[{"beat":2}]}'
	var hit := PlaySession.new(_note_fixture(single))
	hit.update(1.0, {0: {"x": 0.5, "pressed": true}})
	_expect_close(hit.score, PlaySession.SCORE_TOTAL, "分数：减算里 just+（权重 1）不扣分")
	var half := PlaySession.new(_note_fixture(single))
	half.update(1.095, {0: {"x": 0.5, "pressed": true}})
	_expect_close(half.score, PlaySession.SCORE_TOTAL * 0.5, "分数：减算里 ok 扣掉一半权重")
	var gone := PlaySession.new(_note_fixture(single))
	gone.update(2.0, {})
	_expect_close(gone.score, 0.0, "分数：减算里漏判扣光这个单位")
	# 同一串判定在两个模式下各跑一遍：总分必须一模一样（区别只是数字往上还是往下走）。
	var totals: Array[int] = []
	for mode in [Setting.SCORE_ADD, Setting.SCORE_SUB]:
		Setting.score_mode = mode
		Setting.apply_settings()
		var session := PlaySession.new(ChartData.new(TAP_CHART))
		session.update(0.5, {0: {"x": 0.5, "pressed": true}})
		session.update(1.0, {0: {"x": 0.5, "pressed": true}})
		session.update(1.5, {0: {"x": 0.5, "pressed": false}})
		session.update(2.2, {})
		totals.append(session.result_summary().score)
	_expect(totals[0] == totals[1] and totals[0] == 750000, "分数：两种算法总分一致（加算 %d / 减算 %d）" % [totals[0], totals[1]])
	# 非法值回落到加算，存盘能读回。
	Setting.score_mode = "乱填"
	Setting.apply_settings()
	_expect(Setting.score_mode == Setting.SCORE_ADD, "分数：非法算法回落到加算")
	# 设置页预览：显示的分数就是这种算法的开局值，切换算法立刻跟着变（实时预览）。
	var preview_field := Playfield.new()
	Setting.score_mode = Setting.SCORE_SUB
	_expect(preview_field.preview_score_text() == "1000000", "分数：减算的预览从满分起（实际 %s）" % preview_field.preview_score_text())
	Setting.score_mode = Setting.SCORE_ADD
	_expect(preview_field.preview_score_text() == "0000000", "分数：加算的预览从 0 起（实际 %s）" % preview_field.preview_score_text())
	preview_field.free()
	Setting.score_mode = Setting.SCORE_SUB
	Setting.save_settings()
	Setting.load_settings()
	_expect(Setting.score_mode == Setting.SCORE_SUB, "分数：算法存盘后读回")
	Setting.score_mode = original
	Setting.apply_settings()
	Setting.save_settings()


## Hold 尾部打击音：头判与尾判共用 sound_hold 这一个素材，这个开关只管尾判那一声，
## 判定、连击和尾巴那下 Hit 特效都不受影响（见 Playfield.hit_sound_enabled）。
func _check_hit_sound() -> void:
	var original := Setting.hold_tail_sound
	var backup := _read_optional(Setting.SETTINGS_PATH)
	# 旧配置里没有这个键时必须默认开着，否则升级后大家都会少一声。
	var config := ConfigFile.new()
	config.load(Setting.SETTINGS_PATH)
	if config.has_section_key("game", "hold_tail_sound"):
		config.erase_section_key("game", "hold_tail_sound")
	config.save(Setting.SETTINGS_PATH)
	Setting.load_settings()
	_expect(Setting.hold_tail_sound, "尾部打击音：旧配置里没有这个键时默认开启")
	# 手改成非布尔（数字 0 算 false，别的回落到默认开启）。
	config.load(Setting.SETTINGS_PATH)
	config.set_value("game", "hold_tail_sound", 0)
	config.save(Setting.SETTINGS_PATH)
	Setting.load_settings()
	_expect(not Setting.hold_tail_sound, "尾部打击音：配置里的 0 读成关闭")
	config.load(Setting.SETTINGS_PATH)
	config.set_value("game", "hold_tail_sound", "不是布尔")
	config.save(Setting.SETTINGS_PATH)
	Setting.load_settings()
	_expect(Setting.hold_tail_sound, "尾部打击音：非法值回落到开启")
	# 存盘 / 读盘往返。
	Setting.hold_tail_sound = false
	Setting.save_settings()
	Setting.hold_tail_sound = true
	Setting.load_settings()
	_expect(not Setting.hold_tail_sound, "尾部打击音：关掉后可以存盘并读回")
	if backup.is_empty():
		DirAccess.remove_absolute(Setting.SETTINGS_PATH)
	else:
		Storage.write_bytes(Setting.SETTINGS_PATH, backup)
	# 发声判定：只有 Hold 尾判会被挡掉，其余一律出声。
	var field := Playfield.new()
	add_child(field)
	field.configure(Vector2(1600, 900))
	field.attach_session(PlaySession.new(ChartData.new(TAP_CHART)))
	Setting.hold_tail_sound = true
	_expect(field.hit_sound_enabled("hold", "tail"), "尾部打击音：开启时尾判出声")
	Setting.hold_tail_sound = false
	_expect(not field.hit_sound_enabled("hold", "tail"), "尾部打击音：关掉后尾判不出声")
	for other in [["hold", "head"], ["tap", "head"], ["slide", "head"]]:
		_expect(field.hit_sound_enabled(other[0], other[1]), "尾部打击音：%s 的 %s 判定不受影响" % [other[0], other[1]])
	# 静音只针对声音：尾巴那下 Hit 特效照旧进队列（_hits 就是画特效用的）。
	var before := field._hits.size()
	field._on_feedback_ready(1, "just+", "tail")
	_expect(field._hits.size() == before + 1, "尾部打击音：静音后尾判的 Hit 特效照旧出现")
	field.queue_free()
	Setting.load_settings()
	_expect(Setting.hold_tail_sound == original, "尾部打击音：自检结束后恢复到原值")


func _check_result_scene() -> void:
	var original: Dictionary = ChartLoader.last_result
	var art := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	art.fill(FIXTURE_ART)
	ChartLoader.last_result = {"info": {"song_name": "测试曲名", "chart_name": "Master", "artist": "曲师", "chartor": "谱师", "level": "12"},
		"score": 912345, "max_combo": 123, "total_units": 106, "position_mode": Setting.JUDGE_POSITION_CURRENT,
		"counts": {"just+": 80, "just": 20, "good": 3, "ok": 2, "miss": 1},
		"average_offset": -0.0123, "offset_samples": 214,
		"background": ImageTexture.create_from_image(art)}
	# 固定尺寸的宿主：窄屏（内容比屏幕高）与宽屏两种断点都能在无头环境下量到。
	var host := Control.new()
	host.size = Vector2(900, 420)
	add_child(host)
	var scene: PackedScene = load("res://gd/room/results.tscn")
	var result := scene.instantiate()
	host.add_child(result)
	await get_tree().process_frame
	await get_tree().process_frame
	if result.get("_page") == null:
		_expect(false, "结算界面：可以加载")
		host.queue_free()
		ChartLoader.last_result = original
		return
	_expect(result.get("_score").text == "0912345", "结算界面：显示七位分数")
	_expect(result.get("_max_combo").text == "123" and result.get("_title").text == "测试曲名", "结算界面：显示歌曲与最大连击")
	_expect((result.get("_difficulty") as Label).text == "Master · 12", "结算界面：显示难度与等级")
	var credits: Label = result.get("_credits")
	_expect(credits.text.contains("曲师") and credits.text.contains("谱师"), "结算界面：显示曲师与谱师（实际 %s）" % credits.text)
	_expect((result.get("_art") as TextureRect).texture != null, "结算界面：显示歌曲背景图")
	var labels: Dictionary = result.get("_grade_values")
	_expect(labels.size() == 5 and labels["just+"].text == "80" and labels.miss.text == "1", "结算界面：显示全部判定数量")
	_expect((result.get("_grid") as GridContainer).columns == 5, "结算界面：宽屏时五个判定数量横排")
	# 判定数量用游玩内的判定色，Miss 用错误红：两块都要真的落到标签上。
	_expect((labels["just+"] as Label).get_theme_color("font_color") == Skins.GRADE_COLOR
		and (labels.miss as Label).get_theme_color("font_color") == ImGuiTheme.ERROR_TEXT, "结算界面：判定数量沿用游玩内的判定配色")
	# 没有刷新纪录时不挂「新纪录」徽章（last_result 里 is_best 为假或缺失）。
	_expect(_find_tag(result, "result:record", "Label") == null, "结算界面：不是新纪录就不挂徽章")
	# 平均击打延迟：按下 Tap / Hold 的平均偏差，读数和界面共用同一份格式。
	var offset_label := _find_tag(result, "result:average_offset", "Label") as Label
	_expect(offset_label != null, "结算界面：显示平均击打延迟行")
	if offset_label != null:
		_expect(offset_label.text == UI.latency_text(-0.0123, 214),
			"结算界面：平均击打延迟读数（实际 %s / 期望 %s）" % [offset_label.text, UI.latency_text(-0.0123, 214)])
	# 窄屏（内容比屏幕高）时整页可以拖动滚动，安卓上没有别的办法看到下半部分。
	var page: ScrollContainer = result.get("_page")
	var bar := page.get_v_scroll_bar() as ScrollBar
	_expect(bar.max_value > page.size.y, "结算界面：窄屏宿主里内容比页面高（可滚动）")
	if bar.max_value > page.size.y:
		var point := _passive_point(result, page.get_global_rect().grow(-8))
		_push_touch(point, true)
		for step in 4:
			_push_drag(point + Vector2(0, -20.0 * (step + 1)), Vector2(0, -20.0))
		_push_touch(point + Vector2(0, -80.0), false)
		await get_tree().process_frame
		_expect(bar.value > 0.0, "结算界面：拖动可以滚动本页（value = %.0f）" % bar.value)
		_push_wheel(page.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
		await get_tree().process_frame
		_expect(bar.value == 0.0, "结算界面：滚轮向上回到顶部且不越界（value = %.0f）" % bar.value)
	# 竖屏断点：判定数量改成两列，避免挤在一行里。
	host.size = Vector2(420, 780)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect((result.get("_grid") as GridContainer).columns == 2, "结算界面：窄屏时判定数量两列")
	result.queue_free()
	await get_tree().process_frame
	# 刷新纪录时挂上「新纪录！」徽章，用强调色；这一份快照没有按点样本，延迟显示占位符。
	ChartLoader.last_result["is_best"] = true
	ChartLoader.last_result.erase("average_offset")
	ChartLoader.last_result.erase("offset_samples")
	var best_run := scene.instantiate()
	host.add_child(best_run)
	await get_tree().process_frame
	await get_tree().process_frame
	var badge := _find_tag(best_run, "result:record", "Label") as Label
	_expect(badge != null and badge.text == "新纪录！", "结算界面：刷新纪录时显示「新纪录！」")
	_expect(badge != null and badge.get_theme_color("font_color") == UI.Style.ACCENT, "结算界面：新纪录徽章用强调色")
	var blank_offset := _find_tag(best_run, "result:average_offset", "Label") as Label
	_expect(blank_offset != null and blank_offset.text == "—", "结算界面：没有按点样本时延迟显示占位符（实际 %s）" % (blank_offset.text if blank_offset != null else "没有这一行"))
	best_run.queue_free()
	await get_tree().process_frame
	host.queue_free()
	await get_tree().process_frame
	ChartLoader.last_result = original


# ---------------------------------------------------------------- 选曲 / 结算界面像素

## 两个界面的像素核对：整屏铺底、卡片造型、强调色、背景图与判定配色都真的画出来了。
## 只在有渲染帧时跑（headless 跳过），套路与 3D 舞台像素检查一致。
func _check_ui_pixels() -> void:
	if DisplayServer.get_name() == "headless":
		_note("界面像素检查：headless 没有渲染帧，跳过")
		return
	_write_song_fixture(FIXTURE_PIXELS, SONG_CHART, FIXTURE_ART)
	# 先给夹具记一份成绩：过滤之后它会被自动选中，面板上就该出现这些数字。
	Scores.record(FIXTURE_PIXELS, {"score": 654321, "max_combo": 88, "total_units": 100,
		"position_mode": Setting.judge_position_mode,
		"counts": {"just+": 70, "just": 20, "good": 4, "ok": 3, "miss": 3}})
	var select: Control = (load("res://gd/room/startroom.tscn") as PackedScene).instantiate()
	add_child(select)
	await get_tree().process_frame
	await get_tree().process_frame
	# 用搜索框把谱面库过滤到夹具这一条，这样卡片里显示的背景一定是我们写进去的颜色。
	(select.get("_search") as LineEdit).text = "__self_check_pixels"
	select.call("_filter")
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var transform := get_viewport().get_final_transform()
	var scale := absf(transform.get_scale().x * transform.get_scale().y)
	_expect_color(image.get_pixel(2, 2), ImGuiTheme.APP_BG, "选曲：整屏铺 ImGui 的黑色底")
	var art: TextureRect = select.get("_art")
	var art_area := art.get_global_rect().grow(-6.0)
	var art_hits := _region_count(image, transform, art_area, FIXTURE_ART, 0.06)
	_expect(art_hits >= int(art_area.get_area() * scale * 0.9),
		"选曲：卡片里画出谱面背景图（%d / %.0f 像素匹配）" % [art_hits, art_area.get_area() * scale])
	var difficulty: Label = select.get("_difficulty")
	_expect(_region_count(image, transform, difficulty.get_global_rect(), ImGuiTheme.ACCENT, 0.10) >= 5,
		"选曲：难度用的是强调色")
	# 歌曲信息右侧的最佳成绩：七位分数是强调色，Miss 的数量是错误红。
	var score_label: Label = select.get("_score")
	_expect(score_label.text == "0654321", "选曲：最佳成绩显示这一首的最高分（实际 %s）" % score_label.text)
	_expect(_region_count(image, transform, score_label.get_global_rect(), ImGuiTheme.ACCENT, 0.10) >= 20,
		"选曲：最佳成绩的分数用强调色")
	var miss_value: Label = (select.get("_score_values") as Dictionary)["miss"]
	_expect(_region_count(image, transform, miss_value.get_global_rect(), ImGuiTheme.ERROR_TEXT, 0.10) >= 3,
		"选曲：最佳成绩里的 Miss 用错误红")
	# 开始游玩按钮：取按钮上沿（避开中间的文字）量 ImGui 的按钮蓝。
	var play: Button = select.get("_play")
	var play_rect := play.get_global_rect()
	var strip := Rect2(play_rect.position + Vector2(8.0, 6.0), Vector2(play_rect.size.x - 16.0, 10.0))
	var button_fill := ImGuiTheme.BUTTON
	_expect_color(_pixel_of(image, transform, strip.get_center()),
		Color(button_fill.r * button_fill.a, button_fill.g * button_fill.a, button_fill.b * button_fill.a), "选曲：开始游玩按钮用 ImGui 的按钮蓝")
	# 卡片：1px 边框比内部亮，内部是 WindowBg 的深灰；列表底色比卡片再暗一档。
	var panel := (select.get("_song_card") as Control).get_parent() as PanelContainer
	var panel_rect := panel.get_global_rect()
	var probe_x := roundi(panel_rect.get_center().x)
	var edge := roundi(panel_rect.position.y)
	var border := 0.0
	for row in 3:
		border = maxf(border, _pixel_of(image, transform, Vector2(probe_x, edge + row)).r)
	var interior := _pixel_of(image, transform, Vector2(probe_x, edge + 6.0)).r
	_expect(border > interior + 0.05 and interior < 0.12,
		"选曲：卡片是 1px 边框 + WindowBg 底（边框 %.2f / 内部 %.2f）" % [border, interior])
	var list: ItemList = select.find_child("ChartList", true, false)
	# 过滤后只剩一行，列表下半部分就是它自己的底色。
	var list_fill := _pixel_of(image, transform, list.get_global_rect().position + Vector2(30.0, 120.0)).r
	_expect(list_fill < interior - 0.005, "选曲：谱面库底色比卡片更暗（%.3f < %.3f）" % [list_fill, interior])
	select.queue_free()
	await get_tree().process_frame
	_remove_tree(FIXTURE_PIXELS)
	Scores.clear()
	# 结算界面：背景图、分数强调色、判定数量的判定色都要落到画面上。
	var original: Dictionary = ChartLoader.last_result
	var art_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	art_image.fill(FIXTURE_ART)
	ChartLoader.last_result = {"info": {"song_name": "测试曲名", "chart_name": "Master", "artist": "曲师", "chartor": "谱师"},
		"score": 912345, "max_combo": 123, "total_units": 106, "position_mode": Setting.JUDGE_POSITION_CURRENT,
		"counts": {"just+": 80, "just": 20, "good": 3, "ok": 2, "miss": 1},
		"background": ImageTexture.create_from_image(art_image)}
	var results: Control = (load("res://gd/room/results.tscn") as PackedScene).instantiate()
	add_child(results)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	image = get_viewport().get_texture().get_image()
	transform = get_viewport().get_final_transform()
	scale = absf(transform.get_scale().x * transform.get_scale().y)
	_expect_color(image.get_pixel(2, 2), ImGuiTheme.APP_BG, "结算：整屏铺 ImGui 的黑色底")
	var result_art: TextureRect = results.get("_art")
	var result_area := result_art.get_global_rect().grow(-6.0)
	var result_hits := _region_count(image, transform, result_area, FIXTURE_ART, 0.06)
	_expect(result_hits >= int(result_area.get_area() * scale * 0.9),
		"结算：卡片里画出歌曲背景（%d / %.0f 像素匹配）" % [result_hits, result_area.get_area() * scale])
	var score: Label = results.get("_score")
	_expect(_region_count(image, transform, score.get_global_rect(), ImGuiTheme.ACCENT, 0.10) >= 20,
		"结算：分数用强调色")
	var values: Dictionary = results.get("_grade_values")
	_expect(_region_count(image, transform, values["just+"].get_global_rect(), Skins.GRADE_COLOR, 0.10) >= 3,
		"结算：Just+ 数量用游玩内的判定色")
	_expect(_region_count(image, transform, values.miss.get_global_rect(), ImGuiTheme.ERROR_TEXT, 0.10) >= 3,
		"结算：Miss 数量用错误红")
	results.queue_free()
	await get_tree().process_frame
	ChartLoader.last_result = original


## 逻辑坐标处的像素。相机/缩放变换由 get_final_transform 提供，和设备分辨率无关。
func _pixel_of(image: Image, transform: Transform2D, point: Vector2) -> Color:
	var mapped := transform * point
	return image.get_pixel(clampi(roundi(mapped.x), 0, image.get_width() - 1), clampi(roundi(mapped.y), 0, image.get_height() - 1))


## 数一个逻辑区域里接近 expected 的像素个数：文字有抗锯齿，只要求“出现了若干像素”。
func _region_count(image: Image, transform: Transform2D, rect: Rect2, expected: Color, tolerance: float) -> int:
	var top_left := transform * rect.position
	var bottom_right := transform * rect.end
	var left := clampi(floori(minf(top_left.x, bottom_right.x)), 0, image.get_width() - 1)
	var right := clampi(ceili(maxf(top_left.x, bottom_right.x)), 0, image.get_width() - 1)
	var top := clampi(floori(minf(top_left.y, bottom_right.y)), 0, image.get_height() - 1)
	var bottom := clampi(ceili(maxf(top_left.y, bottom_right.y)), 0, image.get_height() - 1)
	var count := 0
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - expected.r) <= tolerance and absf(pixel.g - expected.g) <= tolerance and absf(pixel.b - expected.b) <= tolerance:
				count += 1
	return count


## 判定测试显式配置居中全宽轨道，不依赖运行时捏造无事件轨道。
func _note_fixture(text: String) -> ChartData:
	var data: Dictionary = JSON.parse_string(text)
	data.event = []
	var ids := {}
	for note in data.note:
		ids[int(note.get("track", 1))] = true
	for id in ids:
		data.event.append({"track": id, "type": "x", "beat": 0, "from": 50, "to": 50})
		data.event.append({"track": id, "type": "w", "beat": 0, "from": 100, "to": 100})
	return ChartData.new(JSON.stringify(data))


func _check_love_reference() -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/love_event_reference.json"))
	var evaluator := TrackEvaluator.new(ChartData.new("{}"))
	var same := true
	for example in reference.sort:
		var values := {}
		for i in 4:
			values[TrackEvaluator.TYPES[i]] = Vector2(0, example.ranks[i])
		var pair := evaluator._latest_pair(values)
		same = same and pair == [TrackEvaluator.TYPES[int(example.pair[0])], TrackEvaluator.TYPES[int(example.pair[1])]]
	_expect(same, "LOVE 对照：256 种事件时间组合与真实 LuaJIT 排序取值一致")
	var largest := 0.0
	for example in reference.easings:
		var actual := evaluator._transition({"type": "easings", "easings": int(example.id)}, float(example.t))
		largest = maxf(largest, absf(actual - float(example.value)))
	_expect(largest < 0.00001, "LOVE 对照：全部缓动及端点与编辑器一致（最大偏差 %.8f）" % largest)
	var chart := ChartData.new('{"note":[{"beat":2,"track":1}],"track":{"1":{},"2":{"w0thenShow":1}}}')
	evaluator = TrackEvaluator.new(chart)
	_expect(evaluator.at(1, 1) == Vector2.ZERO and evaluator.sample(1).size() == 1, "LOVE 对照：无事件不生成全宽，纯轨道定义不参与绘制")
	var layers := PlaySession.new(ChartData.new('{"note":[{"beat":4,"track":1},{"beat":5,"track":2}],"track":{"1":{"zindex":10},"2":{"zindex":0}}}'))
	layers.update(0, {})
	_expect(layers.visible_notes_by_layer(3) == [1,0], "Note：先按轨道 zindex 再按拍绘制")
	var field := Playfield.new()
	field.configure(Vector2(1600, 900))
	_expect_close(field.note_width(10.0 / field.geometry.width), 10, "Note：窄轨道宽度不被额外间距吞掉")
	field.free()


class RenderFixProbe:
	extends Playfield
	var lanes_only := false
	func draw_field(canvas: CanvasItem) -> void:
		if lanes_only:
			_draw_session(canvas)
			return
		var positions := [0.14, 0.38, 0.62, 0.86]
		for i in 4:
			var kind: String = ["tap", "slide", "hold", "hold"][i]
			var bottom := geometry.size.y * 0.65
			var tail := bottom - 400 * geometry.pixel_scale if i == 2 else bottom - 1 * geometry.pixel_scale
			_draw_note(canvas, kind, positions[i], 0.18, bottom, tail)

func _check_hold_slices_and_lane_layers() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Setting.reset_layout()
	var originals := {}
	var source := Image.create(64, 24, false, Image.FORMAT_RGBA8)
	source.fill(Color.GREEN)
	source.fill_rect(Rect2i(0,0,8,24), Color.RED)
	source.fill_rect(Rect2i(56,0,8,24), Color.RED)
	var texture := ImageTexture.create_from_image(source)
	for kind in ["tap", "slide", "hold"]:
		var slot: String = "note_" + kind
		originals[slot] = Setting.skin[slot].duplicate(true)
		Setting.skin[slot] = {"path": "", "margin_left": 8, "margin_right": 8, "margin_top": 4, "margin_bottom": 4, "stretch_mode": "center"}
		Skins._textures[slot] = {"path": "", "texture": texture}
	var probe := RenderFixProbe.new()
	add_child(probe)
	probe.configure(get_viewport().get_visible_rect().size)
	for mode in ["center", "sides"]:
		for slot in originals:
			Setting.skin[slot].stretch_mode = mode
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		var transform := get_viewport().get_final_transform()
		var widths: Array[int] = []
		for position in [0.14, 0.38, 0.62, 0.86]:
			var center := transform * Vector2(probe.geometry.x(position), probe.geometry.size.y * 0.65 - 12 * probe.geometry.pixel_scale)
			var row := clampi(roundi(center.y), 0, screenshot.get_height()-1)
			var count := 0
			for x in range(maxi(0, roundi(center.x)-130), mini(screenshot.get_width(), roundi(center.x)+130)):
				var color := screenshot.get_pixel(x,row)
				if color.g > 0.8 and color.r < 0.2:
					count += 1
			widths.append(count)
		_expect(widths[0] > 0 and absi(widths[0]-widths[1]) <= 2 and absi(widths[0]-widths[2]) <= 2 and absi(widths[0]-widths[3]) <= 2,
			"Hold 切片：%s 模式 Tap/Slide/长 Hold/收尾 Hold 的中间宽度一致 %s" % [mode, widths])
	probe.lanes_only = true
	probe.session = PlaySession.new(ChartData.new("{}"))
	probe.session.tracks = [{"x": 0.25, "w": 0.4, "visible": true}, {"x": 0.5, "w": 0.8, "visible": true}]
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	var position := get_viewport().get_final_transform() * Vector2(probe.geometry.x(0.45), probe.geometry.size.y * 0.3)
	var brightest := 0.0
	for x in range(roundi(position.x)-2, roundi(position.x)+3):
		brightest = maxf(brightest, screenshot.get_pixel(x,roundi(position.y)).r)
	_expect(brightest > 0.9, "轨道层级：后绘制的轨道背景不会压暗前一轨道边线")
	probe.queue_free()
	await get_tree().process_frame
	for slot in originals:
		Setting.skin[slot] = originals[slot]
		Skins._textures.erase(slot)
	Setting.reset_layout()
