extends Node2D
## 场景只负责音频时钟、UI 导航和输入转发。
## PlaySession 负责判定；Playfield 负责绘制，设置预览也复用后者。

## 谱面时钟：音频时刻只在每次混音时跳一下（Compatibility 渲染器下约 10 ms 一跳），
## 直接喂给判定与绘制会让画面一顿一跳（240 fps 下约 6% 的帧原地不动、4% 的帧跳两倍）。
## 这里按墙钟推进，只调整前进速度朝音频时刻收敛，把台阶抹平；偏差超过 CLOCK_SNAP 说明
## 是真的跳转（开始放歌、恢复前台、换音频设备），这时直接对齐——跳一下也好过冻结。
## 阈值要明显大于一个混音周期（安卓上能到 40 ms 以上），否则音频时钟自己的台阶就会被当成跳转。
const CLOCK_SNAP := 0.15
## 收敛速度（1/秒）：偏差 10 ms 时前进速度偏离正常 8%，肉眼看不出来。
const CLOCK_GAIN := 8.0
## 收敛时的速度上下限（倍）：最多两倍、最少停住，时间不会倒退。
const CLOCK_MAX_RATE := 2.0
## 单次推进的上限：后台或长时间卡顿之后不要一次跨太多。
const CLOCK_MAX_ADVANCE := 0.05

var session: PlaySession
var playfield: Playfield
var music_player: AudioStreamPlayer
var fingers: Dictionary = {}
var _countdown: float = 0.0
var _music_started: bool = false
var _leaving: bool = false
var _exit_button: Button
var _restart_button: Button
var _status: Label
var _paused: bool = false
var _clock: float = 0.0
var _clock_ready: bool = false
var _clock_stamp: int = 0

func _ready() -> void:
	if ChartLoader.chart_data == null:
		ChartLoader.readChart()
		ChartLoader.readMusic()
		ChartLoader.readBg()
	if ChartLoader.chart_data == null:
		_leave()
		return
	Skins.prepare_gameplay()
	session = PlaySession.new(ChartLoader.chart_data)
	playfield = Playfield.new()
	add_child(playfield)
	playfield.attach_session(session)
	playfield.background = ChartLoader.bg
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.stream = ChartLoader.music
	add_child(music_player)
	_build_ui()
	get_viewport().size_changed.connect(_resize)
	Setting.changed.connect(_update_icons)
	_resize()
	_update_icons()
	# Android 返回键由本场景处理，不让系统直接退出应用。
	get_tree().auto_accept_quit = false

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	_exit_button = _button("退出", ui, _leave)
	_restart_button = _button("重开", ui, _restart)
	_status = Label.new()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(_status)

func _button(title: String, parent: Node, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(120, 64)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 38)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _resize() -> void:
	var size := get_viewport_rect().size
	playfield.configure(size)
	var button_width := clampf(size.x * 0.15, 100, 180)
	_exit_button.position = Vector2(16, 16)
	_exit_button.size = Vector2(button_width, 64)
	_restart_button.position = Vector2(size.x - button_width - 16, 16)
	_restart_button.size = Vector2(button_width, 64)
	_status.position = Vector2(size.x * 0.25, size.y * 0.4)
	_status.size = Vector2(size.x * 0.5, 50)

func _update_icons() -> void:
	_exit_button.icon = Skins.texture("exit")
	_restart_button.icon = Skins.texture("restart")

func _process(delta: float) -> void:
	if _leaving or session == null or _paused:
		return
	_countdown += delta
	var chart_offset := ChartLoader.total_offset_seconds()
	var chart_time := _countdown - ChartLoader.wait_time - chart_offset
	if not _music_started and _countdown >= ChartLoader.wait_time:
		_music_started = true
		if music_player.stream:
			music_player.play(maxf(0, _countdown - ChartLoader.wait_time))
	# 音频混音时间是基准，避免帧率波动造成歌曲与判定长期漂移。
	if _music_started and music_player.playing:
		chart_time = _audio_time() - chart_offset
		_countdown = chart_time + chart_offset + ChartLoader.wait_time
	session.update(_chart_clock(chart_time), fingers)
	for finger in fingers.values():
		finger.pressed = false
		finger.previous_x = finger.x
	_status.text = str(ceili(ChartLoader.wait_time - _countdown)) if _countdown < ChartLoader.wait_time else ""
	if _music_started and not music_player.playing and session.is_finished():
		_show_results()
		return
	if Setting.show_fps:
		_status.text += "  FPS %d" % Engine.get_frames_per_second()


## 音频时刻（秒）：播放位置 + 本次混音已经过去的时间 − 输出延迟，就是此刻听众听到的位置。
func _audio_time() -> float:
	return music_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()


## 平滑后的谱面时钟：按墙钟推进，只在前进速度上做修正（见文件开头的常量说明）。
## 用墙钟而不是帧间隔，是因为一次输入事件（_process_touch_now）也要按事件自己的时刻推进。
func _chart_clock(target: float) -> float:
	var stamp := Time.get_ticks_usec()
	var advance := 0.0
	if _clock_stamp > 0:
		advance = clampf(float(stamp - _clock_stamp) / 1000000.0, 0.0, CLOCK_MAX_ADVANCE)
	_clock_stamp = stamp
	_clock = target if not _clock_ready else clock_step(_clock, target, advance)
	_clock_ready = true
	return _clock


## 时钟的一步：advance 是距上次调用过了多久，返回值永远不会比 clock 小。
## 单独抽成一个函数（而不是藏在上面的墙钟里），自检才能直接喂一段时间序列验证抹平效果。
func clock_step(clock: float, target: float, advance: float) -> float:
	if absf(target - clock) > CLOCK_SNAP:
		return target
	return clock + advance * clampf(1.0 + (target - clock) * CLOCK_GAIN, 0.0, CLOCK_MAX_RATE)

func _unhandled_input(event: InputEvent) -> void:
	if _leaving or playfield == null or _paused or session == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var x := playfield.geometry.normalized_x(event.position)
			fingers[event.index] = {"x": x, "previous_x": x, "pressed": true}
			_process_touch_now()
			fingers[event.index].pressed = false
		else:
			_process_touch_now()
			fingers.erase(event.index)
	elif event is InputEventScreenDrag:
		if fingers.has(event.index):
			fingers[event.index].previous_x = fingers[event.index].x
			fingers[event.index].x = playfield.geometry.normalized_x(event.position)
			_process_touch_now()
			fingers[event.index].previous_x = fingers[event.index].x
	elif event.is_action_pressed("ui_cancel"):
		_leave()

## 按下、抬起、拖动都按事件发生的当下判定：这里同样走 _chart_clock，
## 于是判定用的时刻与画面上的音符位置始终是同一个时钟，按下的那一帧不会看到音符跳。
func _process_touch_now() -> void:
	var chart_offset := ChartLoader.total_offset_seconds()
	var now := _countdown - ChartLoader.wait_time - chart_offset
	if _music_started and music_player.playing:
		now = _audio_time() - chart_offset
	session.update(_chart_clock(now), fingers)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_leave()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_paused = true
		fingers.clear()
		if music_player:
			music_player.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_paused = false
		if music_player:
			music_player.stream_paused = false

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	if music_player:
		music_player.stop()
	get_tree().change_scene_to_file.call_deferred("res://gd/room/startroom.tscn")

func _restart() -> void:
	if _leaving:
		return
	_leaving = true
	music_player.stop()
	get_tree().reload_current_scene.call_deferred()


func _show_results() -> void:
	if _leaving:
		return
	_leaving = true
	finish_run()
	music_player.stop()
	get_tree().change_scene_to_file.call_deferred("res://gd/room/results.tscn")


## 结算快照 + 记成绩：无论好坏都算一次游玩，分数更高才刷新最好成绩（见 Scores.record）。
## 单独抽成一个不切场景的函数，自检才能直接验证「一局结束后成绩进了成绩册」。
func finish_run() -> void:
	ChartLoader.last_result = session.result_summary()
	ChartLoader.last_result.info = ChartLoader.chart_data.info.duplicate(true)
	ChartLoader.last_result.background = ChartLoader.bg
	ChartLoader.last_result.is_best = Scores.record(ChartLoader.selected_folder, ChartLoader.last_result)
