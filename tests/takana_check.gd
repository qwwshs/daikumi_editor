extends Node
const READER = preload("res://readers/takana_reader.gd")
const MOTION = preload("res://gd/gameplay/takana_motion.gd")
var checks := 0
var failed := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		push_error(message)
func _ready() -> void:
	var reader := READER.new()
	var fixture := {"version": 3, "mode": "t3", "properties": {"offset": {"value": 163}}, "components": [
		{"id": 0, "model": {"type": "line"}, "children": [
			{"id": 7, "model": {"type": "track", "timeStart": 200, "timeEnd": 5000,
				"movement": {"type": "trackDirectMovement", "position": {"type": "position", "list": {"0": "v1e_(-2.25, s)", "1000": "v1e_(2.25, u)"}},
				"width": {"type": "position", "list": {"0": "v1e_(2.25, u)"}}}},
			"children": [{"id": 8, "model": {"type": "hit", "timeJudge": 1000}},
				{"id": 9, "model": {"type": "hold", "timeJudge": 2000, "timeEnd": 4000}}]}]}]}
	var converted := reader.convert_chart(fixture)
	check(not converted.is_empty(), "convert v3")
	var chart := ChartData.new(JSON.stringify(converted))
	check(chart.mode == "takana" and chart.offset == -163, "mode and offset sign")
	check(chart.note.size() == 2 and chart.note[1].beat2 == 4, "nested notes and milliseconds")
	var evaluator := TrackEvaluator.new(chart)
	check(evaluator.at(1, 0.5).is_equal_approx(Vector2(0.5, 0.25)), "direct movement and stage width")
	check(not evaluator.sample(0.1)[0].visible and evaluator.sample(0.2)[0].visible and not evaluator.sample(5.01)[0].visible, "track lifetime")
	check(ChartData.new(JSON.stringify(fixture)).mode == "takana", "raw automatic mode detection")
	fixture.mode = "unknown"
	check(reader.convert_chart(fixture).is_empty() and not reader.last_error.is_empty(), "reject unknown gameplay mode")
	var legacy := {"version": 1, "components": [{"id": 0, "type": "judgeLine"}, {"id": 3, "type": "track", "line": 0, "timeStart": 0, "timeEnd": 3000,
		"movement": {"left": {"list": ["(0, -4.5, s)", "1000, -2.25, u)"]}, "right": {"list": ["(0, 0, u)"]}}},
		{"id": 4, "type": "slide", "track": 3, "timeJudge": 1000}]}
	check(reader.convert_chart(legacy).note[0].type == "Slide", "legacy flat hierarchy")
	check(is_equal_approx(MOTION.easing("2i", 0.5), 0.75), "TAKANA reversed ease convention")
	check(is_equal_approx(MOTION.easing("2o", 0.5), 0.25), "TAKANA reversed ease convention 2")
	var speeds := reader.parse_speed({"type": "baseNoteMoveList", "list": {"0": "(1)", "1000": "(2)"}})
	check(is_equal_approx(MOTION.distance(speeds, 0.0, 2.0), 3.0), "piecewise speed integral")
	check(is_equal_approx(MOTION.distance(speeds, 2.0, 2.0), 0.0), "movement anchors at judgement")
	var slide_chart := ChartData.new(JSON.stringify({"note": [{"type": "Slide", "beat": 2, "track": 1}], "event": [
		{"track": 1, "type": "x", "beat": 0.1, "from": 50, "to": 50}, {"track": 1, "type": "w", "beat": 0.1, "from": 10, "to": 10}]}))
	var session := PlaySession.new(slide_chart)
	var feedback: Array = []
	session.feedback_ready.connect(func(i, g, p): feedback.append([i,g,p]))
	session.update(0.98, {1: {"x": 0.8, "previous_x": 0.2, "pressed": false}})
	check(session.states[0] == PlaySession.State.SLIDE_WAITING and feedback.is_empty(), "swept Slide waits for scheduled time")
	session.update(1.01, {})
	check(feedback.size() == 1 and session.states[0] == PlaySession.State.DONE, "Slide feedback exactly once")
	var hold_session := PlaySession.new(chart)
	hold_session.update(2.0, {1: {"x": 0.75, "pressed": true}})
	hold_session.update(3.89, {1: {"x": 0.75, "pressed": false}})
	hold_session.update(3.999, {})
	check(hold_session.states[1] == PlaySession.State.HOLDING, "early Hold release retains visual until tail")
	hold_session.update(4.01, {})
	check(hold_session.states[1] == PlaySession.State.DONE and hold_session.last_grade == "just+", "tail grace completes at tail")
	var paths: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/takana_source_paths.json"))
	# offset 的符号不能只靠夹具：本仓库自带的 Antithesis 在两种格式下各有一份，
	# TAKANA 那份是 +163、dakumi 那份是 −163，读进来必须落在 dakumi 的数字上。
	var author_chart := ChartData.new(FileAccess.get_file_as_string("res://chart/Antithesis/chart.json"))
	for path in paths:
		if not str(path).replace("\\", "/").ends_with("isT3chart/Antithesis/master.json"): continue
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var loaded := ChartData.new(JSON.stringify(reader.convert_chart(source)))
		check(is_equal_approx(loaded.offset, author_chart.offset), "real chart offset sign %f vs %f" % [loaded.offset, author_chart.offset])
	var source_notes := 0
	var sampled_points := 0
	for path in paths:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var data := reader.convert_chart(raw)
		check(not data.is_empty(), "real chart " + str(path) + " " + reader.last_error)
		if data.is_empty(): continue
		var parsed := ChartData.new(JSON.stringify(data))
		# 期望值全部由本测试自己从源 JSON 重算，不读读取器的中间结果。
		var state := {"count": 0, "source": {}, "tracks": {}, "notes": []}
		if int(raw.version) < 2:
			_index_v1_tracks(raw.components, state)
		walk(raw.components, int(raw.version), -1, state)
		check(parsed.note.size() == state.notes.size(), "real chart note count %s (%d vs %d)" % [str(path), parsed.note.size(), state.notes.size()])
		if parsed.note.size() == state.notes.size():
			var actual: Array = []
			for item in parsed.note:
				actual.append("%s|%d|%.3f|%.3f|%d" % [item.type, item.track, item.beat, item.beat2, item.fake])
			actual.sort()
			state.notes.sort()
			check(actual == state.notes, "real chart notes match source " + str(path))
		source_notes += state.notes.size()
		var lanes := TrackEvaluator.new(parsed)
		for id in state.tracks:
			var lane: Dictionary = state.tracks[id]
			if lane.fallback:
				var plain := lanes.at(id, 0.0)
				check(is_equal_approx(plain.x, 0.5) and is_equal_approx(plain.y, 1.0 / 9.0), "real chart fallback track %s" % str(path))
				continue
			for now in _sample_times(lane):
				var value := lanes.at(id, now)
				var left: float = _edge(lane.a, now)
				var right: float = _edge(lane.b, now)
				var expect := Vector2((left + right) * 0.5, absf(right - left)) if not lane.direct else Vector2(left, absf(right))
				expect = Vector2((expect.x + 4.5) / 9.0, expect.y / 9.0)
				check(value.is_equal_approx(expect), "real chart track %s %d @%.3f got %s want %s" % [str(path), id, now, str(value), str(expect)])
				sampled_points += 1
		for now in [0.0, 30.0, 90.0]:
			for lane in lanes.sample(now): check(is_finite(lane.x) and is_finite(lane.w), "finite real track")
	print("TAKANA checks: %d passed, %d failed; %d real source notes, %d sampled control points" % [checks-failed, failed, source_notes, sampled_points])
	get_tree().quit(1 if failed else 0)


## 只按源文件重算一遍：轨道按出现顺序编号（读取器就是这么分配 dakumi 轨道号的），
## 音符记下 类型/轨道号/头判(ms)/尾判(ms)/是否装饰 五项，与转换结果逐项对照。
func walk(items: Array, version: int, parent: int, state: Dictionary) -> void:
	for item in items:
		if not item is Dictionary: continue
		var model: Dictionary = item.get("model", {}) if version >= 2 else item
		var kind := str(model.get("type", "")).trim_prefix("e_")
		var properties: Dictionary = model.get("properties", {})
		var editor_only := bool(_property(properties, "isEditorOnly", false))
		var inner := parent
		if kind == "track":
			state.count += 1
			inner = state.count
			if not editor_only:
				var movement: Dictionary = model.get("movement", {})
				var direct: bool = movement.get("type", "") == "trackDirectMovement"
				state.tracks[inner] = {"direct": direct, "fallback": movement.is_empty() or movement.get("type", "") == "trackFallbackMovement",
					"a": _points(movement.get("position" if direct else "left", {}), version),
					"b": _points(movement.get("width" if direct else "right", {}), version)}
		elif kind in ["hit", "hold", "tap", "slide"] and not editor_only:
			var id := parent if version >= 2 else int(state.source.get(int(item.get("track", -1)), 0))
			state.notes.append("%s|%d|%.3f|%.3f|%d" % [
				"Hold" if kind == "hold" else ("Slide" if kind == "slide" or model.get("hitType") == "Slide" else "Tap"),
				id, float(model.get("timeJudge", 0)) / 1000.0,
				float(model.get("timeEnd", model.get("timeJudge", 0))) / 1000.0,
				int(bool(_property(properties, "isDummy", false)))])
		if item.get("children") is Array:
			walk(item.children, version, inner, state)


## V1 是平铺结构：音符用源文件里的 track 字段指向父轨道，先把源 id 映射到轨道号。
func _index_v1_tracks(items: Array, state: Dictionary) -> void:
	for item in items:
		if item is Dictionary and str(item.get("type", "")).trim_prefix("e_") == "track":
			state.count += 1
			state.source[int(item.get("id", -1))] = state.count


func _property(properties: Dictionary, key: String, fallback: Variant) -> Variant:
	var value: Variant = properties.get(key, fallback)
	return value.get("value", fallback) if value is Dictionary else value


## 控制点列表。V2+ 是「毫秒当键、值是 (位置, 缓动) 元组」的字典，V1 是 (时间, 位置, 缓动) 数组。
func _points(movement: Variant, version: int) -> Array:
	var result: Array = []
	if not movement is Dictionary: return result
	var items: Variant = movement.get("list", {})
	if items is Dictionary:
		for key in items:
			var parts := _tuple(str(items[key]))
			result.append({"time": float(key) / 1000.0, "value": float(parts[0]), "ease": parts[1] if parts.size() > 1 else "u"})
	elif items is Array:
		for entry in items:
			var parts := _tuple(str(entry))
			result.append({"time": float(parts[0]) / 1000.0, "value": float(parts[1]), "ease": parts[2].strip_edges()})
	result.sort_custom(func(a, b): return a.time < b.time)
	return result


func _tuple(text: String) -> PackedStringArray:
	return text.substr(text.find("(") + 1).trim_suffix(")").split(",")


## 控制点处的取值：第一个控制点之前、最后一个控制点之后都保持不变；正好落在控制点上就是它的值；
## 两点之间只有「保持」（缓动 u）能确定。返回 INF 表示这一刻在两条控制点之间插值，测试不猜，跳过。
## 时刻比较必须严格相等：is_equal_approx 认为 103.201 与 103.202 也相等，会把插值当控制点。
func _edge(points: Array, time: float) -> float:
	if points.is_empty(): return INF
	var index := -1
	for i in points.size():
		if float(points[i].time) <= time: index = i
	if index < 0: return float(points[0].value)
	if float(points[index].time) == time or index == points.size() - 1: return float(points[index].value)
	return float(points[index].value) if points[index].ease == "u" else INF


## 每张谱面每根轨道抽 40 个能确定取值的时刻；全部 44 万个控制点逐个跑太慢。
func _sample_times(lane: Dictionary) -> Array:
	var result: Array = []
	for side in ["a", "b"]:
		var taken := 0
		for point in lane[side]:
			if _edge(lane.a, float(point.time)) == INF or _edge(lane.b, float(point.time)) == INF: continue
			result.append(float(point.time))
			taken += 1
			if taken >= 40: break
	return result
