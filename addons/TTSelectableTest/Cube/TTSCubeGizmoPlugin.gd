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
		var am := DPArrayMesher.new();
		am.quad_add(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1));
		am.quad_add(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1));
		am.quad_add(Vector3(0, -2, 0), Vector3(1, 0, 0), Vector3(0, 0, 1));
		am.quad_add(Vector3(0, -3, 0), Vector3(1, 0, 0), Vector3(0, 0, 1));
		am.quad_add(Vector3(0, -4, 0), Vector3(1, 0, 0), Vector3(0, 0, 1));
		local_mesh.add_surface_from_arrays(am.get_primitive_type(), am.get_surface_array());
	
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
