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
	for stored: String in config.get_section_keys(SECTION):
		var key := Setting.song_key(stored)
		# 一个文件夹里有多张谱面时，键是「文件夹#谱面」；song_key 会把 # 之后当 SAF 相对路径砍掉，
		# 这里把谱面那半截补回来（SAF 路径的 # 在 song_key 里已经单独处理过，不会走到这里）。
		# 只在真的带 # 时才补：get_slice 越界会原样返回整串，拿它判断会把「自检曲目」拼成「自检曲目#自检曲目」。
		var chart := ""
		if not stored.begins_with("content://") and stored.get_slice_count("#") > 1:
			chart = stored.get_slice("#", 1).to_lower()
		if not chart.is_empty():
			key += "#" + chart
		var entry := _normalize(config.get_value(SECTION, stored, {}))
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


## 成绩在成绩册里的键。只有一张谱面的文件夹沿用文件夹名——这次改动之前记的成绩都在那个键上，
## 仍然读得出来；一个文件夹里有多张谱面时按「文件夹#谱面」分开记，各难度不再互相覆盖。
## chart_count 由调用方给出（它知道这个文件夹里有几张谱面，见 ChartLoader.charts）。
func key_of(folder: String, chart: String = "", chart_count: int = 0) -> String:
	var base := Setting.song_key(folder)
	if base.is_empty():
		return ""
	var stem := Setting.chart_key(chart)
	if stem.is_empty():
		return base
	return base + "#" + stem if chart_count > 1 or _scoped(base) else base


## 这个文件夹已经在按谱面分记成绩了吗（成绩册里有它的「文件夹#谱面」键）。
## 删掉一张谱面后文件夹里只剩一张，剩下的成绩还留在原来那张谱面的键上，不能被当成整首歌的成绩。
func _scoped(base: String) -> bool:
	var prefix := base + "#"
	for key: String in scores:
		if key.begins_with(prefix):
			return true
	return false


## 某首歌（或其中一张谱面）的最好成绩；没有就是空字典，界面据此显示占位符。
func best(folder: String, chart: String = "", chart_count: int = 0) -> Dictionary:
	var key := key_of(folder, chart, chart_count)
	return scores.get(key, {}) if not key.is_empty() else {}


func plays(folder: String, chart: String = "", chart_count: int = 0) -> int:
	return int(best(folder, chart, chart_count).get("plays", 0))


## 记录一局：无论好坏都算一次游玩，只有分数更高才替换成绩快照。
## 返回 true 表示刷新了最高分，结算界面据此显示「新纪录」。
func record(folder: String, result: Dictionary, chart: String = "", chart_count: int = 0) -> bool:
	var key := key_of(folder, chart, chart_count)
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


## 删掉一张谱面的成绩（删谱面时调用）。文件夹里只剩一张谱面时成绩记在文件夹名上，
## 那一条由 forget_song 处理——删掉最后一张谱面就等于删掉了整首歌。
func forget_chart(folder: String, chart: String) -> bool:
	var base := Setting.song_key(folder)
	var stem := Setting.chart_key(chart)
	return _erase(base + "#" + stem) if not base.is_empty() and not stem.is_empty() else false


## 删掉整首歌的成绩：文件夹名那一键，以及按谱面分记的所有键。
func forget_song(folder: String) -> bool:
	var base := Setting.song_key(folder)
	if base.is_empty():
		return false
	var prefix := base + "#"
	var removed := false
	for key: String in scores.keys():
		if key == base or key.begins_with(prefix):
			scores.erase(key)
			removed = true
	if not removed:
		return false
	save_scores()
	score_changed.emit(base)
	return true


## 清空整本成绩（目前只有自检用；界面里没有入口）。
func clear() -> void:
	scores.clear()
	save_scores()
	score_changed.emit("")


func _erase(key: String) -> bool:
	if not scores.has(key):
		return false
	scores.erase(key)
	save_scores()
	score_changed.emit(key)
	return true


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
