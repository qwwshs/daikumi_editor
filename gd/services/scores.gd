extends Node
## 成绩册：每首歌只留最好的一次成绩，存在 user://scores.cfg。
## 和设置分开存：恢复默认设置不该抹掉成绩，成绩也不会把设置文件撑大。
## 身份是谱面文件夹名（Setting.song_key），换存储根目录（公有 ↔ 私有）后同一首歌的成绩仍然对得上。

signal score_changed(folder: String)

const SCORES_PATH := "user://scores.cfg"
const SECTION := "score"
## 判定从高到低，与游玩、结算界面一致；读盘与记录都按这套键逐个校验。
const GRADES: Array[String] = ["just+", "just", "good", "ok", "miss"]
const MAX_SCORE := 1000000
## 连击数、判定单位数、游玩次数共用的上限：够大，又不会让坏配置算出溢出的整数。
const MAX_UNITS := 1 << 30
## 平均击打延迟的读取范围（秒）：正常按点偏差不到 0.12 秒，留够余量即可。
const MAX_OFFSET := 1.0

## 文件路径留成变量：自检会把它换成临时文件，免得动到玩家真实的成绩。
var file_path: String = SCORES_PATH
## 键是 Setting.song_key 归一化后的文件夹名，值是 _normalize() 整理过的成绩。
var scores: Dictionary = {}


func _ready() -> void:
	load_scores()


func load_scores() -> void:
	scores.clear()
	var config := ConfigFile.new()
	if config.load(file_path) != OK or not config.has_section(SECTION):
		return
	for folder: String in config.get_section_keys(SECTION):
		var key := Setting.song_key(folder)
		var entry := _normalize(config.get_value(SECTION, folder, {}))
		if not key.is_empty() and not entry.is_empty():
			scores[key] = entry


func save_scores() -> void:
	var config := ConfigFile.new()
	# 保留其他模块可能写进这个文件的节；成绩整节重写，删掉的歌不会留下旧成绩。
	config.load(file_path)
	# erase_section 对不存在的节会打引擎错误，所以先问一句再删。
	if config.has_section(SECTION):
		config.erase_section(SECTION)
	for key: String in scores:
		config.set_value(SECTION, key, scores[key])
	var result := config.save(file_path)
	if result != OK:
		push_warning("成绩保存失败，错误码：%s" % result)


## 某首歌的最好成绩；没有就是空字典，界面据此显示占位符。
func best(folder: String) -> Dictionary:
	var key := Setting.song_key(folder)
	return scores.get(key, {}) if not key.is_empty() else {}


func plays(folder: String) -> int:
	return int(best(folder).get("plays", 0))


## 记录一局：无论好坏都算一次游玩，只有分数更高才替换成绩快照。
## 返回 true 表示刷新了最高分，结算界面据此显示「新纪录」。
func record(folder: String, result: Dictionary) -> bool:
	var key := Setting.song_key(folder)
	if key.is_empty() or result.is_empty():
		return false
	var entry: Dictionary = scores.get(key, {}).duplicate(true)
	var previous := int(entry.get("score", -1))
	var score := _int(result.get("score"), 0, 0, MAX_SCORE)
	var is_best := previous < 0 or score > previous
	entry["plays"] = int(entry.get("plays", 0)) + 1
	if is_best:
		entry["score"] = score
		entry["max_combo"] = _int(result.get("max_combo"), 0, 0, MAX_UNITS)
		entry["total_units"] = _int(result.get("total_units"), 0, 0, MAX_UNITS)
		entry["counts"] = _counts(result.get("counts"))
		entry["average_offset"] = _float(result.get("average_offset"), 0.0, -MAX_OFFSET, MAX_OFFSET)
		entry["offset_samples"] = _int(result.get("offset_samples"), 0, 0, MAX_UNITS)
		var mode := str(result.get("position_mode", ""))
		entry["mode"] = mode if mode in [Setting.JUDGE_POSITION_CURRENT, Setting.JUDGE_POSITION_NOTE] else ""
	entry["time"] = int(Time.get_unix_time_from_system())
	scores[key] = entry
	save_scores()
	score_changed.emit(key)
	return is_best


## 清空整本成绩（目前只有自检用；界面里没有入口）。
func clear() -> void:
	scores.clear()
	save_scores()
	score_changed.emit("")


## 读盘 / 记录都走这里：坏值一律丢掉或归零，不让外部数据决定界面显示什么。
## 没有 score 字段的条目直接丢掉——那是配置文件被改坏了，不是一条 0 分成绩。
static func _normalize(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not value.has("score"):
		return {}
	return {
		"score": _int(value.get("score"), 0, 0, MAX_SCORE),
		"max_combo": _int(value.get("max_combo"), 0, 0, MAX_UNITS),
		"total_units": _int(value.get("total_units"), 0, 0, MAX_UNITS),
		"counts": _counts(value.get("counts")),
		"average_offset": _float(value.get("average_offset"), 0.0, -MAX_OFFSET, MAX_OFFSET),
		"offset_samples": _int(value.get("offset_samples"), 0, 0, MAX_UNITS),
		"plays": _int(value.get("plays"), 1, 1, MAX_UNITS),
		"mode": str(value.get("mode", "")),
		"time": _int(value.get("time"), 0, 0, 1 << 40),
	}


static func _counts(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for grade in GRADES:
		result[grade] = _int(source.get(grade), 0, 0, MAX_UNITS)
	return result


static func _int(value: Variant, fallback: int, minimum: int, maximum: int) -> int:
	if value is not int and value is not float:
		return fallback
	var number := float(value)
	if not is_finite(number):
		return fallback
	return clampi(roundi(number), minimum, maximum)


static func _float(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if value is not int and value is not float:
		return fallback
	var number := float(value)
	if not is_finite(number):
		return fallback
	return clampf(number, minimum, maximum)
