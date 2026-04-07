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
	
	# Set up signals now
	if !EditorInterface.get_selection().selection_changed.is_connected(_on_selection_changed):
		EditorInterface.get_selection().selection_changed.connect(_on_selection_changed);
		
	pass
	
# When selection changes we want to update the entire UI
func _on_selection_changed() -> void:
	print("New Selection");
	
	# we want to grab the last Editor object in the selection
	var last_selected_item : Node = null;
	var editor_selection := EditorInterface.get_selection();
	for i in range(editor_selection.get_selected_nodes().size()-1, -1, -1):
		var item = editor_selection.get_selected_nodes()[i];
		if item is DP_Map:
			last_selected_item = item;
			break;
	
	var target_gizmo := _plugin._plugin_maphelper._get_target_gizmo(_plugin, last_selected_item as DP_Map);
	if target_gizmo:
		var subgizmo_selection := target_gizmo.get_subgizmo_selection();
		
		if not subgizmo_selection.is_empty():
			# Grab the first face we can get
			var subgizmo_id := subgizmo_selection[subgizmo_selection.size() - 1];
			var solid_id := subgizmo_id & _plugin.cDPG_MapTest1.SELBIT_MASK_SOLID;
			var face_id := 0;
			if subgizmo_id < _plugin.cDPG_MapTest1.SELECTION_MAX_VALUE:
				face_id = 0;
			else:
				face_id = (subgizmo_id >> _plugin.cDPG_MapTest1.SELBIT_SHIFT_FACE) & _plugin.cDPG_MapTest1.SELBIT_MASK_FACE;
			
			# Grab the face:
			var map := last_selected_item as DP_Map;
			var solid := map.solids[solid_id];
			var face := solid.faces[face_id];
			
			# We can now update the editor with the face info:
			update_with_face_info(map, face);
	
	pass
	
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
	
	pass

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

## Updates the UI with the input face's parameters.
func update_with_face_info(map : DP_Map, face : DPMapFace) -> void:
	var mat := map.materials[face.material];
	
	# Update the material thumbnail
	_texture_label.text = mat.resource_path.get_basename().get_file();
	EditorInterface.get_resource_previewer().queue_resource_preview(mat.resource_path, self, "_on_material_dialog_preview_done", null);
	
	# TODO: Update the other items in the UI
	pass
