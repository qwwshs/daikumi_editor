extends Node
## 素材服务（Autoload: Skins）
##
## 名字特意加上 s：Godot 4.7 内置了同名类 Skin，autoload 若直接叫 Skin 会被解析成内置类，
## 导致所有 Skins.xxx() 调用在编译期报 “Static function not found in base GDScriptNativeClass”。
##
## 职责：把 Setting 中的“槽位配置”解析成可以直接绘制/播放的东西——纹理、九宫格拉伸、
## 精灵图动画、数字字形与打击音。它只读取 Setting（配置）并借助 ImportAPI 读取文件，
## 不反向依赖设置界面、游玩场景或节点结构，因此可以在任意场景中安全调用。
##
## 槽位一览（与 Setting.SKIN_SLOTS 保持一致）：
##   note_tap / note_hold / note_slide / judge_line —— 九宫格面板
##   hit_tap / hit_hold / hit_slide                —— 单图或精灵图动画
##   digit_0 … digit_9                             —— 分数与连击数字
##   judge_just_plus / judge_just / judge_good / judge_ok / judge_miss
##                                                 —— 判定反馈（默认文字，可换图片）
##   judge_fast / judge_late                       —— 击打延迟显示（默认文字，可换图片）
##   exit / restart                                —— 游玩界面按钮图标
##   sound_tap / sound_hold / sound_slide          —— 打击音
##
## 缓存策略：以“槽位 + 当前路径”作为有效缓存键，路径一变立即重新加载，
## 所以设置界面里的实时预览不需要额外的刷新通知，也不会读到旧素材。

## 未指定自定义素材时使用的内置素材；缺失的槽位返回 null。
const BUILTIN_TEXTURES := {
	"note_tap": "res://assets/img/note.png",
	"note_hold": "res://assets/img/hold_body.png",
	"note_slide": "res://assets/img/wipe.png",
	"judge_line": "res://assets/img/button.png",
	"hit_tap": "res://assets/img/hit.png",
	"hit_hold": "res://assets/img/hit.png",
	"hit_slide": "res://assets/img/hit.png",
	"digit_0": "res://assets/img/font-combo-0.png",
	"digit_1": "res://assets/img/font-combo-1.png",
	"digit_2": "res://assets/img/font-combo-2.png",
	"digit_3": "res://assets/img/font-combo-3.png",
	"digit_4": "res://assets/img/font-combo-4.png",
	"digit_5": "res://assets/img/font-combo-5.png",
	"digit_6": "res://assets/img/font-combo-6.png",
	"digit_7": "res://assets/img/font-combo-7.png",
	"digit_8": "res://assets/img/font-combo-8.png",
	"digit_9": "res://assets/img/font-combo-9.png",
	"exit": "res://assets/img/close.png",
	"restart": "res://assets/img/refresh.png",
}
const BUILTIN_SOUNDS := {
	"tap": "res://assets/sound/hit.ogg",
	"hold": "res://assets/sound/hit.ogg",
	"slide": "res://assets/sound/hit.ogg",
}
## 同时可叠加播放的打击音数量；超过后复用最早的播放器。
const SOUND_POOL_SIZE := 8
const HIT_FADE_RATIO := 0.25
## 单图打击特效在这个比例（相对显示时长）内从 0 放大到当前大小，之后保持满尺寸。
const HIT_SCALE_IN_RATIO := 0.6
## 未导入判定图片时，判定文字使用的颜色（与内置 HUD 的青色一致）。
const GRADE_COLOR := Color("82e4d9")
## 击打延迟显示的两个方向：按早了 fast、按晚了 late（素材槽位 judge_fast / judge_late）。
const OFFSET_WORDS: Array[String] = ["fast", "late"]
## 画成文字时的大写写法；导入图片后这个文字不再出现。
const OFFSET_TEXTS := {"fast": "FAST", "late": "LATE"}
## 文字颜色：提早偏蓝、延迟偏橙，和判定反馈的青色区分得开。
const FAST_COLOR := Color("5aa9ff")
const LATE_COLOR := Color("ff8a5c")
## 判定名与素材槽位的对应关系；"+" 在槽位名里写成 _plus。
const GRADE_SLOTS := {
	"just+": "judge_just_plus",
	"just": "judge_just",
	"good": "judge_good",
	"ok": "judge_ok",
	"miss": "judge_miss",
}

var last_error: String = ""

var _textures: Dictionary = {}        # slot -> {"path": String, "texture": Texture2D}
var _streams: Dictionary = {}         # kind -> {"path": String, "stream": AudioStream}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0


## 开始计时前预热，首次出现音符/判定时不再同步读取资源或创建播放器。
func prepare_gameplay() -> void:
	for slot in Setting.SKIN_SLOTS:
		if not slot.begins_with("sound_"):
			texture(slot)
	for kind in BUILTIN_SOUNDS:
		sound(kind)
	if _players.is_empty():
		_build_player_pool()


## 返回该槽位当前应使用的纹理：自定义素材优先，读不到时回退内置素材。
## 自定义路径可以指向 user://、公有目录或 Android content:// 文档。
func texture(slot: String) -> Texture2D:
	var path := str(Setting.get_skin(slot).get("path", ""))
	var cached: Dictionary = _textures.get(slot, {})
	if cached.get("path", null) == path:
		return cached.get("texture")
	var texture := _load_texture(path, slot)
	_textures[slot] = {"path": path, "texture": texture}
	return texture


func texture_size(slot: String) -> Vector2:
	var value := texture(slot)
	return value.get_size() if value != null else Vector2.ZERO


## 返回该类型当前的打击音。自定义文件失败时回退到内置音效。
func sound(kind: String) -> AudioStream:
	var slot := "sound_" + kind
	var path := str(Setting.get_skin(slot).get("path", ""))
	var cached: Dictionary = _streams.get(kind, {})
	if cached.get("path", null) == path:
		return cached.get("stream")
	var stream := _load_audio(path, kind)
	_streams[kind] = {"path": path, "stream": stream}
	return stream


## 播放一次打击音；音量取槽位音量，总音量由 Hit 音频总线控制。
func play_sound(kind: String) -> void:
	var stream := sound(kind)
	if stream == null:
		return
	if _players.is_empty():
		_build_player_pool()
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	var volume := clampf(float(Setting.get_skin("sound_" + kind).get("volume", 1.0)), 0.0, 1.0)
	player.stream = stream
	player.volume_db = -80.0 if volume <= 0.0 else linear_to_db(volume)
	player.play()


## 丢弃全部缓存；下次绘制时按当前配置重新读取。测试与“重新导入素材”后可用。
func clear_cache() -> void:
	_textures.clear()
	_streams.clear()


## 绘制九宫格面板。边距单位是原图像素，边框按目标高度的比例缩放，从而保持原图比例；
## stretch_mode 为 "center" 时中间区域拉伸、左右两侧保持原宽；
## 为 "sides" 时中间保持原宽、把多出来的宽度平均分给左右两侧。
## 边距全为 0 时退化为普通拉伸。
func draw_panel(canvas: CanvasItem, slot: String, rect: Rect2, reference_height: float = -1.0) -> void:
	var texture_value := texture(slot)
	if texture_value == null:
		return
	_slice_patches(canvas, texture_value, rect, Setting.get_skin(slot), reference_height)


## 单图打击特效的缩放倍率：elapsed 为 0 时是 0，到 duration × HIT_SCALE_IN_RATIO 时是 1；
## 中间由槽位的 scale_curve（三阶贝塞尔 [x1, y1, x2, y2]）决定，允许大于 1 的回弹。
func hit_scale_curve(spec: Dictionary, elapsed: float, duration: float) -> float:
	var curve: Variant = spec.get("scale_curve", null)
	if not (curve is Array) or curve.size() != 4:
		return 1.0
	var progress := clampf(elapsed / maxf(duration * HIT_SCALE_IN_RATIO, 0.001), 0.0, 1.0)
	if progress >= 1.0:
		return 1.0
	var table: Array = curve
	return maxf(0.0, Bezier.bezier(0.0, 1.0, 0.0, 1.0, table, progress))


## 绘制一次打击特效，返回 true 表示下一帧仍需继续绘制。
## elapsed 为已经过秒数；holding 表示这一击是正在保持的 Hold；
## 尺寸取布局设置里的 hit_size（设计像素）乘以 scale。
## 单图素材从 0 开始放大，过程由槽位的 scale_curve（三阶贝塞尔）控制；
## 精灵图仍然按帧播放，不做缩放。
func draw_hit(canvas: CanvasItem, kind: String, center: Vector2, elapsed: float, holding: bool = false, scale: float = 1.0) -> bool:
	if elapsed < 0.0:
		return false
	var slot := "hit_" + kind
	var texture_value := texture(slot)
	if texture_value == null:
		return false
	var spec := Setting.get_skin(slot)
	var columns := maxi(1, int(spec.get("columns", 1)))
	var rows := maxi(1, int(spec.get("rows", 1)))
	var total_frames := columns * rows
	var start := clampi(int(spec.get("start_frame", 0)), 0, maxi(0, total_frames - 1))
	var frames := clampi(int(spec.get("frames", 1)), 1, maxi(1, total_frames - start))
	var frame_duration := maxf(0.001, float(spec.get("frame_duration", 0.05)))
	var duration := maxf(0.001, float(spec.get("duration", 0.3)))
	var looping := bool(spec.get("loop_hold", false))
	# 单图只用“显示时长”；精灵图按帧数与每帧时长播放。
	var sheet := total_frames > 1 or frames > 1
	var alpha := 1.0
	var frame := start
	if sheet:
		if looping and holding:
			# 循环到 Hold 结束：只要还按着就一直播放。
			frame = start + int(elapsed / frame_duration) % frames
		else:
			var played := int(elapsed / frame_duration)
			if played >= frames:
				return false
			frame = start + played
	else:
		if looping and holding:
			pass  # 单图 + 循环到 Hold 结束：保持显示，不做淡出。
		elif elapsed >= duration:
			return false
		else:
			alpha = clampf((duration - elapsed) / maxf(duration * HIT_FADE_RATIO, 0.001), 0.0, 1.0)
	var cell := Vector2(texture_value.get_width() / float(columns), texture_value.get_height() / float(rows))
	if cell.x <= 0.0 or cell.y <= 0.0:
		return false
	# 等比缩放让整个单元格落在 hit_size 方框内，避免非方形素材被拉伸变形。
	# 单图额外乘上缩放曲线的进度倍率（0 → 1）。
	var curve_scale := 1.0 if sheet else hit_scale_curve(spec, elapsed, duration)
	var fit := maxf(1.0, float(Setting.layout.hit_size)) * scale * curve_scale / maxf(cell.x, cell.y)
	var size := cell * fit
	var target := Rect2(center - size * 0.5, size)
	if total_frames <= 1:
		canvas.draw_texture_rect(texture_value, target, false, Color(1, 1, 1, alpha))
	else:
		var column := frame % columns
		var row := frame / columns
		canvas.draw_texture_rect_region(texture_value, target, Rect2(column * cell.x, row * cell.y, cell.x, cell.y), Color(1, 1, 1, alpha))
	return true


## 居中绘制一串数字；数字使用各自的素材，其他字符（如负号）回退到内置字体。
func draw_number(canvas: CanvasItem, text: String, center_top: Vector2, height: float) -> void:
	if text.is_empty() or height <= 0.0:
		return
	var font := ThemeDB.fallback_font
	var font_size := maxi(1, int(roundf(height)))
	var glyphs: Array[Dictionary] = []
	var total_width := 0.0
	for index in text.length():
		var character := text[index]
		var texture_value := texture("digit_" + character) if character.is_valid_int() else null
		var width := height * float(texture_value.get_width()) / maxf(float(texture_value.get_height()), 1.0) if texture_value != null \
			else font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		glyphs.append({"texture": texture_value, "character": character, "width": width})
		total_width += width
	var cursor := center_top.x - total_width * 0.5
	for glyph in glyphs:
		if glyph.texture != null:
			# 数字素材按高度对齐，宽度保持原图比例。
			canvas.draw_texture_rect(glyph.texture, Rect2(cursor, center_top.y, glyph.width, height), false, Color.WHITE)
		else:
			canvas.draw_string(font, Vector2(cursor, center_top.y + font.get_ascent(font_size)), glyph.character,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		cursor += glyph.width


## 判定名 → 素材槽位。未知判定（外部读取器可能自定义判定名）也会得到稳定的槽位名，
## 只是没有对应素材，绘制时仍然回退成文字。
func grade_slot(grade: String) -> String:
	if GRADE_SLOTS.has(grade):
		return GRADE_SLOTS[grade]
	return "judge_" + grade.replace("+", "_plus")


## 该判定当前使用的自定义图片；没有导入时返回 null，由 draw_grade 回退成文字。
func grade_texture(grade: String) -> Texture2D:
	var slot := grade_slot(grade)
	# 只认槽位表里存在的判定，避免未知判定名往设置里写入没有意义的键。
	return texture(slot) if Setting.skin.has(slot) else null


## 绘制判定反馈：导入过图片就画图片（按 height 等比缩放，宽度自适应），否则居中画判定文字。
## center_top 是显示区域顶部中点，与 draw_number 的对齐方式一致。
func draw_grade(canvas: CanvasItem, grade: String, center_top: Vector2, height: float, color: Color = GRADE_COLOR) -> void:
	if grade.is_empty():
		return
	_draw_feedback(canvas, grade_texture(grade), grade, center_top, height, color)


## 偏差（秒，正数 = 按晚了）→ 方向名。HUD 的击打延迟显示用它挑槽位与文字。
func offset_word(offset: float) -> String:
	return "fast" if offset < 0.0 else "late"


func offset_color(word: String) -> Color:
	return FAST_COLOR if word == "fast" else LATE_COLOR


## 绘制击打延迟显示：judge_fast / judge_late 导入过图片就画图片（与判定反馈同一套缩放），
## 否则画 FAST / LATE 文字。方向名只有 fast / late 两个，别的一律当作 late 之外的空名。
func draw_offset_word(canvas: CanvasItem, word: String, center_top: Vector2, height: float) -> void:
	if not OFFSET_WORDS.has(word):
		return
	var slot := "judge_" + word
	_draw_feedback(canvas, texture(slot) if Setting.skin.has(slot) else null,
		str(OFFSET_TEXTS.get(word, word)), center_top, height, offset_color(word))


## 判定反馈与击打延迟显示共用的绘制：有图片画图片，没有就居中画文字。
func _draw_feedback(canvas: CanvasItem, texture_value: Texture2D, text: String, center_top: Vector2, height: float, color: Color) -> void:
	if height <= 0.0:
		return
	if texture_value != null and texture_value.get_height() > 0.0:
		var image_width := height * float(texture_value.get_width()) / float(texture_value.get_height())
		canvas.draw_texture_rect(texture_value, Rect2(center_top.x - image_width * 0.5, center_top.y, image_width, height), false, Color.WHITE)
		return
	var font := ThemeDB.fallback_font
	var font_size := maxi(1, int(roundf(height)))
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, Vector2(center_top.x - text_width * 0.5, center_top.y + font.get_ascent(font_size)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _slice_patches(canvas: CanvasItem, texture_value: Texture2D, rect: Rect2, spec: Dictionary, reference_height: float = -1.0) -> void:
	var source := texture_value.get_size()
	if source.x <= 0.0 or source.y <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var left := clampf(float(spec.get("margin_left", 0.0)), 0.0, source.x * 0.5)
	var right := clampf(float(spec.get("margin_right", 0.0)), 0.0, source.x * 0.5)
	var top := clampf(float(spec.get("margin_top", 0.0)), 0.0, source.y * 0.5)
	var bottom := clampf(float(spec.get("margin_bottom", 0.0)), 0.0, source.y * 0.5)
	# 以目标高度为基准换算边框，保证四角与四边的图形比例与原图一致。
	# Hold 长度只拉伸中段，切片比例按单个 Note 高度固定。
	var ratio := (reference_height if reference_height > 0.0 else rect.size.y) / source.y
	var border_left := left * ratio
	var border_right := right * ratio
	var border_top := top * ratio
	var border_bottom := bottom * ratio
	# 目标区域小于边框总宽/高时整体压缩，避免九宫格互相重叠绘制。
	var shrink_x := minf(1.0, rect.size.x / maxf(border_left + border_right, 0.0001))
	var shrink_y := minf(1.0, rect.size.y / maxf(border_top + border_bottom, 0.0001))
	border_left *= shrink_x
	border_right *= shrink_x
	border_top *= shrink_y
	border_bottom *= shrink_y
	var source_center := Vector2(source.x - left - right, source.y - top - bottom)
	var target_center := Vector2(rect.size.x - border_left - border_right, rect.size.y - border_top - border_bottom)
	if str(spec.get("stretch_mode", "center")) == "sides" and source_center.x > 0.0:
		# 中间保持原图宽度，多出来的宽度平均分给左右两边。
		var native_center := minf(source_center.x * ratio, target_center.x)
		var extra := (target_center.x - native_center) * 0.5
		target_center.x = native_center
		border_left += extra
		border_right += extra
	var source_x := [0.0, left, source.x - right]
	var source_width := [left, source_center.x, right]
	var target_x := [rect.position.x, rect.position.x + border_left, rect.end.x - border_right]
	var target_width := [border_left, target_center.x, border_right]
	var source_y := [0.0, top, source.y - bottom]
	var source_height := [top, source_center.y, bottom]
	var target_y := [rect.position.y, rect.position.y + border_top, rect.end.y - border_bottom]
	var target_height := [border_top, target_center.y, border_bottom]
	for row in 3:
		for column in 3:
			if source_width[column] <= 0.0 or source_height[row] <= 0.0:
				continue
			if target_width[column] <= 0.0 or target_height[row] <= 0.0:
				continue
			canvas.draw_texture_rect_region(texture_value,
				Rect2(target_x[column], target_y[row], target_width[column], target_height[row]),
				Rect2(source_x[column], source_y[row], source_width[column], source_height[row]))


func _load_texture(path: String, slot: String) -> Texture2D:
	if not path.is_empty():
		var custom := _read_texture(path)
		if custom != null:
			return custom
		last_error = "无法读取自定义素材，已回退到内置素材：%s" % path
		push_warning(last_error)
	var builtin: String = BUILTIN_TEXTURES.get(slot, "")
	if builtin.is_empty():
		return null
	var resource := load(builtin)
	return resource if resource is Texture2D else null


func _read_texture(path: String) -> Texture2D:
	if path.begins_with("res://"):
		var resource := load(path)
		return resource if resource is Texture2D else null
	# 外部路径交给公共导入接口，它支持 PNG / JPEG / WebP 与 content:// 文档。
	return ImportAPI.load_background(path)


func _load_audio(path: String, kind: String) -> AudioStream:
	if not path.is_empty():
		var custom := ImportAPI.load_audio(path) if not path.begins_with("res://") else load(path)
		if custom is AudioStream:
			return custom
		last_error = "无法读取自定义打击音，已回退到内置音效：%s" % path
		push_warning(last_error)
	var builtin: String = BUILTIN_SOUNDS.get(kind, "")
	if builtin.is_empty():
		return null
	var resource := load(builtin)
	return resource if resource is AudioStream else null


func _build_player_pool() -> void:
	# 打击音会重叠播放，因此用一组播放器轮流复用，而不是互相打断。
	for _index in SOUND_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Hit"
		add_child(player)
		_players.append(player)
