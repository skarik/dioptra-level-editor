@tool
extends Control

var _plugin : DioptraEditorMainPlugin = null;

var _texture_button : Button = null;
var _texture_label : Label = null;

var _scale_spinbox_x : SpinBox = null;
var _scale_spinbox_y : SpinBox = null;
var _angle_spinbox : SpinBox = null;
var _offset_spinbox_x : SpinBox = null;
var _offset_spinbox_y : SpinBox = null;

var _material_dialog : EditorFileDialog = null;

func _ready() -> void:
	_texture_button = $"Container Material Select/HFlowContainer/TextureButton";
	_texture_label = $"Container Material Select/HFlowContainer/MaterialName";
	
	_scale_spinbox_x = $"Container UVs/VContainer/GridContainer/VBoxContainerScale/HBoxContainerX/SpinBoxX";
	_scale_spinbox_y = $"Container UVs/VContainer/GridContainer/VBoxContainerScale/HBoxContainerY/SpinBoxY";
	_angle_spinbox = $"Container UVs/VContainer/GridContainer/VBoxContainerRot/HBoxContainer2/SpinBoxRot";
	_offset_spinbox_x = $"Container UVs/VContainer/GridContainer/VBoxContainerOffset/HBoxContainerX/SpinBoxX"
	_offset_spinbox_y = $"Container UVs/VContainer/GridContainer/VBoxContainerOffset/HBoxContainerY/SpinBoxY"
	pass
	
func setPlugin(plugin : DioptraEditorMainPlugin) -> void:
	_plugin = plugin;
	
	# Set up signals now
	if !EditorInterface.get_selection().selection_changed.is_connected(_on_selection_changed):
		EditorInterface.get_selection().selection_changed.connect(_on_selection_changed);
		
	pass
	
# When selection changes we want to update the entire UI
func _on_selection_changed() -> void:
	# we want to grab the last Editor object in the selection
	var last_selected_item : Node = null;
	var editor_selection := EditorInterface.get_selection();
	for i in range(editor_selection.get_selected_nodes().size()-1, -1, -1):
		var item = editor_selection.get_selected_nodes()[i];
		if item is DP_Map:
			last_selected_item = item;
			break;
	
	# Grab map gizmo for the selection
	var target_gizmo : EditorNode3DGizmo = null;
	if _plugin and is_instance_valid(_plugin._plugin_maphelper):
		target_gizmo = _plugin._plugin_maphelper._get_target_gizmo(_plugin, last_selected_item as DP_Map);
	if target_gizmo:
		var subgizmo_selection := target_gizmo.get_subgizmo_selection();
		
		if not subgizmo_selection.is_empty():
			# Grab the first face we can get
			var subgizmo_id := subgizmo_selection[subgizmo_selection.size() - 1];
			var solid_id := subgizmo_id & DPHelpers.SELBIT_MASK_SOLID;
			var face_id := 0;
			if subgizmo_id < DPHelpers.SELECTION_MAX_VALUE:
				face_id = 0;
			else:
				face_id = (subgizmo_id >> DPHelpers.SELBIT_SHIFT_FACE) & DPHelpers.SELBIT_MASK_FACE;
			
			# Grab the face:
			var map := last_selected_item as DP_Map;
			var solid := map.solids[solid_id];
			var face := solid.faces[face_id];
			
			# We can now update the editor with the face info:
			update_with_face_info(map, face);
	
	pass
	
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var dict = data as Dictionary;
	if dict["type"] == "files":
		var filename = dict["files"][0];
		var res : Resource = load(filename);
		if res is Material:
			return true;
	return false;
	
func _drop_data(at_position: Vector2, data: Variant) -> void:
	var dict = data as Dictionary;
	var filename = dict["files"][0];
	_on_material_dialog_selected(filename);
	
	
#------------------------------------------------------------------------------#
# Texture providing:
	
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
		update_ui_with_material(mat);
		
		# Apply the material to the map:
		_plugin._plugin_maphelper.do_assign_material(mat);
		pass
	pass
	
func _on_material_dialog_preview_done(path : String, preview : Texture2D, thumbnail_preview : Texture2D, userdata : Variant) -> void:
	_texture_button.icon = preview;
	pass

## Updates the UI with the given material
func update_ui_with_material(mat : Material) -> void:
	_texture_label.text = mat.resource_path.get_basename().get_file();
	EditorInterface.get_resource_previewer().queue_resource_preview(mat.resource_path, self, "_on_material_dialog_preview_done", null);
	pass

#------------------------------------------------------------------------------#

## Updates the UI with the input face's parameters.
func update_with_face_info(map : DP_Map, face : DPMapFace) -> void:
	var mat := map.materials[face.material];
	
	# Update the material thumbnail
	update_ui_with_material(mat);
	
	# TODO: Update the other items in the UI
	
	# Update scale
	_scale_spinbox_x.set_value_no_signal(face.uv_scale.x);
	_scale_spinbox_y.set_value_no_signal(face.uv_scale.y);
	# Update rotation
	_angle_spinbox.set_value_no_signal(face.uv_rotation);
	# Update translation
	_offset_spinbox_x.set_value_no_signal(face.uv_offset.x);
	_offset_spinbox_y.set_value_no_signal(face.uv_offset.y);
	
	pass
	
#------------------------------------------------------------------------------#
# Misc Handlers
func _on_mode_selection_changed(modeType : int) -> void:
	_plugin._uvModePer =  modeType as DioptraEditorMainPlugin.UVModePer;
	print("UV Mode: %s" % _plugin.UVModePer.find_key(_plugin._uvModePer));

	for child in $"Container UVs/VContainer/GridContainer/HBoxContainerMode".get_children():
		var child_button := child as Button;
		if child_button != null:
			child_button.button_pressed = false;
			
	var child_main = $"Container UVs/VContainer/GridContainer/HBoxContainerMode".get_children()[modeType];
	var child_main_button = child_main as Button;
	if child_main_button != null:
		child_main_button.button_pressed = true;

	pass
	
#------------------------------------------------------------------------------#
# Texture transformation handlers

func _on_flip_x() -> void:
	_scale_spinbox_x.value *= -1.0;
	
func _on_flip_y() -> void:
	_scale_spinbox_y.value *= -1.0;
	
func _on_scale_changed(_dummy : float) -> void:
	var uv_scale := Vector2(_scale_spinbox_x.value, _scale_spinbox_y.value);
	_plugin._plugin_maphelper.do_assign_uv_scale(uv_scale);

func _on_rotate_180() -> void:
	_angle_spinbox.value += 180;

func _on_rotate_90() -> void:
	_angle_spinbox.value += 90;
	
func _on_rotate_N90() -> void:
	_angle_spinbox.value -= 90;
	
func _on_rotate_45() -> void:
	_angle_spinbox.value += 45;
	
func _on_angle_changed(_dummy : float) -> void:
	var angle := wrapf(_angle_spinbox.value, -360, 360);
	_angle_spinbox.set_value_no_signal(angle);
	_plugin._plugin_maphelper.do_assign_uv_angle(angle);
	
func _on_offset_changed(_dummy : float) -> void:
	var uv_offset := Vector2(_offset_spinbox_x.value, _offset_spinbox_y.value);
	_plugin._plugin_maphelper.do_assign_uv_offset(uv_offset);

	
