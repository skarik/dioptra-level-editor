@tool
extends Control

var _plugin : DioptraEditorMainPlugin = null;

var _texture_button : Button = null;
var _texture_label : Label = null;

var _material_dialog : EditorFileDialog = null;

func _ready() -> void:
	_texture_button = $"Container Material Select/HFlowContainer/TextureButton";
	_texture_label = $"Container Material Select/HFlowContainer/MaterialName";
	pass
	
func setPlugin(plugin : DioptraEditorMainPlugin) -> void:
	_plugin = plugin;
	
	

# This is a hack for materials because I have no idea how to do drag and drop (_get_drag_data????)
func _on_texture_button_pressed() -> void:
	_material_dialog = EditorFileDialog.new();
	_material_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE;
	_material_dialog.access = EditorFileDialog.ACCESS_RESOURCES;
	_material_dialog.filters = ["*.tres, *.material, *.res ; Supported Materials"];
	_material_dialog.title = "Select a Material";
	_material_dialog.file_selected.connect(_on_material_dialog_selected);
	
	var viewport = EditorInterface.get_base_control();
	viewport.add_child(_material_dialog);
	
	_material_dialog.set_meta("_created_by", self);
	_material_dialog.popup_file_dialog();
	
	pass # Replace with function body.

func _on_material_dialog_selected(filename : String) -> void:
	var res : Resource = load(filename);
	if res is Material:
		var mat := res as Material;
		_texture_label.text = mat.resource_path.get_basename().get_file();
		EditorInterface.get_resource_previewer().queue_resource_preview(filename, self, "_on_material_dialog_preview_done", null);
		
		# Apply the material to the map:
		_plugin._plugin_maphelper.do_assign_material(mat);
		pass
	pass
	
func _on_material_dialog_preview_done(path : String, preview : Texture2D, thumbnail_preview : Texture2D, userdata : Variant) -> void:
	_texture_button.icon = preview;
	pass
