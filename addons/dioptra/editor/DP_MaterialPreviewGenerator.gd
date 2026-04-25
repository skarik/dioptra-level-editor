@tool
extends EditorResourcePreviewGenerator

var _plugin : DioptraEditorMainPlugin = null;

func _init(plugin : DioptraEditorMainPlugin) -> void:
	_plugin = plugin;
	# EditorSettings.filesystem/file_dialog/thumbnail_size
	# request_draw_and_wait for the rendering server

func _can_generate_small_preview() -> bool:
	print("_can_generate_small_preview");
	return true;
	
func _handles(type: String) -> bool:
	print(type);
	return false;

func _generate(resource: Resource, size: Vector2i, metadata: Dictionary) -> Texture2D:
	print(resource.resource_path);
	return null;
