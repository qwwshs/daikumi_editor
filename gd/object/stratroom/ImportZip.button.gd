extends Button
## 导入谱面：ZIP 压缩包、整个谱面文件夹，或 TAKANA 曲包（.t3bundle / .t3pkg）。
## 复制、大小校验、解压与安全文件名检查都由 Storage / ImportAPI 完成；这里只负责选择与提示。

const ZIP_FILTERS: PackedStringArray = ["*.zip ; ZIP 压缩包"]
## 曲包过滤器：.t3bundle 是一批歌，.t3pkg 是单个歌包，导入结果都等同于导入一个歌曲文件夹。
const BUNDLE_FILTERS: PackedStringArray = ["*.t3bundle, *.t3pkg ; TAKANA 曲包"]


func _ready() -> void:
	text = "导入谱面"
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	# 用弹出菜单而不是系统对话框，避免与文件选择器嵌套。
	var menu := PopupMenu.new()
	menu.add_item("导入 ZIP 压缩包", 0)
	menu.add_item("导入谱面文件夹", 1)
	menu.add_item("导入 TAKANA 曲包（.t3bundle / .t3pkg）", 2)
	# 处理函数先绑到变量上：match 直接写在 connect(...) 的参数位置时，
	# 解析器会把右括号当成 match 模式的一部分。
	var handle := func(id: int) -> void:
		menu.queue_free()
		match id:
			0: _import_zip()
			1: _import_folder()
			2: _import_bundle()
	menu.id_pressed.connect(handle)
	add_child(menu)
	menu.popup_centered()


func _import_zip() -> void:
	Storage.pick_file(self, ZIP_FILTERS, func(path: String) -> void:
		if path.is_empty():
			return
		var target := Storage.import_zip(path)
		_report("压缩包", target))


func _import_folder() -> void:
	# 只选文件夹时整个目录树会被复制，谱面引用的其他文件因此保持可用。
	Storage.pick_directory(self, func(path: String) -> void:
		if path.is_empty():
			return
		var target := ImportAPI.import_files("", "", "", path)
		_report("谱面文件夹", target))


## TAKANA 曲包：一个文件里装着若干首歌（内层还可能是各自打包的单曲包），
## 导入后库里多一个以曲包命名的文件夹，里面每首歌各占一个子文件夹。
func _import_bundle() -> void:
	Storage.pick_file(self, BUNDLE_FILTERS, func(path: String) -> void:
		if path.is_empty():
			return
		_report("曲包", ImportAPI.import_bundle(path)))


func _report(what: String, target: String) -> void:
	if not target.is_empty():
		_show_message("导入完成", "%s已导入到：\n%s" % [what, target])
		return
	var reason := Storage.last_error if not Storage.last_error.is_empty() else ImportAPI.last_error
	_show_message("导入失败", reason)


func _show_message(title: String, message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message if not message.is_empty() else "未知错误。"
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
