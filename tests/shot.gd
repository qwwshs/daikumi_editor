extends Node
## 截图工具：把某个场景渲染若干帧后保存成 PNG，用于人工核对界面。
##
##   godot --path . res://tests/shot.tscn -- --scene=res://gd/room/settings.tscn --out=user://shot.png
##
## 参数用 "--" 之后的自定义命令行传入；不传则截取当前场景。仅用于开发核对，不参与游戏运行。
## 输出请放在 user:// 或项目外：写进 res:// 会触发资源导入，留下 .import 与 .godot/imported 缓存。

const DEFAULT_FRAMES := 24


func _ready() -> void:
	var target := ""
	var output := "user://shot.png"
	var frames := DEFAULT_FRAMES
	var wait := 0.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			target = argument.trim_prefix("--scene=")
		elif argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
		elif argument.begins_with("--frames="):
			frames = maxi(1, int(argument.trim_prefix("--frames=")))
		elif argument.begins_with("--wait="):
			# 按秒等待：游玩场景的时间轴跟随音频时钟，用秒数比帧数更可控。
			wait = clampf(float(argument.trim_prefix("--wait=")), 0.0, 300.0)
	if not target.is_empty():
		var scene := load(target)
		if scene == null:
			push_error("无法加载场景：%s" % target)
			get_tree().quit(1)
			return
		add_child(scene.instantiate())
	# 两种等待方式：--frames 数帧（默认），--wait 按秒（游玩场景的时间轴跟随音频时钟，
	# 用秒数比帧数更可控）。给了 --wait 就不再套用帧数上限，否则长等待会被 24 帧截断。
	if wait > 0.0:
		var deadline := Time.get_ticks_msec() + int(wait * 1000.0)
		while Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
	else:
		for _frame in frames:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(output)
	# save_png 不会创建目录，先补上目标文件夹。
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var result := image.save_png(path)
	print("截图 %s：%s（%d×%d）" % ["失败" if result != OK else "完成", path, image.get_width(), image.get_height()])
	get_tree().quit(0 if result == OK else 1)
