extends RefCounted
## Runtime evaluation of parsed TAKANA curves; independent of LOVE easing semantics.
static func lower(points: Array, time: float) -> int:
	var lo := 0
	var hi := points.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if points[mid].time <= time: lo = mid + 1
		else: hi = mid
	return maxi(0, lo - 1)

static func position(points: Array, time: float) -> float:
	if points.is_empty(): return 0.0
	var index := lower(points, time)
	var item: Dictionary = points[index]
	if index == points.size() - 1 or time <= float(item.time): return float(item.value)
	var next: Dictionary = points[index + 1]
	var t := clampf((time - item.time) / (next.time - item.time), 0, 1)
	if item.ease == "bezier":
		t = cubic_factor(item.controls, t)
	else:
		t = easing(item.ease, t)
	return lerpf(item.value, next.value, t)

static func lane(data: Dictionary, time: float) -> Vector2:
	if data.fallback: return Vector2(0, 1)
	var a := position(data.a, time)
	var b := position(data.b, time)
	return Vector2(a, absf(b)) if data.direct else Vector2((a + b) * 0.5, absf(b - a))

static func integral(points: Array, time: float) -> float:
	if points.is_empty(): return time
	var item: Dictionary = points[lower(points, time)]
	return item.integral + (time - item.time) * item.speed

static func distance(points: Array, now: float, target: float) -> float:
	return integral(points, target) - integral(points, now)

static func easing(code: String, t: float) -> float:
	if code == "u": return 0.0
	if code.length() != 2: return t
	var family := code.substr(0, 1)
	# TAKANA stores the opposite direction on the starting control point.
	match code.substr(1):
		"i": return 1.0 - ease_in(family, 1.0 - t)
		"o": return ease_in(family, t)
		"a": return (1.0 - ease_in(family, 1.0 - 2.0*t)) * 0.5 if t < 0.5 else 0.5 + ease_in(family, 2.0*t-1.0)*0.5
		"b": return ease_in(family, 2.0*t)*0.5 if t < 0.5 else 1.0 - ease_in(family, 2.0-2.0*t)*0.5
	return t

static func ease_in(family: String, t: float) -> float:
	match family:
		"s": return 1.0 - cos(t * PI * 0.5)
		"2", "3", "4", "5": return pow(t, int(family))
		"e": return 0.0 if t == 0.0 else pow(2.0, 10.0*t-10.0)
		"c": return 1.0 - sqrt(maxf(0.0, 1.0-t*t))
		"b": return 2.70158*t*t*t - 1.70158*t*t
		"l": return t if t == 0.0 or t == 1.0 else -pow(2.0, 10.0*t-10.0)*sin((t*10.0-10.75)*TAU/3.0)
		"w": return 1.0 - bounce(1.0-t)
	return t

static func bounce(t: float) -> float:
	if t < 1.0/2.75: return 7.5625*t*t
	if t < 2.0/2.75: return 7.5625*pow(t-1.5/2.75, 2)+0.75
	if t < 2.5/2.75: return 7.5625*pow(t-2.25/2.75, 2)+0.9375
	return 7.5625*pow(t-2.625/2.75, 2)+0.984375

static func cubic_factor(points: Array, time: float) -> float:
	var t := time
	for iteration in 5:
		var u := 1.0 - t
		var current: float = 3.0*u*u*t*points[0] + 3.0*u*t*t*points[2] + t*t*t
		var slope: float = 3.0*u*u*points[0] + 6.0*u*t*(points[2]-points[0]) + 3.0*t*t*(1.0-points[2])
		if absf(slope) < 0.000001: break
		t = clampf(t - (current-time)/slope, 0.0, 1.0)
	var u := 1.0 - t
	return clampf(3.0*u*u*t*points[1] + 3.0*u*t*t*points[3] + t*t*t, 0.0, 1.0)

static func entry_time(points: Array, target: float, threshold: float) -> float:
	if points.is_empty(): return target - threshold
	var goal := integral(points, target)
	for i in points.size():
		var item: Dictionary = points[i]
		var start: float = -INF if i == 0 else item.time
		var end: float = minf(target, points[i+1].time) if i+1 < points.size() else target
		if start > end: break
		var speed: float = item.speed
		if speed > 0.0:
			var crossing: float = item.time + (goal - item.integral - threshold) / speed
			if maxf(start, crossing) <= end: return maxf(start, crossing)
		elif start == -INF:
			if speed < 0.0 or goal - item.integral <= threshold: return -INF
		elif goal - integral(points, start) <= threshold:
			return start
	return target
