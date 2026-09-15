extends ItemList
## 谱面列表：数据来自 Storage 的谱面库，选中项写入 ChartLoader.selected_folder。
## 监听存储位置变化与导入完成，因此导入新谱面后无需重启即可看到并选中。

## 与列表项一一对应的谱面文件夹路径。
var _paths: Array[String] = []


func _ready() -> void:
	Storage.storage_changed.connect(_refresh)
	Storage.library_changed.connect(_refresh)
	item_clicked.connect(_on_item_clicked)
	_refresh()


## new_path 是刚导入的目录；刷新后优先选中它，其次是之前选中的项。
func _refresh(new_path: String = "") -> void:
	var wanted := new_path if not new_path.is_empty() else ChartLoader.selected_folder
	clear()
	_paths.clear()
	for entry in Storage.library_directories():
		_paths.append(str(entry.path))
		add_item(Storage.display_name(entry.path))
		set_item_tooltip(get_item_count() - 1, str(entry.path))
	if _paths.is_empty():
		add_item("谱面库为空，请先导入")
		set_item_disabled(0, true)
		ChartLoader.selected_folder = ""
		return
	var index := _paths.find(wanted)
	if index < 0:
		# 默认选中第一项，让“开始游玩”始终有明确目标。
		index = 0
	select(index)
	ChartLoader.selected_folder = _paths[index]


func _on_item_clicked(index: int, _at_position: Vector2, _mouse_button: int) -> void:
	if index < 0 or index >= _paths.size():
		return
	ChartLoader.selected_folder = _paths[index]
