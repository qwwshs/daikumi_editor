class_name BeatTimeline
extends RefCounted
## BPM 时间表：加载时计算分段累计时间，查询只做二分，不依赖场景或单例。

var segments: Array[Dictionary] = []

func _init(bpms: Array = []) -> void:
	for raw in bpms:
		var entry: Dictionary = raw.duplicate()
		if not segments.is_empty() and is_equal_approx(entry.beat, segments[-1].beat):
			segments[-1] = entry
		else:
			segments.append(entry)
	if segments.is_empty():
		segments.append({"beat": 0.0, "bpm": 120.0, "linear_ramp": 0})
	var elapsed: float = float(segments[0].beat) * 60.0 / segments[0].bpm
	for i in segments.size():
		var item := segments[i]
		item.time = elapsed
		item.slope = 0.0
		if i + 1 < segments.size():
			var distance: float = segments[i + 1].beat - item.beat
			if item.get("linear_ramp", 0) == 1 and distance > 0:
				item.slope = (segments[i + 1].bpm - item.bpm) / distance
			elapsed += _duration(item, distance)

func _duration(segment: Dictionary, beats: float) -> float:
	if absf(segment.slope) < 0.000001:
		return beats * 60.0 / segment.bpm
	return 60.0 / segment.slope * log(maxf(0.000001, (segment.bpm + segment.slope * beats) / segment.bpm))

func _find(field: String, value: float) -> int:
	var low := 0
	var high := segments.size()
	while low < high:
		var mid := (low + high) >> 1
		if float(segments[mid][field]) <= value:
			low = mid + 1
		else:
			high = mid
	return maxi(0, low - 1)

func to_time(beat: float) -> float:
	var item := segments[_find("beat", beat)]
	if beat < float(segments[0].beat):
		return item.time + (beat - item.beat) * 60.0 / item.bpm
	return item.time + _duration(item, beat - item.beat)

func to_beat(time: float) -> float:
	var item := segments[_find("time", time)]
	var elapsed: float = time - item.time
	if time < float(segments[0].time) or absf(item.slope) < 0.000001:
		return item.beat + elapsed * item.bpm / 60.0
	return item.beat + item.bpm * (exp(item.slope * elapsed / 60.0) - 1.0) / item.slope
