extends RefCounted
## Dear ImGui 深色主题：方角、1px 边框、蓝色强调色。
##
## 取色直接来自 ImGui 的 StyleColorsDark（imgui_draw.cpp）：
##   WindowBg (0.06,0.06,0.06,0.94)   FrameBg (0.16,0.29,0.48,0.54)
##   Button   (0.26,0.59,0.98,0.40)   ButtonActive (0.06,0.53,0.98,1.00)
##   CheckMark / SliderGrabActive 同色 (0.26,0.59,0.98,1.00)
##   Border (0.43,0.43,0.50,0.50)     TextDisabled (0.50,0.50,0.50,1.00)
## 所有圆角为 0、边框 1px，与 ImGui 的方角风格一致。
##
## 用法：theme = ImGuiTheme.build()
##
## 复选框方框、滑块色条、下拉箭头、微调箭头这几个图标都在运行时用 Image 生成，
## 不依赖 Godot 默认主题的造型，所以整套外观是自洽的，换引擎版本也不会走样。
##
## 唯一有意保留差异的是尺寸：ImGui 桌面版控件高约 19px，触屏上无法准确点按，
## 因此这里只照搬配色、直角与紧凑间距，控件高度仍由设置界面按可触摸尺寸给出。

## 控件尺寸（IMGUI 的桌面尺寸在手机上太小，这里只固定“造型”相关的部分）。
const BOX_SIZE := 20          # 复选框方框边长
const GRABBER_SIZE := Vector2i(18, 14)   # 滑块把手：竖直色条，与轨道等高
const TRACK_MARGIN := 7       # 轨道/滚动条半高，两倍后就是可见高度
const FRAME_MARGIN := Vector2i(10, 7)    # 输入框、按钮的内边距

const TEXT := Color(1.0, 1.0, 1.0, 1.0)
const TEXT_DISABLED := Color(0.50, 0.50, 0.50, 1.0)
const ACCENT := Color(0.26, 0.59, 0.98, 1.0)
const BUTTON := Color(0.26, 0.59, 0.98, 0.40)
const BUTTON_HOVER := Color(0.26, 0.59, 0.98, 1.0)
const BUTTON_ACTIVE := Color(0.06, 0.53, 0.98, 1.0)
const DISABLED_BG := Color(0.16, 0.29, 0.48, 0.20)
const FRAME_BG := Color(0.16, 0.29, 0.48, 0.54)
const FRAME_BG_ACTIVE := Color(0.26, 0.59, 0.98, 0.67)
const WINDOW_BG := Color(0.06, 0.06, 0.06, 1.0)
const APP_BG := Color(0.0, 0.0, 0.0, 1.0)
const POPUP_BG := Color(0.08, 0.08, 0.08, 1.0)
const MENU_HOVER := Color(0.26, 0.59, 0.98, 0.80)
const BORDER := Color(0.43, 0.43, 0.50, 0.50)
const SCROLL_BG := Color(0.02, 0.02, 0.02, 0.53)
const SCROLL_GRAB := Color(0.31, 0.31, 0.31, 1.0)
const SCROLL_GRAB_HOVER := Color(0.41, 0.41, 0.41, 1.0)
const SCROLL_GRAB_ACTIVE := Color(0.51, 0.51, 0.51, 1.0)
const SLIDER_GRAB := Color(0.24, 0.52, 0.88, 1.0)
## 状态提示用色：错误偏红，普通提示用 ImGui 的 TextDisabled。
const ERROR_TEXT := Color(0.94, 0.42, 0.42, 1.0)


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", TEXT)
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("separation", "HBoxContainer", 8)

	# 按钮、下拉框：ImGui 的半透明蓝底 + 白字，按下时变得最亮。
	for control_type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", control_type, _flat(BUTTON))
		theme.set_stylebox("hover", control_type, _flat(BUTTON_HOVER))
		theme.set_stylebox("pressed", control_type, _flat(BUTTON_ACTIVE))
		theme.set_stylebox("disabled", control_type, _flat(DISABLED_BG))
		theme.set_stylebox("focus", control_type, _outline(ACCENT, 2))
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(color_name, control_type, TEXT)
		theme.set_color("font_disabled_color", control_type, TEXT_DISABLED)
	theme.set_constant("arrow_margin", "OptionButton", 8)
	theme.set_icon("arrow", "OptionButton", _triangle_icon(Vector2i(11, 6), false, TEXT))

	# 复选框：方框本身就是图标（含边框、填充和勾），所以背景保持透明，
	# 只有获得焦点时画一圈强调色边框，方便手柄 / 键盘导航。
	theme.set_stylebox("normal", "CheckBox", _flat(Color.TRANSPARENT, Vector2i(2, 2)))
	theme.set_stylebox("hover", "CheckBox", _flat(Color.TRANSPARENT, Vector2i(2, 2)))
	theme.set_stylebox("hover_pressed", "CheckBox", _flat(Color.TRANSPARENT, Vector2i(2, 2)))
	theme.set_stylebox("pressed", "CheckBox", _flat(Color.TRANSPARENT, Vector2i(2, 2)))
	theme.set_stylebox("disabled", "CheckBox", _flat(Color.TRANSPARENT, Vector2i(2, 2)))
	theme.set_stylebox("focus", "CheckBox", _outline(ACCENT, 2))
	theme.set_icon("checked", "CheckBox", _checkbox_icon(true))
	theme.set_icon("unchecked", "CheckBox", _checkbox_icon(false))
	theme.set_icon("checked_disabled", "CheckBox", _checkbox_icon(true, true))
	theme.set_icon("unchecked_disabled", "CheckBox", _checkbox_icon(false, true))
	# 图标里已经带好颜色，避免引擎再按默认色调制一次。
	theme.set_color("checkbox_checked_color", "CheckBox", Color.WHITE)
	theme.set_color("checkbox_unchecked_color", "CheckBox", Color.WHITE)
	theme.set_constant("h_separation", "CheckBox", 8)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "CheckBox", TEXT)
	theme.set_color("font_disabled_color", "CheckBox", TEXT_DISABLED)

	# 卡片与窗口：WindowBg 配 1px 边框，正是 ImGui 窗口的样子。
	theme.set_stylebox("panel", "PanelContainer", _flat(WINDOW_BG, Vector2i(14, 12), BORDER, 1))

	# 列表（选曲界面的谱面库）：底色比卡片更暗，选中项用按钮蓝，行距放宽便于手指点按。
	theme.set_stylebox("panel", "ItemList", _flat(SCROLL_BG))
	theme.set_stylebox("selected", "ItemList", _flat(BUTTON))
	theme.set_stylebox("selected_focus", "ItemList", _flat(BUTTON_ACTIVE))
	theme.set_color("font_color", "ItemList", TEXT)
	theme.set_color("font_selected_color", "ItemList", TEXT)
	theme.set_constant("v_separation", "ItemList", 24)
	theme.set_font_size("font_size", "ItemList", 24)

	# 输入框：ImGui 的 FrameBg 是偏蓝的灰，聚焦时变亮。
	theme.set_stylebox("normal", "LineEdit", _flat(FRAME_BG, FRAME_MARGIN))
	theme.set_stylebox("focus", "LineEdit", _flat(FRAME_BG_ACTIVE, FRAME_MARGIN, ACCENT, 1))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", TEXT)
	theme.set_color("selection_color", "LineEdit", ACCENT)

	# 数值框的上下箭头；未悬停时用合并图标，悬停时引擎会叠上单边箭头。
	theme.set_icon("updown", "SpinBox", _updown_icon())
	theme.set_icon("up", "SpinBox", _triangle_icon(Vector2i(9, 6), true, TEXT))
	theme.set_icon("down", "SpinBox", _triangle_icon(Vector2i(9, 6), false, TEXT))
	for color_name in ["up_icon_modulate", "up_hover_icon_modulate", "up_pressed_icon_modulate",
			"down_icon_modulate", "down_hover_icon_modulate", "down_pressed_icon_modulate"]:
		theme.set_color(color_name, "SpinBox", TEXT)
	theme.set_color("up_disabled_icon_modulate", "SpinBox", TEXT_DISABLED)
	theme.set_color("down_disabled_icon_modulate", "SpinBox", TEXT_DISABLED)
	theme.set_constant("buttons_width", "SpinBox", 28)

	# 滑块：轨道是 FrameBg，把手是 SliderGrab 竖直色条。
	# 已填充部分用同色的 grabber_area 覆盖：半透明的 FrameBg 叠两次会略亮一点，
	# 于是能看出“已填充”的边界，又不会像 ImGui 那样出现明显的高亮条。
	theme.set_stylebox("slider", "HSlider", _flat(FRAME_BG, Vector2i(TRACK_MARGIN, TRACK_MARGIN)))
	theme.set_stylebox("grabber_area", "HSlider", _flat(FRAME_BG, Vector2i(TRACK_MARGIN, TRACK_MARGIN)))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _flat(FRAME_BG, Vector2i(TRACK_MARGIN, TRACK_MARGIN)))
	theme.set_icon("grabber", "HSlider", _grabber_icon(SLIDER_GRAB))
	theme.set_icon("grabber_highlight", "HSlider", _grabber_icon(ACCENT))
	theme.set_icon("grabber_disabled", "HSlider", _grabber_icon(TEXT_DISABLED))
	theme.set_constant("grabber_offset", "HSlider", 0)

	# 滚动条：方角细条，滚动条背景几乎全黑。
	for scroll_type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", scroll_type, _flat(SCROLL_BG, Vector2i(TRACK_MARGIN, TRACK_MARGIN)))
		theme.set_stylebox("scroll_focus", scroll_type, _flat(SCROLL_BG, Vector2i(TRACK_MARGIN, TRACK_MARGIN)))
		theme.set_stylebox("grabber", scroll_type, _flat(SCROLL_GRAB, Vector2i(TRACK_MARGIN, TRACK_MARGIN)))
		theme.set_stylebox("grabber_highlight", scroll_type, _flat(SCROLL_GRAB_HOVER, Vector2i(TRACK_MARGIN, TRACK_MARGIN)))
		theme.set_stylebox("grabber_pressed", scroll_type, _flat(SCROLL_GRAB_ACTIVE, Vector2i(TRACK_MARGIN, TRACK_MARGIN)))

	# 下拉菜单与对话框。
	theme.set_stylebox("panel", "PopupMenu", _flat(POPUP_BG, Vector2i(6, 6), BORDER, 1))
	theme.set_stylebox("hover", "PopupMenu", _flat(MENU_HOVER, Vector2i(6, 4)))
	theme.set_stylebox("separator", "PopupMenu", _line(BORDER))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", TEXT)
	theme.set_color("font_disabled_color", "PopupMenu", TEXT_DISABLED)
	theme.set_constant("v_separation", "PopupMenu", 8)
	theme.set_stylebox("panel", "AcceptDialog", _flat(WINDOW_BG, Vector2i(14, 12), BORDER, 1))
	theme.set_constant("buttons_min_width", "AcceptDialog", 96)
	theme.set_constant("buttons_min_height", "AcceptDialog", 44)
	theme.set_constant("buttons_separation", "AcceptDialog", 10)
	theme.set_font_size("title_font_size", "Window", 20)
	theme.set_color("title_color", "Window", TEXT)
	theme.set_constant("title_height", "Window", 30)
	theme.set_stylebox("embedded_border", "Window", _flat(WINDOW_BG, Vector2i(10, 8), BORDER, 1))
	return theme


## 直角 StyleBox。ImGui 的所有圆角都是 0，边框默认 1px。
static func _flat(bg: Color, margin: Vector2i = FRAME_MARGIN, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(0)
	box.content_margin_left = margin.x
	box.content_margin_right = margin.x
	box.content_margin_top = margin.y
	box.content_margin_bottom = margin.y
	if border_width > 0 and border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(border_width)
	return box


## 只描边的 StyleBox：用于焦点提示，不改变控件的底色。
static func _outline(color: Color, width: int) -> StyleBoxFlat:
	var box := _flat(Color.TRANSPARENT, Vector2i(2, 2), color, width)
	return box


## 1px 横线，用作菜单分隔条。
static func _line(color: Color) -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = color
	line.thickness = 1
	return line


# ---------------------------------------------------------------- 运行时生成的图标

static func _checkbox_icon(checked: bool, disabled: bool = false) -> ImageTexture:
	var image := Image.create_empty(BOX_SIZE, BOX_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var fill := Color(0.16, 0.29, 0.48, 0.20) if disabled else FRAME_BG
	var border := Color(0.43, 0.43, 0.50, 0.30) if disabled else BORDER
	var mark := TEXT_DISABLED if disabled else ACCENT
	for y in BOX_SIZE:
		for x in BOX_SIZE:
			var edge := x == 0 or y == 0 or x == BOX_SIZE - 1 or y == BOX_SIZE - 1
			image.set_pixel(x, y, border if edge else fill)
	if checked:
		# 勾：两段折线，比例照搬 ImGui 的方框勾形。
		_stroke(image, Vector2(5.0, 10.5), Vector2(8.5, 14.0), mark)
		_stroke(image, Vector2(8.5, 14.0), Vector2(14.5, 6.0), mark)
	return ImageTexture.create_from_image(image)


static func _grabber_icon(color: Color) -> ImageTexture:
	var image := Image.create_empty(GRABBER_SIZE.x, GRABBER_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


static func _triangle_icon(size: Vector2i, up: bool, color: Color) -> ImageTexture:
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_paint_triangle(image, Rect2i(Vector2i.ZERO, size), up, color)
	return ImageTexture.create_from_image(image)


## 微调按钮的合并图标：上面一个向上箭头，下面一个向下箭头。
static func _updown_icon() -> ImageTexture:
	var width := 11
	var height := 6
	var gap := 3
	var image := Image.create_empty(width, height * 2 + gap, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_paint_triangle(image, Rect2i(0, 0, width, height), true, TEXT)
	_paint_triangle(image, Rect2i(0, height + gap, width, height), false, TEXT)
	return ImageTexture.create_from_image(image)


static func _paint_triangle(image: Image, area: Rect2i, up: bool, color: Color) -> void:
	for row in area.size.y:
		# 宽度从尖端到底边线性增长，得到等腰三角形。
		var ratio := (float(row) + 0.5) / float(maxi(area.size.y, 1))
		var half := (ratio if up else 1.0 - ratio) * float(area.size.x) * 0.5
		var center := float(area.size.x) * 0.5
		for column in area.size.x:
			if absf(float(column) + 0.5 - center) <= half:
				image.set_pixel(area.position.x + column, area.position.y + row, color)


## 用圆形笔刷画一段粗线；尺寸很小，不需要抗锯齿。
static func _stroke(image: Image, from: Vector2, to: Vector2, color: Color, thickness: float = 2.0) -> void:
	var radius := maxf(thickness, 1.0) * 0.5
	var steps := int(maxf(absf(to.x - from.x), absf(to.y - from.y)) * 2.0) + 1
	for step in steps + 1:
		var point := from.lerp(to, float(step) / float(steps))
		for offset_y in range(-2, 3):
			for offset_x in range(-2, 3):
				if Vector2(offset_x, offset_y).length() > radius + 0.25:
					continue
				var x := int(round(point.x)) + offset_x
				var y := int(round(point.y)) + offset_y
				if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
					continue
				image.set_pixel(x, y, color)
