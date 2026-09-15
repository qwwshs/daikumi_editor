extends Node
## 选曲 / 结算界面截图：加载 res://chart/Antithesis 后截取其中一个界面，供人工核对。
##
##   godot --path . res://tests/song_screens_shot.tscn              # 选曲
##   godot --path . res://tests/song_screens_shot.tscn -- --results # 结算
##
## 输出默认写到 user://（可用 --out= 换目录），再由脚本或人工拷进 artifacts/：
## 写进 res:// 会触发资源导入，还会连上正在运行的编辑器，属于自找麻烦。
func _ready() -> void:
	Storage.chart_dir = "res://chart"
	ChartLoader.selected_folder = "res://chart/Antithesis"
	var is_result := "--results" in OS.get_cmdline_user_args()
	var output_dir := "user://"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_dir = argument.trim_prefix("--out=")
	ChartLoader.load_from_folder(ChartLoader.selected_folder)
	# 选曲截图要能看到「最佳成绩」面板，所以先往临时成绩册里记一局；
	# 用临时文件，别动玩家真实的 user://scores.cfg。
	Scores.file_path = "user://__shot_scores__.cfg"
	Scores.scores.clear()
	Scores.record(ChartLoader.selected_folder, {"score": 968420, "max_combo": 328, "total_units": 531,
		"position_mode": Setting.judge_position_mode, "average_offset": -0.0123, "offset_samples": 512,
		"counts": {"just+": 486, "just": 32, "good": 8, "ok": 2, "miss": 3}})
	if is_result:
		ChartLoader.last_result = {"info": ChartLoader.chart_data.info.duplicate(), "background": ChartLoader.bg,
			"score": 968420, "max_combo": 328, "is_best": true, "position_mode": Setting.judge_position_mode,
			"average_offset": -0.0123, "offset_samples": 512,
			"counts": {"just+": 486, "just": 32, "good": 8, "ok": 2, "miss": 3}}
	var scene: PackedScene = load("res://gd/room/results.tscn" if is_result else "res://gd/room/startroom.tscn")
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().create_timer(0.6).timeout
	# 截图看不到文字，顺手把面板内容打到日志里，便于核对截图里画的是什么。
	if not is_result:
		print("截图里的最佳成绩：%s / %s" % [instance.get("_score").text, instance.get("_score_summary").text])
	else:
		var offset_label := _find_tag(instance, "result:average_offset")
		print("截图里的平均击打延迟：%s" % (offset_label.text if offset_label is Label else "找不到"))
	await RenderingServer.frame_post_draw
	var suffix := "results" if is_result else "song_select"
	var path := ProjectSettings.globalize_path(output_dir.path_join(suffix + ".png"))
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("截图 %s：%s" % ["失败" if result != OK else "完成", path])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Scores.file_path))
	get_tree().quit(0 if result == OK else 1)


func _find_tag(node: Node, tag: String) -> Node:
	if str(node.get_meta("dakumi_setting", "")) == tag:
		return node
	for child in node.get_children():
		var found := _find_tag(child, tag)
		if found != null:
			return found
	return null
