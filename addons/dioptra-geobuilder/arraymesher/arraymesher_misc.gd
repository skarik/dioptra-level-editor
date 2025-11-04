## Adds a point:
static func point_add(mesher : DPArrayMesher, position : Vector3) -> void:
	mesher.add_storage(1, 0);
	
	var vertex := mesher.get_surface_vertex();
	vertex[mesher._vertex_count + 0] = position;
	
	if mesher.has_normals():
		var normal = mesher.get_surface_normal();
		normal[mesher._vertex_count + 0] = Vector3.UP;
	
	if mesher.has_uv():
		var tex_uv = mesher.get_surface_tex_uv();
		tex_uv[mesher._vertex_count + 0] = Vector2.ZERO;
		
	if mesher.has_colors():
		var color = mesher.get_surface_color();
		color[mesher._vertex_count + 0] = Color.WHITE;

	mesher._vertex_count += 1;
	pass
