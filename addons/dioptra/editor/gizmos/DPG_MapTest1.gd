@tool
extends EditorNode3DGizmoPlugin

var mUndoRedo : EditorUndoRedoManager = null;

var _ghost_box : DPUBoxGhost = null;
var _face_selection : Array[int]; # 2x array of [Solid,Face] pairs

func _init(undoredo : EditorUndoRedoManager):
	create_material("lines", Color(1.0, 1.0, 1.0), false, true, true);
	_ghost_box = DPUBoxGhost.new();
	_face_selection = [];

	mUndoRedo = undoredo;
	pass

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is DP_Map;
	
func _get_gizmo_name() -> String:
	return "DP Map Test 1";
	
func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	_ghost_box.cleanup();

	var node3d := gizmo.get_node_3d()
	var map := node3d as DP_Map;
	
	# Do all solids
	var linesNormie := PackedVector3Array();
	var linesSelect := PackedVector3Array();

	
	for solid_index in range(0, map.solids.size()):
		var solid := map.solids[solid_index];
		if not solid:
			continue;
		
		for face in solid.faces:
			for corner_index in range(1, face.corners.size()):
				if gizmo.is_subgizmo_selected(solid_index):
					linesSelect.append(solid.points[face.corners[corner_index - 1]].v3);
					linesSelect.append(solid.points[face.corners[corner_index + 0]].v3);
				else:
					#linesNormie.append(solid.points[face.corners[corner_index - 1]].v3);
					#linesNormie.append(solid.points[face.corners[corner_index + 0]].v3);
					pass
				pass
			pass	
		
		if gizmo.is_subgizmo_selected(solid_index):
			var min_p := solid.points[0].v3;
			var max_p := solid.points[0].v3;
			for point in solid.points:
				min_p = min_p.min(point.v3);
				max_p = max_p.max(point.v3);
			_ghost_box.box_start = min_p;
			_ghost_box.box_end = max_p;
			_ghost_box.update(EditorInterface.get_editor_viewport_3d(0).get_camera_3d());

		pass
	
	# Move this check to user????
	if gizmo.is_subgizmo_selected(map.solids.size()):
		for pair_index in range(0, _face_selection.size(), 2):
			var solid := map.solids[_face_selection[pair_index+0]];
			var face := solid.faces[_face_selection[pair_index+1]];
			
			for corner_index in range(1, face.corners.size()):
				linesSelect.append(solid.points[face.corners[corner_index - 1]].v3);
				linesSelect.append(solid.points[face.corners[corner_index + 0]].v3);
		pass
	
	# Add the solids now:
	gizmo.add_lines(linesNormie, get_material("lines", gizmo), false, Color(0.8, 0.8, 0.1, 0.5));
	gizmo.add_lines(linesSelect, get_material("lines", gizmo), false, Color(1.0, 1.0, 1.0, 1.0));
	
	pass
	
## Selection Raycast Logic:
func _subgizmos_intersect_ray(gizmo: EditorNode3DGizmo, camera: Camera3D, screen_pos: Vector2) -> int:
	var ray_pos := camera.project_ray_origin(screen_pos);
	var ray_dir := camera.project_ray_normal(screen_pos);
	
	var node3d := gizmo.get_node_3d()
	var map := node3d as DP_Map;
	
	var closest_solid := -1; # No selection
	var closest_solid_distance := 0.0;
	_face_selection = []; # Clear out the face selection
	
	# Find the solid we hit
	for solid_index in range(0, map.solids.size()):
		var solid := map.solids[solid_index];
		if solid:
			# for now build an aabb
			# later, use Geometry3D.ray_intersects_triangle
			var min_p := solid.points[0].v3;
			var max_p := solid.points[0].v3;
			for point in solid.points:
				min_p = min_p.min(point.v3);
				max_p = max_p.max(point.v3);
			var solid_bbox := AABB(min_p, max_p - min_p); 
			var hit_result = solid_bbox.intersects_ray(ray_pos, ray_dir);
			if hit_result != null:
				var dist_sqr : float = ray_pos.distance_squared_to(hit_result as Vector3);
				if closest_solid == -1 or dist_sqr < closest_solid_distance:
					closest_solid = solid_index;
					closest_solid_distance = dist_sqr;
			pass
	
	return closest_solid;
	
func _begin_handle_action(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> void:
	print("action: %s" % ("true" if secondary else "false"));
	pass
	
func _get_subgizmo_transform(gizmo: EditorNode3DGizmo, subgizmo_id: int) -> Transform3D:
	var t := Transform3D.IDENTITY;
	
	var node3d := gizmo.get_node_3d()
	var map := node3d as DP_Map;
	
	#var selection := gizmo.get_subgizmo_selection();
	#if not selection.is_empty():
		#var selected_index := selection[0];
		#t = t.translated(map.solids[selected_index].points[0].v3);
	if subgizmo_id >= 0 and subgizmo_id < map.solids.size():
		t = t.translated(map.solids[subgizmo_id].points[0].v3);
	
	return t;
	
class StartingTransform:
	var transform : Transform3D;
	var points : Array[MapVector3];
	
var _is_transforming : bool = false;
var _transform_start : Array[StartingTransform];

func _start_subgizmo_transform(gizmo: EditorNode3DGizmo, subgizmo_id: int) -> void:
	var node3d := gizmo.get_node_3d()
	var map := node3d as DP_Map;
	var solid := map.solids[subgizmo_id];
	
	_is_transforming = true;
	if _transform_start.size() <= subgizmo_id:
		_transform_start.resize(subgizmo_id + 1);
		
	_transform_start[subgizmo_id] = StartingTransform.new();
	_transform_start[subgizmo_id].transform = _get_subgizmo_transform(gizmo, subgizmo_id);
	_transform_start[subgizmo_id].points = solid.points.duplicate();
	for i in _transform_start[subgizmo_id].points.size():
		_transform_start[subgizmo_id].points[i] = MapVector3.new();
		_transform_start[subgizmo_id].points[i].v3i = solid.points[i].v3i;
	
	pass
	
func _set_subgizmo_transform(gizmo: EditorNode3DGizmo, subgizmo_id: int, transform: Transform3D) -> void:
	# if we're beginning then mark a start with the current transform start
	if not _is_transforming:
		_start_subgizmo_transform(gizmo, subgizmo_id);
	
	print("set gizmo transform: %d" % subgizmo_id);
	
	var node3d := gizmo.get_node_3d()
	var map := node3d as DP_Map;
	
	var solid := map.solids[subgizmo_id];
	var reference := _transform_start[subgizmo_id];
	
	var delta_position = DioptraInterface.get_grid_round_v3((reference.transform.inverse() * transform).origin);
	
	# Offset the points
	for i in solid.points.size():
		solid.points[i].v3 = reference.points[i].v3 + delta_position;
		
	map.update_gizmos();
		
	pass

func _commit_subgizmos(gizmo: EditorNode3DGizmo, ids: PackedInt32Array, restores: Array[Transform3D], cancel: bool) -> void:
	print("commit subgizmos: cancel %s" % ("true" if cancel else "false"));
	
	_is_transforming = false;
	
	var node3d := gizmo.get_node_3d()
	var map := node3d as DP_Map;
	map.rebuild_editor_map(); #todo
	
	map.update_gizmos();
	
	pass
	
	
