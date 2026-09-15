extends Button
## 开始游玩：把选中的谱面文件夹交给加载层，成功后进入游玩场景。
## 读取细节（清单、分散文件、外部读取器）全部由 ImportAPI 负责，这里只做导航与提示。


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if not ChartLoader.load_from_folder(ChartLoader.selected_folder):
		_show_message("无法开始游玩", ChartLoader.last_error)
		return
	get_tree().change_scene_to_file("res://gd/room/demo.tscn")


func _show_message(title: String, message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message if not message.is_empty() else "未知错误。"
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
