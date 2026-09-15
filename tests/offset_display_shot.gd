extends Node
## 击打延迟显示的设置页截图：切到「数字 / 判定 / 按钮」页、滚到这张卡片，供人工核对。
## 左边预览里同时能看到 FAST / LATE 两行（预览与游玩共用同一条绘制路径）。
##
##   godot --path . res://tests/offset_display_shot.tscn --out=user://settings_latency.png
##
## 输出默认写到 user://（可用 --out= 换目录），再由脚本或人工拷进 artifacts/：
## 写进 res:// 会触发资源导入，还会连上正在运行的编辑器，属于自找麻烦。

## 击打延迟显示卡片所在的页号（_build_editor 里的顺序，见 _build_art_page）。
const PAGE := 3
## 卡片顶边离页面顶端的距离：留下标题栏的余量，别把标题切掉。
const TOP_MARGIN := 70.0
## 截图里把延迟显示高度临时调大：预览区只有几百像素宽，默认 20 的等比例结果不到 9 像素高，
## 截出来看不出字形。只影响这张图，退出前会还原。
const SHOT_SIZE := 90.0


func _ready() -> void:
	var output_dir := "user://"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_dir = argument.trim_prefix("--out=")
	var scene: PackedScene = load("res://gd/room/settings.tscn")
	var settings := scene.instantiate()
	add_child(settings)
	await get_tree().process_frame
	await get_tree().process_frame
	settings.call("_show_page", PAGE)
	await get_tree().process_frame
	# 卡片本身没有标签，用它的判定勾选框反查：往上找到贴着页内容的那个 PanelContainer。
	var check := _find_tag(settings, "offset_grade:just+")
	var pages: Array = settings.get("_pages")
	if check != null and pages.size() > PAGE:
		var page: ScrollContainer = pages[PAGE]
		var offset: float = check.get_global_rect().position.y - page.get_global_rect().position.y
		page.scroll_vertical = maxi(0, roundi(offset - TOP_MARGIN))
	Setting.set_layout("judge_offset_size", SHOT_SIZE)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(output_dir.path_join("settings_latency.png"))
	var result := image.save_png(path)
	print("截图 %s：%s" % ["失败" if result != OK else "完成", path])
	# 截图看不到东西，把「卡片在不在画面里、预览里有没有 FAST / LATE」打进日志，便于核对。
	if check != null:
		var card := _card_of(check)
		var visible_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		print("卡片：%s / 在画面里：%s" % [str(card.get_global_rect()) if card != null else "找不到",
			str(card != null and visible_rect.intersects(card.get_global_rect()))])
	print("方向词像素：FAST %d / LATE %d（截图里高度临时设为 %.0f）" % [_count(image, Skins.FAST_COLOR), _count(image, Skins.LATE_COLOR), SHOT_SIZE])
	Setting.reset_layout()
	get_tree().quit(0 if result == OK else 1)


## 从勾选框往上找卡片（贴着页内容的那个 PanelContainer）。
func _card_of(node: Node) -> Control:
	var current := node as Control
	while current != null and not (current is PanelContainer):
		current = current.get_parent() as Control
	return current


## 全图里接近 expected 的像素个数：方向词用的是固定色，数一下就知道画没画出来。
func _count(image: Image, expected: Color) -> int:
	var total := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - expected.r) <= 0.06 and absf(pixel.g - expected.g) <= 0.06 and absf(pixel.b - expected.b) <= 0.06:
				total += 1
	return total


func _find_tag(node: Node, tag: String) -> Node:
	if str(node.get_meta("dakumi_setting", "")) == tag:
		return node
	for child in node.get_children():
		var found := _find_tag(child, tag)
		if found != null:
			return found
	return null
