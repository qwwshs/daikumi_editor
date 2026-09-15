extends RefCounted
## TAKANA³ V1 / V2 / V3 adapter. Can also be installed through the external-reader UI.
## Coordinates: TAKANA stage width = 9, origin at the centre; source times are ms.
var last_error := ""

func can_read(kind: String, path: String, context: DakumiImportContext) -> bool:
	if kind != "chart" or not path.to_lower().ends_with(".json"):
		return false
	return recognizes(JSON.parse_string(context.read_text(path)))

static func recognizes(value: Variant) -> bool:
	if not value is Dictionary or not value.get("components") is Array or value.has("note"):
		return false
	return int(value.get("version", 1)) in [1, 2, 3]

func read_chart(path: String, context: DakumiImportContext) -> Variant:
	var result := convert_chart(JSON.parse_string(context.read_text(path)))
	if not result.is_empty():
		result.info.song_name = path.get_file().get_basename()
		if context.exists("songinfo.yaml"):
			var metadata := simple_yaml(context.read_text("songinfo.yaml"))
			result.info.song_name = localized(metadata.get("title", result.info.song_name))
			result.info.artist = localized(metadata.get("composer", ""))
			var name := path.get_file().to_lower().replace(".editing", "").get_basename()
			var number := ["normal", "hard", "master", "insanity", "ravage"].find(name) + 1
			var difficulty: Variant = metadata.get("difficulties", {}).get(str(number), {})
			if difficulty is Dictionary:
				result.info.chart_name = name.to_upper() + " " + str(difficulty.get("levelDisplay", ""))
				result.info.chartor = localized(difficulty.get("charter", ""))
	return result if not result.is_empty() else {"reader_error": last_error}

func resolve_bundle(context: DakumiImportContext) -> Dictionary:
	var chart := ""
	var music := ""
	var cover := ""
	var config := {}
	var entries := context.list()
	for entry in entries:
		if not entry.is_dir and str(entry.name).ends_with(".t3proj"):
			config = simple_yaml(context.read_text(entry.path))
	for entry in entries:
		if entry.is_dir:
			continue
		var name := str(entry.name)
		if name.get_extension().to_lower() in ["mp3", "ogg", "wav"] and music.is_empty():
			music = entry.path
		if name.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"] and cover.is_empty():
			cover = entry.path
		if chart.is_empty() and can_read("chart", entry.path, context):
			chart = entry.path
	for pair in [["musicFileName", "music"], ["coverFileName", "cover"]]:
		var name := str(config.get(pair[0], ""))
		if not name.is_empty() and context.exists(name):
			if pair[1] == "music": music = context.resolve(name)
			else: cover = context.resolve(name)
	return {"chart": chart, "audio": music, "background": cover} if not chart.is_empty() else {}

static func localized(value: Variant) -> String:
	if value is Dictionary:
		for language in ["zh-Hans", "zh-CN", "zh", "en"]:
			if value.has(language): return str(value[language])
		return str(value.values()[0]) if not value.is_empty() else ""
	return str(value)

## Read only the scalar/mapping subset used by TAKANA metadata (never execute tags).
static func simple_yaml(content: String) -> Dictionary:
	var result := {}
	var stack: Array = [{"indent": -1, "value": result}]
	for raw in content.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#") or not line.contains(":"): continue
		var indent := raw.length() - raw.lstrip(" ").length()
		while stack.size() > 1 and indent <= int(stack[-1].indent): stack.pop_back()
		var split := line.find(":")
		var key := line.substr(0, split).strip_edges().trim_prefix('"').trim_suffix('"')
		var value := line.substr(split + 1).strip_edges()
		if value.is_empty():
			var child := {}
			stack[-1].value[key] = child
			stack.append({"indent": indent, "value": child})
		else:
			stack[-1].value[key] = value.trim_prefix('"').trim_suffix('"').trim_prefix("'").trim_suffix("'")
	return result

static func property_value(properties: Dictionary, key: String, fallback: Variant) -> Variant:
	var value: Variant = properties.get(key, fallback)
	return value.get("value", fallback) if value is Dictionary else value

## TAKANA 的轨道只有位置曲线和 showWhen0，dakumi 的轨道默认值全都不存在。
## 让 ChartData 去逐个补全的话，每张谱面开局都会打印「缺失属性已自动补全（上千项）」，
## 还会把真正缺字段的谱面淹掉，所以这里直接带上 dakumi 的默认值。
static func with_track_defaults(values: Dictionary) -> Dictionary:
	var result: Dictionary = ChartData.TRACK_DEFAULTS.duplicate(true)
	result.merge(values, true)
	return result

func convert_chart(source: Variant) -> Dictionary:
	last_error = ""
	if not recognizes(source):
		last_error = "不是受支持的 TAKANA V1/V2/V3 谱面"
		return {}
	if str(source.get("mode", "t3")) != "t3":
		last_error = "暂不支持 TAKANA 的谱面模式：" + str(source.mode)
		return {}
	# TAKANA 的谱面 offset 与 dakumi 正负号相反：官方 DakumiToTakanaConverter 写回时是
	# SetOffsetInfo(-dakumiChart.Offset)（源码里注明 offset is reversed），本仓库自带的
	# Antithesis 两种格式也正好是 +163 / −163，所以读进来要取负。单位都是毫秒。
	var out := {"version": 1, "mode": "takana", "offset": -float(property_value(source.get("properties", {}), "offset", 0)),
		"bpm_list": [{"beat": 0, "bpm": 60}], "note": [], "event": [], "effect": [],
		"info": {"song_name": "", "chart_name": "", "chartor": "", "artist": "", "mode": "takana"},
		"preference": {"x_offset": 4.5, "event_scale": 9.0}, "track": {}}
	var flat: Array = []
	flatten(source.components, -1, flat, int(source.get("version", 1)))
	var ids := {}
	for component in flat:
		if component.model.get("type", "").trim_prefix("e_") == "track":
			if ids.has(component.id):
				last_error = "TAKANA 轨道 ID 重复"
				return {}
			ids[component.id] = ids.size() + 1
	for component in flat:
		var model: Dictionary = component.model
		var kind := str(model.get("type", "")).trim_prefix("e_")
		var props: Dictionary = model.get("properties", {})
		if bool(property_value(props, "isEditorOnly", false)): continue
		if kind == "track":
			var movement: Dictionary = model.get("movement", {})
			var direct: bool = movement.get("type", "") == "trackDirectMovement"
			var first := movement.get("position" if direct else "left", {}) as Dictionary
			var second := movement.get("width" if direct else "right", {}) as Dictionary
			var data := {"start": float(model.get("timeStart", 0)) / 1000.0,
				"end": float(model.get("timeEnd", 0)) / 1000.0, "direct": direct,
				"fallback": movement.is_empty() or movement.get("type", "") == "trackFallbackMovement",
				"a": parse_positions(first), "b": parse_positions(second)}
			out.track[str(ids[component.id])] = with_track_defaults({"name": component.get("name", ""), "takana": data, "w0thenShow": int(bool(property_value(props, "showWhen0", false)))})
		elif kind in ["hit", "tap", "slide", "hold"]:
			if not ids.has(component.parent):
				last_error = "TAKANA 音符缺少所属轨道：%s" % component.id
				return {}
			var time := float(model.get("timeJudge", 0)) / 1000.0
			var tail := float(model.get("timeEnd", model.get("timeJudge", 0))) / 1000.0
			out.note.append({"type": "Hold" if kind == "hold" else ("Slide" if kind == "slide" or model.get("hitType") == "Slide" else "Tap"),
				"track": ids[component.parent], "beat": time, "beat2": tail,
				"fake": bool(property_value(props, "isDummy", false)),
				"takana_speed": parse_speed(model.get("movement", {})), "takana_tail_speed": parse_speed(model.get("tailMovement", {}))})
		elif kind not in ["line", "judgeLine"]:
			last_error = "不支持的 TAKANA 组件：" + kind
			return {}
	if not last_error.is_empty(): return {}
	return out

func flatten(items: Array, parent: int, result: Array, version: int) -> void:
	for item in items:
		if not item is Dictionary: continue
		var model: Dictionary = item.get("model", {}) if version >= 2 else item
		var runtime_id := result.size() if version >= 2 else int(item.get("id", -1))
		result.append({"id": runtime_id, "model": model, "name": item.get("name", ""),
			"parent": parent if version >= 2 else int(item.get("track", item.get("line", -1)))})
		if item.get("children") is Array: flatten(item.children, runtime_id, result, version)

static func tuple_parts(value: Variant) -> PackedStringArray:
	var s := str(value)
	var start := s.find("(")
	return s.substr(start + 1).trim_suffix(")").split(",")

static func time_key(key: String) -> float:
	return float(key) if key.contains(".") else float(key) / 1000.0

func parse_positions(movement: Dictionary) -> Array:
	var result: Array = []
	var items: Variant = movement.get("list", {})
	if movement.get("type", "position") not in ["position", "v1e"]:
		last_error = "不支持的 TAKANA 轨道运动：" + str(movement.get("type"))
		return []
	if items is Dictionary:
		for key in items:
			var parts := tuple_parts(items[key])
			if parts.size() not in [2, 5]:
				last_error = "无效的 TAKANA 轨道控制点"
				continue
			result.append({"time": time_key(str(key)), "value": float(parts[0]),
				"ease": parts[1].strip_edges() if parts.size() == 2 else "bezier",
				"controls": [float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4])] if parts.size() == 5 else []})
	elif items is Array:
		for entry in items:
			var parts := tuple_parts(entry)
			if parts.size() == 3:
				result.append({"time": time_key(parts[0].strip_edges()), "value": float(parts[1]), "ease": parts[2].strip_edges(), "controls": []})
			else: last_error = "无效的 TAKANA V1 轨道控制点"
	result.sort_custom(func(a, b): return a.time < b.time)
	return result

func parse_speed(movement: Dictionary) -> Array:
	var result: Array = []
	if movement.is_empty(): return result
	if movement.get("type", "baseNoteMoveList") != "baseNoteMoveList":
		last_error = "不支持的 TAKANA 音符运动：" + str(movement.get("type"))
		return result
	var items: Variant = movement.get("list", {})
	if items is Dictionary:
		for key in items:
			result.append({"time": time_key(str(key)), "speed": float(tuple_parts(items[key])[0])})
	result.sort_custom(func(a, b): return a.time < b.time)
	var integral := 0.0
	for i in result.size():
		if i > 0: integral += (result[i].time - result[i-1].time) * result[i-1].speed
		result[i]["integral"] = integral
	return result
