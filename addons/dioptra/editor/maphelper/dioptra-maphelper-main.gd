@tool
extends EditorPlugin
class_name DioptraEditorMaphelperPlugin

#------------------------------------------------------------------------------#

var _editor_plugin : DioptraEditorMainPlugin = null;

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
	
	if editor._currentTool == null:
		if event is InputEventKey:
			#print(event.get_class() + " : " + event.as_text());
			if event.keycode == KEY_DELETE:
				if _action_delete_selected_object(editor, map):
					return EditorPlugin.AFTER_GUI_INPUT_STOP;
		pass
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS;
	
#------------------------------------------------------------------------------#

func _get_editor_plugin() -> DioptraEditorMainPlugin:
	if _editor_plugin != null:
		return _editor_plugin;
	
	# Search the owner (assumed editor):
	#for child in EditorInterface.get_edited_scene_root():
	for child in get_parent().get_children():
		if child is DioptraEditorMainPlugin:
			_editor_plugin = child;
			break;
		
	return _editor_plugin;

#------------------------------------------------------------------------------#

func _get_target_gizmo(editor : DioptraEditorMainPlugin, map : DP_Map) -> EditorNode3DGizmo:
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

func _action_delete_selected_object(editor : DioptraEditorMainPlugin, map : DP_Map) -> bool:
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
