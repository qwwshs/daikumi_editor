class_name PlaySession
extends RefCounted
## 纯游玩状态。谱面保留不变；重开只需新建会话，无需重新导入文件。

signal judged(index: int, grade: String, phase: String)
## 判定记录立即更新；提前命中的 Slide 视听反馈等待谱面时间。
signal feedback_ready(index: int, grade: String, phase: String)
enum State { PENDING, HOLDING, DONE, SLIDE_WAITING }
const WINDOWS := [0.040, 0.060, 0.085, 0.100]
const GRADES := ["just+", "just", "good", "ok"]
const WEIGHTS := {"just+": 1.0, "just": 0.9, "good": 0.75, "ok": 0.5, "miss": 0.0}
## 满分。加算把它当终点、减算把它当起点；一局打完两种模式算出同一个分数。
const SCORE_TOTAL := 1000000.0
const HOLD_GRACE := 0.100

var mode := "dakumi"
const MOTION := preload("res://gd/gameplay/takana_motion.gd")
const SAME_TIME_TOLERANCE := 0.002
const HOLD_TAIL_GRACE := 0.120
## TAKANA 的判定框余量（T3ComboFactory.ExtraRange = 0.1 舞台单位）。TAKANA 舞台宽 9，
## dakumi 用 0..1 归一化坐标，于是 0.1 舞台单位 = 0.1 / 9。Tap 与 Slide 的判定框两边各加这么宽，
## Hold 头不加（TAKANA 在有长条时又把这份加宽减了回去，免得按住时误判），
## Hold 的按住过程同样加宽（TAKANA 的 IsFingerOnTrack 也带 ExtraRange）。
const EXTRA_RANGE := 0.1 / 9.0
## 判定扫描范围：最多回看 100 ms（更早的音符已经算过期），最多前瞻 150 ms（Slide 的提前窗口要用满 150）。
## 扫进来的 Tap / Hold 还要落在命中窗口（±WINDOWS[-1] = 100 ms）里才会被判——TAKANA 会把提前
## 100~150 ms 的那次按下按 Miss 消费掉（EarlyMiss），这里不这么做：那会打死玩家马上要按的音符，
## 音符留给属于它自己的那次按下（或自然漏判）。
const SCAN_LATE := 0.100
const SCAN_EARLY := 0.150
## Slide 的判定窗口不对称：TAKANA 的 slide 配置里只有 CriticalJust，提前 150 ms 到延后 100 ms
## 全都算命中（T3SlideJudgeConfig）。它比 Tap 的 ±100 ms 宽，是 Slide 好打的来源。
const SLIDE_EARLY := 0.150
const SLIDE_LATE := 0.100
var notes: Array = []
var states := PackedByteArray()
var timeline: BeatTimeline
var evaluator: TrackEvaluator
var tracks: Array[Dictionary] = []
var active_holds: Dictionary = {}
## 同一时刻没被这次按下认领的其他长条：挂着等别的手指（用那次按下的判定），
## 一直没人按就在快判漏时归给按下它们的那根手指（见 _defer_hold / _resolve_deferred_holds）。
var deferred_holds: Dictionary = {}
var combo: int = 0
var max_combo: int = 0
var judgement_counts := {"just+": 0, "just": 0, "good": 0, "ok": 0, "miss": 0}
var judged_units: int = 0
var end_time: float = 0.0
var score: float = 0.0
var total_units: int = 0
var last_grade: String = ""
## 最近一次判定是不是「真的按下去」：时间到了漏掉没碰的音符是 false。
## HUD 的击打延迟显示据此只在按下的那一刻出现（漏判没有按点可谈）。
var last_hit_from_press: bool = false
## 最近一次按下离音符时刻的偏差（秒，正数 = 按晚了）。只有按下时更新。
var last_hit_offset: float = 0.0
## 平均击打延迟的累计：只统计按下去判定的 Tap / Hold 头（Hold 尾与 Slide 不算按点）。
var hit_offset_sum: float = 0.0
var hit_offset_count: int = 0
var time: float = -3.0
var beat: float = 0.0
var _miss_cursor: int = 0
var _visible_cursor: int = 0
var _visible: Array[int] = []
var _appearances: Array = []
var _appearance_window := -1.0
var _pending_slide_feedback: Array[int] = []
var _head_positions := PackedVector2Array()
var _layer_source: Array[int] = []
var _layer_visible: Array[int] = []

func _init(chart: ChartData) -> void:
	mode = chart.mode
	timeline = BeatTimeline.new(chart.bpmlist)
	evaluator = TrackEvaluator.new(chart)
	# 只在加载时复制；手指绑定等状态放在 active_holds，不写入谱面。
	notes = chart.note.duplicate(true)
	states.resize(notes.size())
	states.fill(State.PENDING)
	for item in notes:
		item.time = timeline.to_time(item.beat)
		item.time2 = maxf(item.time, timeline.to_time(item.beat2))
		end_time = maxf(end_time, item.time2)
		if not item.fake:
			total_units += 2 if item.type == "Hold" else 1
	# 目标时刻的位置仅与谱面有关：加载时预计算，不干扰游玩帧的当前拍缓存。
	_head_positions.resize(notes.size())
	for index in notes.size():
		_head_positions[index] = evaluator.at(notes[index].track, notes[index].beat)
	# 起点由分数算法决定，必须在 total_units 数完之后（加算 0 分起步、减算满分开局）。
	score = _initial_score()


## 加算：0 分起步往上加；减算：满分起步往下扣。两种模式对同一局判定给出的总分相同，
## 每个计分单位在加算里加一份权重、在减算里扣掉剩下的那部分（见 _record）。
func _initial_score() -> float:
	return 0.0 if Setting.score_mode == Setting.SCORE_ADD else SCORE_TOTAL

func head_position(index: int) -> Vector2:
	if Setting.judge_position_mode == Setting.JUDGE_POSITION_NOTE:
		return _head_positions[index]
	return evaluator.at(notes[index].track, beat)

func update(now: float, fingers: Dictionary) -> void:
	time = now
	beat = timeline.to_beat(time)
	tracks = evaluator.sample(beat)
	for lane in tracks:
		for finger_id in fingers:
			var finger: Dictionary = fingers[finger_id]
			if _inside(finger.x, lane.x, lane.w, EXTRA_RANGE):
				lane.touch = true
				break
	for id in fingers:
		_judge_finger(id, fingers[id])
	_resolve_deferred_holds()
	# 过期音符只处理一次，时间越靠后也不会扫描旧音符。
	while _miss_cursor < notes.size() and notes[_miss_cursor].time < time - WINDOWS[-1]:
		var index := _miss_cursor
		_miss_cursor += 1
		if states[index] != State.PENDING:
			continue
		states[index] = State.DONE
		if not notes[index].fake:
			last_hit_from_press = false
			_record(index, "miss", "head")
			if notes[index].type == "Hold":
				_record(index, "miss", "tail")
	for index in active_holds.keys():
		var hold: Dictionary = active_holds[index]
		var lane := evaluator.at(notes[index].track, beat)
		if fingers.has(hold.finger) and _swept_inside(fingers[hold.finger], lane.x, lane.y, EXTRA_RANGE):
			hold.last_touch = time
		# Once the tail grace is reached, retain the Hold until its scheduled tail.
		if float(hold.last_touch) >= float(notes[index].time2) - HOLD_TAIL_GRACE:
			hold["tail_ready"] = true
		if time >= notes[index].time2 and hold.get("tail_ready", false):
			_finish_hold(index, "just+")
		elif not hold.get("tail_ready", false) and time - hold.last_touch > HOLD_GRACE:
			_finish_hold(index, "miss")

	# 使用歌曲时钟，暂停不会触发，跨过目标时间的第一帧播放且只播放一次。
	var pending_count := 0
	for index in _pending_slide_feedback:
		if notes[index].time <= time:
			states[index] = State.DONE
			feedback_ready.emit(index, "just+", "head")
		else:
			_pending_slide_feedback[pending_count] = index
			pending_count += 1
	_pending_slide_feedback.resize(pending_count)

## 横向判定：落在轨道宽度的一半以内就算碰到。轨道宽度为 0 时留一个最小可点范围，
## 额外的 extra 是 TAKANA 的判定框余量（见 EXTRA_RANGE），Hold 头传 0。
func _inside(x: float, center: float, width: float, extra: float = 0.0) -> bool:
	return absf(x - center) <= maxf(absf(width) / 2.0, 0.012) + extra

## 扫掠版：手指在这一帧从 previous_x 划到 x，只要有重叠就算碰到。
func _swept_inside(finger: Dictionary, center: float, width: float, extra: float = 0.0) -> bool:
	var left := minf(float(finger.get("previous_x", finger.x)), float(finger.x))
	var right := maxf(float(finger.get("previous_x", finger.x)), float(finger.x))
	var half := maxf(absf(width) * 0.5, 0.012) + extra
	return right >= center - half and left <= center + half

func note_distance(index: int, tail: bool = false) -> float:
	var item: Dictionary = notes[index]
	var target: float = item.time2 if tail else item.time
	if mode == "takana":
		return MOTION.distance(item.get("takana_tail_speed" if tail else "takana_speed", []), time, target)
	return target - time

func _lower_time(value: float) -> int:
	var low := 0
	var high := notes.size()
	while low < high:
		var mid := (low + high) >> 1
		if float(notes[mid].time) < value:
			low = mid + 1
		else:
			high = mid
	return low

func _judge_finger(id: int, finger: Dictionary) -> void:
	var candidates: Array[int] = []
	var index := _lower_time(time - SCAN_LATE)
	while index < notes.size() and notes[index].time <= time + SCAN_EARLY:
		var item: Dictionary = notes[index]
		if states[index] == State.PENDING and not item.fake:
			var lane := head_position(index)
			# Slide 用扫掠判定、Tap/Hold 看当前这一点；Hold 头的判定框不额外加宽。
			var extra := 0.0 if item.type == "Hold" else EXTRA_RANGE
			if (_swept_inside(finger, lane.x, lane.y, extra) if item.type == "Slide" else _inside(finger.x, lane.x, lane.y, extra)):
				candidates.append(index)
		index += 1
	# 一次按下只判「同一个时刻」：目标 = 离按下最近的那颗 Tap/Hold（一样近时取谱面里靠前的），
	# 其余音符要与它同时（±SAME_TIME_TOLERANCE）才跟着一起判。以前凡是落进扫描窗口的音符
	# 都会被这次按下一起判掉，于是按一颗 Tap 会顺手把 100 ms 后才开始的 Hold 也判掉、
	# 更远一点还会直接记成 miss；那颗 Hold 再用它自己那次按下时反而什么都不发生。
	var target := -1
	for candidate in candidates:
		if notes[candidate].type == "Slide":
			continue
		if target < 0 or absf(float(notes[candidate].time) - time) < absf(float(notes[target].time) - time):
			target = candidate
	var moment: float = notes[target].time if target >= 0 else 0.0
	var tap_consumed := false
	var hold_claimed := false
	for candidate in candidates:
		var item: Dictionary = notes[candidate]
		var difference: float = item.time - time
		if item.type == "Slide":
			# Slide 不需要按下，停留或划过就算命中；窗口是 TAKANA 的非对称区间。
			if difference >= -SLIDE_LATE and difference <= SLIDE_EARLY:
				states[candidate] = State.SLIDE_WAITING if time < item.time else State.DONE
				_record(candidate, "just+", "head")
			continue
		if not finger.get("pressed", false):
			continue
		if absf(difference) > WINDOWS[-1] or absf(float(item.time) - moment) > SAME_TIME_TOLERANCE:
			continue
		if item.type == "Hold":
			# 同一时刻的多根长条一次按下只认领一根，其余的挂起来（见 deferred_holds）。
			if hold_claimed:
				_defer_hold(candidate, id)
				continue
			hold_claimed = true
		else:
			if tap_consumed:
				continue
			tap_consumed = true
		var grade := _grade(absf(difference))
		if item.type == "Hold":
			# 别的手指认领了挂起的长条：从挂起表里摘掉，免得快判漏时又归位一次。
			deferred_holds.erase(candidate)
			states[candidate] = State.HOLDING
			active_holds[candidate] = {"finger": id, "last_touch": time, "started": time}
		else:
			states[candidate] = State.DONE
		# 按点偏差：正数 = 按晚了。Slide 是停留即命中，没有「按下的时刻」，不进平均。
		last_hit_from_press = true
		last_hit_offset = time - float(item.time)
		hit_offset_sum += last_hit_offset
		hit_offset_count += 1
		_record(candidate, grade, "head")

## 同一时刻的其他长条：先不判定，只把「这一次按下」记下来——哪根手指按的、判成什么、偏差多少。
## 别的手指按下来时用那次按下的判定认领它（「否则那个 hold 就采用其他手指按下的时候的判定」），
## 一直没人按就在快判漏时归给这里记下的手指（_resolve_deferred_holds）。
func _defer_hold(index: int, id: int) -> void:
	var offset := time - float(notes[index].time)
	deferred_holds[index] = {"finger": id, "grade": _grade(absf(offset)), "offset": offset}

## 挂起的长条不能一直挂着：再不动手就要判漏的那一刻（头判窗口的末尾），归给按下它的那根手指，
## 并用那一次按下给出的判定与偏差。挂起期间手指不用一直按着——按点早在那一刻定下了。
func _resolve_deferred_holds() -> void:
	for index in deferred_holds.keys():
		if float(notes[index].time) >= time - WINDOWS[-1]:
			continue
		var entry: Dictionary = deferred_holds[index]
		deferred_holds.erase(index)
		states[index] = State.HOLDING
		active_holds[index] = {"finger": entry.finger, "last_touch": time, "started": time}
		last_hit_from_press = true
		last_hit_offset = entry.offset
		hit_offset_sum += last_hit_offset
		hit_offset_count += 1
		_record(index, entry.grade, "head")

func _grade(difference: float) -> String:
	for i in WINDOWS.size():
		if difference <= WINDOWS[i]:
			return GRADES[i]
	return "miss"

func _finish_hold(index: int, grade: String) -> void:
	active_holds.erase(index)
	states[index] = State.DONE
	_record(index, grade, "tail")

func _record(index: int, grade: String, phase: String) -> void:
	combo = 0 if grade == "miss" else combo + 1
	max_combo = maxi(max_combo, combo)
	judgement_counts[grade] += 1
	judged_units += 1
	# 每个计分单位值 满分 / 计分单位数；加算加「拿到的权重」，减算扣「丢掉的权重」。
	var unit := SCORE_TOTAL / maxf(total_units, 1)
	if Setting.score_mode == Setting.SCORE_SUB:
		score -= unit * (1.0 - WEIGHTS[grade])
	else:
		score += unit * WEIGHTS[grade]
	last_grade = grade
	judged.emit(index, grade, phase)
	if notes[index].type == "Slide" and grade != "miss" and time < notes[index].time:
		_pending_slide_feedback.append(index)
	else:
		feedback_ready.emit(index, grade, phase)

func visible_notes(lookahead: float) -> Array[int]:
	if mode == "takana":
		return _takana_visible(lookahead)
	# 单向入场游标 + 活动窗口，不受某一个超长 Hold 的起点影响。
	while _visible_cursor < notes.size() and notes[_visible_cursor].time <= time + lookahead:
		_visible.append(_visible_cursor)
		_visible_cursor += 1
	var count := 0
	for index in _visible:
		if notes[index].time2 >= time - 0.15 and states[index] != State.DONE:
			_visible[count] = index
			count += 1
	_visible.resize(count)
	return _visible


func result_summary() -> Dictionary:
	return {"score": clampi(roundi(score), 0, roundi(SCORE_TOTAL)), "max_combo": max_combo,
		"counts": judgement_counts.duplicate(), "total_units": total_units,
		"position_mode": Setting.judge_position_mode, "chart_mode": mode,
		"average_offset": average_hit_offset(), "offset_samples": hit_offset_count}


## 平均击打延迟（秒，正数 = 按晚了）：按下 Tap / Hold 头的那一刻离音符时刻的平均偏差。
## 漏掉没碰的音符没有按点、Hold 尾与 Slide 也不算按点，都不计入；一次都没按下时返回 0。
func average_hit_offset() -> float:
	return hit_offset_sum / hit_offset_count if hit_offset_count > 0 else 0.0

func is_finished() -> bool:
	return judged_units >= total_units and active_holds.is_empty() and deferred_holds.is_empty() and _pending_slide_feedback.is_empty() and time >= end_time + 0.35


func visible_notes_by_layer(lookahead: float) -> Array[int]:
	var visible := visible_notes(lookahead)
	if visible == _layer_source:
		return _layer_visible
	_layer_source.assign(visible)
	_layer_visible.assign(visible)
	_layer_visible.sort_custom(func(a: int, b: int) -> bool:
		var az := int(evaluator.tracks[notes[a].track].attribute.zindex)
		var bz := int(evaluator.tracks[notes[b].track].attribute.zindex)
		return az < bz if az != bz else a < b)
	return _layer_visible

## Compile an entry schedule once per speed change, including stops and reversals.
## Per-frame work then visits only entered, unfinished notes.
func _takana_visible(lookahead: float) -> Array[int]:
	if lookahead != _appearance_window:
		_appearance_window = lookahead
		_appearances.clear()
		_visible.clear()
		_visible_cursor = 0
		for index in notes.size():
			var item: Dictionary = notes[index]
			var start := MOTION.entry_time(item.get("takana_speed", []), item.time, lookahead)
			if item.type == "Hold": start = minf(start, MOTION.entry_time(item.get("takana_tail_speed", []), item.time2, lookahead))
			_appearances.append({"time": start, "index": index})
		_appearances.sort_custom(func(a, b): return a.time < b.time)
	while _visible_cursor < _appearances.size() and _appearances[_visible_cursor].time <= time:
		_visible.append(_appearances[_visible_cursor].index)
		_visible_cursor += 1
	var count := 0
	for index in _visible:
		if states[index] != State.DONE and notes[index].time2 >= time - 0.15:
			_visible[count] = index
			count += 1
	_visible.resize(count)
	return _visible
