extends Node

func _ready() -> void:
	var data := {"event": [], "track": {}}
	for id in range(1, 65):
		data.track[str(id)] = {}
		for kind in ["x", "w"]:
			data.event.append({"track": id, "type": kind, "beat": 0, "beat2": 100,
				"from": 20, "to": 80, "trans": {"type": "bezier", "trans": [0.15, 0.85, 0.3, 1.0]}})
	var evaluator := TrackEvaluator.new(ChartData.new(JSON.stringify(data)))
	var times: Array[int] = []
	for frame in 640:
		var start := Time.get_ticks_usec()
		evaluator.sample(float(frame) / 10.0)
		for hit in 24:
			Skins.hit_scale_curve(Setting.get_skin("hit_tap"), float((frame + hit) % 180) / 1000.0, 0.3)
		if frame >= 40:
			times.append(Time.get_ticks_usec() - start)
	times.sort()
	var sum := 0
	for value in times:
		sum += value
	print("BENCH 64 moving tracks + 24 hit curves: mean=%.3f ms p95=%.3f ms p99=%.3f ms max=%.3f ms" % [sum / float(times.size()) / 1000.0, times[569] / 1000.0, times[593] / 1000.0, times[-1] / 1000.0])
	get_tree().quit()
