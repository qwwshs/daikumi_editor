class_name TrackEvaluator
extends RefCounted
## 按轨道/事件类型建立索引。同拍缓存本地事件值，根查询缓存最终父链和边界结果。

const TAKANA_MOTION := preload("res://gd/gameplay/takana_motion.gd")
const TYPES := ["x", "w", "lpos", "rpos"]
var tracks: Dictionary = {}
var preference: Dictionary
var _beat: float = INF
var _cache: Dictionary = {}
var _track_order: Array = []
var _local_cache: Dictionary = {}

func _init(chart: ChartData) -> void:
	preference = chart.preference
	for key in chart.track:
		_ensure(int(key), chart.track[key])
	for item in chart.note:
		var lane := _ensure(item.track)
		lane.has_notes = true
	for item in chart.event:
		_ensure(item.track)
		if item.type in TYPES:
			tracks[item.track].events[item.type].append(item)
	# 编辑器仅绘制被事件或音符使用的轨道；纯父/边界定义仍参与递归。
	for id in tracks:
		if tracks[id].attribute.has("takana") or tracks[id].has_notes or TYPES.any(func(kind): return not tracks[id].events[kind].is_empty()):
			_track_order.append(id)
	_track_order.sort_custom(func(a: int, b: int) -> bool:
		var az := int(tracks[a].attribute.zindex)
		var bz := int(tracks[b].attribute.zindex)
		return az < bz if az != bz else a < b)
	# ChartData 已按拍稳定排序，分组后直接保留顺序。

func _ensure(id: int, attributes: Dictionary = {}) -> Dictionary:
	if not tracks.has(id):
		var defaults := ChartData.TRACK_DEFAULTS.duplicate(true)
		defaults.merge(attributes, true)
		tracks[id] = {"events": {"x": [], "w": [], "lpos": [], "rpos": []}, "attribute": defaults, "has_notes": false}
	return tracks[id]

func _value(events: Array, beat: float) -> Dictionary:
	var low := 0
	var high := events.size()
	while low < high:
		var mid := (low + high) >> 1
		if float(events[mid].beat) <= beat:
			low = mid + 1
		else:
			high = mid
	if low == 0:
		return {"x": 0.0, "y": 0.0}
	var item: Dictionary = events[low - 1]
	var span: float = item.beat2 - item.beat
	var progress := 1.0 if span <= 0.0 else clampf((beat - item.beat) / span, 0, 1)
	return {"x": lerpf(item.from, item.to, _transition(item.trans, progress)), "y": minf(beat, item.beat2)}

func _transition(config: Dictionary, progress: float) -> float:
	if config.get("type") not in ["bezier", "easings"]:
		return 1.0
	if config.get("type") == "easings":
		var easing: Callable = Easings.get_easing(Easings.get_easing_name(clampi(int(config.get("easings", 1)) - 1, 0, Easings.all_name.size() - 1)))
		return easing.call(progress)
	if progress <= 0.0 or progress >= 1.0:
		return progress
	var points: Array = config.get("trans", [0, 0, 1, 1])
	if points == [0, 0, 1, 1] or points.is_empty():
		return progress
	return Bezier.bezier(0, 1, 0, 1, points, progress)

func sample(beat: float) -> Array[Dictionary]:
	_begin(beat)
	var result: Array[Dictionary] = []
	for id in _track_order:
		var raw := _raw(id, {})
		var attribute: Dictionary = tracks[id].attribute
		result.append({"track": id, "x": (raw.x + preference.x_offset) / preference.event_scale,
			"w": absf(raw.y / preference.event_scale),
			"visible": (beat >= attribute.takana.start and beat <= attribute.takana.end) if attribute.has("takana") else (int(attribute.w0thenShow) == 1 or raw.y != 0.0),
			"touch": false, "zindex": int(attribute.zindex)})
	return result

func at(id: int, beat: float) -> Vector2:
	_begin(beat)
	var raw := _raw(id, {})
	return Vector2((raw.x + preference.x_offset) / preference.event_scale, absf(raw.y / preference.event_scale))

func _begin(beat: float) -> void:
	if beat != _beat:
		_beat = beat
		_cache.clear()
		_local_cache.clear()

func _raw(id: int, visiting: Dictionary, boundaries: Dictionary = {}) -> Vector2:
	# 边界与父链中的环会使递归结果依赖当前路径，只缓存根查询。
	var cacheable := visiting.is_empty() and boundaries.is_empty()
	if cacheable and _cache.has(id):
		return _cache[id]
	if not tracks.has(id) or visiting.has(id):
		return Vector2.ZERO
	if tracks[id].attribute.has("takana"):
		var value := TAKANA_MOTION.lane(tracks[id].attribute.takana, _beat)
		_cache[id] = value
		return value
	visiting[id] = true
	var result := _local(id)
	var attribute: Dictionary = tracks[id].attribute
	var parent_id := int(attribute.parent)
	if parent_id != 0:
		if visiting.has(parent_id):
			visiting.erase(id)
			return result
		var parent := _raw(parent_id, visiting, boundaries)
		if int(attribute.scale_with_parent) == 1:
			result = Vector2(parent.x - parent.y / 2.0 + (result.x + preference.x_offset) / preference.event_scale * parent.y, result.y / preference.event_scale * parent.y)
		else:
			result.x += parent.x
	var natural_l := result.x - result.y / 2.0
	var natural_r := result.x + result.y / 2.0
	var clipped_l := natural_l
	var clipped_r := natural_r
	var limits := Vector2(-INF, INF)
	if attribute.boundary_type == "pos":
		limits = Vector2(float(attribute.left_boundary), float(attribute.right_boundary))
	elif attribute.boundary_type == "track":
		limits.x = _boundary(int(attribute.left_boundary), str(attribute.left_reference), -INF, boundaries)
		limits.y = _boundary(int(attribute.right_boundary), str(attribute.right_reference), INF, boundaries)
	clipped_l = maxf(clipped_l, limits.x)
	clipped_r = minf(clipped_r, limits.y)
	if clipped_l > clipped_r and (is_finite(limits.x) or is_finite(limits.y)):
		if is_finite(limits.x) and natural_r <= limits.x:
			clipped_l = limits.x
			clipped_r = clipped_l
		elif is_finite(limits.y) and natural_l >= limits.y:
			clipped_r = limits.y
			clipped_l = clipped_r
		else:
			clipped_l = (clipped_l + clipped_r) / 2.0
			clipped_r = clipped_l
	result = Vector2((clipped_l + clipped_r) / 2.0, absf(clipped_r - clipped_l))
	visiting.erase(id)
	if cacheable:
		_cache[id] = result
	return result

func _boundary(id: int, reference: String, fallback: float, boundaries: Dictionary) -> float:
	if not tracks.has(id) or boundaries.has(id):
		return fallback
	boundaries[id] = true
	# 共享祖先不是环：每个边界轨道独立解析自己的父链。
	var value := _raw(id, {}, boundaries)
	boundaries.erase(id)
	match reference:
		"x": return value.x
		"w": return value.y
		"lpos": return value.x - value.y / 2.0
		"rpos": return value.x + value.y / 2.0
	return fallback

func _local(id: int) -> Vector2:
	if _local_cache.has(id):
		return _local_cache[id]
	var values: Dictionary = {}
	for kind in TYPES:
		values[kind] = _value(tracks[id].events[kind], _beat)
	var pair := _latest_pair(values)
	var x: float = values.x.x
	var w: float = values.w.x
	var left: float = values.lpos.x
	var right: float = values.rpos.x
	var result := Vector2(x, w)
	if "lpos" in pair and "rpos" in pair:
		result = Vector2((left + right) / 2.0, right - left)
	elif "x" in pair and "lpos" in pair:
		result = Vector2(x, (x - left) * 2.0)
	elif "x" in pair and "rpos" in pair:
		result = Vector2(x, (right - x) * 2.0)
	elif "w" in pair and "lpos" in pair:
		result = Vector2(left + w / 2.0, w)
	elif "w" in pair and "rpos" in pair:
		result = Vector2(right - w / 2.0, w)
	_local_cache[id] = result
	return result


## 对齐 LOVE 的 LuaJIT table.sort 四元素路径，尤其是同拍事件的交换顺序。
## 这里不能改成稳定排序：同拍时选出的两种类型直接决定轨道宽度。
func _latest_pair(values: Dictionary) -> Array:
	var order := ["x", "w", "lpos", "rpos"]
	if values[order[3]].y > values[order[0]].y:
		_swap(order, 0, 3)
	if values[order[1]].y > values[order[0]].y:
		_swap(order, 1, 0)
	elif values[order[3]].y > values[order[1]].y:
		_swap(order, 1, 3)
	_swap(order, 1, 2)
	var pivot: String = order[2]
	var i := 0
	var j := 2
	while true:
		i += 1
		while values[order[i]].y > values[pivot].y:
			i += 1
		j -= 1
		while values[pivot].y > values[order[j]].y:
			j -= 1
		if j < i:
			break
		_swap(order, i, j)
	_swap(order, i, 2)
	if i == 2 and values[order[1]].y > values[order[0]].y:
		_swap(order, 0, 1)
	elif i == 1 and values[order[3]].y > values[order[2]].y:
		_swap(order, 2, 3)
	return [order[0], order[1]]

func _swap(items: Array, a: int, b: int) -> void:
	var value = items[a]
	items[a] = items[b]
	items[b] = value
