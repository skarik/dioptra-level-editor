@tool
extends EditorNode3DGizmo
class_name TTSItemGizmo


func _redraw():
	clear()
	
	var lines = PackedVector3Array()

	const boxSize : float = 0.3;
	
	lines.push_back(Vector3(-1, -1, -1) * boxSize)
	lines.push_back(Vector3(-1,  1, -1) * boxSize)
	lines.push_back(Vector3(-1,  1, -1) * boxSize)
	lines.push_back(Vector3( 1,  1, -1) * boxSize)
	lines.push_back(Vector3( 1,  1, -1) * boxSize)
	lines.push_back(Vector3( 1, -1, -1) * boxSize)
	lines.push_back(Vector3( 1, -1, -1) * boxSize)
	lines.push_back(Vector3(-1, -1, -1) * boxSize)
	
	lines.push_back(Vector3(-1, -1,  1) * boxSize)
	lines.push_back(Vector3(-1,  1,  1) * boxSize)
	lines.push_back(Vector3(-1,  1,  1) * boxSize)
	lines.push_back(Vector3( 1,  1,  1) * boxSize)
	lines.push_back(Vector3( 1,  1,  1) * boxSize)
	lines.push_back(Vector3( 1, -1,  1) * boxSize)
	lines.push_back(Vector3( 1, -1,  1) * boxSize)
	lines.push_back(Vector3(-1, -1,  1) * boxSize)
	
	lines.push_back(Vector3(-1, -1, -1) * boxSize)
	lines.push_back(Vector3(-1, -1,  1) * boxSize)
	lines.push_back(Vector3(-1,  1, -1) * boxSize)
	lines.push_back(Vector3(-1,  1,  1) * boxSize)
	lines.push_back(Vector3( 1,  1, -1) * boxSize)
	lines.push_back(Vector3( 1,  1,  1) * boxSize)
	lines.push_back(Vector3( 1, -1, -1) * boxSize)
	lines.push_back(Vector3( 1, -1,  1) * boxSize)

	var handles = PackedVector3Array()

	handles.push_back(Vector3(0, 0, 0))
	handles.push_back(Vector3(0, 1, 0))
	#handles.push_back(Vector3(gizmo_size, node3d.my_custom_value, 0))

	var material = get_plugin().get_material("main", self)
	add_lines(lines, material, false)

	var handles_material = get_plugin().get_material("handles", self)
	add_handles(handles, handles_material, [])
	
	print("redraw w/ %d" % get_plugin().get_instance_id())
	assert(get_plugin().mSelectMesh != null)

	add_mesh(get_plugin().mSelectMesh, material)
	
	add_collision_triangles(get_plugin().mSelectMesh);
