## Adds a quad:
static func quad_add(mesher : DPArrayMesher, position : Vector3, up : Vector3, right : Vector3) -> void:
	mesher.add_storage(4, 6);
	
	var vertex := mesher.get_surface_vertex();
	vertex[mesher._vertex_count + 0] = position + up + right;
	vertex[mesher._vertex_count + 1] = position + up - right;
	vertex[mesher._vertex_count + 2] = position - up + right;
	vertex[mesher._vertex_count + 3] = position - up - right;
	
	if mesher.has_normals():
		var normal = mesher.get_surface_normal();
		var face_normal := up.cross(right).normalized();
		normal[mesher._vertex_count + 0] = face_normal;
		normal[mesher._vertex_count + 1] = face_normal;
		normal[mesher._vertex_count + 2] = face_normal;
		normal[mesher._vertex_count + 3] = face_normal;
	
	if mesher.has_uv():
		var tex_uv = mesher.get_surface_tex_uv();
		tex_uv[mesher._vertex_count + 0] = Vector2(0, 0);
		tex_uv[mesher._vertex_count + 1] = Vector2(1, 0);
		tex_uv[mesher._vertex_count + 2] = Vector2(0, 1);
		tex_uv[mesher._vertex_count + 3] = Vector2(1, 1);
		
	if mesher.has_colors():
		var color = mesher.get_surface_color();
		color[mesher._vertex_count + 0] = Color.WHITE;
		color[mesher._vertex_count + 1] = Color.WHITE;
		color[mesher._vertex_count + 2] = Color.WHITE;
		color[mesher._vertex_count + 3] = Color.WHITE;
		
	var index := mesher.get_surface_index();
	index[mesher._index_count + 0] = mesher._vertex_count + 0;
	index[mesher._index_count + 1] = mesher._vertex_count + 1;
	index[mesher._index_count + 2] = mesher._vertex_count + 2;
	index[mesher._index_count + 3] = mesher._vertex_count + 1;
	index[mesher._index_count + 4] = mesher._vertex_count + 3;
	index[mesher._index_count + 5] = mesher._vertex_count + 2;
	
	mesher._vertex_count += 4;
	mesher._index_count += 6;
	pass
