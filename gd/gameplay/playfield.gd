class_name Playfield
extends Node2D
## 正式游玩与设置预览共用绘制器；不创建每个音符的场景节点。
##
## 倾斜用真正的 3D 实现，参数在 playfield_geometry.gd 里推导：
##   · 轨道内容（轨道线、游玩区域两侧的侧线、Note、判定线、打击特效）先画进一张 2D 画布
##     （_field_viewport）。画布比画面高：判定线上方多出来的行就是“能看到多远”，
##     画布顶端本身就在画面顶端之上（镜头随角度后退保证灭线一直在画面之上），
##     所以游玩区域一直铺到屏幕顶端、Note 从屏幕顶端进入，不会中途截断。
##   · Note 的下落幅度取“判定线到屏幕顶端的画布距离”（geometry.y），因此不管倾斜多少度、
##     接近曲线怎么调，Note 都在屏幕顶端刚好出现、不会在画面中途凭空冒出来。
##     从屏幕顶端落到判定线的时间就是 lookahead = 10 / 流速（秒），流速越大越快、同屏越少。
##   · 画布贴到 3D 舞台上的一块平面（QuadMesh）：平面绕过判定线中点的水平轴旋转
##     track_angle，相机放在判定线正前方、用偏心视锥把判定线压到画面 judge_y 那一行。
##     平面带透明通道，所以画布没画到的地方露出下面的 2D 背景。
##   · 平面按 1 / cos(角度) 纵向预拉伸，所以判定线（含中点）与不倾斜时逐像素一致，
##     触摸换算不需要逆变换；3D 光栅化的贴图采样是透视正确的，这正是之前 Hold
##     在倾斜下被拉长的根因。
##   · 角度为 0 时投影退化成恒等变换，与旧的平面绘制完全一致。
## 背景是普通 2D：铺满整个画面、不参与倾斜，和 HUD 一样只画在主视口里。

## 手指按住轨道时给的一点反馈：背景更实、线更亮（不改变黑白配色）。
const TOUCH_ALPHA_BOOST := 0.2
## 进度条：贴着屏幕顶边的一条白线，按谱面时钟从左到右伸长，走完刚好覆盖整条顶边。
## 只在真的有会话（正式游玩）时出现：预览与 3D 舞台自检的探针没有会话，
## 画面顶端那几行要留给轨道内容。
const PROGRESS_HEIGHT := 5.0
## 已走过的部分是亮白，没走到的部分压暗当底，两种情况都能看出歌还剩多少。
const PROGRESS_ALPHA := 0.95
const PROGRESS_TRACK_ALPHA := 0.22
## 轨道层画布的分辨率上限：避免高分辨率设备上 2D 画布过大。
const MAX_DEVICE_SCALE := 2.0
## 预览里上一颗音符越过判定线多久之后排下一颗（秒）。
const PREVIEW_GAP := 1.6


## 子层只把绘制回调转交给 Playfield，好处是分层而不必为内容建场景节点。
class FieldLayer extends Node2D:
	var field: Playfield

	func _draw() -> void:
		field.draw_field(self)


## 背景层：普通 2D，铺满整个画面，不参与倾斜。
class BackLayer extends Node2D:
	var field: Playfield

	func _draw() -> void:
		field.draw_background(self)


class HudLayer extends Node2D:
	var field: Playfield

	func _draw() -> void:
		field.draw_hud(self)


var geometry := PlayfieldGeometry.new()
var session: PlaySession
var preview_kind: String = "all"
var preview_sound: bool = false
var preview: bool = false
var background: Texture2D:
	set(value):
		background = value
		if is_instance_valid(_back_layer):
			_back_layer.queue_redraw()
var _view_size := Vector2(1600, 900)
var _elapsed: float = 0.0
var _display_grade: String = ""
## 击打延迟显示：当前要显示的方向名（fast / late，空 = 不显示）与出现的时刻。
var _offset_word: String = ""
var _offset_start: float = 0.0
var _field_viewport: SubViewport
var _stage_viewport: SubViewport
var _field_layer: FieldLayer
var _back_layer: BackLayer
var _hud_layer: HudLayer
var _display: TextureRect
var _camera: Camera3D
var _plane: MeshInstance3D
var _plane_mesh: QuadMesh
var _plane_material: StandardMaterial3D
var _hits: Array[Dictionary] = []
var _hold_hits: Dictionary = {}
var _preview_previous: Dictionary = {}
var _preview_judges: Dictionary = {}


func _ready() -> void:
	# 轨道层画布：内容是 2D 的，分辨率按设备像素放大，倾斜后依然清晰。
	_field_viewport = SubViewport.new()
	_field_viewport.disable_3d = true
	# 画布本身要透明：没画到轨道的地方要露出下面的 2D 背景。
	_field_viewport.transparent_bg = true
	_field_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_field_viewport)
	_field_layer = FieldLayer.new()
	_field_layer.field = self
	_field_viewport.add_child(_field_layer)
	# 3D 舞台：一张贴了画布的平面 + 一台偏心视锥的相机。
	_stage_viewport = SubViewport.new()
	_stage_viewport.own_world_3d = true
	# 舞台要透出下面的 2D 背景，所以两边都开透明：视口清成透明，平面按 alpha 混合。
	_stage_viewport.transparent_bg = true
	_stage_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_stage_viewport)
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_stage_viewport.add_child(_camera)
	_plane_material = StandardMaterial3D.new()
	_plane_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_plane_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_plane_material.albedo_texture = _field_viewport.get_texture()
	_plane_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_plane_mesh = QuadMesh.new()
	_plane_mesh.orientation = PlaneMesh.FACE_Z
	_plane_mesh.material = _plane_material
	_plane = MeshInstance3D.new()
	_plane.mesh = _plane_mesh
	_stage_viewport.add_child(_plane)
	# 背景层是普通 2D：铺满整个画面，在舞台贴图下面。
	_back_layer = BackLayer.new()
	_back_layer.field = self
	_back_layer.z_index = -1
	add_child(_back_layer)
	# 舞台结果按 1:1 铺在主视口上，HUD 再盖在它上面（不参与倾斜）。
	_display = TextureRect.new()
	_display.texture = _stage_viewport.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)
	_hud_layer = HudLayer.new()
	_hud_layer.field = self
	_hud_layer.z_index = 1
	add_child(_hud_layer)
	Setting.changed.connect(_settings_changed)
	_settings_changed()


func configure(view_size: Vector2) -> void:
	_view_size = view_size
	geometry.configure(view_size, Setting.layout)
	_apply_stage()
	_redraw()


func set_preview(enabled: bool = true) -> void:
	preview = enabled
	_redraw()


func attach_session(value: PlaySession) -> void:
	if session != null:
		session.feedback_ready.disconnect(_on_feedback_ready)
		session.judged.disconnect(_on_score_changed)
	_hits.clear()
	_hold_hits.clear()
	_display_grade = ""
	_offset_word = ""
	session = value
	session.feedback_ready.connect(_on_feedback_ready)
	session.judged.connect(_on_score_changed)
	_redraw()


func preview_hit(kind: String) -> void:
	_hits.append({"kind": kind, "x": 0.5, "start": _elapsed})
	_redraw()


## 3D 舞台当前使用的参数；自检与调试用。
func stage_parameters() -> Dictionary:
	var parameters := {
		"stage_ready": _camera != null and _plane != null and _display != null,
		"tilt_degrees": geometry.tilt_degrees(),
		"row_factor": geometry.row_factor,
		"vertical_stretch": geometry.vertical_stretch,
	}
	if _camera != null:
		parameters["camera_distance"] = geometry.camera_distance
		# Camera3D 把 set_frustum 的前两个参数存在 size / frustum_offset 上。
		parameters["frustum_size"] = _camera.size
		parameters["frustum_offset"] = _camera.frustum_offset
		parameters["frustum_near"] = _camera.near
		parameters["projection"] = _camera.projection
		parameters["keep_aspect"] = _camera.keep_aspect
	if _plane != null:
		parameters["plane_position"] = _plane.position
		parameters["plane_rotation_x"] = _plane.rotation.x
	if _plane_mesh != null:
		parameters["plane_size"] = _plane_mesh.size
		parameters["plane_center_offset"] = _plane_mesh.center_offset
	if _field_viewport != null:
		parameters["field_size"] = Vector2(_field_viewport.size)
	if _stage_viewport != null:
		parameters["stage_size"] = Vector2(_stage_viewport.size)
	return parameters


func _settings_changed() -> void:
	geometry.configure(_view_size, Setting.layout)
	_apply_stage()
	_redraw()


## 把几何参数同步到 3D 舞台：视口分辨率、平面网格、相机视锥。
func _apply_stage() -> void:
	if _camera == null:
		return
	var device_scale := _device_scale()
	# 扩展横向画布，容纳原本在屏幕外、透视后仍可见的 Note。
	# 限制额外像素预算，避免倾斜时扩展画布再次引入大幅 GPU 开销。
	device_scale *= minf(1.0, sqrt(2.0 * geometry.size.x / geometry.canvas_width))
	var field_size := Vector2(geometry.canvas_width, geometry.canvas_bottom - geometry.canvas_top) * device_scale
	_field_viewport.size = Vector2i(maxi(1, roundi(field_size.x)), maxi(1, roundi(field_size.y)))
	# 画布按设备像素放大绘制，坐标仍然使用设计像素（两层共用同一套画布坐标）。
	_field_layer.scale = Vector2(device_scale, device_scale)
	_field_layer.position = Vector2(-geometry.canvas_left, -geometry.canvas_top) * device_scale
	_stage_viewport.size = Vector2i(maxi(1, roundi(geometry.size.x * device_scale)), maxi(1, roundi(geometry.size.y * device_scale)))
	_display.size = geometry.size
	_display.position = Vector2.ZERO
	_camera.set_frustum(geometry.frustum_size, geometry.frustum_offset, geometry.frustum_near, geometry.camera_far)
	_camera.position = Vector3.ZERO
	_camera.rotation = Vector3.ZERO
	var world_size := geometry.plane_world_size()
	_plane_mesh.size = world_size
	_plane_mesh.center_offset = Vector3(0.0, geometry.plane_center_offset(), 0.0)
	# 判定线（旋转轴）放在相机正前方 camera_distance 处，平面向内倾斜。
	_plane.position = Vector3(0.0, 0.0, -geometry.camera_distance)
	_plane.rotation = Vector3(-geometry.tilt_angle, 0.0, 0.0)


## 主视口的画布缩放（设备像素 / 设计像素）；画布分辨率按它放大。
func _device_scale() -> float:
	var scale := 1.0
	var viewport := get_viewport()
	if viewport != null:
		var factor := viewport.get_final_transform().get_scale()
		if factor.x > 0.0 and is_finite(factor.x):
			scale = factor.x
	return clampf(scale, 1.0, MAX_DEVICE_SCALE)


func _redraw() -> void:
	if is_instance_valid(_back_layer):
		_back_layer.queue_redraw()
	if is_instance_valid(_field_layer):
		_field_layer.queue_redraw()
	if is_instance_valid(_hud_layer):
		_hud_layer.queue_redraw()


func _on_score_changed(_index: int, _grade: String, _phase: String) -> void:
	if is_instance_valid(_hud_layer):
		_hud_layer.queue_redraw()


func _on_feedback_ready(index: int, grade: String, phase: String) -> void:
	var item: Dictionary = session.notes[index]
	_display_grade = grade
	# 击打延迟显示：按下 Tap / Hold 判定、且这个判定在设置里被勾选时才出现。
	if _offset_visible(index, grade, phase):
		_offset_word = Skins.offset_word(session.last_hit_offset)
		_offset_start = _elapsed
	if is_instance_valid(_hud_layer):
		_hud_layer.queue_redraw()
	if phase == "tail":
		_hold_hits.erase(index)
	if grade == "miss":
		return
	var kind := String(item.type).to_lower()
	var lane := session.evaluator.at(item.track, session.beat)
	if kind == "hold" and phase == "head":
		_hold_hits[index] = _elapsed
	else:
		_hits.append({"kind": kind, "x": lane.x, "start": _elapsed})
	if hit_sound_enabled(kind, phase):
		Skins.play_sound(kind)


## 这次判定要不要出声。Hold 的头判与尾判共用 sound_hold 这一个素材，尾判可以在设置里
## 单独关掉（game:hold_tail_sound）——只影响声音，尾巴那下 Hit 特效照旧出现。
## Tap、Slide 以及 Hold 头判一律出声；漏判在更上面就返回了，走不到这里。
func hit_sound_enabled(kind: String, phase: String) -> bool:
	return Setting.hold_tail_sound or not (kind == "hold" and phase == "tail")


func _process(delta: float) -> void:
	_elapsed += delta
	_field_layer.queue_redraw()
	# HUD 基本没有时间动画，仅在判定或布局/素材变化时重绘；两处例外：
	#   · 击打延迟显示只亮一小会儿，显示期间逐帧重绘，到点清掉后再次停手；
	#   · 进度条跟着谱面时钟走，有会话时就逐帧重绘。
	if session == null and _offset_word.is_empty():
		return
	if not _offset_word.is_empty() and _elapsed - _offset_start > float(Setting.layout.judge_offset_duration):
		_offset_word = ""
	if is_instance_valid(_hud_layer):
		_hud_layer.queue_redraw()


## 背景是普通 2D：单独一层铺满整个画面，不跟着轨道倾斜。
## 画布没画到轨道的地方（倾斜后收敛的游玩区域两侧、画面的角落）露出的就是这一层。
func draw_background(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, _view_size), Color.BLACK)
	if background == null or background.get_width() <= 0.0 or background.get_height() <= 0.0:
		return
	# 背景图按画面尺寸等比铺满，与旧的画布内绘制完全一致，只是不再参与倾斜。
	var ratio := maxf(_view_size.x / background.get_width(), _view_size.y / background.get_height())
	var bg_size := background.get_size() * ratio
	canvas.draw_texture_rect(background, Rect2((_view_size - bg_size) / 2, bg_size), false, Color(1, 1, 1, 0.3))


func draw_field(canvas: CanvasItem) -> void:
	if preview:
		_draw_preview(canvas)
	elif session:
		_draw_session(canvas)
	_draw_side_lines(canvas)
	_draw_judge_line(canvas)
	_draw_hits(canvas)


## 游玩区域左右两条侧线：标出轨道区域的边界，笔画是轨道线的四倍（见 SIDE_LINE_STROKE_RATIO）。
## 贴在区域外侧，所以不会压住区域里的轨道；和轨道一样纵向铺满画布，一直画到屏幕顶端。
func _draw_side_lines(canvas: CanvasItem) -> void:
	var line := Color(1, 1, 1, Setting.layout.lane_line_alpha)
	canvas.draw_rect(geometry.side_line_rect(0.0), line)
	canvas.draw_rect(geometry.side_line_rect(1.0), line)


func draw_hud(canvas: CanvasItem) -> void:
	if preview:
		# 正式游玩用场景里的真实按钮节点；预览里直接画一遍，方便检查自定义外观。
		var button_size := Vector2.ONE * maxf(28, geometry.pixel_scale * 56)
		Skins.draw_panel(canvas, "exit", Rect2(Vector2(12, 12), button_size))
		Skins.draw_panel(canvas, "restart", Rect2(Vector2(_view_size.x - button_size.x - 12, 12), button_size))
	_draw_numbers(canvas)
	# 进度条画在最后：它只占顶端 5 像素，谁被摆到那上面都该让位给它。
	_draw_progress(canvas)


## 已游玩的比例（0 ~ 1）：拿谱面时钟比最后一颗音符的尾巴。
## 没有会话（预览 / 舞台探针）或谱面还没有时长时是 0，等于不画。
func progress_ratio() -> float:
	if session == null or session.end_time <= 0.0:
		return 0.0
	return clampf(session.time / session.end_time, 0.0, 1.0)


## 进度条是 HUD：不参与倾斜，直接铺在画面顶边，宽度按比例给。
func _draw_progress(canvas: CanvasItem) -> void:
	if session == null:
		return
	var track := Rect2(0.0, 0.0, _view_size.x, PROGRESS_HEIGHT)
	canvas.draw_rect(track, Color(1, 1, 1, PROGRESS_TRACK_ALPHA))
	canvas.draw_rect(Rect2(0.0, 0.0, _view_size.x * progress_ratio(), PROGRESS_HEIGHT),
		Color(1, 1, 1, PROGRESS_ALPHA))


func _draw_lane(canvas: CanvasItem, lane: Dictionary) -> void:
	_draw_lane_background(canvas, lane)
	_draw_lane_outline(canvas, lane)

func _lane_rect(lane: Dictionary) -> Rect2:
	var width: float = lane.w * geometry.width
	return Rect2(geometry.x(lane.x) - width * 0.5, geometry.canvas_top, width, geometry.canvas_bottom - geometry.canvas_top)

func _draw_lane_background(canvas: CanvasItem, lane: Dictionary) -> void:
	if not lane.visible or lane.w == 0.0:
		return
	var fill := Color(0, 0, 0, Setting.layout.lane_alpha)
	if lane.get("touch", false):
		fill.a = minf(1.0, fill.a + TOUCH_ALPHA_BOOST)
	canvas.draw_rect(_lane_rect(lane), fill)

func _draw_lane_outline(canvas: CanvasItem, lane: Dictionary) -> void:
	if not lane.visible:
		return
	var line := Color(1, 1, 1, Setting.layout.lane_line_alpha)
	if lane.get("touch", false):
		line.a = minf(1.0, line.a + TOUCH_ALPHA_BOOST)
	canvas.draw_rect(_lane_rect(lane), line, false, geometry.lane_stroke())


func _draw_note(canvas: CanvasItem, kind: String, x: float, width: float, head_y: float, tail_y: float, holding: bool = false) -> void:
	var height: float = Setting.layout.note_height * geometry.pixel_scale
	var w := note_width(width, kind)
	# 保持中的 Hold 头停在判定线，不再越过它继续下落。
	var bottom := minf(head_y, geometry.judge_y) if holding else head_y
	var top := tail_y - height if kind == "hold" else bottom - height
	var rect := Rect2(geometry.x(x) - w / 2, top, w, maxf(height, bottom - top))
	Skins.draw_panel(canvas, "note_" + kind, rect, height)


func _draw_session(canvas: CanvasItem) -> void:
	for lane in session.tracks:
		_draw_lane_background(canvas, lane)
	for lane in session.tracks:
		_draw_lane_outline(canvas, lane)
	var lookahead := 10.0 / maxf(Setting.speed, 0.5)
	for index in session.visible_notes_by_layer(lookahead * 2):
		var item: Dictionary = session.notes[index]
		if minf(session.note_distance(index), session.note_distance(index, true)) > lookahead * 2:
			continue
		var lane := session.evaluator.at(item.track, session.beat)
		if lane.y <= 0:
			continue
		_draw_note(canvas, String(item.type).to_lower(), lane.x, lane.y,
			geometry.y(session.note_distance(index), lookahead), geometry.y(session.note_distance(index, true), lookahead),
			session.states[index] == PlaySession.State.HOLDING)
	for index in _hold_hits:
		if session.active_holds.has(index):
			var lane := session.evaluator.at(session.notes[index].track, session.beat)
			Skins.draw_hit(canvas, "hold", Vector2(geometry.x(lane.x), geometry.judge_y), _elapsed - _hold_hits[index], true, geometry.pixel_scale)


func _draw_preview(canvas: CanvasItem) -> void:
	var kinds := ["tap", "hold", "slide"] if preview_kind == "all" else [preview_kind]
	var lookahead := 10.0 / maxf(Setting.speed, 0.5)
	# 预览里音频只是一个跟着音符响的打击音，两个偏移旋钮对它等价：都取「音频相对谱面」的方向。
	var shift := (Setting.offset - Setting.chart_offset) / 1000.0
	for i in kinds.size():
		var kind: String = kinds[i]
		var x := (float(i) + 0.5) / kinds.size()
		var lane := {"x": x, "w": 0.85 / kinds.size(), "visible": true}
		_draw_lane(canvas, lane)
		# 每类音符各自排程：判定时刻走完才排下一颗。改“流速”只改变落速与间隔，
		# 不会让屏幕上的 Note 跳位置；第一颗从屏幕顶端开始落（见 geometry.y）。
		var judge := _preview_judge_time(kind, i, lookahead)
		var until := judge - _elapsed + shift
		if until < -PREVIEW_GAP:
			until = _preview_advance(kind, lookahead) - _elapsed + shift
		if _preview_previous.has(kind) and _preview_previous[kind] > 0.0 and until <= 0.0 and preview_sound:
			Skins.play_sound(kind)
		_preview_previous[kind] = until
		var hold_time := 0.9 if kind == "hold" else 0.0
		if until >= 0 or (kind == "hold" and until + hold_time > 0):
			_draw_note(canvas, kind, x, lane.w, geometry.y(until, lookahead), geometry.y(until + hold_time, lookahead), until < 0)
		if until < 0:
			Skins.draw_hit(canvas, kind, Vector2(geometry.x(x), geometry.judge_y), -until, kind == "hold" and -until < hold_time, geometry.pixel_scale)


## 预览里某个音符落在判定线上的时刻；首次见到这个类型时从屏幕顶端开始落。
func _preview_judge_time(kind: String, index: int, lookahead: float) -> float:
	if not _preview_judges.has(kind):
		_preview_judges[kind] = _elapsed + 0.25 * float(index) + lookahead
	return float(_preview_judges[kind])


## 排下一颗：间隔 = 当前流速的 lookahead + PREVIEW_GAP（流速越大出现得越密、落得越快）。
func _preview_advance(kind: String, lookahead: float) -> float:
	var next := float(_preview_judges[kind]) + lookahead + PREVIEW_GAP
	_preview_judges[kind] = next
	return next


## 预览排程快照（类型 → 当前音符的判定时刻）；自检用。
func preview_schedule() -> Dictionary:
	return _preview_judges.duplicate()


## 判定线矩形：左右两端正好落在游玩区域的侧线上（也就是轨道区域的左右边缘），
## 以判定线行居中。它同时是 3D 舞台的旋转轴所在行、判定线图片的绘制矩形，
## 所以自检可以直接按这个矩形核对像素位置。
func judge_line_rect() -> Rect2:
	var height: float = maxf(1.0, float(Setting.layout.judge_height) * geometry.pixel_scale)
	return Rect2(geometry.x(0.0), geometry.judge_y - height * 0.5, geometry.width, height)


## 判定线图片的绘制矩形：在实际判定线上按设置纵向平移（布局像素，跟着画布缩放）。
## 只挪图片这一层——判定线本身是 3D 舞台的旋转轴，也是判定与触摸反算的基准，
## 不跟着图片动（见 Setting.layout.judge_image_offset）。
func judge_line_image_rect() -> Rect2:
	var rect := judge_line_rect()
	rect.position.y += float(Setting.layout.judge_image_offset) * geometry.pixel_scale
	return rect


func _draw_judge_line(canvas: CanvasItem) -> void:
	Skins.draw_panel(canvas, "judge_line", judge_line_image_rect())


func _draw_hits(canvas: CanvasItem) -> void:
	var count := 0
	for hit in _hits:
		if Skins.draw_hit(canvas, hit.kind, Vector2(geometry.x(hit.x), geometry.judge_y), _elapsed - hit.start, false, geometry.pixel_scale):
			_hits[count] = hit
			count += 1
	_hits.resize(count)


func _draw_numbers(canvas: CanvasItem) -> void:
	# 连击、分数、判定三者的显示高度各自独立设置（judge_size 沿用旧键）。
	var combo_height := maxf(6, float(Setting.layout.combo_size) * geometry.pixel_scale)
	var score_height := maxf(6, float(Setting.layout.score_size) * geometry.pixel_scale)
	var grade_height := maxf(6, float(Setting.layout.judge_size) * geometry.pixel_scale)
	# 预览固定显示全部字形，便于逐个位置检查素材。
	var combo := "0123456789" if preview else str(session.combo if session else 0)
	if not preview and (session == null or session.combo <= 0):
		combo = ""
	if not combo.is_empty():
		Skins.draw_number(canvas, combo, Vector2(_view_size.x / 2, _view_size.y * 0.15), combo_height)
	if session:
		Skins.draw_number(canvas, str(roundi(session.score)).pad_zeros(7), Vector2(_view_size.x / 2, _view_size.y * 0.22), score_height)
		_draw_grade_feedback(canvas, _display_grade, _view_size.y * float(Setting.layout.judge_text_y), grade_height)
		_draw_offset_feedback(canvas)
	elif preview:
		# 分数的预览就是这种算法的开局数值（加算 0000000 / 减算 1000000），
		# 切换算法时能立刻看出数字是往上还是往下走。
		Skins.draw_number(canvas, preview_score_text(), Vector2(_view_size.x / 2, _view_size.y * 0.22), score_height)
		# 五种判定按行预览，每行使用与游玩相同的单个/镜像双个布局。
		var preview_height := maxf(grade_height, _view_size.y * 0.04)
		var grades := ["just+", "just", "good", "ok", "miss"]
		for index in grades.size():
			_draw_grade_feedback(canvas, grades[index], _view_size.y * float(Setting.layout.judge_text_y) + index * (preview_height + 6 * geometry.pixel_scale), preview_height)
		# 击打延迟显示的两种方向也各占一行：位置、大小、素材改了都能立刻看到。
		var offset_height := _offset_height()
		for index in Skins.OFFSET_WORDS.size():
			Skins.draw_offset_word(canvas, Skins.OFFSET_WORDS[index],
				_offset_position(index * (offset_height + 6 * geometry.pixel_scale)), offset_height)


## 击打延迟显示的触发条件：按下去判定的 Tap / Hold 头，且这个判定在设置里被勾选
## （选项就是判定文字，见 Setting.JUDGE_OFFSET_GRADES）。漏掉没碰的音符、Hold 尾、
## Slide 的自动命中都不算「按下去」，所以不会出现。
func _offset_visible(index: int, grade: String, phase: String) -> bool:
	if phase != "head" or not session.last_hit_from_press or not Setting.judge_offset_enabled(grade):
		return false
	var kind := String((session.notes[index] as Dictionary).type).to_lower()
	return kind == "tap" or kind == "hold"


func _offset_height() -> float:
	return maxf(6, float(Setting.layout.judge_offset_size) * geometry.pixel_scale)


## 击打延迟显示的顶部中点：横纵都是画面比例，和判定文字同一套坐标习惯。
func _offset_position(step: float = 0.0) -> Vector2:
	return Vector2(_view_size.x * float(Setting.layout.judge_offset_x),
		_view_size.y * float(Setting.layout.judge_offset_y) + step)


func _draw_offset_feedback(canvas: CanvasItem) -> void:
	if _offset_word.is_empty():
		return
	Skins.draw_offset_word(canvas, _offset_word, _offset_position(), _offset_height())


func judge_positions(y: float) -> PackedVector2Array:
	var x := _view_size.x * float(Setting.layout.judge_x)
	var result := PackedVector2Array([Vector2(x, y)])
	if int(Setting.layout.judge_count) == 2:
		result.append(Vector2(_view_size.x - x, y))
	return result


func _draw_grade_feedback(canvas: CanvasItem, grade: String, y: float, height: float) -> void:
	for position in judge_positions(y):
		Skins.draw_grade(canvas, grade, position, height)


## LOVE 的间距规则：窄轨道不强制变宽，Tap / Slide / Hold 使用相同横向尺寸。
## 预览里显示的分数文本：就是这种算法开局的数值（加算 0000000 / 减算 1000000）。
## 设置页左边的预览与自检都读这里，切换算法立刻能看出数字往哪边走。
func preview_score_text() -> String:
	var start := 0 if Setting.score_mode == Setting.SCORE_ADD else roundi(PlaySession.SCORE_TOTAL)
	return str(start).pad_zeros(7)


## Note 的绘制宽度：所在轨道宽度减去这个类型的横向间隔（间隔左右各分一半）。
## 间隔在「Note / 判定线」页按 Tap / Hold / Slide 分别设置，所以这里要带上类型。
## 轨道窄到放不下时退化成「至少留出间隔」或「照轨道宽度画」，不会出现负宽度。
func note_width(width: float, kind: String = "tap") -> float:
	var key := "note_gap_" + kind
	var pixels := absf(width) * geometry.width
	var spacing := maxf(0.0, float(Setting.layout.get(key, Setting.DEFAULT_LAYOUT[key]))) * geometry.pixel_scale
	if pixels > spacing * 2.0:
		return pixels - spacing
	if pixels > spacing:
		return spacing
	return pixels
