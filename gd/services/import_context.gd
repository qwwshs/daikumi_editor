class_name DakumiImportContext
extends RefCounted
## Reader-facing access to the entire folder explicitly selected by the player.
## Paths may be normal paths or Android content:// tree URIs; retain them verbatim.

var root: String
var source: String
var _storage: Node


func _init(storage: Node, folder: String, source_path: String = "") -> void:
	_storage = storage
	root = folder
	source = source_path


func resolve(path: String = "") -> String:
	return _storage.resolve_path(root, path)


func list(path: String = "") -> Array[Dictionary]:
	return _storage.list_directory(resolve(path))


func read_bytes(path: String) -> PackedByteArray:
	return _storage.read_bytes(resolve(path))


func read_text(path: String) -> String:
	return read_bytes(path).get_string_from_utf8()


func exists(path: String) -> bool:
	return FileAccess.file_exists(resolve(path))


func get_error() -> String:
	return _storage.last_error
