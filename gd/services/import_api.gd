extends Node
## Public loading API. Custom readers return null to let the next reader or the
## built-in JSON / MP3 / WAV / OGG / PNG / JPEG / WebP decoder handle a file.

signal plugins_changed

const REGISTRY_PATH := "user://reader_plugins.json"
const MANIFEST_NAME := "dakumi.bundle.json"
const CONTEXT := preload("res://gd/services/import_context.gd")

var last_error: String = ""
var _plugins: Array[Dictionary] = []
var _readers: Array[Dictionary] = []


func _ready() -> void:
	register_reader("builtin-takana", preload("res://readers/takana_reader.gd").new(), -100)
	if FileAccess.file_exists(REGISTRY_PATH):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
		if saved is Array:
			for value in saved:
				if value is Dictionary and value.has_all(["id", "path", "name", "enabled"]):
					_plugins.append(value)
	# Only explicitly enabled readers are executed on subsequent launches.
	for plugin in _plugins:
		if plugin.enabled:
			if not _activate_plugin(plugin):
				plugin.enabled = false


func make_context(path: String, context_root: String = "") -> DakumiImportContext:
	return CONTEXT.new(Storage, context_root if not context_root.is_empty() else Storage.base_directory(path), path)


## kind is "chart", "audio" or "background"; higher priority runs first.
func register_reader(id: String, reader: RefCounted, priority: int = 0) -> void:
	unregister_reader(id)
	_readers.append({"id": id, "reader": reader, "priority": priority})
	_readers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.priority > b.priority)


func unregister_reader(id: String) -> void:
	for index in range(_readers.size() - 1, -1, -1):
		if _readers[index].id == id:
			_readers.remove_at(index)


func _try_readers(kind: String, path: String, context: DakumiImportContext) -> Variant:
	for registered in _readers:
		var reader: RefCounted = registered.reader
		if reader.has_method("can_read") and reader.has_method("read_" + kind) and reader.call("can_read", kind, path, context):
			var result: Variant = reader.call("read_" + kind, path, context)
			if result != null:
				return result
	return null


func load_chart(path: String, context_root: String = "") -> Variant:
	last_error = ""
	Storage.last_error = ""
	var context := make_context(path, context_root)
	var custom: Variant = _try_readers("chart", path, context)
	if custom is Dictionary and custom.has("reader_error"):
		last_error = str(custom.reader_error)
		return null
	if custom is Dictionary or custom is String:
		return custom
	var text := Storage.read_bytes(path).get_string_from_utf8()
	if not Storage.last_error.is_empty():
		last_error = Storage.last_error
		return null
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		last_error = "谱面不是有效的 JSON 对象，或需要先启用对应读取扩展：%s" % Storage.display_name(path)
		return null
	return parser.data


func load_audio(path: String, context_root: String = "") -> AudioStream:
	last_error = ""
	Storage.last_error = ""
	if path.is_empty():
		return null
	var custom: Variant = _try_readers("audio", path, make_context(path, context_root))
	if custom is AudioStream:
		return custom
	var data := Storage.read_bytes(path)
	if not Storage.last_error.is_empty():
		last_error = Storage.last_error
		return null
	var extension := Storage.display_name(path).get_extension().to_lower()
	var audio: AudioStream
	# MIME providers sometimes return an opaque document ID with no extension.
	if extension == "wav" or (data.size() > 12 and data.slice(0, 4).get_string_from_ascii() == "RIFF"):
		audio = AudioStreamWAV.load_from_buffer(data)
	elif extension == "ogg" or (data.size() > 4 and data.slice(0, 4).get_string_from_ascii() == "OggS"):
		audio = AudioStreamOggVorbis.load_from_buffer(data)
	elif extension == "mp3" or (data.size() > 3 and (data.slice(0, 3).get_string_from_ascii() == "ID3" or (data[0] == 0xff and data[1] & 0xe0 == 0xe0))):
		audio = AudioStreamMP3.load_from_buffer(data)
	# 解码器遇到损坏数据时可能返回“非 null 但不可用”的流（例如 WAV 头损坏后采样率为 0），
	# 这里补一次可用性校验，避免导入看起来成功却没有声音。
	if audio is AudioStreamWAV:
		var wav: AudioStreamWAV = audio
		if wav.mix_rate <= 0 or wav.data.is_empty():
			audio = null
	elif audio != null and audio.get_length() <= 0.0:
		audio = null
	if audio == null:
		last_error = "无法解码音频；内置支持 MP3、WAV、OGG，也可启用音频读取扩展。"
	return audio


func load_background(path: String, context_root: String = "") -> Texture2D:
	last_error = ""
	Storage.last_error = ""
	if path.is_empty():
		return null
	var custom: Variant = _try_readers("background", path, make_context(path, context_root))
	if custom is Texture2D:
		return custom
	var bytes := Storage.read_bytes(path)
	if not Storage.last_error.is_empty():
		last_error = Storage.last_error
		return null
	var image := Image.new()
	var result := ERR_FILE_UNRECOGNIZED
	if bytes.size() >= 8 and bytes[0] == 137 and bytes.slice(1, 4).get_string_from_ascii() == "PNG":
		result = image.load_png_from_buffer(bytes)
	elif bytes.size() >= 3 and bytes[0] == 255 and bytes[1] == 216:
		result = image.load_jpg_from_buffer(bytes)
	elif bytes.size() >= 12 and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		result = image.load_webp_from_buffer(bytes)
	if result != OK:
		last_error = "图片解码失败；内置支持 PNG、JPEG、WebP，也可启用图片读取扩展。"
		return null
	return ImageTexture.create_from_image(image)


func load_bundle(chart_path: String, audio_path: String = "", background_path: String = "", folder: String = "") -> Dictionary:
	var result := {"ok": false, "data": null, "music": null, "bg": null, "chart_path": chart_path, "audio_path": audio_path, "background_path": background_path, "folder": folder, "error": ""}
	result.data = load_chart(chart_path, folder)
	if result.data == null:
		result.error = last_error
		return result
	if not audio_path.is_empty():
		result.music = load_audio(audio_path, folder)
		if result.music == null:
			result.error = last_error
			return result
	if not background_path.is_empty():
		result.bg = load_background(background_path, folder)
		if result.bg == null:
			result.error = last_error
			return result
	result.ok = true
	return result


## Manifest paths may be relative to the folder, absolute, or independent SAF
## document URIs. A custom reader can resolve a folder with resolve_bundle().
func resolve_directory(folder: String) -> Dictionary:
	return _resolve_directory(folder, 0)


func _resolve_directory(folder: String, depth: int) -> Dictionary:
	last_error = ""
	var context := make_context("", folder)
	var manifest := Storage.resolve_path(folder, MANIFEST_NAME)
	if FileAccess.file_exists(manifest):
		var data: Variant = JSON.parse_string(Storage.read_bytes(manifest).get_string_from_utf8())
		var chart := str(data.get("chart", "")) if data is Dictionary else ""
		if not chart.is_empty():
			var manifest_audio := str(data.get("audio", "")) if data is Dictionary else ""
			var manifest_background := str(data.get("background", "")) if data is Dictionary else ""
			var manifest_folder := str(data.get("folder", "")) if data is Dictionary else ""
			var bundle := load_bundle(context.resolve(chart),
				context.resolve(manifest_audio) if not manifest_audio.is_empty() else "",
				context.resolve(manifest_background) if not manifest_background.is_empty() else "",
				context.resolve(manifest_folder))
			if not bundle.get("ok", false):
				bundle.error = "dakumi.bundle.json 指向的文件无法读取：%s" % bundle.get("error", "")
			return bundle
		# 清单存在但没有可用的谱面路径时继续扫描目录，方便手写或修改清单。
	for registered in _readers:
		var reader: RefCounted = registered.reader
		if reader.has_method("resolve_bundle"):
			var custom: Variant = reader.call("resolve_bundle", context)
			if custom is Dictionary and custom.has("chart"):
				return load_bundle(context.resolve(str(custom.chart)), context.resolve(str(custom.audio)) if custom.has("audio") and not str(custom.audio).is_empty() else "", context.resolve(str(custom.background)) if custom.has("background") and not str(custom.background).is_empty() else "", folder)
	var candidates: Array[String] = []
	var directories: Array[String] = []
	var audio := ""
	var background := ""
	for entry in context.list():
		if entry.is_dir:
			directories.append(entry.path)
			continue
		var filename: String = entry.name
		var extension := filename.get_extension().to_lower()
		if extension in ["mp3", "wav", "ogg"] and audio.is_empty():
			audio = entry.path
		elif extension in ["png", "jpg", "jpeg", "webp"] and background.is_empty():
			background = entry.path
		elif filename.to_lower() not in [MANIFEST_NAME, "skin.json", "manifest.json", "settings.json", "reader_plugins.json"]:
			if extension == "json":
				var value: Variant = JSON.parse_string(Storage.read_bytes(entry.path).get_string_from_utf8())
				if value is Dictionary and (filename.to_lower() == "chart.json" or value.has("note") or value.has("bpm") or value.has("event")):
					if filename.to_lower() == "chart.json":
						candidates.push_front(entry.path)
					else:
						candidates.append(entry.path)
			else:
				for registered in _readers:
					if registered.reader.has_method("can_read") and registered.reader.call("can_read", "chart", entry.path, context):
						candidates.append(entry.path)
						break
	if not candidates.is_empty():
		return load_bundle(candidates[0], audio, background, folder)
	# A ZIP commonly has a single top-level song directory. Also handle song
	# packs deterministically while keeping the recursion bounded.
	if depth < 8:
		for directory in directories:
			var nested := _resolve_directory(directory, depth + 1)
			if nested.get("ok", false):
				return nested
	last_error = "文件夹内未找到可读取的谱面；自定义格式请先启用读取扩展，或使用分散文件导入。"
	return {"ok": false, "error": last_error}


## Store a portable library entry. Sidecars retain their folder layout, while
## separately picked audio/background files are copied into a distinct folder.
## 只选文件夹时整个目录树会被复制，谱面、音频、背景由 resolve_directory 扫描得到。
func import_files(chart_path: String, audio_path: String = "", background_path: String = "", chart_folder: String = "") -> String:
	last_error = ""
	Storage.last_error = ""
	if chart_path.is_empty() and chart_folder.is_empty():
		last_error = "请先选择谱面文件或谱面文件夹。"
		return ""
	var folder_import := not chart_folder.is_empty()
	var target := Storage.import_folder(chart_folder) if folder_import else Storage.unique_path(Storage.chart_dir, Storage.display_name(chart_path).get_basename().validate_filename())
	if target.is_empty():
		last_error = Storage.last_error
		return ""
	var assets := Storage.unique_path(target, "_dakumi_selected")
	var manifest := {"version": 1, "chart": "", "audio": "", "background": "", "folder": ""}
	for item in [{"key": "chart", "path": chart_path}, {"key": "audio", "path": audio_path}, {"key": "background", "path": background_path}]:
		var source: String = item.path
		if source.is_empty():
			continue
		var relative := _relative_to_folder(source, chart_folder)
		if not relative.is_empty() and FileAccess.file_exists(Storage.resolve_path(target, relative)):
			manifest[item.key] = relative
		else:
			var file_name: String = Storage.display_name(source).validate_filename()
			var destination: String = Storage.unique_path(assets.path_join(item.key), file_name if not file_name.is_empty() else "selected")
			if not Storage.copy_file(source, destination):
				last_error = Storage.last_error
				return ""
			manifest[item.key] = destination.trim_prefix(target + "/")
	# 只导入文件夹时目录本身就是自描述的，不需要清单；有单独选中的文件才写清单。
	if not manifest.chart.is_empty() or not manifest.audio.is_empty() or not manifest.background.is_empty():
		if not Storage.write_bytes(target.path_join(MANIFEST_NAME), JSON.stringify(manifest, "\t").to_utf8_buffer()):
			last_error = Storage.last_error
			return ""
	Storage.library_changed.emit(target)
	return target


func _relative_to_folder(path: String, folder: String) -> String:
	if folder.is_empty():
		return ""
	var prefix := folder.trim_suffix("/") + "/"
	if folder.begins_with("content://"):
		prefix = folder + "#" if not folder.contains("#") else folder.trim_suffix("/") + "/"
	return path.trim_prefix(prefix) if path.begins_with(prefix) else ""


func import_plugin(path: String) -> String:
	last_error = ""
	Storage.last_error = ""
	var bytes := Storage.read_bytes(path)
	if not Storage.last_error.is_empty() or bytes.is_empty():
		last_error = Storage.last_error if not Storage.last_error.is_empty() else "读取扩展文件为空。"
		return ""
	if bytes.size() > 1024 * 1024:
		last_error = "单个读取扩展最大 1 MiB。"
		return ""
	var id := bytes.get_string_from_utf8().sha256_text()
	for plugin in _plugins:
		if plugin.id == id:
			return id
	var target := Storage.users_dir.path_join("readers").path_join(id + ".gd")
	if not Storage.write_bytes(target, bytes):
		last_error = Storage.last_error
		return ""
	_plugins.append({"id": id, "name": Storage.display_name(path), "path": target, "enabled": false})
	_save_plugins()
	plugins_changed.emit()
	return id


func list_plugins() -> Array[Dictionary]:
	return _plugins.duplicate(true)


## Enabling is an explicit player action: GDScript is executable code with
## the application's permissions, not a sandboxed data-format description.
func set_plugin_enabled(id: String, enabled: bool) -> bool:
	last_error = ""
	for plugin in _plugins:
		if plugin.id != id:
			continue
		if enabled and not _activate_plugin(plugin):
			return false
		if not enabled:
			unregister_reader(id)
		plugin.enabled = enabled
		_save_plugins()
		plugins_changed.emit()
		return true
	last_error = "未找到该读取扩展。"
	return false


func _activate_plugin(plugin: Dictionary) -> bool:
	var bytes := Storage.read_bytes(plugin.path)
	if bytes.is_empty() or bytes.get_string_from_utf8().sha256_text() != plugin.id:
		last_error = "读取扩展丢失或内容已改变，请重新导入并确认启用：%s" % plugin.name
		return false
	var script := GDScript.new()
	script.source_code = bytes.get_string_from_utf8()
	if script.reload() != OK or not script.can_instantiate():
		last_error = "读取扩展无法编译：%s" % plugin.name
		return false
	var reader: Variant = script.new()
	if not reader is RefCounted or not reader.has_method("can_read"):
		last_error = "读取扩展必须继承 RefCounted 并提供 can_read(kind, path, context)。"
		if reader is Node:
			reader.free()
		return false
	register_reader(plugin.id, reader, 100)
	return true


func _save_plugins() -> void:
	Storage.write_bytes(REGISTRY_PATH, JSON.stringify(_plugins, "\t").to_utf8_buffer())
