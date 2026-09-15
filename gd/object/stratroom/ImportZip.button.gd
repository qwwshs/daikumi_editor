extends Button
## 导入谱面：ZIP 压缩包或整个谱面文件夹。
## 复制、大小校验、解压与安全文件名检查都由 Storage 完成；这里只负责选择与提示。

const ZIP_FILTERS: PackedStringArray = ["*.zip ; ZIP 压缩包"]


func _ready() -> void:
	text = "导入谱面"
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	# 用弹出菜单而不是系统对话框，避免与文件选择器嵌套。
	var menu := PopupMenu.new()
	menu.add_item("导入 ZIP 压缩包", 0)
	menu.add_item("导入谱面文件夹", 1)
	menu.id_pressed.connect(func(id: int) -> void:
		menu.queue_free()
		if id == 0:
			_import_zip()
		else:
			_import_folder())
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
