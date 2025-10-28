extends EditorNode3DGizmoPlugin

func _init() -> void:
	create_material("geo", Color(1.0, 1.0, 0.5), false, false, false);
	pass

func _get_gizmo_name() -> String:
	return "TTSCube";
	
func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is TTSCube;
	
func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	
	var node3d = gizmo.get_node_3d();
	var nodecube = node3d as TTSCube;
	
	var local_mesh : ArrayMesh = ArrayMesh.new();
	if true:
		var surface_array : Array[Variant] = [];
		surface_array.resize(Mesh.ARRAY_MAX);
		
		var verts := PackedVector3Array();
		var uvs := PackedVector2Array();
		var normals := PackedVector3Array();
		var indices := PackedInt32Array();
		
		verts.append(Vector3(1, 1, 0));
		verts.append(Vector3(-1, 1, 0));
		verts.append(Vector3(1, -1, 0));
		verts.append(Vector3(-1, -1, 0));
		
		uvs.append(Vector2(0, 0));
		uvs.append(Vector2(1, 0));
		uvs.append(Vector2(0, 1));
		uvs.append(Vector2(1, 1));
		
		for i in 4:
			normals.append(Vector3(0, 0, 1))
			indices.append(i)
		
		surface_array[Mesh.ARRAY_VERTEX] = verts
		surface_array[Mesh.ARRAY_TEX_UV] = uvs
		surface_array[Mesh.ARRAY_NORMAL] = normals
		surface_array[Mesh.ARRAY_INDEX] = indices
		
		local_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, surface_array)
	
	gizmo.add_mesh(local_mesh, get_material("geo"));
	
	gizmo.add_collision_triangles(local_mesh.generate_triangle_mesh());
	
	pass

func _set_subgizmo_transform(gizmo: EditorNode3DGizmo, subgizmo_id: int, transform: Transform3D) -> void:
	print("subgizmo transform");
	
func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	print("handle")
	
func _subgizmos_intersect_ray(gizmo: EditorNode3DGizmo, camera: Camera3D, screen_pos: Vector2) -> int:
	var rayed = camera.project_position(screen_pos, 10.0);
	
	return -1;
