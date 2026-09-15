# ChartData.gd
# Runtime representation of the editor chart format.
extends RefCounted
class_name ChartData

const CURRENT_FORMAT_VERSION := 1
const INFO_DEFAULTS := {
	"song_name": "", "chart_name": "", "chartor": "", "artist": ""
}
const PREFERENCE_DEFAULTS := {"x_offset": 0.0, "event_scale": 100.0}
const TRACK_DEFAULTS := {
	"name": "", "w0thenShow": 0, "type": "xw", "parent": 0,
	"scale_with_parent": 0, "zindex": 0,
	"left_boundary": 0, "right_boundary": 0, "boundary_type": "nil",
	"left_reference": "x", "right_reference": "x"
}

var mode: String = "dakumi"
var version: int = CURRENT_FORMAT_VERSION
var bpmlist: Array = []
var note: Array = []
var event: Array = []
var offset: float = 0.0
var effect: Array = []
var info: Dictionary = {
	"song_name": "",
	"chart_name": "",
	"chartor": "",
	"artist": ""
}
var preference: Dictionary = {
	"x_offset": 0.0,
	"event_scale": 100.0
}
var track: Dictionary = {}
var error_message: String = ""
var filled_properties: PackedStringArray = []


func _init(chart_json: String) -> void:
	var json := JSON.new()
	var parse_error := json.parse(chart_json)
	if parse_error != OK:
		error_message = "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()]
		push_error(error_message)
		return
	if not json.data is Dictionary:
		error_message = "Chart root must be a JSON object"
		push_error(error_message)
		return

	var source: Dictionary = json.data
	var reader := preload("res://readers/takana_reader.gd").new()
	if reader.recognizes(source):
		source = reader.convert_chart(source)
		if source.is_empty():
			error_message = reader.last_error
			return
	if source.has("components"):
		error_message = "无法识别的组件谱面版本"
		return
	if source.has("reader_error"):
		error_message = str(source.reader_error)
		return
	mode = str(source.get("mode", "dakumi"))
	if mode not in ["dakumi", "takana"]:
		error_message = "不支持的谱面模式：" + mode
		return
	_record_missing_root_fields(source)
	version = int(source.get("version", CURRENT_FORMAT_VERSION))
	offset = float(source.get("offset", 0.0))
	bpmlist = _duplicate_array(source.get("bpm_list", []))
	note = _duplicate_array(source.get("note", []))
	event = _duplicate_array(source.get("event", []))
	effect = _duplicate_array(source.get("effect", []))
	_fill_named_dictionary(info, source.get("info", {}), INFO_DEFAULTS, "info")
	_fill_named_dictionary(preference, source.get("preference", {}), PREFERENCE_DEFAULTS, "preference")
	preference.x_offset = float(preference.get("x_offset", 0.0))
	preference.event_scale = maxf(absf(float(preference.get("event_scale", 100.0))), 0.000001)
	track = source.get("track", {}).duplicate(true) if source.get("track", {}) is Dictionary else {}

	_normalize_bpm()
	_normalize_events(event)
	_normalize_timed_items(effect)
	_normalize_notes()
	_normalize_tracks()
	version = CURRENT_FORMAT_VERSION
	if not filled_properties.is_empty():
		print("谱面缺失属性已自动补全（%d 项）" % filled_properties.size())


func _duplicate_array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []


func _record_missing_root_fields(source: Dictionary) -> void:
	var defaults := {
		"version": CURRENT_FORMAT_VERSION, "offset": 0.0, "bpm_list": [],
		"note": [], "event": [], "effect": [], "info": {},
		"preference": {}, "track": {}
	}
	for field in defaults:
		if not source.has(field) or source[field] == null:
			filled_properties.append(field)
			source[field] = defaults[field]


func _fill_named_dictionary(target: Dictionary, value: Variant, defaults: Dictionary, path: String) -> void:
	target.clear()
	var source: Dictionary = value if value is Dictionary else {}
	if not value is Dictionary:
		filled_properties.append(path)
	for field in defaults:
		if source.has(field) and source[field] != null:
			target[field] = source[field]
		else:
			target[field] = defaults[field]
			filled_properties.append("%s.%s" % [path, field])
	# Preserve extension fields added by future editor versions.
	for field in source:
		if not target.has(field):
			target[field] = source[field]


func _fill_item_default(item: Dictionary, field: String, default_value: Variant, path: String) -> void:
	if not item.has(field) or item[field] == null:
		item[field] = default_value.duplicate(true) if default_value is Array or default_value is Dictionary else default_value
		filled_properties.append("%s.%s" % [path, field])


func _beat_to_float(value: Variant, fallback: float = 0.0) -> float:
	if value is Array and value.size() >= 3:
		var denominator := _number(value[2], 1.0)
		if is_zero_approx(denominator):
			return fallback
		return _number(value[0], 0.0) + _number(value[1], 0.0) / denominator
	if value is float or value is int:
		return float(value)
	return fallback


## JSON null / 错误字段类型不会进入数值转换；合法的 0 不会被当作缺失。
func _number(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		return float(value) if is_finite(float(value)) else fallback
	if value is String and value.is_valid_float():
		return float(value)
	return fallback


func _normalize_bpm() -> void:
	var normalized: Array = []
	for index in range(bpmlist.size()):
		var raw = bpmlist[index]
		if not raw is Dictionary:
			continue
		var item: Dictionary = raw
		_fill_item_default(item, "beat", [0, 0, 1], "bpm_list[%d]" % index)
		_fill_item_default(item, "bpm", 120.0, "bpm_list[%d]" % index)
		_fill_item_default(item, "linear_ramp", 0, "bpm_list[%d]" % index)
		item.beat = _beat_to_float(item.get("beat", 0.0))
		item.bpm = maxf(_number(item.get("bpm"), 120.0), 0.000001)
		item.linear_ramp = int(item.get("linear_ramp", 0))
		normalized.append(item)
	if normalized.is_empty():
		normalized.append({"beat": 0.0, "bpm": 120.0, "linear_ramp": 0})
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.beat < b.beat)
	bpmlist = normalized


func _normalize_events(items: Array) -> void:
	var normalized: Array = []
	for index in range(items.size()):
		var raw = items[index]
		if not raw is Dictionary:
			continue
		var item: Dictionary = raw
		var path := "event[%d]" % index
		_fill_item_default(item, "beat", [0, 0, 1], path)
		_fill_item_default(item, "beat2", item.beat, path)
		_fill_item_default(item, "track", 1, path)
		_fill_item_default(item, "type", "x", path)
		if not item.has("from") and not item.has("form"):
			_fill_item_default(item, "from", 1.0, path)
		_fill_item_default(item, "to", item.get("from", item.get("form", 1.0)), path)
		_fill_item_default(item, "trans", {"type": "bezier", "trans": [0.0, 0.0, 1.0, 1.0], "easings": 1}, path)
		item.beat = _beat_to_float(item.get("beat", 0.0))
		item.beat2 = _beat_to_float(item.get("beat2", item.beat), item.beat)
		item.track = int(item.get("track", 1))
		item.type = str(item.get("type", "x"))
		# Editor migration: old charts used `form` and a bare bezier array.
		item.from = _number(item.get("from", item.get("form", 1.0)), 1.0)
		item.to = _number(item.get("to"), item.from)
		item.erase("form")
		var raw_trans: Variant = item.get("trans", {})
		if raw_trans is Array:
			item.trans = {"type": "bezier", "trans": raw_trans.duplicate(), "easings": 1}
		elif raw_trans is Dictionary:
			var trans: Dictionary = raw_trans
			_fill_item_default(trans, "type", "bezier", "%s.trans" % path)
			_fill_item_default(trans, "trans", [0.0, 0.0, 1.0, 1.0], "%s.trans" % path)
			_fill_item_default(trans, "easings", 1, "%s.trans" % path)
			trans.type = str(trans.get("type", "bezier"))
			trans.trans = trans.get("trans", [0.0, 0.0, 1.0, 1.0])
			trans.easings = int(trans.get("easings", 1))
			item.trans = trans
		else:
			item.trans = {"type": "bezier", "trans": [0.0, 0.0, 1.0, 1.0], "easings": 1}
		var points: Variant = item.trans.get("trans")
		var valid_points: bool = points is Array
		if valid_points:
			valid_points = points.size() % 2 == 0 and points.size() >= 4
			for point in points:
				if not (point is int or point is float):
					valid_points = false
		if not valid_points:
			item.trans.trans = [0.0, 0.0, 1.0, 1.0]
		normalized.append(item)
	# 同轨同拍按源文件顺序保留，逆向查询才能稳定选中最后一条事件。
	for index in normalized.size():
		normalized[index]._event_order = index
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.beat != b.beat:
			return a.beat < b.beat
		return a._event_order < b._event_order
	)
	for item in normalized:
		item.erase("_event_order")
	items.assign(normalized)


func _normalize_timed_items(items: Array) -> void:
	for index in range(items.size()):
		var raw = items[index]
		if raw is Dictionary:
			_fill_item_default(raw, "beat", [0, 0, 1], "effect[%d]" % index)
			_fill_item_default(raw, "beat2", raw.beat, "effect[%d]" % index)
			raw.beat = _beat_to_float(raw.get("beat", 0.0))
			raw.beat2 = _beat_to_float(raw.get("beat2", raw.beat), raw.beat)


func _normalize_notes() -> void:
	var normalized: Array = []
	for index in range(note.size()):
		var raw = note[index]
		if not raw is Dictionary:
			continue
		var item: Dictionary = raw
		var path := "note[%d]" % index
		_fill_item_default(item, "beat", [0, 0, 1], path)
		_fill_item_default(item, "track", 1, path)
		_fill_item_default(item, "type", "note", path)
		_fill_item_default(item, "fake", 0, path)
		item.beat = _beat_to_float(item.get("beat", 0.0))
		item.beat2 = maxf(item.beat, _beat_to_float(item.get("beat2", item.beat), item.beat))
		item.track = int(item.get("track", 1))
		item.fake = int(item.get("fake", 0))
		var editor_type := str(item.get("type", "note")).to_lower()
		if editor_type == "hold":
			_fill_item_default(item, "beat2", item.beat, path)
			_fill_item_default(item, "note_head", 0, path)
			_fill_item_default(item, "wipe_head", 0, path)
			item.note_head = int(item.get("note_head", 0))
			item.wipe_head = int(item.get("wipe_head", 0))
			if item.note_head == 1:
				normalized.append(_make_head_note(item, "Tap"))
			if item.wipe_head == 1:
				normalized.append(_make_head_note(item, "Slide"))
		item.type = {"note": "Tap", "tap": "Tap", "wipe": "Slide", "slide": "Slide", "hold": "Hold"}.get(editor_type, "Tap")
		normalized.append(item)
	# Godot 的自定义排序不稳定；显式顺序保证附加头在 Hold 本体之前。
	for index in normalized.size():
		normalized[index]._order = index
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.beat != b.beat:
			return a.beat < b.beat
		if a.track != b.track:
			return a.track < b.track
		return a._order < b._order
	)
	for item in normalized:
		item.erase("_order")
	note = normalized


func _normalize_tracks() -> void:
	var normalized: Dictionary = {}
	for raw_key in track:
		var key_text := str(raw_key)
		if not (raw_key is int or key_text.is_valid_int()):
			continue
		var track_id := int(raw_key)
		var item: Dictionary = track[raw_key] if track[raw_key] is Dictionary else {}
		for field in TRACK_DEFAULTS:
			_fill_item_default(item, field, TRACK_DEFAULTS[field], "track.%d" % track_id)
		normalized[str(track_id)] = item
	for item in note:
		_ensure_track(normalized, int(item.track))
	for item in event:
		_ensure_track(normalized, int(item.track))
	track = normalized


func _ensure_track(target: Dictionary, track_id: int) -> void:
	var key := str(track_id)
	if target.has(key):
		return
	target[key] = TRACK_DEFAULTS.duplicate(true)
	filled_properties.append("track.%d" % track_id)


func _make_head_note(hold: Dictionary, runtime_type: String) -> Dictionary:
	return {
		"type": runtime_type,
		"beat": hold.beat,
		"beat2": hold.beat,
		"track": hold.track,
		"fake": hold.fake
	}
