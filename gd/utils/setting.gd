extends Node
## 只负责配置、校验和变更通知；素材加载与绘制由 Skins 负责。

signal changed

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_VERSION := 13
## 单曲延迟所在的配置节：键是谱面文件夹名，值是毫秒。
const SONG_OFFSET_SECTION := "song_offset"
const JUDGE_POSITION_CURRENT := "current"
const JUDGE_POSITION_NOTE := "note"
## 击打延迟显示支持的选项：与判定文字一模一样，而且就是全部选项（见 Skins.GRADE_SLOTS）。
## 只有命中的判定在这个列表里，元件才会在按下判定时出现 FAST / LATE。
const JUDGE_OFFSET_GRADES: Array[String] = ["just+", "just", "good", "ok", "miss"]
## 默认「判定不为 just+ 时触发」，也就是其余四个都在列表里。
const DEFAULT_JUDGE_OFFSET_GRADES: Array[String] = ["just", "good", "ok", "miss"]
## 最高帧率只认这几个档位；0 表示不限制（交给引擎与屏幕刷新率），也是默认值。
const FPS_CHOICES: Array[int] = [30, 60, 120, 240, 0]
const DEFAULT_MAX_FPS := 0
## 分数算法：加算 = 从 0 一路加到满分（默认），减算 = 从满分一路扣到 0。
## 两种模式对同一局判定给出的总分完全相同，只是 HUD 上的数字往上还是往下走（见 PlaySession）。
const SCORE_ADD := "add"
const SCORE_SUB := "sub"
const SCORE_MODES: Array[String] = [SCORE_ADD, SCORE_SUB]
const DEFAULT_SCORE_MODE := SCORE_ADD
## 时间偏移（音频延迟）的可调范围（毫秒）：超出端点的值一律夹到端点，
## 设置页的数值框与滑条也用这个量程。谱面偏移与单曲延迟不设上下限——
## 谱面自带的 offset 可能远超常用范围，玩家要用单曲延迟把它拉回来。
const OFFSET_LIMIT := 3000.0
const DEFAULT_LAYOUT := {
	"note_height": 24.0,
	# 三种音符与所在轨道之间的横向间隔（布局像素，左右各分一半），各自独立可调。
	"note_gap_tap": 20.0,
	"note_gap_hold": 20.0,
	"note_gap_slide": 20.0,
	"track_angle": 0.0,
	"track_width": 0.8,
	"judge_height": 10.0,
	"judge_y": 0.8,
	"hit_size": 100.0,
	"judge_size": 24.0,
	"judge_count": 1.0,
	"judge_x": 0.5,
	"judge_text_y": 0.28,
	"judge_offset_x": 0.5,
	"judge_offset_y": 0.36,
	"judge_offset_size": 20.0,
	"judge_offset_duration": 0.7,
	"combo_size": 40.0,
	"score_size": 28.0,
	# 判定线图片相对实际判定线的纵向偏移（布局像素）：只挪图片层，判定线本身不动。
	"judge_image_offset": 0.0,
	"approach_curve": 1.0,
	"lane_alpha": 0.5,
	"lane_line_alpha": 1.0,
}
const LAYOUT_RANGES := {
	"note_height": Vector2(4.0, 160.0),
	# 0 = 音符正好铺满轨道；上限给到轨道整宽的量级，够摆出很细的条。
	"note_gap_tap": Vector2(0.0, 400.0),
	"note_gap_hold": Vector2(0.0, 400.0),
	"note_gap_slide": Vector2(0.0, 400.0),
	# 上限与 PlayfieldGeometry 的 MAX_ANGLE_DEGREES 一致：真 3D 透视能承受更大角度。
	"track_angle": Vector2(-45.0, 70.0),
	"track_width": Vector2(0.2, 1.0),
	"judge_height": Vector2(1.0, 80.0),
	"judge_y": Vector2(0.2, 0.95),
	"hit_size": Vector2(8.0, 400.0),
	"judge_size": Vector2(8.0, 200.0),
	"judge_count": Vector2(1.0, 2.0),
	"judge_x": Vector2(0.0, 1.0),
	"judge_text_y": Vector2(0.0, 1.0),
	"judge_offset_x": Vector2(0.0, 1.0),
	"judge_offset_y": Vector2(0.0, 1.0),
	"judge_offset_size": Vector2(8.0, 200.0),
	"judge_offset_duration": Vector2(0.05, 5.0),
	"combo_size": Vector2(8.0, 200.0),
	"score_size": Vector2(8.0, 200.0),
	# 偏移只影响观感：宽一点没关系（高倾角下画布被放大，布局像素也跟着放大）。
	"judge_image_offset": Vector2(-300.0, 300.0),
	"approach_curve": Vector2(0.25, 4.0),
	"lane_alpha": Vector2(0.0, 1.0),
	"lane_line_alpha": Vector2(0.0, 1.0),
}
## 单图打击特效“从 0 放大到当前大小”的三阶贝塞尔： [x1, y1, x2, y2]，
## x 是进度（0~1）、y 是缩放倍率（1 表示当前大小，可以大于 1 做一点回弹）。
const DEFAULT_HIT_CURVE := [0.15, 0.85, 0.3, 1.0]
const SKIN_SLOTS := [
	"note_tap", "note_hold", "note_slide", "judge_line",
	"hit_tap", "hit_hold", "hit_slide",
	"digit_0", "digit_1", "digit_2", "digit_3", "digit_4",
	"digit_5", "digit_6", "digit_7", "digit_8", "digit_9",
	# 判定反馈：默认绘制文字，导入图片后改画图片（见 Skins.draw_grade）。
	"judge_just_plus", "judge_just", "judge_good", "judge_ok", "judge_miss",
	# 击打延迟显示：按早了 fast、按晚了 late，同样可以先文字后换图片。
	"judge_fast", "judge_late",
	"exit", "restart", "sound_tap", "sound_hold", "sound_slide",
]

# 保留旧界面及谱面加载器使用的字段。
var master_volume: float = 0.8
var music_volume: float = 0.7
var hit_volume: float = 0.8
var speed: float = 7.0
## 时间偏移（音频延迟，毫秒）：可调范围是 ±OFFSET_LIMIT（见常量）。
var offset: float = 0.0
## 谱面偏移（毫秒）：和「时间偏移」同一个相对位移的反方向写法——谱面偏移 +100
## 与时间偏移 -100 完全等效，最终延迟里是被减掉的一项（见 ChartLoader.total_offset_seconds）。
var chart_offset: float = 0.0
## 单曲延迟（毫秒）：键是谱面文件夹名，值是玩家给这一首歌单独调出来的偏移。
## 最终延迟 = 单曲延迟 + 时间偏移 - 谱面偏移 + 谱面自带 offset，见 ChartLoader.total_offset_seconds。
var song_offsets: Dictionary = {}
var show_fps: bool = false
## Hold 尾部打击音：关掉后 Hold 只在头判响一声，尾判不再出声（头判照旧）。
## 尾判用的仍是 sound_hold 这一个素材，这里只是个开关，不开新槽位（见 Playfield._on_feedback_ready）。
var hold_tail_sound: bool = true
## 最高帧率（帧/秒），0 表示不限制；只接受 FPS_CHOICES 里的档位。
var max_fps: int = DEFAULT_MAX_FPS
## 分数算法（加算 / 减算）：只接受 SCORE_MODES 里的值，见 PlaySession 的计分。
var score_mode: String = DEFAULT_SCORE_MODE
var judge_position_mode: String = JUDGE_POSITION_CURRENT
## 击打延迟显示在哪些判定上出现。选项就是判定文字本身（全部五个），默认除了 just+ 都显示。
var judge_offset_grades: Array[String] = DEFAULT_JUDGE_OFFSET_GRADES.duplicate()
# 谱面库位置由 Storage 服务决定（公有目录或私有目录），设置不保存路径，
# 避免旧配置指向已经失去权限的目录。
var layout: Dictionary = DEFAULT_LAYOUT.duplicate(true)
var skin: Dictionary = _default_skin()


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	master_volume = _number(config.get_value("audio", "master_volume", 0.8), 0.8, 0.0, 1.0)
	music_volume = _number(config.get_value("audio", "music_volume", 0.7), 0.7, 0.0, 1.0)
	hit_volume = _number(config.get_value("audio", "hit_volume", 0.8), 0.8, 0.0, 1.0)
	speed = _number(config.get_value("game", "speed", 7.0), 7.0, 1.0, 30.0)
	# 音频延迟限死在 ±OFFSET_LIMIT：手改配置或旧版本留下的越界值读回来也夹到端点。
	offset = _number(config.get_value("game", "offset", 0.0), 0.0, -OFFSET_LIMIT, OFFSET_LIMIT)
	# 谱面偏移同样不设上下限，只是正负与音频延迟相反（见 total_offset_seconds）。
	chart_offset = _unbounded_number(config.get_value("game", "chart_offset", 0.0), 0.0)
	song_offsets.clear()
	if config.has_section(SONG_OFFSET_SECTION):
		for folder: String in config.get_section_keys(SONG_OFFSET_SECTION):
			var key := song_key(folder)
			var value := _unbounded_number(config.get_value(SONG_OFFSET_SECTION, folder, 0.0), 0.0)
			if not key.is_empty() and value != 0.0:
				song_offsets[key] = value
	show_fps = _boolean(config.get_value("game", "show_fps", false), false)
	hold_tail_sound = _boolean(config.get_value("game", "hold_tail_sound", true), true)
	max_fps = _fps(config.get_value("game", "max_fps", DEFAULT_MAX_FPS), DEFAULT_MAX_FPS)
	var saved_score_mode: Variant = config.get_value("game", "score_mode", DEFAULT_SCORE_MODE)
	score_mode = saved_score_mode if saved_score_mode in SCORE_MODES else DEFAULT_SCORE_MODE
	var saved_mode: Variant = config.get_value("game", "judge_position_mode", JUDGE_POSITION_CURRENT)
	judge_position_mode = saved_mode if saved_mode in [JUDGE_POSITION_CURRENT, JUDGE_POSITION_NOTE] else JUDGE_POSITION_CURRENT
	judge_offset_grades = _grades(config.get_value("game", "judge_offset_grades", DEFAULT_JUDGE_OFFSET_GRADES), DEFAULT_JUDGE_OFFSET_GRADES)
	layout = DEFAULT_LAYOUT.duplicate(true)
	for key: String in DEFAULT_LAYOUT:
		var limits: Vector2 = LAYOUT_RANGES[key]
		layout[key] = _number(config.get_value("layout", key, DEFAULT_LAYOUT[key]), DEFAULT_LAYOUT[key], limits.x, limits.y)
	layout.judge_count = roundf(layout.judge_count)
	skin = _default_skin()
	# 每个槽位递归补全，更新版本后旧配置无需重建，扩展字段仍可保留。
	if config.has_section("skin"):
		for slot: String in config.get_section_keys("skin"):
			var candidate: Variant = config.get_value("skin", slot)
			if candidate is Dictionary:
				skin[slot] = _normalize_skin(slot, candidate)
	apply_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	# 保留其他模块写入的配置节，升级不会抹掉扩展设置。
	config.load(SETTINGS_PATH)
	config.set_value("meta", "version", SETTINGS_VERSION)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "hit_volume", hit_volume)
	config.set_value("game", "speed", speed)
	config.set_value("game", "offset", offset)
	config.set_value("game", "chart_offset", chart_offset)
	# 单曲延迟整节重写：谱面删掉、延迟归零后这里不会留下旧键。
	# erase_section 对不存在的节会打引擎错误，所以先问一句再删。
	if config.has_section(SONG_OFFSET_SECTION):
		config.erase_section(SONG_OFFSET_SECTION)
	for folder: String in song_offsets:
		config.set_value(SONG_OFFSET_SECTION, folder, song_offsets[folder])
	config.set_value("game", "show_fps", show_fps)
	config.set_value("game", "hold_tail_sound", hold_tail_sound)
	config.set_value("game", "max_fps", max_fps)
	config.set_value("game", "score_mode", score_mode)
	config.set_value("game", "judge_position_mode", judge_position_mode)
	config.set_value("game", "judge_offset_grades", judge_offset_grades.duplicate())
	# 布局节按当前键集重写：删掉某个布局项后，旧配置里不会留下没人再读的键。
	# erase_section_key / get_section_keys 对不存在的节或键会打引擎错误，所以先问一句。
	if config.has_section("layout"):
		for key: String in config.get_section_keys("layout"):
			if not DEFAULT_LAYOUT.has(key):
				config.erase_section_key("layout", key)
	for key: String in layout:
		config.set_value("layout", key, layout[key])
	for slot: String in skin:
		config.set_value("skin", slot, skin[slot])
	var result := config.save(SETTINGS_PATH)
	if result != OK:
		push_warning("设置保存失败，错误码：%s" % result)
	apply_settings()


func apply_settings() -> void:
	master_volume = _number(master_volume, 0.8, 0.0, 1.0)
	music_volume = _number(music_volume, 0.7, 0.0, 1.0)
	hit_volume = _number(hit_volume, 0.8, 0.0, 1.0)
	speed = _number(speed, 7.0, 1.0, 30.0)
	offset = _number(offset, 0.0, -OFFSET_LIMIT, OFFSET_LIMIT)
	chart_offset = _unbounded_number(chart_offset, 0.0)
	hold_tail_sound = _boolean(hold_tail_sound, true)
	max_fps = _fps(max_fps, DEFAULT_MAX_FPS)
	if score_mode not in SCORE_MODES:
		score_mode = DEFAULT_SCORE_MODE
	if judge_position_mode not in [JUDGE_POSITION_CURRENT, JUDGE_POSITION_NOTE]:
		judge_position_mode = JUDGE_POSITION_CURRENT
	judge_offset_grades = _grades(judge_offset_grades, DEFAULT_JUDGE_OFFSET_GRADES)
	_apply_bus("Master", master_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("Hit", hit_volume)
	# 最高帧率立即生效：0 表示不限制，其余按档位限制渲染频率。
	Engine.max_fps = max_fps
	changed.emit()


func set_layout(key: String, value: Variant) -> void:
	if not DEFAULT_LAYOUT.has(key):
		return
	var limits: Vector2 = LAYOUT_RANGES[key]
	var validated := _number(value, DEFAULT_LAYOUT[key], limits.x, limits.y)
	if key == "judge_count":
		validated = roundf(validated)
	if layout.get(key) == validated:
		return
	layout[key] = validated
	# 实时预览只通知内存变更；由设置界面在合适时机统一保存。
	changed.emit()


func reset_layout() -> void:
	layout = DEFAULT_LAYOUT.duplicate(true)
	changed.emit()


## 谱面在设置里的身份：文件夹名。用名字而不是完整路径，换存储根目录（公有 ↔ 私有）
## 或换设备后同一首歌还能对上同一条单曲延迟。结尾斜杠、反斜杠、URL 编码都算同一首歌。
static func song_key(folder: String) -> String:
	var normalized := folder.strip_edges().replace("\\", "/").rstrip("/")
	if normalized.is_empty():
		return ""
	# SAF 的文件夹是 tree_uri#相对路径，身份在 # 之后；普通路径的 # 只是后缀，砍掉。
	var relative := normalized.get_slice("#", 1) if normalized.begins_with("content://") else ""
	var name := relative if not relative.is_empty() else normalized.get_slice("#", 0)
	return name.uri_decode().get_file()


## 某首歌的单曲延迟（毫秒）；没调过就是 0。
func song_offset_of(folder: String) -> float:
	var key := song_key(folder)
	return float(song_offsets.get(key, 0.0)) if not key.is_empty() else 0.0


## 最高帧率：档位以外的值一律忽略，改完立即生效（Engine.max_fps）。
func set_max_fps(value: Variant) -> void:
	var fps := _fps(value, -1)
	if fps < 0 or fps == max_fps:
		return
	max_fps = fps
	apply_settings()


# ---------------------------------------------------------------- 击打延迟显示

## 这个判定要不要显示击打延迟（元件触发条件之一）。
func judge_offset_enabled(grade: String) -> bool:
	return grade in judge_offset_grades


## 勾选 / 取消一个判定。选项就是判定文字本身（JUDGE_OFFSET_GRADES），
## 其他名字一律忽略，列表始终按判定文字的顺序排列。
func set_judge_offset_grade(grade: String, enabled: bool) -> void:
	if not JUDGE_OFFSET_GRADES.has(grade) or judge_offset_enabled(grade) == enabled:
		return
	var next := judge_offset_grades.duplicate()
	if enabled:
		next.append(grade)
	else:
		next.erase(grade)
	judge_offset_grades = _grades(next, DEFAULT_JUDGE_OFFSET_GRADES)
	changed.emit()


## 判定名单：只认判定文字里的那五个名字，去重并按判定的顺序排列（空列表是合法值：都不显示）。
static func _grades(value: Variant, fallback: Array[String]) -> Array[String]:
	if not (value is Array):
		return fallback.duplicate()
	var result: Array[String] = []
	for grade in JUDGE_OFFSET_GRADES:
		if grade in value:
			result.append(grade)
	return result


## 写单曲延迟：和时间偏移一样不设上下限，只拒绝无法参与运算的输入；
## 归零就把这个键删掉，配置文件里不留没用的 0。
func set_song_offset(folder: String, value: Variant) -> void:
	var key := song_key(folder)
	if key.is_empty():
		return
	var validated := _unbounded_number(value, 0.0)
	if song_offset_of(key) == validated:
		return
	if validated == 0.0:
		song_offsets.erase(key)
	else:
		song_offsets[key] = validated
	changed.emit()


func get_skin(slot: String) -> Dictionary:
	# 返回只读使用的视图，绘制热路径不重复复制字典。
	if not skin.has(slot):
		skin[slot] = _default_slot(slot)
	return skin[slot]


func set_skin_field(slot: String, key: String, value: Variant) -> void:
	var candidate := get_skin(slot).duplicate(true)
	candidate[key] = value
	var validated := _normalize_skin(slot, candidate)
	if validated == skin[slot]:
		return
	skin[slot] = validated
	changed.emit()


func reset_skin(slot: String) -> void:
	skin[slot] = _default_slot(slot)
	changed.emit()


func _apply_bus(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.000001)))
	AudioServer.set_bus_mute(index, volume <= 0.0)


static func _default_skin() -> Dictionary:
	var result := {}
	for slot: String in SKIN_SLOTS:
		result[slot] = _default_slot(slot)
	return result


static func _default_slot(slot: String) -> Dictionary:
	var result := {"path": ""}
	if slot.begins_with("note_") or slot == "judge_line":
		result.merge({"margin_left": 0.0, "margin_right": 0.0, "margin_top": 0.0, "margin_bottom": 0.0, "stretch_mode": "center"})
	if slot.begins_with("hit_"):
		result.merge({"duration": 0.3, "frames": 1, "frame_duration": 0.05, "rows": 1, "columns": 1, "start_frame": 0, "loop_hold": false,
			"scale_curve": DEFAULT_HIT_CURVE.duplicate()})
	if slot.begins_with("sound_"):
		result["volume"] = 1.0
	return result


static func _normalize_skin(slot: String, candidate: Dictionary) -> Dictionary:
	var result := _fill_missing(candidate, _default_slot(slot))
	if not result.get("path") is String:
		result["path"] = ""
	if slot.begins_with("note_") or slot == "judge_line":
		for key: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			result[key] = _number(result[key], 0.0, 0.0, 16384.0)
		if result["stretch_mode"] not in ["center", "sides"]:
			result["stretch_mode"] = "center"
	if slot.begins_with("hit_"):
		result["duration"] = _number(result["duration"], 0.3, 0.016, 10.0)
		result["frame_duration"] = _number(result["frame_duration"], 0.05, 0.001, 5.0)
		result["rows"] = int(_number(result["rows"], 1, 1, 256))
		result["columns"] = int(_number(result["columns"], 1, 1, 256))
		var total := int(result["rows"]) * int(result["columns"])
		result["start_frame"] = int(_number(result["start_frame"], 0, 0, total - 1))
		result["frames"] = int(_number(result["frames"], 1, 1, total - int(result["start_frame"])))
		result["loop_hold"] = _boolean(result["loop_hold"], false)
		result["scale_curve"] = _curve(result["scale_curve"])
	if slot.begins_with("sound_"):
		result["volume"] = _number(result["volume"], 1.0, 0.0, 1.0)
	return result


static func _fill_missing(candidate: Dictionary, defaults: Dictionary) -> Dictionary:
	var result := candidate.duplicate(true)
	for key: Variant in defaults:
		if not result.has(key):
			result[key] = defaults[key]
		elif defaults[key] is Dictionary:
			result[key] = _fill_missing(result[key] if result[key] is Dictionary else {}, defaults[key])
	return result


static func _number(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if value is not int and value is not float:
		return fallback
	var number := float(value)
	return clampf(number, minimum, maximum) if is_finite(number) else fallback


## 不设上下限的数值（谱面偏移、单曲延迟专用）：只拒绝无法参与运算的输入，
## 大小由玩家决定——谱面自带的 offset 可能远超常用范围，得靠这两个值去对齐。
## 时间偏移有范围（见 OFFSET_LIMIT），别用它。
static func _unbounded_number(value: Variant, fallback: float) -> float:
	if value is not int and value is not float:
		return fallback
	var number := float(value)
	return number if is_finite(number) else fallback


## 最高帧率档位：配置里存的是档位本身，读到别的一律回落到默认档。
static func _fps(value: Variant, fallback: int) -> int:
	if value is not int and value is not float:
		return fallback
	var number := float(value)
	if not is_finite(number) or absf(number) > 100000.0:
		return fallback
	var rounded := roundi(number)
	return rounded if FPS_CHOICES.has(rounded) else fallback


## 打击缩放曲线：x 落在 0~1（进度），y 落在 0~2（倍率，允许大于 1 的回弹）。
static func _curve(value: Variant) -> Array:
	if not (value is Array) or value.size() != 4:
		return DEFAULT_HIT_CURVE.duplicate()
	var result: Array = []
	for index in 4:
		var number: Variant = value[index]
		if not (number is int or number is float):
			return DEFAULT_HIT_CURVE.duplicate()
		var normalized := float(number)
		if not is_finite(normalized):
			return DEFAULT_HIT_CURVE.duplicate()
		result.append(clampf(normalized, 0.0, 1.0) if index % 2 == 0 else clampf(normalized, 0.0, 2.0))
	return result


static func _boolean(value: Variant, fallback: bool) -> bool:
	if value is bool:
		return value
	if value is int and value in [0, 1]:
		return bool(value)
	return fallback
