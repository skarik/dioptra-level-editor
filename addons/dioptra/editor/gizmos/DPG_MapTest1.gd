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
				var corner_count : int = face.corners.size();
				for corner_index in corner_count:
					var corner_0 := corner_index + 0;
					var corner_1 := (corner_index + 1) % corner_count;
					linesSelect.append(solid.points[face.corners[corner_0]].v3);
					linesSelect.append(solid.points[face.corners[corner_1]].v3);
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
			print("face selection")
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
	
	# Add the solids now:
	gizmo.add_lines(linesNormie, get_material("lines", gizmo), false, Color(0.8, 0.8, 0.1, 0.5));
	gizmo.add_lines(linesSelect, get_material("lines", gizmo), false, Color(1.0, 1.0, 1.0, 1.0));
	if am.get_index_count() > 0:
		var local_mesh : ArrayMesh = ArrayMesh.new();
		local_mesh.add_surface_from_arrays(am.get_primitive_type(), am.get_surface_array());
		gizmo.add_mesh(local_mesh, get_material("geo", gizmo));
	
	pass
	
## Selection Raycast Logic:
func _subgizmos_intersect_ray(gizmo: EditorNode3DGizmo, camera: Camera3D, screen_pos: Vector2) -> int:
	var ray_pos := camera.project_ray_origin(screen_pos);
	var ray_dir := camera.project_ray_normal(screen_pos);
	
	var node3d := gizmo.get_node_3d()
	var map := node3d as DP_Map;
	
	var closest_solid := -1; # No selection
	var closest_solid_distance := 0.0;
	var closest_face := -1;
	var closest_vertex_proc2 := -1;
	var closest_position : Vector3;
	
	# Get selection mode from the plugin:
	var selection_mode := mEditorPlugin.get_selection_mode();
	
	# Find the solid we hit
	#for solid_index in range(0, map.solids.size()):
		#var solid := map.solids[solid_index];
		#if solid:
			## for now build an aabb
			## later, use Geometry3D.ray_intersects_triangle
			#var min_p := solid.points[0].v3;
			#var max_p := solid.points[0].v3;
			#for point in solid.points:
				#min_p = min_p.min(point.v3);
				#max_p = max_p.max(point.v3);
			#var solid_bbox := AABB(min_p, max_p - min_p); 
			#var hit_result = solid_bbox.intersects_ray(ray_pos, ray_dir);
			#if hit_result != null:
				#var dist_sqr : float = ray_pos.distance_squared_to(hit_result as Vector3);
				#if closest_solid == -1 or dist_sqr < closest_solid_distance:
					#closest_solid = solid_index;
					#closest_solid_distance = dist_sqr;
			#pass
	
	# TODO: We really should just raycast against the geometry the map has
	# Each triangle already encodes the solid & face in the BONE channel
	#Geometry3D.ray_intersects_triangle()
	# for mesh in map.get_editor_instances()
	# but if it's not C++ side or a built-in....
	
	# TODO: arrange the solids spatially if this ever starts to have speed issues
	for solid_index in range(0, map.solids.size()):
		# Build an AABB for the solid
		var solid := map.solids[solid_index];
		if not solid:
			continue;
		# TODO: Cache the AABBs
		var min_p := solid.points[0].v3;
		var max_p := solid.points[0].v3;
		for point in solid.points:
			min_p = min_p.min(point.v3);
			max_p = max_p.max(point.v3);
		var solid_bbox := AABB(min_p, max_p - min_p); 
		# Hit against the AABB
		var hit_result = solid_bbox.intersects_ray(ray_pos, ray_dir);
		if hit_result == null:
			continue;
		var dist_sqr : float = ray_pos.distance_squared_to(hit_result as Vector3);
		if closest_solid == -1 or dist_sqr < closest_solid_distance:
			# If this one has been clicked, now we do the more expensive check per-triangle
			# Loop through each face in the group
			for i_face in solid.faces.size():
				var face := solid.faces[i_face];
				for i_corner in range(1, face.corners.size() - 1):
					# Corners are 0, i_corner, i_corner+1
					var hit_result_hd = Geometry3D.ray_intersects_triangle(
						ray_pos, ray_dir,
						solid.points[face.corners[0]].v3,
						solid.points[face.corners[i_corner + 0]].v3,
						solid.points[face.corners[i_corner + 1]].v3);
					if hit_result_hd == null:
						continue
					# With out-hit result, check if it's valid:
					dist_sqr = ray_pos.distance_squared_to(hit_result_hd as Vector3);
					if closest_solid == -1 or dist_sqr < closest_solid_distance:
						# If it's the closest one, update the clicked item
						closest_solid = solid_index;
						closest_face = i_face;
						closest_vertex_proc2 = i_corner;
						closest_solid_distance = dist_sqr;
						closest_position = hit_result_hd as Vector3;
					pass # End corner loop
				pass # End faces loop
			pass # End check AABB
		pass # End solids loop
		
	# If there's a selection, emit selection changed.
	if closest_solid != -1:
		_queue_selection_changed = true;
		
	if selection_mode == DioptraEditorMainPlugin.SelectMode.SOLID:
		return closest_solid;
	elif selection_mode == DioptraEditorMainPlugin.SelectMode.FACE:
		print("face: %d" % closest_face);
		return closest_solid | DPHelpers.SELBIT_HAS_FACE | (closest_face << DPHelpers.SELBIT_SHIFT_FACE);
	elif selection_mode == DioptraEditorMainPlugin.SelectMode.EDGE:
		#return closest_solid | SELBIT_SHIFT_EDGE | (closest_face << SELBIT_SHIFT_EDGE);
		pass
	elif selection_mode == DioptraEditorMainPlugin.SelectMode.VERTEX:
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
		
	var solid_id = subgizmo_id & DPHelpers.SELBIT_MASK_SOLID;
	if solid_id >= 0 and solid_id < map.solids.size():
		# Solid Corner
		if subgizmo_id < DPHelpers.SELECTION_MAX_VALUE:
			t = t.translated(map.solids[solid_id].points[0].v3);
		# Face Corner
		elif (subgizmo_id & DPHelpers.SELBIT_HAS_FACE) != 0:
			var face_id = (subgizmo_id >> DPHelpers.SELBIT_SHIFT_FACE) & DPHelpers.SELBIT_MASK_FACE;
			var solid := map.solids[solid_id];
			if face_id < solid.faces.size():
				t = t.translated(solid.points[solid.faces[face_id].corners[0]].v3);
	return t;
	
class StartingTransform:
	var transform : Transform3D;
	var points : Array[MapVector3];
	
var _is_transforming : bool = false;
var _transform_start : Dictionary[int, StartingTransform];

func _start_subgizmo_transform(gizmo: EditorNode3DGizmo, subgizmo_id: int) -> void:
	var node3d := gizmo.get_node_3d()
	var map := node3d as DP_Map;
	var solid_id = subgizmo_id & DPHelpers.SELBIT_MASK_SOLID;
	var solid := map.solids[solid_id];
	
	_is_transforming = true;
	#if _transform_start.size() <= subgizmo_id:
	#	_transform_start.resize(subgizmo_id + 1);
		
	_transform_start[subgizmo_id] = StartingTransform.new();
	_transform_start[subgizmo_id].transform = _get_subgizmo_transform(gizmo, subgizmo_id);
	
	_transform_start[subgizmo_id].points = solid.points.duplicate();
	for i in _transform_start[subgizmo_id].points.size():
		_transform_start[subgizmo_id].points[i] = MapVector3.new();
		_transform_start[subgizmo_id].points[i].v3i = solid.points[i].v3i;
	# Moving solid
	#if subgizmo_id < SELECTION_MAX_VALUE:
		#_transform_start[subgizmo_id].points = solid.points.duplicate();
		#for i in _transform_start[subgizmo_id].points.size():
			#_transform_start[subgizmo_id].points[i] = MapVector3.new();
			#_transform_start[subgizmo_id].points[i].v3i = solid.points[i].v3i;
	## Moving face
	#elif (subgizmo_id & SELBIT_HAS_FACE) != 0:
		#_transform_start[subgizmo_id].points = solid.points.duplicate();
		#for i in _transform_start[subgizmo_id].points.size():
			#_transform_start[subgizmo_id].points[i] = MapVector3.new();
			#_transform_start[subgizmo_id].points[i].v3i = solid.points[i].v3i;
	
	pass
	
func _set_subgizmo_transform(gizmo: EditorNode3DGizmo, subgizmo_id: int, transform: Transform3D) -> void:
	# if we're beginning then mark a start with the current transform start
	if not _is_transforming:
		_start_subgizmo_transform(gizmo, subgizmo_id);
	
	var solid_id = subgizmo_id & DPHelpers.SELBIT_MASK_SOLID;
	print("set gizmo transform: %d" % solid_id);
	
	var node3d := gizmo.get_node_3d();
	var map := node3d as DP_Map;
	
	var solid := map.solids[solid_id];
	var reference := _transform_start[subgizmo_id];
	
	var delta_position = DioptraInterface.get_grid_round_v3((reference.transform.inverse() * transform).origin);
	
	# Offset the points
	# Moving solid
	if subgizmo_id < DPHelpers.SELECTION_MAX_VALUE:
		for i in solid.points.size():
			solid.points[i].v3 = reference.points[i].v3 + delta_position;
	# Moving face
	elif (subgizmo_id & DPHelpers.SELBIT_HAS_FACE) != 0:
		var face_id = (subgizmo_id >> DPHelpers.SELBIT_SHIFT_FACE) & DPHelpers.SELBIT_MASK_FACE;
		for i in solid.faces[face_id].corners.size():
			var vert = solid.faces[face_id].corners[i];
			solid.points[vert].v3 = reference.points[vert].v3 + delta_position;
		
	map.update_gizmos();
		
	pass

func _commit_subgizmos(gizmo: EditorNode3DGizmo, ids: PackedInt32Array, restores: Array[Transform3D], cancel: bool) -> void:
	print("commit subgizmos: cancel %s" % ("true" if cancel else "false"));
	
	_is_transforming = false;
	
	var node3d := gizmo.get_node_3d()
	var map := node3d as DP_Map;
	map.rebuild_editor_map(); #todo, grab a Solid from the map
	
	map.update_gizmos();
	
	pass
	
	
