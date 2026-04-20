@tool
extends EditorNode3DGizmoPlugin

var mEditorPlugin : DioptraEditorMainPlugin = null;
var mUndoRedo : EditorUndoRedoManager = null;

var _ghost_box : DPUBoxGhost = null;
var _queue_selection_changed : bool = false;

const cGlowSize = 8.0;


func _init(editorPlugin : DioptraEditorMainPlugin, undoredo : EditorUndoRedoManager):
	create_material("lines", Color(1.0, 1.0, 1.0), false, true, true);
	create_material("geo", Color(1.0, 1.0, 1.0, 0.5), false, false, true);
	create_handle_material("handles");
	_ghost_box = DPUBoxGhost.new();

	mEditorPlugin = editorPlugin;
	mUndoRedo = undoredo;
	pass

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is DP_Map;
	
func _get_gizmo_name() -> String:
	return "DP Map Test 1";
	
func _redraw(gizmo: EditorNode3DGizmo) -> void:
	# If there's a selection, emit selection changed.
	if _queue_selection_changed:
		_queue_selection_changed = false;
		EditorInterface.get_selection().selection_changed.emit();
	
	gizmo.clear()
	_ghost_box.cleanup();

	var node3d := gizmo.get_node_3d()
	var map := node3d as DP_Map;
	
	var color_sel : Color = EditorInterface.get_editor_theme().get_color("warning_color", "Editor");

	# Do all solids
	var linesNormie := PackedVector3Array();
	var linesSelect := PackedVector3Array();
	var handles := PackedVector3Array();
	var am := DPArrayMesher.new(DPArrayMesher.TypeFlags.VERTEX \
			| DPArrayMesher.TypeFlags.NORMAL | DPArrayMesher.TypeFlags.TEX_UV \
			| DPArrayMesher.TypeFlags.COLOR \
			| DPArrayMesher.TypeFlags.INDEX);

	# Get the selection
	var selection_list := gizmo.get_subgizmo_selection();
	for subgizmo_id in selection_list:
		var selection := DPHelpers.get_selection(map, subgizmo_id);
		
		# Normal full selection item
		if selection.type == DPHelpers.SelectionType.SOLID:
			var solid := selection.solid;
				
			# Add selection for the edges:
			for face in solid.faces:
				var normal : Vector3 = -(solid.points[face.corners[1]].v3 - solid.points[face.corners[0]].v3).cross(
					solid.points[face.corners[2]].v3 - solid.points[face.corners[0]].v3).normalized();
				normal /= DioptraInterface.get_position_scale_top();
				normal *= DioptraInterface.get_position_scale_div();
				var corner_count : int = face.corners.size();
				for corner_index in corner_count:
					var corner_0 := corner_index + 0;
					var corner_1 := (corner_index + 1) % corner_count;
					linesSelect.append(solid.points[face.corners[corner_0]].v3 + normal);
					linesSelect.append(solid.points[face.corners[corner_1]].v3 + normal);
				pass
			
			# Draw ghost box for the sizes (only one box so it'll work for the last selection)
			var min_p := solid.points[0].v3;
			var max_p := solid.points[0].v3;
			for point in solid.points:
				min_p = min_p.min(point.v3);
				max_p = max_p.max(point.v3);
			_ghost_box.box_start = min_p;
			_ghost_box.box_end = max_p;
			_ghost_box.update(EditorInterface.get_editor_viewport_3d(0).get_camera_3d());
			
		elif selection.type == DPHelpers.SelectionType.FACE:
			var solid := selection.solid;
			var face := selection.face;
			var corner_count : int = face.corners.size();
				
			# Add selection for the edges:
			var normal : Vector3 = -(solid.points[face.corners[1]].v3 - solid.points[face.corners[0]].v3).cross(
				solid.points[face.corners[2]].v3 - solid.points[face.corners[0]].v3).normalized();
			normal /= DioptraInterface.get_position_scale_top();
			normal *= DioptraInterface.get_position_scale_div();
			for corner_index in range(corner_count):
				var corner_0 := corner_index + 0;
				var corner_1 := (corner_index + 1) % corner_count;
				linesSelect.append(solid.points[face.corners[corner_0]].v3 + normal);
				linesSelect.append(solid.points[face.corners[corner_1]].v3 + normal);
			pass
			
			# Draw ghost box for the face size
			var min_p := solid.points[face.corners[0]].v3;
			var max_p := solid.points[face.corners[0]].v3;
			for corner_index in face.corners:
				min_p = min_p.min(solid.points[corner_index].v3);
				max_p = max_p.max(solid.points[corner_index].v3);
			_ghost_box.box_start = min_p;
			_ghost_box.box_end = max_p;
			_ghost_box.update(EditorInterface.get_editor_viewport_3d(0).get_camera_3d());
			
			# Add glow mesh around the face
			var scale : float = DioptraInterface.get_position_scale_div() / float(DioptraInterface.get_position_scale_top());
			for corner_index in range(corner_count):
				var corner_0 := corner_index + 0;
				var corner_1 := (corner_index + 1) % corner_count;
				var corner_2 := (corner_index + 2) % corner_count;
				var corner_3 := (corner_index + 3) % corner_count;
				var point_0 := solid.points[face.corners[corner_0]].v3;
				var point_1 := solid.points[face.corners[corner_1]].v3;
				var point_2 := solid.points[face.corners[corner_2]].v3;
				var point_3 := solid.points[face.corners[corner_3]].v3;
				var d_12 = (point_2 - point_1).normalized() * scale * cGlowSize;
				var d_01 = (point_1 - point_0).normalized() * scale * cGlowSize;
				var d_23 = (point_3 - point_2).normalized() * scale * cGlowSize;
				var vert0 := am.get_vertex_count();
				am.point_add(point_1 + normal);
				am.point_add(point_1 + normal + d_01 - d_12);
				am.point_add(point_2 + normal);
				am.point_add(point_2 + normal - d_23 + d_12);
				am.tri_add_indicies(vert0 + 0, vert0 + 1, vert0 + 2);
				am.tri_add_indicies(vert0 + 2, vert0 + 1, vert0 + 3);
				am.get_surface_color()[vert0 + 0] = color_sel; 
				am.get_surface_color()[vert0 + 2] = color_sel;
				am.get_surface_color()[vert0 + 1] = color_sel * Color(1.0, 1.0, 1.0, 0.0);
				am.get_surface_color()[vert0 + 3] = color_sel * Color(1.0, 1.0, 1.0, 0.0);
			pass # End adding glowmesh
	
		elif selection.type == DPHelpers.SelectionType.DECAL:
			var decal := selection.decal;
			handles.push_back(decal.position.v3);
			pass
	
	# Add boxes around all decals
	for decal in map.decals:
		# Grab properties
		var pos := decal.position.v3;
		var material := map.material_objects[decal.material];
		var pixels_per_gdunit := DioptraInterface.get_pixel_scale_top() / float(DioptraInterface.get_pixel_scale_div());
		var gdunit_per_dpunit := DioptraInterface.get_position_scale_div() / float(DioptraInterface.get_position_scale_top());
		var decal_texel_size := DPHelpers.get_material_primary_texture_size(material);
		var decal_size := decal_texel_size / pixels_per_gdunit;
		
		# Build the basis
		var decal_rotation := Quaternion.from_euler(decal.rotation);
		var normal := decal_rotation * -Vector3.FORWARD;
		var up := decal_rotation * Vector3.UP;
		var left := decal_rotation * Vector3.LEFT;
		
		# Get corners
		var w_up := up * decal_size.y * 0.5;
		var w_left := left * decal_size.x * 0.5;
		var corners : PackedVector3Array = [
				pos + w_up + w_left,
				pos + w_up - w_left,
				pos - w_up - w_left,
				pos - w_up + w_left,
		];
		for corner_index in corners.size():
			linesNormie.append(normal * gdunit_per_dpunit + corners[(corner_index + 0)]);
			linesNormie.append(normal * gdunit_per_dpunit + corners[(corner_index + 1) % 4]);
		
		#linesSelect.append(pos);
		#linesSelect.append(pos + normal * 2);
		#linesSelect.append(pos);
		#linesSelect.append(pos + up * 2);
	
	# Add the solids now:
	if not linesNormie.is_empty():
		gizmo.add_lines(linesNormie, get_material("lines", gizmo), false, Color(0.8, 0.8, 0.1, 0.5));
	if not linesSelect.is_empty():
		gizmo.add_lines(linesSelect, get_material("lines", gizmo), false, Color(1.0, 1.0, 1.0, 1.0));
	if am.get_index_count() > 0:
		var local_mesh : ArrayMesh = ArrayMesh.new();
		local_mesh.add_surface_from_arrays(am.get_primitive_type(), am.get_surface_array());
		gizmo.add_mesh(local_mesh, get_material("geo", gizmo));
	if not handles.is_empty():
		gizmo.add_handles(handles, get_material("handles", gizmo), []);
	
	pass
	
## Selection Raycast Logic:
func _subgizmos_intersect_ray(gizmo: EditorNode3DGizmo, camera: Camera3D, screen_pos: Vector2) -> int:
	var node3d := gizmo.get_node_3d();
	var map := node3d as DP_Map;
	
	# Get selection mode from the plugin:
	var selection_mode := mEditorPlugin.get_selection_mode();
	
	var subgizmo_id = DPEditorSelection.subgizmo_intersect_ray(map, camera, screen_pos, selection_mode);
	if subgizmo_id != -1:
		_queue_selection_changed = true;
		
	return subgizmo_id;
	
## Selection transforming logic
func _begin_handle_action(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> void:
	print("action: %s" % ("true" if secondary else "false"));
	# TODO unify storing gizmo reference
	pass
	
func _get_subgizmo_transform(gizmo: EditorNode3DGizmo, subgizmo_id: int) -> Transform3D:
	var t := Transform3D.IDENTITY;
	
	var node3d := gizmo.get_node_3d()
	var map := node3d as DP_Map;
		
	var selection := DPHelpers.get_selection(map, subgizmo_id);
	
	if selection.type <= DPHelpers.SelectionType.VERTEX:
		var solid := selection.solid;
		# Solid Corner
		if selection.type == DPHelpers.SelectionType.SOLID:
			t = Transform3D(Basis.IDENTITY, solid.points[0].v3);
		# Face Corner
		elif selection.type == DPHelpers.SelectionType.FACE:
			var face := selection.face;
			t = Transform3D(Basis.IDENTITY, solid.points[face.corners[0]].v3);
	elif selection.type == DPHelpers.SelectionType.DECAL:
		var decal_id := selection.decal_id;
		var decal := map.decals[decal_id];
		t = Transform3D(Basis(Quaternion.from_euler(decal.rotation)), decal.position.v3);
		
	return t;
	
## Helper class for storing the starting transform of items
class StartingTransform:
	var transform : Transform3D;
	var points : Array[Vector3i] = [];

var _is_transforming : bool = false;
var _transform_start : Dictionary[int, StartingTransform];
var _transforming_reference_subgizmo : int = -1;

## Gets the reference transform & points for the given subgizmo_id.
## When [param set_main_reference] is true, will mark this sugbizmo as the main
##   reference point for transforming.
func _start_subgizmo_transform_get_ref(gizmo: EditorNode3DGizmo, subgizmo_id: int, set_main_reference: bool) -> void:
	var node3d := gizmo.get_node_3d()
	var map := node3d as DP_Map;
	var selection := DPHelpers.get_selection(map, subgizmo_id);
	var solid_id = selection.solid_id;
	var solid := map.solids[solid_id];
	
	if set_main_reference:
		_is_transforming = true;
		
	_transform_start[subgizmo_id] = StartingTransform.new();
	_transform_start[subgizmo_id].transform = _get_subgizmo_transform(gizmo, subgizmo_id);
	
	# Save points:
	if selection.type <= DPHelpers.SelectionType.VERTEX:
		_transform_start[subgizmo_id].points.resize(solid.points.size());
		for i in _transform_start[subgizmo_id].points.size():
			_transform_start[subgizmo_id].points[i] = solid.points[i].v3i;
			
	if set_main_reference:
		_transforming_reference_subgizmo = subgizmo_id;
		
	pass
	
func _start_subgizmo_transform(gizmo: EditorNode3DGizmo, subgizmo_id: int) -> void:
	_start_subgizmo_transform_get_ref(gizmo, subgizmo_id, true);
	print("start gizmo transform: %d" % subgizmo_id);
	
func _set_subgizmo_transform(gizmo: EditorNode3DGizmo, subgizmo_id: int, transform: Transform3D) -> void:
	# if we're beginning then mark a start with the current transform start
	if not _is_transforming:
		_start_subgizmo_transform(gizmo, subgizmo_id);
	
	#var solid_id = subgizmo_id & DPHelpers.SELBIT_MASK_SOLID;
	#print("set gizmo transform: %d" % solid_id);
	
	var node3d := gizmo.get_node_3d();
	var map := node3d as DP_Map;
	
	var selection := DPHelpers.get_selection(map, subgizmo_id);
	
	# Grab reference
	if not _transform_start.has(subgizmo_id):
		# Above _start_subgizmo_transform will only work for the main selected
		# item, not ALL items that need reference. So we get reference again
		# here.
		_start_subgizmo_transform_get_ref(gizmo, subgizmo_id, false);
	var reference := _transform_start[subgizmo_id];
	
	# Generate the delta
	var reference_gizmo_id = _transforming_reference_subgizmo;
	var delta_position = DioptraInterface.get_grid_round_v3((transform * reference.transform.inverse()).origin);
	
	# Offset the points
	# Transforming solid
	if selection.type == DPHelpers.SelectionType.SOLID:
		var solid := selection.solid;
		for i in solid.points.size():
			solid.points[i].v3i = reference.points[i];
			solid.points[i].v3 += delta_position;
	# Transforming face
	elif selection.type == DPHelpers.SelectionType.FACE:
		var solid := selection.solid;
		var face := selection.face;
		for i in face.corners.size():
			var vert = face.corners[i];
			solid.points[vert].v3i = reference.points[vert];
			solid.points[vert].v3 += delta_position;
	# Transforming decal
	elif selection.type == DPHelpers.SelectionType.DECAL:
		var decal := selection.decal;
		decal.position.v3 = reference.transform.origin + delta_position;
			
	# We did it! Update the gizmos so we can see what we're doing.
	map.update_gizmos();
	pass

func _commit_subgizmos(gizmo: EditorNode3DGizmo, ids: PackedInt32Array, restores: Array[Transform3D], cancel: bool) -> void:
	print("commit subgizmos: cancel %s" % ("true" if cancel else "false"));
	
	_is_transforming = false;
	
	var node3d := gizmo.get_node_3d()
	var map := node3d as DP_Map;
	map.rebuild_editor_map(); #todo, grab a Solid from the map
	map.rebuild_editor_decals(); # TODO: only rebuild the decals attached to the given solid
	
	map.update_gizmos();
	
	# Clear off the transform start state
	_transform_start.clear();
	_transforming_reference_subgizmo = -1;
	
	pass
	
	
