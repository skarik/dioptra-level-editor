@tool
extends EditorPlugin
class_name DioptraEditorMaphelperPlugin
## Class for handling editor input with the DP_Map itself.
##
## Any input that needs to come in through the 3D editor when the DP_Map is selected is captured by
## this class. The signals are then either forwarded to the main plugin or handled here, depending
## on the action.
## 
## TODO: make most of the map actions here for cleanliness & consistency or no?

#------------------------------------------------------------------------------#

var _editor_plugin : DioptraEditorMainPlugin = null; #circular is OK here because they're nodes

#------------------------------------------------------------------------------#

func _enter_tree() -> void:
	pass

func _exit_tree() -> void:
	_editor_plugin = null;
	pass
	
func _enable_plugin() -> void:
	pass
	
func _disable_plugin() -> void:
	_editor_plugin = null;
	pass
	
func _ready() -> void:
	_get_editor_plugin();
	
func _process(delta: float) -> void:
	# TODO: Does not work
	if not _selection_restore.is_empty():
		EditorInterface.get_selection().clear();
		for node in _selection_restore:
			EditorInterface.get_selection().add_node(node);
		_selection_restore = [];
	
	pass

#------------------------------------------------------------------------------#

var _last_edited_map : DP_Map = null;
var _selection_restore : Array[Node] = [];

#------------------------------------------------------------------------------#

# Handle the DP_InternalTool, which lets us actually perform work with the editor
func _handles(object: Object) -> bool:
	if object is DP_Map:
		return true;
	return false;
	
func _edit(object: Object) -> void:
	if object is DP_Map:
		_last_edited_map = object as DP_Map;
	pass
	
func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	var editor := _get_editor_plugin();
	var map := editor.get_last_edited_map();
	
	#print(event.get_class() + " : " + event.as_text());
	
	if editor._currentTool == null:
		if event is InputEventKey:
			#print(event.get_class() + " : " + event.as_text());
			if event.keycode == KEY_DELETE:
				if _action_delete_selected_solids(editor, map):
					return EditorPlugin.AFTER_GUI_INPUT_STOP;
		pass
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS;
	
#------------------------------------------------------------------------------#

func _get_editor_plugin() -> DioptraEditorMainPlugin:
	if _editor_plugin != null:
		return _editor_plugin;
	
	# Search the owner (assumed editor):
	for child in get_parent().get_children():
		if child is DioptraEditorMainPlugin:
			_editor_plugin = child;
			_editor_plugin._plugin_maphelper = self;
			break;
		
	return _editor_plugin;

#------------------------------------------------------------------------------#

func _get_target_gizmo(editor : DioptraEditorMainPlugin, map : DP_Map) -> EditorNode3DGizmo:
	if not map:
		return null;
	var gizmos := map.get_gizmos();
	var target_gizmo : EditorNode3DGizmo = null;
	for item : Node3DGizmo in gizmos:
		if item is EditorNode3DGizmo:
			var editor_item = item as EditorNode3DGizmo;
			var plugin : EditorNode3DGizmoPlugin = editor_item.get_plugin();
			if plugin == editor.DPGizmoPlugin_MapTest1:
				target_gizmo = editor_item;
				break;
	return target_gizmo;

func _action_delete_selected_solids(editor : DioptraEditorMainPlugin, map : DP_Map) -> bool:
	# TODO: assert we're in solid selection mode
	var target_gizmo := _get_target_gizmo(editor, map);
	if target_gizmo:
		var subgizmo_selection := target_gizmo.get_subgizmo_selection();
		# Count upwards when deleting
		subgizmo_selection.sort();
		for i in subgizmo_selection.size():
			var selection = subgizmo_selection[i] - i;
			map.solids.remove_at(selection);
		# Clear selection
		map.clear_subgizmo_selection();
		# Remove the editor map entirely on delete
		map.rebuild_editor_mesh_groups();
		map.rebuild_editor_map();
		# Hack so that SceneTreeDock doesn't keep monching the deleting signal. We'll bring it back next frame
		_selection_restore = EditorInterface.get_selection().get_selected_nodes().duplicate();
		EditorInterface.get_selection().clear(); # hack (see scene_tree_dock.cpp)
		# Return we did something
		if not subgizmo_selection.is_empty():
			return true;
	else:
		push_warning("Could not find the selection gizmo plugin when working in Maphelper.");
	return false;

func _action_assign_material_to_selected_solids(editor : DioptraEditorMainPlugin, map : DP_Map, mat : Material) -> bool:
	# TODO: assert we're in solid selection mode
	# Add material to the map
	var material_index := map.get_or_add_material(mat);
	editor._last_material = material_index;
	
	# Apply the material to all faces
	var target_gizmo := _get_target_gizmo(editor, map);
	if target_gizmo:
		var subgizmo_selection := target_gizmo.get_subgizmo_selection();
		# Apply it to all items in selection
		for selection in subgizmo_selection:
			# Apply it to all faces in selection
			for face in map.solids[selection].faces:
				face.material = material_index;
		# Rebuild the mesh with the new material
		if not subgizmo_selection.is_empty():
			if subgizmo_selection.size() > 1:
				map.rebuild_editor_map();
			else:
				map.rebuild_editor_map(map.solids[subgizmo_selection[0]]);
			return true;
	
	return false;

func _action_assign_uv_properties(editor : DioptraEditorMainPlugin, map : DP_Map, scale : Vector2, offset : Vector2, angle : float) -> void:
	pass
func _action_assign_uv_scale(editor : DioptraEditorMainPlugin, map : DP_Map, scale : Vector2) -> void:
	pass
func _action_assign_uv_offset(editor : DioptraEditorMainPlugin, map : DP_Map, offset : Vector2) -> void:
	pass
func _action_assign_uv_angle(editor : DioptraEditorMainPlugin, map : DP_Map, angle : float) -> void:
	pass

func do_assign_material(mat : Material) -> void:
	var editor := _get_editor_plugin();
	var map := editor.get_last_edited_map();
	_action_assign_material_to_selected_solids(editor, map, mat);
	
func do_assign_uv_scale(scale : Vector2) -> void:
	var editor := _get_editor_plugin();
	var map := editor.get_last_edited_map();
	_action_assign_uv_scale(editor, map, scale);
	
func do_assign_uv_offset(offset : Vector2) -> void:
	var editor := _get_editor_plugin();
	var map := editor.get_last_edited_map();
	_action_assign_uv_offset(editor, map, offset);
	
func do_assign_uv_angle(angle : float) -> void:
	var editor := _get_editor_plugin();
	var map := editor.get_last_edited_map();
	_action_assign_uv_angle(editor, map, angle);
	
