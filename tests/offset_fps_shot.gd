extends Node
## 设置页几张卡片的截图：偏移旋钮 + 实时读数、最高帧率档位、三种音符与轨道的横向间隔、
## 判定线图片的纵向偏移、Hold 尾部打击音开关、分数算法（加算 / 减算）与预览里的起始分数。
##
##   godot --path . res://tests/offset_fps_shot.tscn --out=user://
##
## 输出默认写到 user://（可用 --out= 换目录），再由脚本或人工拷进 artifacts/：
## 写进 res:// 会触发资源导入，还会连上正在运行的编辑器，属于自找麻烦。

## 每张截图：页号（_build_editor 里的顺序）+ 目标控件的 meta 标签 + 文件名 + 标题。
## 标签不依赖显示文案，所以改文案、挪位置都不会让这里失效。
const SHOTS := [
	[0, "game:offset", "settings_offset.png", "偏移旋钮"],
	[0, "game:max_fps:0", "settings_fps.png", "最高帧率"],
	[1, "layout:note_gap_tap", "settings_note_gap.png", "音符与轨道的横向间隔"],
	[1, "layout:judge_image_offset", "settings_judge_image.png", "判定线图片 Y 偏移"],
	[2, "game:hold_tail_sound", "settings_hold_tail_sound.png", "Hold 尾部打击音"],
	[3, "game:score_mode", "settings_score_mode.png", "分数算法"],
]
## 目标行离页面顶端的距离：留下标题栏与上一张卡片的余量。
const TOP_MARGIN := 120.0


func _ready() -> void:
	var output_dir := "user://"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_dir = argument.trim_prefix("--out=")
	var scene: PackedScene = load("res://gd/room/settings.tscn")
	if scene == null:
		print("设置界面加载失败")
		get_tree().quit(1)
		return
	var settings := scene.instantiate()
	add_child(settings)
	await get_tree().process_frame
	await get_tree().process_frame
	var pages: Array = settings.get("_pages")
	var original_score_mode: String = Setting.score_mode
	var original_hold_tail: bool = Setting.hold_tail_sound
	for shot in SHOTS:
		var index := int(shot[0])
		if pages.size() <= index:
			print("找不到设置页 %d" % index)
			get_tree().quit(1)
			return
		settings.call("_show_page", index)
		await get_tree().process_frame
		await _shoot(pages[index], _find_tag(settings, str(shot[1])),
			output_dir.path_join(str(shot[2])), str(shot[3]))
	# 再拍一张关掉尾部打击音的：勾选框里的勾会消失、提示与文案不动，
	# 两张图对拍就能确认这个开关的两种状态都真的画了出来（只改内存，拍完还原）。
	Setting.hold_tail_sound = false
	Setting.apply_settings()
	settings.call("_show_page", 2)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shoot(pages[2], _find_tag(settings, "game:hold_tail_sound"),
		output_dir.path_join("settings_hold_tail_sound_off.png"), "Hold 尾部打击音 · 关闭")
	Setting.hold_tail_sound = original_hold_tail
	Setting.apply_settings()
	# 再拍一张减算：预览里 HUD 的起始分数会从 0000000 变成 1000000，说明实时预览跟着算法走。
	# 只改内存不存盘，拍完还原，玩家的设置文件不动。
	Setting.score_mode = Setting.SCORE_SUB
	Setting.apply_settings()
	settings.call("_show_page", 3)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shoot(pages[3], _find_tag(settings, "game:score_mode"),
		output_dir.path_join("settings_score_mode_sub.png"), "分数算法 · 减算")
	Setting.score_mode = original_score_mode
	Setting.apply_settings()
	get_tree().quit(0)


## 把 target 滚到页面顶端下方 TOP_MARGIN 处再截图；截图看不到东西，
## 所以把几何与控制状态一起打进日志（框在不在画面里、按钮有没有互相压住），便于人工核对。
func _shoot(page: ScrollContainer, target: Node, path: String, title: String) -> void:
	if target is Control:
		var offset: float = (target as Control).get_global_rect().position.y - page.get_global_rect().position.y
		page.scroll_vertical = maxi(0, roundi(page.scroll_vertical + offset - TOP_MARGIN))
	else:
		print("%s：找不到目标控件" % title)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var full := ProjectSettings.globalize_path(path)
	var result := image.save_png(full)
	print("%s 截图%s：%s" % [title, "失败" if result != OK else "完成", full])
	if target is Control:
		print("%s：目标框 %s / 页可见区 %s / 在画面里 %s" % [title, str((target as Control).get_global_rect()),
			str(page.get_global_rect()), str(page.get_global_rect().encloses((target as Control).get_global_rect()))])
	if target is Button:
		var button := target as Button
		print("%s：按钮「%s」选中态 %s" % [title, button.text, str(button.button_pressed)])
		print("%s：同排按钮 %s" % [title, _row_rects(button)])
	var readout := _find_tag(page, "game:offset_readout")
	if readout is Label:
		print("读数：%s" % (readout as Label).text)

## 同一排（同一个父容器）里所有按钮的框与相邻间距：负数或零就说明按钮挤在一起了。
func _row_rects(button: Button) -> String:
	var parent := button.get_parent()
	if parent == null:
		return "没有父容器"
	var parts: Array[String] = []
	var previous: Rect2
	for child in parent.get_children():
		if not (child is Button):
			continue
		var rect := (child as Button).get_global_rect()
		parts.append("%s %s" % [(child as Button).text, str(rect)])
		if previous.size.x > 0.0:
			parts.append("间距 %.1f" % (rect.position.x - previous.end.x))
		previous = rect
	return " / ".join(parts)


## 页面上那行实时读数的文字（按 meta 标签找，不依赖显示位置）。
func _find_tag(node: Node, tag: String) -> Node:
	if str(node.get_meta("dakumi_setting", "")) == tag:
		return node
	for child in node.get_children():
		var found := _find_tag(child, tag)
		if found != null:
			return found
	return null
