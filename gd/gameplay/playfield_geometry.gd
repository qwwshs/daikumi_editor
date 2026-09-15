class_name PlayfieldGeometry
extends RefCounted
## 绘制、触摸换算与 3D 舞台共用的几何换算。
##
## 坐标统一以画面左上角为原点（与传给 configure 的 view_size 一致）：
## 判定线在 y = judge_y，轨道横向范围是画面中心左右各 width / 2；
## 除像素缩放外，所有数值都是“设计像素”（与窗口分辨率无关）。
##
## 倾斜（track_angle）由 playfield.gd 里的 3D 舞台完成，参数全部在这里推导：
##   · 轨道平面绕过判定线中点的水平轴旋转 tilt_angle，纵向预拉伸 1 / cos(tilt_angle)；
##   · 相机放在判定线正前方 camera_distance 处，并用偏心视锥把判定线压到
##     画面 judge_y 这一行。于是判定线上 1 设计像素 = 1 画面像素：横向是正交投影、
##     纵向的旋转压缩被预拉伸抵消，判定线（含中点）的大小与不倾斜时逐像素一致，
##     因此触摸换算不需要任何逆变换。
##   · 判定线上方 u 像素处的缩放是 k(u) = 1 / (1 + u * row_factor)：横向乘 k、纵向乘 k²
##     （真 3D 光栅化的结果），越远越窄越矮；贴图采样是透视正确的，长 Hold 的纹理
##     不会被拉长，这就是之前“Hold 拉伸错误”的根因。
##   · angle = 0 时 k ≡ 1，投影退化成恒等变换，与旧的平面绘制完全一致。
##   · 相机随向内倾斜的角度向后退（camera_distance = judge_y * (1 + tan 角度)）：
##     灭线跟着抬高，永远在画面顶端之上，游玩区域于是能一直铺到画面顶端、
##     Note 从画面顶端进入。代价是角度越大透视越缓（见 _effective_camera_distance）。

## 角度范围：向内（上方向远处倒、像站在马路中间看远方）最多 70°，
## 向外（上方向观察者一侧倒）最多 45°。极端组合（判定线很低 + 角度很大）下
## 实际角度会被 _guarded_angle 收窄，保证平面不穿到相机后面。
const MIN_ANGLE_DEGREES := -45.0
const MAX_ANGLE_DEGREES := 70.0
## 向内倾斜时相机后退的系数（见 _effective_camera_distance）：
## 相机距离 = judge_y * (1 + 系数 * tan 角度)。系数 1 时灭线恰好落在画面顶端之上，
## 角度越大后退越多；再小就会在角度偏大时把灭线压进画面（游玩区域无法铺到顶端）。
const CAMERA_PULLBACK := 1.0
## 画布在画面之外多画的比例：顶端按画布行数多留、底端按画面行数多留，
## 只为盖住取整误差，别让平面的边缘在画面边上露出一条缝。顶端的余量
## 换算到画面行数会随角度缩得很小（k² 越来越小），所以按画布行数留。
const FIELD_CANVAS_MARGIN := 0.06
## 透视不能出现奇点：平面上任意一行的深度都不能低于相机距离的这个比例。
const DEPTH_FLOOR := 0.35
## 轨道线（判定线同款白描边）的笔画宽度（设备独立像素）。
const LANE_STROKE := 2.0
## 游玩区域两侧侧线的笔画宽度相对轨道线的倍数。
const SIDE_LINE_STROKE_RATIO := 4.0

var size := Vector2(1600, 900)
var width: float = 1280.0
var judge_y: float = 720.0
var pixel_scale: float = 1.0
var approach_curve: float = 1.0
## 轨道平面绕判定线水平轴的旋转角（弧度，向内为正、向观察者为负）。
var tilt_angle: float = 0.0
## 判定线上方 u 像素处的横向缩放是 1 / (1 + u * row_factor)。
var row_factor: float = 0.0
## 平面的纵向预拉伸，使判定线处的纵横比例都保持 1。
var vertical_stretch: float = 1.0
## 轨道层画布的行范围（设计像素）：顶行 canvas_top、底行 canvas_bottom，
## 两者都由角度决定（见 _update_canvas），画布整体向下平移 -canvas_top 后贴到平面上。
var canvas_top: float = -540.0
var canvas_bottom: float = 900.0
var canvas_width: float = 1600.0
var canvas_left: float = 0.0

# --- 交给 playfield.gd 里 Camera3D / MeshInstance3D 的参数 ---
## 相机到判定线平面的距离（设计像素）。向内倾斜时随角度后退，
## 保证灭线始终在画面顶端之上（游玩区域铺满到顶端、Note 从顶端进入）。
var camera_distance: float = 720.0
var frustum_near: float = 360.0
var frustum_size: float = 450.0
var frustum_offset: Vector2 = Vector2.ZERO
var camera_far: float = 2400.0


func configure(view_size: Vector2, layout: Dictionary) -> void:
	size = view_size
	pixel_scale = maxf(0.1, minf(size.x / 1600.0, size.y / 900.0))
	width = size.x * float(layout.get("track_width", 0.8))
	judge_y = size.y * float(layout.get("judge_y", 0.8))
	approach_curve = maxf(0.2, float(layout.get("approach_curve", 1.0)))
	camera_distance = maxf(judge_y, 1.0)
	tilt_angle = _guarded_angle(deg_to_rad(clampf(
		float(layout.get("track_angle", 0.0)), MIN_ANGLE_DEGREES, MAX_ANGLE_DEGREES)))
	camera_distance = _effective_camera_distance(tilt_angle)
	vertical_stretch = 1.0 / maxf(cos(tilt_angle), 0.25)
	# tan 形式让 0° 时严格是恒等变换。
	row_factor = tan(tilt_angle) / camera_distance
	_update_canvas()
	_update_frustum()


## 倾斜角（度），供设置界面与自检读取实际生效值。
func tilt_degrees() -> float:
	return rad_to_deg(tilt_angle)


func is_tilted() -> bool:
	return not is_zero_approx(row_factor)


## 判定线上方 u 像素（u 为负表示判定线下方）处内容的横向缩放。
func row_scale(u: float) -> float:
	return 1.0 / (1.0 + u * row_factor)


## 轨道层里“判定线上方 u 像素”的一行，落在画面的哪一行。
func project_row(u: float) -> float:
	return judge_y - u * row_scale(u)


## project_row 的逆运算：画面行 screen_y 落在判定线上方多少像素。
## 越靠近灭点结果越大，越过灭点则返回一个很大的数。
func row_offset_for_screen(screen_y: float) -> float:
	return _offset_for_screen(screen_y, row_factor)


## 轨道层画布的行范围（设计像素）；绘制时整层要向下平移 -canvas_top。
func canvas_rect() -> Rect2:
	return Rect2(canvas_left, canvas_top, canvas_width, canvas_bottom - canvas_top)


## 判定线在画布内的行号（画布坐标）。
func pivot_row_in_canvas() -> float:
	return judge_y - canvas_top


## 3D 平面的世界尺寸：宽 = 画面宽，高 = 画布行数 × 纵向预拉伸。
func plane_world_size() -> Vector2:
	return Vector2(canvas_width, (canvas_bottom - canvas_top) * vertical_stretch)


## 平面网格的中心偏移，使判定线那一行正好落在节点的原点上（也就是旋转轴上）。
func plane_center_offset() -> float:
	return pivot_row_in_canvas() * vertical_stretch - plane_world_size().y * 0.5


## 轨道中心线所在的画面 x：归一化 0 与 1 分别落在轨道区域左右边缘。
func x(normalized: float) -> float:
	return size.x * 0.5 + (normalized - 0.5) * width


## 轨道线的笔画宽度（设计像素）：与判定线一样，至少一个像素。
func lane_stroke() -> float:
	return maxf(1.0, pixel_scale * LANE_STROKE)


## 游玩区域左右两条侧线的笔画宽度（设计像素）：轨道线的四倍。
func side_line_stroke() -> float:
	return lane_stroke() * SIDE_LINE_STROKE_RATIO


## 游玩区域某一条侧线的矩形（轨道层坐标，纵向铺满画布）。
## normalized 取 0（左边界）或 1（右边界）；侧线贴在游玩区域外侧，
## 内边正好落在边界上，所以不会压住区域里的轨道。
func side_line_rect(normalized: float) -> Rect2:
	var stroke := side_line_stroke()
	var edge := x(normalized)
	var left := edge - stroke if normalized < 0.5 else edge
	return Rect2(left, canvas_top, stroke, canvas_bottom - canvas_top)


## 距判定时刻 seconds_until 秒的音符所在的轨道层 y；正数（还没到）在判定线上方。
## 幅度取“判定线到屏幕顶端”的画布距离（row_offset_for_screen(0)），于是
## distance = 1（也就是 seconds_until = visible_seconds）时音符正好落在屏幕顶端：
## Note 一定从屏幕顶端出现，且从顶端落到判定线恰好用 visible_seconds ——
## 游玩里 visible_seconds = 10 / 流速，“流速”因此有确切含义（每秒多少屏）。
## 倾斜时这个幅度大于 / 小于 judge_y，屏幕上的透视压缩已由投影负责，
## 这里给出的是平面上的行，交给 3D 舞台投影；0° 时它与 judge_y 相等，行为与不倾斜时一致。
func y(seconds_until: float, visible_seconds: float) -> float:
	# 单调的距离缓动：0 始终准确落在判定线，Hold 两端使用相同函数。
	var distance := seconds_until / maxf(visible_seconds, 0.05)
	var journey := maxf(row_offset_for_screen(0.0), 1.0)
	return judge_y - signf(distance) * pow(absf(distance), approach_curve) * journey


## 手指位置（画面坐标）对应的归一化轨道位置。
func normalized_x(position: Vector2) -> float:
	return (position.x - size.x * 0.5) / maxf(width, 1.0) + 0.5


## 平面上某一行相对相机的深度比例（1 表示正好在判定线所在深度）。
func _depth_ratio(u: float) -> float:
	return 1.0 + u * row_factor


func _offset_for_screen(screen_y: float, factor: float) -> float:
	var delta := judge_y - screen_y
	var denominator := 1.0 - factor * delta
	if denominator <= 0.001:
		return 1.0e9
	return delta / denominator


## 画布纵向范围：上下两端都取“画面边界外一点”对应的行，所以游玩区域一直铺到画面边缘
## （顶端就是屏幕顶端本身，再在画布上多留几行盖住取整误差），不会中途截断。
## 向内倾斜时相机后退（_effective_camera_distance）保证这两行总是有限值。
func _update_canvas() -> void:
	canvas_top = judge_y - row_offset_for_screen(0.0) - FIELD_CANVAS_MARGIN * size.y
	canvas_bottom = judge_y - row_offset_for_screen(size.y * (1.0 + FIELD_CANVAS_MARGIN))
	# 屏幕可见区反投影到画布的最宽范围；不能用未经透视的屏幕宽度截断。
	var smallest_scale := minf(row_scale(judge_y - canvas_top), row_scale(judge_y - canvas_bottom))
	canvas_width = size.x / minf(smallest_scale, 1.0)
	canvas_left = (size.x - canvas_width) * 0.5


## 相机距离：向外倾斜（或 0°）时保持 judge_y，向内倾斜时随角度后退。
## 平面上最远的一行趋近灭线所在的行 judge_y - camera_distance * cot(角度)，
## 后退量保证它落在画面顶端之上：游玩区域因此能一直画到屏幕顶端，
## Note 也从屏幕顶端进入，而不是在画面中途出现 / 溶解。
## 代价是相机越远透视越缓，角度很大时收敛会温和一些。
func _effective_camera_distance(angle: float) -> float:
	return maxf(judge_y, 1.0) * (1.0 + CAMERA_PULLBACK * maxf(tan(angle), 0.0))


## 把角度限制在不会让平面穿到相机后面的范围里。
## 只有画布覆盖到的行会被真正绘制，所以最近的一行取“画布上离相机最近的那一行”：
## 向内倾斜时是画面底端外一点，向外倾斜时是画面顶端外一点。
func _guarded_angle(angle: float) -> float:
	if _angle_is_safe(angle):
		return angle
	var low := 0.0
	var high := angle
	for _step in 12:
		var middle := (low + high) * 0.5
		if _angle_is_safe(middle):
			low = middle
		else:
			high = middle
	return low


func _angle_is_safe(angle: float) -> bool:
	var factor := tan(angle) / _effective_camera_distance(angle)
	if is_zero_approx(factor):
		return true
	var nearest := 0.0
	if factor > 0.0:
		nearest = _offset_for_screen(size.y * (1.0 + FIELD_CANVAS_MARGIN), factor)
	else:
		# 向外倾斜时最近的一行是画布顶端（画面顶端那一行再往上留的余量）。
		nearest = _offset_for_screen(0.0, factor) + FIELD_CANVAS_MARGIN * size.y
	return 1.0 + nearest * factor >= DEPTH_FLOOR


func _update_frustum() -> void:
	var near_ratio := _depth_ratio(judge_y - canvas_bottom)
	var far_ratio := _depth_ratio(judge_y - canvas_top)
	frustum_near = camera_distance * maxf(minf(near_ratio, far_ratio), 0.05) * 0.5
	camera_far = camera_distance * maxf(maxf(near_ratio, far_ratio), 0.2) * 2.0
	# 近平面高度取“画面高度 × near / 距离”，于是判定线所在深度上
	# 1 设计像素正好投影成 1 画面像素；视锥中心的偏移把判定线压到 judge_y 这一行。
	var ratio := frustum_near / camera_distance
	frustum_size = size.y * ratio
	frustum_offset = Vector2(0.0, ratio * (judge_y - size.y * 0.5))


