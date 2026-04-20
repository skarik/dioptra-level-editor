@tool
class_name DPEditorSelection

## Selection Raycast Logic:
## Get the subgizmo for the given camera and screenpos
static func subgizmo_intersect_ray(map: DP_Map, camera: Camera3D, screen_pos: Vector2, selection_mode: DioptraEditorMainPlugin.SelectMode) -> int:
	var ray_pos := camera.project_ray_origin(screen_pos);
	var ray_dir := camera.project_ray_normal(screen_pos);
	
	#var node3d := gizmo.get_node_3d();
	#var map := node3d as DP_Map;
	
	var closest_solid := -1; # No selection
	var closest_distance := 0.0;
	var closest_face := -1;
	var closest_vertex_proc2 := -1;
	var closest_position : Vector3;
	var closest_type := DPHelpers.SelectionType.NONE;
	var closest_decal := -1;
	
	# Get selection mode from the plugin:
	#var selection_mode := mEditorPlugin.get_selection_mode();
	
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
		if closest_type == DPHelpers.SelectionType.NONE or dist_sqr < closest_distance:
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
					if closest_solid == -1 or dist_sqr < closest_distance:
						# If it's the closest one, update the clicked item
						closest_solid = solid_index;
						closest_face = i_face;
						closest_vertex_proc2 = i_corner;
						closest_distance = dist_sqr;
						closest_position = hit_result_hd as Vector3;
						closest_type = DPHelpers.SelectionType.SOLID;
					pass # End corner loop
				pass # End faces loop
			pass # End check AABB
		pass # End solids loop
		
	# TODO: is there a better way to check objects
	for decal_index in map.decals.size():
		# Build a tiny AABB for the decal
		var decal := map.decals[decal_index];
		if not decal:
			continue;
		# TODO
		const bbox_halfsize : float = 0.1;
		var decal_bbox := AABB(decal.position.v3 - Vector3.ONE * bbox_halfsize, Vector3.ONE * bbox_halfsize * 2.0); 
		# Hit against the AABB
		var hit_result = decal_bbox.intersects_ray(ray_pos, ray_dir);
		if hit_result == null:
			continue;
		var dist_sqr : float = ray_pos.distance_squared_to(hit_result as Vector3);
		if closest_type == DPHelpers.SelectionType.NONE or dist_sqr < closest_distance:
			dist_sqr = closest_distance;
			closest_type = DPHelpers.SelectionType.DECAL;
			closest_decal = decal_index;
			pass
		
	# If there's a selection, emit selection changed.
	#if closest_type != DPHelpers.SelectionType.NONE:
	#	_queue_selection_changed = true;
		
	var selection := DPSelectionItem.new();
		
	if closest_type == DPHelpers.SelectionType.SOLID:
		if selection_mode == DioptraEditorMainPlugin.SelectMode.SOLID:
			selection.type = DPHelpers.SelectionType.SOLID;
			selection.solid_id = closest_solid;
		elif selection_mode == DioptraEditorMainPlugin.SelectMode.FACE:
			selection.type = DPHelpers.SelectionType.FACE;
			selection.solid_id = closest_solid;
			selection.face_id = closest_face;
		elif selection_mode == DioptraEditorMainPlugin.SelectMode.EDGE:
			selection.type = DPHelpers.SelectionType.EDGE;
			selection.solid_id = closest_solid;
			selection.face_id = closest_face;
			#selection.edge_id = closest_edge;
		elif selection_mode == DioptraEditorMainPlugin.SelectMode.VERTEX:
			selection.type = DPHelpers.SelectionType.VERTEX;
			selection.solid_id = closest_solid;
			selection.face_id = closest_face;
			#selection.edge_id = closest_edge;
			#selection.vertex_id = closest_vertex;
			pass
	elif closest_type == DPHelpers.SelectionType.DECAL:
		selection.type = DPHelpers.SelectionType.DECAL;
		selection.decal_id = closest_decal;
		pass
		
	# TODO: Add decals here

	var subgizmo_selected := DPHelpers.get_subgizmo(selection);
	return subgizmo_selected;
