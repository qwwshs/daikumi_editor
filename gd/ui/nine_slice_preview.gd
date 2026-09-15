extends Control
## Source-image guide shared by the skin editor. Margins are source pixels;
## the gameplay preview next to this panel shows the resulting stretched image.

var slot: String = ""
var show_guides: bool = true


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	Setting.changed.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101929"))
	var tex: Texture2D = Skins.texture(slot)
	if tex == null or tex.get_width() <= 0 or tex.get_height() <= 0:
		return
	var texture_size := tex.get_size()
	var available := (size - Vector2(24, 24)).max(Vector2.ONE)
	var image_scale := minf(available.x / texture_size.x, available.y / texture_size.y)
	var image_size := texture_size * image_scale
	var origin := (size - image_size) * 0.5
	var image_rect := Rect2(origin, image_size)
	draw_texture_rect(tex, image_rect, false)
	draw_rect(image_rect, Color("40536f"), false, 1.0)
	if not show_guides:
		return
	var spec: Dictionary = Setting.get_skin(slot)
	var left := clampf(float(spec.get("margin_left", 0)), 0, texture_size.x) * image_scale
	var right := clampf(float(spec.get("margin_right", 0)), 0, texture_size.x) * image_scale
	var top := clampf(float(spec.get("margin_top", 0)), 0, texture_size.y) * image_scale
	var bottom := clampf(float(spec.get("margin_bottom", 0)), 0, texture_size.y) * image_scale
	var guide_color := Color("59ebdf")
	draw_line(origin + Vector2(left, 0), origin + Vector2(left, image_size.y), guide_color, 2.0)
	draw_line(origin + Vector2(image_size.x - right, 0), origin + Vector2(image_size.x - right, image_size.y), guide_color, 2.0)
	draw_line(origin + Vector2(0, top), origin + Vector2(image_size.x, top), guide_color, 2.0)
	draw_line(origin + Vector2(0, image_size.y - bottom), origin + Vector2(image_size.x, image_size.y - bottom), guide_color, 2.0)
