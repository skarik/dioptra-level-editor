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

const cScript_State := preload("res://addons/dioptra/editor/DP_PanelState.gd");

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
	# Plugins done? Update overlays to set up the systems
	set_force_draw_over_forwarding_enabled();
	update_overlays();
	
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
		
	# Forward shortcuts to the state panel
	if DioptraInterface._get_instance().shortcut_select_solids.matches_event(event) && event.is_pressed() and not event.is_echo():
		var state := _editor_plugin.DPDock_State as cScript_State;
		state.onSelectionTypePressed(DioptraEditorMainPlugin.SelectMode.SOLID);
		return EditorPlugin.AFTER_GUI_INPUT_STOP;
	if DioptraInterface._get_instance().shortcut_select_faces.matches_event(event) && event.is_pressed() and not event.is_echo():
		var state := _editor_plugin.DPDock_State as cScript_State;
		state.onSelectionTypePressed(DioptraEditorMainPlugin.SelectMode.FACE);
		return EditorPlugin.AFTER_GUI_INPUT_STOP;
	
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
		for subgizmo_id in subgizmo_selection:
			var selection_type := DPHelpers.get_selection_type(map, subgizmo_id);
			var selection := DPHelpers.get_selection(map, subgizmo_id);
			var sel_solid := selection.solid as DPMapSolid;
			var sel_face := selection.face as DPMapFace;
			if selection_type == DPHelpers.SelectionType.SOLID:
				for face in sel_solid.faces:
					face.material = material_index;
			elif selection_type == DPHelpers.SelectionType.FACE:
				sel_face.material = material_index;
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
func _action_assign_uv_scale(editor : DioptraEditorMainPlugin, map : DP_Map, scale : Vector2) -> bool:
	var target_gizmo := _get_target_gizmo(editor, map);
	if target_gizmo:
		var subgizmo_selection := target_gizmo.get_subgizmo_selection();
		var last_solid = -1;
		# Apply it to all items in selection
		for subgizmo_id in subgizmo_selection:
			var selection_type := DPHelpers.get_selection_type(map, subgizmo_id);
			var selection := DPHelpers.get_selection(map, subgizmo_id);
			var sel_solid := selection.solid as DPMapSolid;
			var sel_face := selection.face as DPMapFace;
			if selection_type == DPHelpers.SelectionType.SOLID:
				for face in sel_solid.faces:
					face.uv_scale = scale;
			elif selection_type == DPHelpers.SelectionType.FACE:
				sel_face.uv_scale = scale;
				
			last_solid = subgizmo_id & DPHelpers.SELBIT_MASK_SOLID;
		pass # End selection loop
		
		# Rebuild the mesh with the new material
		if not subgizmo_selection.is_empty():
			if subgizmo_selection.size() > 1:
				map.rebuild_editor_map();
			else:
				map.rebuild_editor_map(map.solids[last_solid]);
			return true;
	return false;
func _action_assign_uv_offset(editor : DioptraEditorMainPlugin, map : DP_Map, offset : Vector2) -> bool:
	var target_gizmo := _get_target_gizmo(editor, map);
	if target_gizmo:
		var subgizmo_selection := target_gizmo.get_subgizmo_selection();
		var last_solid = -1;
		# Apply it to all items in selection
		for subgizmo_id in subgizmo_selection:
			var selection_type := DPHelpers.get_selection_type(map, subgizmo_id);
			var selection := DPHelpers.get_selection(map, subgizmo_id);
			var sel_solid := selection.solid as DPMapSolid;
			var sel_face := selection.face as DPMapFace;
			if selection_type == DPHelpers.SelectionType.SOLID:
				for face in sel_solid.faces:
					face.uv_offset = offset;
			elif selection_type == DPHelpers.SelectionType.FACE:
				sel_face.uv_offset = offset;
				
			last_solid = subgizmo_id & DPHelpers.SELBIT_MASK_SOLID;
		pass # End selection loop
		
		# Rebuild the mesh with the new material
		if not subgizmo_selection.is_empty():
			if subgizmo_selection.size() > 1:
				map.rebuild_editor_map();
			else:
				map.rebuild_editor_map(map.solids[last_solid]);
			return true;
	return false;
func _action_assign_uv_angle(editor : DioptraEditorMainPlugin, map : DP_Map, angle : float) -> bool:
	var target_gizmo := _get_target_gizmo(editor, map);
	if target_gizmo:
		var subgizmo_selection := target_gizmo.get_subgizmo_selection();
		var last_solid = -1;
		# Apply it to all items in selection
		for subgizmo_id in subgizmo_selection:
			var selection_type := DPHelpers.get_selection_type(map, subgizmo_id);
			var selection := DPHelpers.get_selection(map, subgizmo_id);
			var sel_solid := selection.solid as DPMapSolid;
			var sel_face := selection.face as DPMapFace;
			if selection_type == DPHelpers.SelectionType.SOLID:
				for face in sel_solid.faces:
					face.uv_rotation = angle;
			elif selection_type == DPHelpers.SelectionType.FACE:
				sel_face.uv_rotation = angle;
				
			last_solid = subgizmo_id & DPHelpers.SELBIT_MASK_SOLID;
		pass # End selection loop
		
		# Rebuild the mesh with the new material
		if not subgizmo_selection.is_empty():
			if subgizmo_selection.size() > 1:
				map.rebuild_editor_map();
			else:
				map.rebuild_editor_map(map.solids[last_solid]);
			return true;
	return false;

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
	
#------------------------------------------------------------------------------#

#drag n drop hack test
var vp_control : Control = null;
func _forward_3d_draw_over_viewport(viewport_control: Control) -> void:
	vp_control = viewport_control;
	vp_control.set_drag_forwarding(Callable(), can_drop_func, Callable())
	pass
		
func _forward_3d_force_draw_over_viewport(viewport_control: Control) -> void:
	vp_control = viewport_control;
	vp_control.set_drag_forwarding(Callable(), can_drop_func, Callable())
	pass
	
func can_drop_func(at_position: Vector2, data: Variant) -> bool:
	if vp_control:
		# See Node3DEditorViewport::can_drop_data_fw in node_3d_editor_plugin.cpp. There's a lot of functionality we need to fall back to.
		#return vp_control.get_parent_control()._can_drop_data(at_position, data);
		#return vp_control.get_parent_control().can_drop_data_fw(at_position, data, self);
		pass
	return true;
