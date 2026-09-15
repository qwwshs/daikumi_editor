extends Node
## All external I/O passes through this service, including Android SAF tree URIs.
## Imports copy their sources; a failed import never overwrites an existing chart.

signal storage_changed
## 谱面库内容发生变化（导入完成）；new_path 为新增目录，开始界面据此刷新并选中它。
signal library_changed(new_path: String)

## 新文件统一写入 data；旧版 date 目录仅作为谱面库的兼容读取来源。
## 公有目录无法写入时退回应用私有目录（user://）。
const PUBLIC_CANDIDATES := [
	"/storage/emulated/0/data/dakumi",
]
const LEGACY_PUBLIC_ROOT := "/storage/emulated/0/date/dakumi"
const MAX_FILE_BYTES := 256 * 1024 * 1024
const MAX_IMPORT_BYTES := 1024 * 1024 * 1024
const MAX_IMPORT_FILES := 10000
## 公有目录需要的运行时权限。MANAGE_EXTERNAL_STORAGE 由系统跳到设置页确认，其余是普通弹窗；
## 缺少它们时仅影响“落在公有目录”，导入本身在私有目录下仍然可用。
const REQUIRED_PERMISSIONS: PackedStringArray = [
	"android.permission.MANAGE_EXTERNAL_STORAGE",
	"android.permission.READ_EXTERNAL_STORAGE",
	"android.permission.WRITE_EXTERNAL_STORAGE",
	"android.permission.READ_MEDIA_AUDIO",
	"android.permission.READ_MEDIA_IMAGES",
]

var root_path: String = "user://"
var chart_dir: String = "user://chart"
var users_dir: String = "user://users"
var is_public: bool = false
var last_error: String = ""
var status_message: String = ""


func _ready() -> void:
	refresh_storage()
	if OS.get_name() != "Android":
		return
	# 申请公有目录需要的运行时权限。系统弹窗会暂停应用，玩家也可能在设置页里手动开启
	# “所有文件访问权限”，两种情况都以「重新获得焦点」收尾；届时重探一次即可自动切换到公有目录。
	var granted := OS.get_granted_permissions()
	for permission in REQUIRED_PERMISSIONS:
		if not granted.has(permission):
			OS.request_permissions()
			break


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and OS.get_name() == "Android" and not is_public:
		refresh_storage()


func refresh_storage() -> void:
	last_error = ""
	var previous_root := root_path
	# Android scoped storage may reject a raw shared-storage path. Probe the
	# actual directories rather than assuming a permission flag grants access.
	root_path = ""
	if OS.get_name() == "Android":
		for candidate in PUBLIC_CANDIDATES:
			if _probe_root(candidate):
				root_path = candidate
				break
	is_public = not root_path.is_empty()
	if not is_public:
		root_path = "user://"
	chart_dir = root_path.path_join("chart")
	users_dir = root_path.path_join("users")
	DirAccess.make_dir_recursive_absolute(chart_dir)
	DirAccess.make_dir_recursive_absolute(users_dir)
	status_message = "公有目录：%s" % root_path if is_public else "私有目录：%s" % ProjectSettings.globalize_path(root_path)
	if OS.get_name() == "Android" and not is_public:
		status_message += "（系统未允许写入指定公有目录，导入仍可使用系统文件选择器）"
	if previous_root != root_path or is_inside_tree():
		storage_changed.emit()


func _probe_root(path: String) -> bool:
	for child in ["chart", "users"]:
		var directory := path.path_join(child)
		# 目录已存在时 make_dir_recursive 也可能返回非 OK，所以先判断存在性。
		if not DirAccess.dir_exists_absolute(directory) and DirAccess.make_dir_recursive_absolute(directory) != OK:
			return false
		var probe := directory.path_join(".dakumi-write-probe-%s" % Time.get_ticks_usec())
		var file := FileAccess.open(probe, FileAccess.WRITE)
		if file == null:
			return false
		file.store_8(1)
		var write_ok := file.get_error() == OK
		file.close()
		DirAccess.remove_absolute(probe)
		if not write_ok:
			return false
	return true


func pick_file(owner: Node, filters: PackedStringArray, callback: Callable) -> void:
	_pick(owner, FileDialog.FILE_MODE_OPEN_FILE, filters, callback)


func pick_directory(owner: Node, callback: Callable) -> void:
	_pick(owner, FileDialog.FILE_MODE_OPEN_DIR, PackedStringArray(), callback)


func _pick(owner: Node, mode: int, filters: PackedStringArray, callback: Callable) -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	dialog.use_native_dialog = true
	dialog.filters = filters
	dialog.title = "选择谱面文件夹（授予整个文件夹访问权限）" if mode == FileDialog.FILE_MODE_OPEN_DIR else "选择导入文件"
	owner.add_child(dialog)
	var selected := func(path: String) -> void:
		persist_uri(path)
		if callback.is_valid():
			callback.call(path)
		dialog.queue_free()
	dialog.file_selected.connect(selected)
	dialog.dir_selected.connect(selected)
	dialog.canceled.connect(func() -> void:
		if callback.is_valid():
			callback.call("")
		dialog.queue_free()
	)
	dialog.popup_centered_ratio(0.85)


func persist_uri(path: String) -> void:
	if not path.begins_with("content://") or not Engine.has_singleton("AndroidRuntime"):
		return
	var runtime := Engine.get_singleton("AndroidRuntime")
	if runtime.has_method("updatePersistableUriPermission"):
		runtime.call("updatePersistableUriPermission", path.get_slice("#", 0), true)


## A SAF tree child is tree_uri#relative/path, NOT tree_uri/relative/path.
func resolve_path(folder: String, relative: String) -> String:
	if relative.is_empty():
		return folder
	if relative.begins_with("content://") or relative.is_absolute_path():
		return relative
	if folder.begins_with("content://"):
		var tree := folder.get_slice("#", 0)
		var prefix := folder.get_slice("#", 1) if folder.contains("#") else ""
		var child := prefix.path_join(relative).simplify_path().trim_prefix("/")
		return tree + "#" + child
	return folder.path_join(relative).simplify_path()


func base_directory(path: String) -> String:
	if path.begins_with("content://"):
		if path.contains("#"):
			var relative := path.get_slice("#", 1)
			return path.get_slice("#", 0) + "#" + relative.get_base_dir()
		# A single-document permission never implies sibling-folder permission.
		return ""
	return path.get_base_dir()


func display_name(path: String) -> String:
	return path.uri_decode().replace("\\", "/").get_file().get_slice("#", 0)


func list_directory(folder: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		last_error = "无法访问文件夹，请重新通过系统选择器授权：%s" % folder
		return entries
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			entries.append({"name": entry, "path": resolve_path(folder, entry), "is_dir": dir.current_is_dir()})
		entry = dir.get_next()
	dir.list_dir_end()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	return entries


func read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "无法读取文件，请检查文件是否存在或重新授权：%s" % path
		return PackedByteArray()
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		last_error = "单文件超过 256 MiB 导入限制：%s" % display_name(path)
		return PackedByteArray()
	var data := file.get_buffer(file.get_length())
	file.close()
	return data


func write_bytes(path: String, bytes: PackedByteArray) -> bool:
	if DirAccess.make_dir_recursive_absolute(base_directory(path)) != OK:
		last_error = "无法创建目标文件夹：%s" % base_directory(path)
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "无法写入文件：%s" % path
		return false
	file.store_buffer(bytes)
	var result := file.get_error()
	file.close()
	if result != OK:
		last_error = "文件写入未完成：%s（%s）" % [path, result]
	return result == OK


func copy_file(source: String, target: String) -> bool:
	var bytes := read_bytes(source)
	if bytes.is_empty() and not last_error.is_empty():
		return false
	return write_bytes(target, bytes)


func import_asset(path: String) -> String:
	last_error = ""
	if path.is_empty():
		return ""
	var target := unique_path(users_dir, _safe_name(display_name(path)))
	return target if copy_file(path, target) else ""

func unique_path(folder: String, filename: String) -> String:
	var candidate := folder.path_join(filename)
	var index := 2
	while FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(candidate):
		var extension := filename.get_extension()
		candidate = folder.path_join("%s (%s)%s" % [filename.get_basename(), index, "." + extension if not extension.is_empty() else ""])
		index += 1
	return candidate


func _safe_name(value: String) -> String:
	var result := value.validate_filename().strip_edges().trim_suffix(".")
	return "imported" if result.is_empty() else result


## Copies the complete selected tree, so custom readers retain sidecar access.
func import_folder(source: String) -> String:
	last_error = ""
	var target := unique_path(chart_dir, _safe_name(display_name(source)))
	if not _copy_tree(source, target, {"count": 0, "bytes": 0}, 0):
		return ""
	library_changed.emit(target)
	return target


func _copy_tree(source: String, target: String, budget: Dictionary, depth: int) -> bool:
	if depth > 32:
		last_error = "文件夹层级超过 32 层，已停止导入。"
		return false
	var directory := DirAccess.open(source)
	if directory == null:
		last_error = "无法读取整个文件夹，请使用文件夹选择器授权：%s" % source
		return false
	if DirAccess.make_dir_recursive_absolute(target) != OK:
		last_error = "无法创建导入目录：%s" % target
		return false
	for entry in list_directory(source):
		var name: String = entry.name
		if not _valid_relative_path(name) or name.contains("/") or directory.is_link(name):
			last_error = "文件夹含有不安全的文件名或符号链接：%s" % name
			return false
		budget.count += 1
		if budget.count > MAX_IMPORT_FILES:
			last_error = "一次导入最多支持 10000 个文件和文件夹。"
			return false
		var destination := target.path_join(name)
		if entry.is_dir:
			if not _copy_tree(entry.path, destination, budget, depth + 1):
				return false
		else:
			var bytes := read_bytes(entry.path)
			if not last_error.is_empty():
				return false
			budget.bytes += bytes.size()
			if budget.bytes > MAX_IMPORT_BYTES:
				last_error = "一次导入的总大小不能超过 1 GiB。"
				return false
			if not write_bytes(destination, bytes):
				return false
	return true


func _valid_relative_path(path: String) -> bool:
	# 用 UTF-8 字节判断 NUL：String.chr(0) 在 4.7 会触发引擎的 “Unexpected NUL character” 警告。
	if path.is_empty() or path.begins_with("/") or path.contains("\\") or path.contains(":") or path.to_utf8_buffer().has(0):
		return false
	for segment in path.trim_suffix("/").split("/"):
		if segment.is_empty() or segment in [".", ".."] or segment != segment.validate_filename() or segment.ends_with(".") or segment.ends_with(" "):
			return false
	return true


## Validate paths and declared uncompressed sizes BEFORE creating output files.
func import_zip(path: String) -> String:
	last_error = ""
	var target := unique_path(chart_dir, _safe_name(display_name(path).get_basename()))
	if not extract_zip(path, target):
		return ""
	library_changed.emit(target)
	return target


## 把 ZIP 解压到一个指定目录：先整包校验（越界路径、重名、大小），再落盘。
## 曲包导入（.t3bundle / .t3pkg）也要用它，所以目录名由调用方决定。
func extract_zip(path: String, target: String) -> bool:
	last_error = ""
	if target.is_empty():
		target = unique_path(chart_dir, _safe_name(display_name(path).get_basename()))
	if not _validate_zip_budget(path):
		return false
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		last_error = "ZIP 无法打开，文件可能已损坏。"
		return false
	var names := reader.get_files()
	var seen: Dictionary = {}
	for name in names:
		var key := name.trim_suffix("/").to_lower()
		if not _valid_relative_path(name) or seen.has(key):
			last_error = "ZIP 含越界路径、重复名称或不兼容的文件名：%s" % name
			reader.close()
			return false
		seen[key] = name.ends_with("/")
	for key in seen:
		var ancestor: String = key.get_base_dir()
		while not ancestor.is_empty():
			if seen.has(ancestor) and not seen[ancestor]:
				last_error = "ZIP 的文件与目录名称冲突：%s" % key
				reader.close()
				return false
			ancestor = ancestor.get_base_dir()
	for name in names:
		var output := target.path_join(name)
		if name.ends_with("/"):
			if DirAccess.make_dir_recursive_absolute(output) != OK:
				last_error = "无法创建解压目录：%s" % output
				break
		else:
			var data := reader.read_file(name)
			if not write_bytes(output, data):
				break
	reader.close()
	return last_error.is_empty()


func _validate_zip_budget(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "无法读取 ZIP：%s" % path
		return false
	var length := file.get_length()
	file.seek(maxi(0, length - 65557))
	var tail := file.get_buffer(mini(length, 65557))
	var end := tail.size() - 22
	while end >= 0 and tail.decode_u32(end) != 0x06054b50:
		end -= 1
	if end < 0:
		last_error = "不是有效的 ZIP 文件。"
		file.close()
		return false
	var count := tail.decode_u16(end + 10)
	var directory_size := tail.decode_u32(end + 12)
	var directory_offset := tail.decode_u32(end + 16)
	if count == 0 or count > MAX_IMPORT_FILES or directory_size > 8 * 1024 * 1024 or directory_offset + directory_size > length or tail.decode_u16(end + 4) != 0:
		last_error = "不支持空 ZIP、分卷、ZIP64 或超大目录（最多 10000 个文件）。"
		file.close()
		return false
	file.seek(directory_offset)
	var central := file.get_buffer(directory_size)
	file.close()
	var cursor := 0
	var total := 0
	for index in count:
		if cursor + 46 > central.size() or central.decode_u32(cursor) != 0x02014b50:
			last_error = "ZIP 文件目录损坏。"
			return false
		var size := central.decode_u32(cursor + 24)
		total += size
		if size > MAX_FILE_BYTES or total > MAX_IMPORT_BYTES or central.decode_u16(cursor + 8) & 1:
			last_error = "ZIP 超过大小限制（单文件 256 MiB / 总计 1 GiB），或含加密文件。"
			return false
		cursor += 46 + central.decode_u16(cursor + 28) + central.decode_u16(cursor + 30) + central.decode_u16(cursor + 32)
	return true


## 在谱面库里新建一个文件夹（用来给歌曲分组）。目录名会做文件名校验；
## 重名自动改成「名字 (2)」而不是报错——玩家想要的是一个装歌的地方，不是一次报错。
func create_folder(folder: String, name: String) -> String:
	last_error = ""
	var base := folder.strip_edges().rstrip("/")
	if base.is_empty():
		base = chart_dir
	if not _inside_library(base):
		last_error = "只能在谱面库里新建文件夹。"
		return ""
	var safe := display_name(name).validate_filename().strip_edges().trim_suffix(".")
	if safe.is_empty() or not _valid_relative_path(safe):
		last_error = "文件夹名字里有不能用的字符：%s" % name
		return ""
	var target := unique_path(base, safe)
	if DirAccess.make_dir_recursive_absolute(target) != OK:
		last_error = "无法创建文件夹：%s" % safe
		return ""
	storage_changed.emit()
	return target


## 把一首歌（或一整个文件夹）挪到另一个文件夹里（空串 = 谱面库根目录）。
## 成绩与单曲延迟按文件夹名记，所以挪位置不会丢；同名时新位置下的名字会自动加「(2)」。
func move_tree(source: String, folder: String) -> String:
	last_error = ""
	var from := source.strip_edges().rstrip("/")
	var into := folder.strip_edges().rstrip("/")
	if into.is_empty():
		into = chart_dir
	if not _inside_library(from):
		last_error = "只能移动谱面库里的内容：%s" % display_name(source)
		return ""
	if not _inside_library(into):
		last_error = "只能移动到谱面库里的文件夹。"
		return ""
	if from == into or into.begins_with(from + "/"):
		last_error = "不能把文件夹移动到它自己里面。"
		return ""
	if from.get_base_dir().rstrip("/") == into:
		return from
	var target := unique_path(into, _safe_name(display_name(from)))
	if not _move_tree(from, target):
		return ""
	storage_changed.emit()
	return target


## 移动一格：同一个卷上直接改名最快，失败（跨卷：私有目录 ↔ 公有目录）时退回「复制 + 删除」。
## 复制这条路万一删不掉源目录，会在 last_error 里说清楚新位置仍然可用，免得玩家以为歌丢了。
func _move_tree(source: String, target: String) -> bool:
	if DirAccess.rename_absolute(source, target) == OK:
		return true
	if not _copy_tree(source, target, {"count": 0, "bytes": 0}, 0):
		return false
	if not _remove_tree(source, 0):
		last_error = "已复制到新位置，但没能删除原来的文件夹：%s" % last_error
		return false
	return true


## 谱面库的根目录们：当前写入位置、私有目录里的旧库，以及安卓上的旧公有目录。
func library_roots() -> Array[String]:
	var roots: Array[String] = [chart_dir]
	if chart_dir != "user://chart":
		roots.append("user://chart")
	if OS.get_name() == "Android":
		roots.append(LEGACY_PUBLIC_ROOT.path_join("chart"))
	return roots


func library_directories() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for library_root in library_roots():
		if not DirAccess.dir_exists_absolute(library_root):
			continue
		for entry in list_directory(library_root):
			if entry.is_dir:
				result.append(entry)
	return result


## 删除一个谱面文件夹（整首歌）。只允许删谱面库里的内容：库根自己与库外路径一律拒绝，
## 免得路径拼错就把整个谱面库或别的目录删掉。成功后广播 storage_changed，界面据此刷新。
func delete_tree(path: String) -> bool:
	last_error = ""
	var target := path.strip_edges().rstrip("/")
	if not _inside_library(target, false):
		last_error = "只能删除谱面库里的内容：%s" % display_name(path)
		return false
	if not _remove_tree(target, 0):
		return false
	storage_changed.emit()
	return true


## 删除单个文件（删除一张谱面用），同样限制在谱面库内。
func delete_file(path: String) -> bool:
	last_error = ""
	if not _inside_library(path, false):
		last_error = "只能删除谱面库里的内容：%s" % display_name(path)
		return false
	if not _remove(path):
		return false
	storage_changed.emit()
	return true


## 库内的路径 = 某个库根的子项，不含 ..（后者能拼出库外的路径）。
## allow_root 决定库根本身算不算数：删除时不算（免得路径拼错就把整个谱面库删了），
## 建文件夹 / 移动到的目标地点算（谱面库根目录就是最外层的那一级）。
func _inside_library(path: String, allow_root: bool = true) -> bool:
	if path.is_empty() or path.begins_with("res://"):
		return false
	for root in library_roots():
		var base := root.trim_suffix("/")
		# 库根本身也算库内（新建 / 移动到根目录就落在它上面），是不是允许由 allow_root 决定。
		if path != base and not (path.begins_with(base + "/") or path.begins_with(base + "#")):
			continue
		var rest := path.trim_prefix(base).trim_prefix("/").trim_prefix("#")
		if rest.contains(".."):
			continue
		if not rest.is_empty() or allow_root:
			return true
	return false


## 递归删除文件夹：先删内容再删自己，深度上限与导入一致。
## 中途有任何一项删不掉就停下并报错（已经删掉的部分不会恢复——删除本来就不保证可回滚）。
func _remove_tree(path: String, depth: int) -> bool:
	if depth > 32:
		last_error = "文件夹层级超过 32 层，已停止删除。"
		return false
	if DirAccess.dir_exists_absolute(path):
		last_error = ""
		var entries := list_directory(path)
		if not last_error.is_empty():
			return false
		for entry in entries:
			if entry.is_dir:
				if not _remove_tree(entry.path, depth + 1):
					return false
			elif not _remove(entry.path):
				return false
	return _remove(path)


func _remove(path: String) -> bool:
	var result := DirAccess.remove_absolute(path)
	if result != OK:
		last_error = "无法删除：%s（错误码 %d）" % [display_name(path), result]
		return false
	return true
