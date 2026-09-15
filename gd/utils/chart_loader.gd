extends Node
## 加载适配层：读取方式由 ImportAPI 提供，谱面补全由 ChartData 负责。
## 导航重开时保留已加载资源；声音播放属于游玩场景，不属于单例。

var chart_data: ChartData
var music: AudioStream
var bg: Texture2D
var wait_time: float = 3.0
var last_error: String = ""
var timeline: BeatTimeline
## 当前选中的谱面文件夹：开始界面写入，游玩场景读取。
var selected_folder: String = ""
## 当前这张谱面（一个文件夹里可能有多张）；空串表示文件夹里的默认谱面。
var selected_chart: String = ""
## 当前文件夹里的全部谱面（ImportAPI.list_charts 的结果）：界面据此展开歌曲，
## 成绩据此判断要不要按谱面分记（见 Scores.key_of）。
var charts: Array[Dictionary] = []
## 结算快照；退出或重开不生成成绩。
var last_result: Dictionary = {}

func accept_chart(data: Variant) -> bool:
	if not data is Dictionary and not data is String:
		last_error = "读取器没有返回 JSON 对象或文本"
		return false
	var parsed := ChartData.new(JSON.stringify(data) if data is Dictionary else data)
	if not parsed.error_message.is_empty():
		last_error = parsed.error_message
		return false
	chart_data = parsed
	timeline = BeatTimeline.new(parsed.bpmlist)
	last_error = ""
	return true


## 读取整个谱面文件夹：清单、分散的音频/背景与外部读取器都由公共导入接口处理。
## chart 为空时读文件夹里的默认谱面（多谱面文件夹是第一张），否则读指定的那张。
func load_from_folder(folder: String, chart: String = "") -> bool:
	if folder.is_empty():
		last_error = "尚未选择谱面文件夹。"
		return false
	charts = ImportAPI.list_charts(folder)
	var bundle := ImportAPI.load_bundle_in(folder, chart)
	if not play_bundle(bundle):
		return false
	selected_folder = folder
	selected_chart = str(bundle.get("chart_path", ""))
	return true


## 当前这张谱面在成绩册里的键：文件夹里只有一张谱面时就是文件夹名，
## 有多张时按谱面分记（见 Scores.key_of）。
func score_key() -> String:
	return Scores.key_of(selected_folder, selected_chart, charts.size())

func readChart(path: String = "res://chart/Antithesis/chart.json", folder: String = "") -> bool:
	# 显式给出文件夹时它就是这首歌的身份，单曲延迟按它取（见 Setting.song_offset_of）。
	if not folder.is_empty():
		selected_folder = folder
	return accept_chart(ImportAPI.load_chart(path, folder))

func readMusic(path: String = "res://chart/Antithesis/96224702..mp3", folder: String = "") -> bool:
	music = ImportAPI.load_audio(path, folder)
	return music != null

func readBg(path: String = "res://chart/Antithesis/96224702.jpg", folder: String = "") -> bool:
	bg = ImportAPI.load_background(path, folder)
	return bg != null

func play_bundle(bundle: Dictionary) -> bool:
	if not bundle.get("ok", false):
		last_error = bundle.get("error", "无法读取谱面")
		return false
	if not accept_chart(bundle.get("data")):
		return false
	music = bundle.get("music")
	bg = bundle.get("bg")
	return true

func getAlltime() -> float:
	return music.get_length() if music else 0.0

## 最终音频延迟（秒）= 单曲延迟 + 时间偏移 - 谱面偏移 + 谱面自带 offset。
## 游玩时钟是 chart_time = 音频位置 - 最终延迟（见 gd/room/demo.gd），所以正值 = 谱面整体推后去等声音，
## 听起来是音频相对谱面提前；玩家填的正是「我这边声音比谱面晚多少毫秒」（设置页提示与这个方向一致，别写反）。
## 「谱面偏移」是同一个相对位移的反方向写法（谱面 +100 与时间偏移 -100 等效），所以这里是减。
## 四项之和只在这里算：游玩时钟与开唱倒计时都走这个出口，避免多处各加一遍。
func total_offset_seconds() -> float:
	var chart_offset := chart_data.offset if chart_data != null else 0.0
	return (chart_offset + Setting.offset + Setting.song_offset_of(selected_folder) - Setting.chart_offset) / 1000.0

func getStartTime() -> float:
	return -total_offset_seconds() - wait_time

func getAllcombo() -> int:
	var units := 0
	if chart_data:
		for note in chart_data.note:
			if not note.fake:
				units += 2 if note.type == "Hold" else 1
	return units
