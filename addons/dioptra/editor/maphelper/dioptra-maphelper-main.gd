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
			#if node == _editor_plugin.get_last_edited_map():
				#var map := node as DP_Map;
				#var gizmo := _get_target_gizmo(_editor_plugin, map);
				#gizmo.get_subgizmo_selection()
			_selection_subgizmo_restore = []; # TODO: figure this out later
		_selection_restore = [];
	
	pass

#------------------------------------------------------------------------------#

var _last_edited_map : DP_Map = null;
var _selection_restore : Array[Node] = [];
var _selection_subgizmo_restore : PackedInt32Array = [];

#------------------------------------------------------------------------------#

# Handle the DP_InternalTool, which lets us actually perform work with the editor
func _handles(object: Object) -> bool:
	if object is DP_Map:
		return true;
	return false;
	
func _edit(object: Object) -> void:
	if object is DP_Map:
		_last_edited_map = object as DP_Map;
		DioptraInterface.set_grid_visible(DioptraInterface.get_grid_visible(), false); # HACK for lightmaps
		DioptraInterface.set_grid_size(DioptraInterface.get_grid_size()); # HACK for init
	elif object == null:
		DioptraInterface.set_grid_visible(false, false); # HACK for lightmaps
	pass
	
func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	var editor := _get_editor_plugin();
	var map := editor.get_last_edited_map();
	
	if editor._currentTool == null:
		if event is InputEventKey:
			if event.keycode == KEY_DELETE:
				if _action_delete_selected_solids(editor, map):
					return EditorPlugin.AFTER_GUI_INPUT_STOP;
		pass
		
	# Forward shortcuts to the state panel
	var state := _editor_plugin.DPDock_State as cScript_State;
	if DioptraInterface._get_instance().shortcut_select_solids.matches_event(event) && event.is_pressed() and not event.is_echo():
		state.onSelectionTypePressed(DioptraEditorMainPlugin.SelectMode.SOLID);
		return EditorPlugin.AFTER_GUI_INPUT_STOP;
		
	if DioptraInterface._get_instance().shortcut_select_faces.matches_event(event) && event.is_pressed() and not event.is_echo():
		state.onSelectionTypePressed(DioptraEditorMainPlugin.SelectMode.FACE);
		return EditorPlugin.AFTER_GUI_INPUT_STOP;
		
	if DioptraInterface._get_instance().shortcut_select_edges.matches_event(event) && event.is_pressed() and not event.is_echo():
		state.onSelectionTypePressed(DioptraEditorMainPlugin.SelectMode.EDGE);
		return EditorPlugin.AFTER_GUI_INPUT_STOP;
	
	if DioptraInterface._get_instance().shortcut_select_verts.matches_event(event) && event.is_pressed() and not event.is_echo():
		state.onSelectionTypePressed(DioptraEditorMainPlugin.SelectMode.VERTEX);
		return EditorPlugin.AFTER_GUI_INPUT_STOP;
		
	# Update mouse
	_editor_plugin.handle_general_editor_input(viewport_camera, event);
	
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
			if plugin == editor.DPGizmoPlugin_MapGlobalEditor:
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
		for subgizmo_id in subgizmo_selection:
			var selection := DPHelpers.get_selection(map, subgizmo_id);
			# Refcounted objects. Remove the main map reference for now.
			if selection.type == DPHelpers.SelectionType.SOLID:
				map.solids[selection.solid_id] = null; 
			elif selection.type == DPHelpers.SelectionType.DECAL:
				map.decals[selection.decal_id] = null;
				
		# Clean up all the null values
		for i in range(map.solids.size() - 1, -1, -1):
			if map.solids[i] == null:
				map.solids.remove_at(i);
		for i in range(map.decals.size() - 1, -1, -1):
			if map.decals[i] == null:
				map.decals.remove_at(i);
				
		# Clear selection
		map.clear_subgizmo_selection();
		# Remove the editor map entirely on delete
		map.rebuild_editor_mesh_groups();
		map.rebuild_editor_map();
		map.rebuild_editor_decals();
		# Hack so that SceneTreeDock doesn't keep monching the deleting signal. We'll bring it back next frame
		_selection_restore = EditorInterface.get_selection().get_selected_nodes().duplicate();
		#_selection_subgizmo_restore = subgizmo_selection.duplicate();
		EditorInterface.get_selection().clear(); # hack (see scene_tree_dock.cpp)
		# Return we did something
		if not subgizmo_selection.is_empty():
			return true;
	else:
		push_warning("Could not find the selection gizmo plugin when working in Maphelper.");
	return false;
	
# TODO: move the UV setting to a separate class as a helper instance inside this one

func _action_assign_material_to_selected_solids(editor : DioptraEditorMainPlugin, map : DP_Map, mat : Material) -> bool:
	# TODO: assert we're in solid selection mode
	# Add material to the map
	editor._last_material = mat;
	
	# Apply the material to all faces
	var target_gizmo := _get_target_gizmo(editor, map);
	if target_gizmo:
		var subgizmo_selection := target_gizmo.get_subgizmo_selection();
		# Apply it to all items in selection
		for subgizmo_id in subgizmo_selection:
			var selection := DPHelpers.get_selection(map, subgizmo_id);
			var is_object : bool = selection.type > DPHelpers.SelectionType.VERTEX;
			var material_index := map.get_or_add_material(mat, is_object); 
			
			if selection.type == DPHelpers.SelectionType.SOLID:
				for face in selection.solid.faces:
					face.material = material_index;
			elif selection.type == DPHelpers.SelectionType.FACE:
				selection.face.material = material_index;
			elif selection.type == DPHelpers.SelectionType.DECAL:
				selection.decal.material = material_index;
				
			# Queue rebuilding map
			# TODO: check if there was a change
			map.rebuild_editor_map_deferred(selection.solid_id);
		pass # End looping thru subgizmos
				
		# Rebuild the mesh with the new material
		if not subgizmo_selection.is_empty():
			return true;
	
	return false;
	
func _action_assign_uv_mode(editor : DioptraEditorMainPlugin, map : DP_Map, mode : DPMapFace.UVMode) -> bool:
	# Apply the material to all faces
	var target_gizmo := _get_target_gizmo(editor, map);
	if target_gizmo:
		var subgizmo_selection := target_gizmo.get_subgizmo_selection();
		# Apply it to all items in selection
		for subgizmo_id in subgizmo_selection:
			var selection := DPHelpers.get_selection(map, subgizmo_id);
			var is_object : bool = selection.type > DPHelpers.SelectionType.VERTEX;
			
			if selection.type == DPHelpers.SelectionType.SOLID:
				for face in selection.solid.faces:
					face.uv_mode = mode;
			elif selection.type == DPHelpers.SelectionType.FACE:
				selection.face.uv_mode = mode;
			elif selection.type == DPHelpers.SelectionType.DECAL:
				selection.decal.uv_mode = mode;
				
			# Queue rebuilding map
			# TODO: check if there was a change
			map.rebuild_editor_map_deferred(selection.solid_id);
		pass # End looping thru subgizmos
				
		# Rebuild the mesh with the new material
		if not subgizmo_selection.is_empty():
			return true;
	
	return false;

func _action_assign_uv_properties(editor : DioptraEditorMainPlugin, map : DP_Map, scale : Vector2, offset : Vector2, angle : float) -> bool:
	print("Not implemented/used")
	return false;
	
func _action_assign_uv_scale(editor : DioptraEditorMainPlugin, map : DP_Map, scale : Vector2) -> bool:
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
					face.uv_scale = scale;
			elif selection_type == DPHelpers.SelectionType.FACE:
				sel_face.uv_scale = scale;
				
			# Queue rebuilding map
			# TODO: check if there was a change
			map.rebuild_editor_map_deferred(selection.solid_id);
		pass # End selection loop
		
		# Rebuild the mesh with the new material
		if not subgizmo_selection.is_empty():
			return true;
	return false;
func _action_assign_uv_offset(editor : DioptraEditorMainPlugin, map : DP_Map, offset : Vector2) -> bool:
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
					face.uv_offset = offset;
			elif selection_type == DPHelpers.SelectionType.FACE:
				sel_face.uv_offset = offset;
			
			# Queue rebuilding map
			# TODO: check if there was a change
			map.rebuild_editor_map_deferred(selection.solid_id);
		pass # End selection loop
		
		# Rebuild the mesh with the new material
		if not subgizmo_selection.is_empty():
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
				
			last_solid = selection.solid_id;
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
	
func do_assign_uv_mode(mode : DPMapFace.UVMode) -> void:
	var editor := _get_editor_plugin();
	var map := editor.get_last_edited_map();
	_action_assign_uv_mode(editor, map, mode);
	
#------------------------------------------------------------------------------#

enum UVActionType {
	AlignLeft		= 0x0001,
	AlignRight		= 0x0002,
	AlignTop		= 0x0004,
	AlignBottom		= 0x0008,
	CenterX			= 0x0010,
	CenterY			= 0x0020,
	FitX			= 0x0040,
	FitY			= 0x0080,
	GuessRotation	= 0x0100,
}

func do_util_uv_align_left() -> void:
	var editor := _get_editor_plugin();
	var map := editor.get_last_edited_map();
	_action_util_uv_align(editor, map, UVActionType.AlignLeft);
func do_util_uv_align_right() -> void:
	var editor := _get_editor_plugin();
	var map := editor.get_last_edited_map();
	_action_util_uv_align(editor, map, UVActionType.AlignRight);
func do_util_uv_align_top() -> void:
	var editor := _get_editor_plugin();
	var map := editor.get_last_edited_map();
	_action_util_uv_align(editor, map, UVActionType.AlignTop);
func do_util_uv_align_bottom() -> void:
	var editor := _get_editor_plugin();
	var map := editor.get_last_edited_map();
	_action_util_uv_align(editor, map, UVActionType.AlignBottom);
func do_util_uv_align_action(action : UVActionType) -> void:
	var editor := _get_editor_plugin();
	var map := editor.get_last_edited_map();
	_action_util_uv_align(editor, map, action);
	
func _action_util_uv_align(editor : DioptraEditorMainPlugin, map : DP_Map, action : UVActionType) -> bool:
	var uv_mode := _editor_plugin._uvModePer;
	var target_gizmo := _get_target_gizmo(editor, map);
	if target_gizmo:
		var working_solids : Array[DPMapSolid] = [];
		var working_faces : Array[DPMapFace] = [];
		
		var subgizmo_selection := target_gizmo.get_subgizmo_selection();
		# Apply it to all items in selection
		for subgizmo_id in subgizmo_selection:
			var selection_type := DPHelpers.get_selection_type(map, subgizmo_id);
			var selection := DPHelpers.get_selection(map, subgizmo_id);
			var sel_solid := selection.solid as DPMapSolid;
			var sel_face := selection.face as DPMapFace;
			if selection_type == DPHelpers.SelectionType.SOLID:
				for face in sel_solid.faces:
					working_solids.push_back(sel_solid);
					working_faces.push_back(face);
					pass
			elif selection_type == DPHelpers.SelectionType.FACE:
				working_solids.push_back(sel_solid);
				working_faces.push_back(sel_face);
				pass
				
			# Queue rebuilding map
			# TODO: check if there was a change
			map.rebuild_editor_map_deferred(selection.solid_id);
		pass # End selection loop
		
		# Buckets of faces depending on the UV mode
		var groups : Array[Array] = [];
		
		if uv_mode == DioptraEditorMainPlugin.UVModePer.GROUP:
			groups.resize(working_faces.size());
			groups.push_back([]);
			groups[0].resize(working_faces.size());
			for i in working_faces.size():
				groups[0][i] = i;
		elif uv_mode == DioptraEditorMainPlugin.UVModePer.FACE:
			groups.resize(working_faces.size());
			for i in working_faces.size():
				groups[i] = [i];
			
		for group in groups:
			# Collect the plane we're going to be working on
			var collected_basis : Basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO);
			
			# Generate the normal
			for face_index in group:
				var solid := working_solids[face_index];
				var face := working_faces[face_index];
				
				# Get the face plane basis
				var face_basis := DPHelpers.face_get_texture_basis(solid, face);
				var normal : Vector3 = face_basis.z;
				
				# Rotate the basis around the face's angle:
				face_basis.x = face_basis.x.rotated(face_basis.z, deg_to_rad(face.uv_rotation));
				face_basis.y = face_basis.y.rotated(face_basis.z, deg_to_rad(face.uv_rotation));
				
				# Collect it!
				collected_basis.x += face_basis.x;
				collected_basis.y += face_basis.y;
				collected_basis.z += face_basis.z;
				
			# Orthonormalize the basis matrix
			collected_basis.orthonormalized();
			
			# Get the min and max coords of the group 
			var min_coord := Vector3.INF;
			var max_coord := -Vector3.INF;
			for face_index in group:
				var solid := working_solids[face_index];
				var face := working_faces[face_index];
				
				for i_corner in face.corners.size():
					var position := solid.points[face.corners[i_corner]].v3 * collected_basis;
					min_coord = min_coord.min(position);
					max_coord = max_coord.max(position);
					
			# Get min and max coords in world coords:
			var min_coord_world := min_coord * collected_basis.inverse();
			var max_coord_world := max_coord * collected_basis.inverse();
					
			# Now do the actual action:
			for face_index in group:
				var solid := working_solids[face_index];
				var face := working_faces[face_index];
				
				# Let's start with align left:
				var face_basis := DPHelpers.face_get_texture_basis(solid, face);
				var face_basis_point := DPHelpers.face_get_texture_base_position(solid, face);
				
				# Rotate the basis around the face's angle:
				face_basis.x = face_basis.x.rotated(face_basis.z, deg_to_rad(face.uv_rotation));
				face_basis.y = face_basis.y.rotated(face_basis.z, deg_to_rad(face.uv_rotation));
				
				# Get material properties
				var material := map.materials[face.material];
				var texture_size := DPHelpers.get_material_primary_texture_size(material);
				var units_to_offset_scale1d := DioptraInterface.get_pixel_scale_top() * float(DioptraInterface.get_pixel_scale_div());
				var units_to_offset_scale2d := Vector2(units_to_offset_scale1d, units_to_offset_scale1d);# / face.uv_scale;
				# Scale happens around the center of the texture origin, not the basis origin
				
				# Get positions in face-space
				var local_basis_point := face_basis_point * face_basis;
				var planar_min := min_coord_world * face_basis;
				var planar_max := max_coord_world * face_basis;
				
				# LEFT & TOP
				if action & UVActionType.AlignLeft:
					face.uv_offset.x = (local_basis_point.x - planar_min.x) * units_to_offset_scale2d.x;
				if action & UVActionType.AlignTop:
					face.uv_offset.y = (local_basis_point.y - planar_min.y) * units_to_offset_scale2d.y;
				# RIGHT & BOTTOM
				if action & UVActionType.AlignRight:
					face.uv_offset.x = (local_basis_point.x - planar_max.x) * units_to_offset_scale2d.x;
				if action & UVActionType.AlignBottom:
					face.uv_offset.y = (local_basis_point.y - planar_max.y) * units_to_offset_scale2d.y;
				# CENTER X & Y
				if action & UVActionType.CenterX:
					face.uv_offset.x = (local_basis_point.x - (planar_min.x + planar_max.x) / 2) * units_to_offset_scale2d.x - texture_size.x / 2 * face.uv_scale.x;
				if action & UVActionType.CenterY:
					face.uv_offset.y = (local_basis_point.y - (planar_min.y + planar_max.y) / 2) * units_to_offset_scale2d.y - texture_size.y / 2 * face.uv_scale.y;
				# FIT X & Y
				if action & UVActionType.FitX:
					face.uv_scale.x = ((planar_max.x - planar_min.x) * units_to_offset_scale2d.x) / texture_size.x;
				if action & UVActionType.FitY:
					face.uv_scale.y = ((planar_max.y - planar_min.y) * units_to_offset_scale2d.y) / texture_size.y;
				
		
		# Rebuild the mesh with the new material
		if not subgizmo_selection.is_empty():
			return true;
	return false;
	
	
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
