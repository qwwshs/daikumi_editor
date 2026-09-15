extends RefCounted
## 选曲与结算共用的界面构件：尺寸、配色、卡片造型都与设置界面一致
## （边距 22、卡片标题 24、按钮高 48、提示文字用 TEXT_DISABLED、滚轮/拖动滚动见 TouchScroll）。
const Style = preload("res://gd/ui/imgui_theme.gd")
## 判定色在 Skins 里，而这里是静态函数：直接读脚本常量，不依赖 autoload 节点。
const SkinStyle = preload("res://gd/services/skin.gd")
## 判定从高到低；结算的成绩卡与选曲的最佳成绩面板共用这一套顺序与名字。
const GRADES: Array[String] = ["just+", "just", "good", "ok", "miss"]
const GRADE_NAMES: Array[String] = ["JUST+", "JUST", "GOOD", "OK", "MISS"]


## 整屏外壳：铺底、外边距、纵向主容器。返回的容器由调用方继续填充。
static func shell(owner: Control) -> VBoxContainer:
	owner.theme = Style.build()
	var background := ColorRect.new()
	background.color = Style.APP_BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	owner.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	return box


## 卡片：ImGui 窗口造型，第一行是 24px 白色标题，返回可以继续放内容的容器。
static func card(parent: Node, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	label(content, title, 24)
	return content


## 纵向容器（默认撑满可用空间），用于卡片内部或页内容。
static func column(parent: Node, separation: int = 16) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box


## 可拖拽滚动的页：竖直方向滚动，横向铺满；内容用 column() 放进去。
## 页本身声明 IGNORE，手指拖动交给界面根节点统一处理（见 TouchScroll）。
static func page(parent: Node) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(scroll)
	return scroll


static func label(parent: Node, text: String, font_size: int = 22, muted: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	if muted:
		node.add_theme_color_override("font_color", Style.TEXT_DISABLED)
	parent.add_child(node)
	return node


## 说明文字：小一号、灰、自动换行，和设置界面里的提示一致。
static func hint(parent: Node, text: String) -> Label:
	var node := label(parent, text, 18, true)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func button(parent: Node, text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 48
	node.pressed.connect(action)
	parent.add_child(node)
	return node


## 歌曲背景：底衬是卡片里的一层 1px 边框，图片按比例填满并裁剪。
static func artwork(parent: Node) -> TextureRect:
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	var texture := TextureRect.new()
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture.custom_minimum_size.y = 180
	texture.clip_contents = true
	frame.add_child(texture)
	return texture


## 谱面库列表：造型来自主题（ItemList），这里只加尺寸与手势相关的设置。
## mouse_filter 保持 PASS：列表自己不响应手指拖动，改成 PASS 后手势上抛给根节点滚动，
## 轻点选中走的仍是引擎生成的模拟鼠标事件，不受影响。
static func chart_list(parent: Node) -> ItemList:
	var control := ItemList.new()
	control.name = "ChartList"
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size = Vector2(240, 180)
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(control)
	return control


# ---------------------------------------------------------------- 谱面信息

static func title(info: Dictionary, fallback: String = "未命名歌曲") -> String:
	var value := str(info.get("song_name", "")).strip_edges()
	return fallback if value.is_empty() else value


static func difficulty(info: Dictionary) -> String:
	var value := str(info.get("difficulty", info.get("chart_name", ""))).strip_edges()
	var level := str(info.get("level", "")).strip_edges()
	return (value + (" · " + level if not level.is_empty() else "")) if not value.is_empty() else (level if not level.is_empty() else "未标注难度")


static func artist(info: Dictionary) -> String:
	var value := str(info.get("artist", "")).strip_edges()
	return value if not value.is_empty() else "未标注曲师"


static func credits(info: Dictionary) -> String:
	var charter := str(info.get("chartor", "")).strip_edges()
	return "曲师  " + artist(info) + ("    /    谱师  " + charter if not charter.is_empty() else "")


static func duration(seconds: float) -> String:
	var value := maxi(0, int(seconds))
	return "%02d:%02d" % [value / 60, value % 60]


# ---------------------------------------------------------------- 成绩

## 分数：七位补零，和游玩中的 HUD、结算界面同一套写法。
static func score_text(value: int) -> String:
	return str(maxi(0, value)).pad_zeros(7)


## 判定配色：Miss 用错误红，其余沿用游玩内的判定色（结算界面也是这套）。
static func grade_color(grade: String) -> Color:
	return Style.ERROR_TEXT if grade == "miss" else SkinStyle.GRADE_COLOR


## 判定模式的中文名；设置、选曲状态行与成绩提示共用，免得各写一份对不上。
static func mode_name(mode: String) -> String:
	return "音符时刻位置判定" if mode == Setting.JUDGE_POSITION_NOTE else "当前时刻位置判定"


## 本地日期（YYYY-MM-DD）；时间戳无效时返回空串，调用方据此决定要不要显示。
static func date(unix_time: int) -> String:
	if unix_time <= 0:
		return ""
	return Time.get_date_string_from_unix_time(unix_time)


## 平均击打延迟读数：秒 → 「+12.3 ms · 偏晚（214 次按下）」。
## 正数 = 按晚了、负数 = 按早了；样本为 0（这一局没有按下过 Tap / Hold）时返回空串。
static func latency_text(seconds: float, samples: int) -> String:
	var brief := latency_brief(seconds, samples)
	return "" if brief.is_empty() else "%s（%d 次按下）" % [brief, samples]


## 短读数：「+12.3 ms · 偏晚」。成绩面板那一行已经挤了连击和游玩次数，省掉样本数。
## 半个毫秒以内当作「几乎没有偏差」：这个量级已经是输入与显示的噪声了。
static func latency_brief(seconds: float, samples: int) -> String:
	if samples <= 0:
		return ""
	var value := snappedf(seconds * 1000.0, 0.1)
	var direction := "偏晚" if value > 0.5 else ("偏早" if value < -0.5 else "几乎没有偏差")
	return "%s%s ms · %s" % ["+" if value > 0.0 else "", String.num(value, 1), direction]


# ---------------------------------------------------------------- 音频延迟读数

## 毫秒读数：整数毫秒不带小数尾巴，正数补上「+」方便看出方向。
## 负零也按 0 打印：谱面偏移那一项是取反后印的，0 会变成 -0.0，读出来是「-0 ms」。
static func ms(value: float) -> String:
	var shown := 0.0 if value == 0.0 else value
	var text := String.num(shown, 3)
	if text.ends_with(".0"):
		text = text.trim_suffix(".0")
	return "+" + text if shown > 0.0 else text


## 最终延迟 = 单曲延迟 + 时间偏移 - 谱面偏移 + 谱面自带 offset，四个数之和就是游玩时用的那个值
## （见 ChartLoader.total_offset_seconds）。各界面共用这一份格式，读数不会各说各话。
## 「谱面偏移」与时间偏移互为反号，所以这里直接印它取反后的贡献值：每个数都是相加项，
## 玩家不用在心里做减法，也不用去猜正负该怎么算（括号里的说明就是提醒这件事）。
static func offset_breakdown(song: float, global_offset: float, chart_shift: float, chart: float) -> String:
	return "最终延迟 = 单曲 %s ms + 时间偏移 %s ms + 谱面偏移（反向）%s ms + 谱面自带 offset %s ms = %s ms" % [
		ms(song), ms(global_offset), ms(-chart_shift), ms(chart),
		ms(song + global_offset - chart_shift + chart)]
