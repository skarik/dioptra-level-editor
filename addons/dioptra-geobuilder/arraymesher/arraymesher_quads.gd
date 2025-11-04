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

## Adds a quad with given indicies:
static func quad_add_indicies(mesher : DPArrayMesher, corner_00 : int, corner_10 : int, corner_01 : int, corner_11 : int) -> void:
	mesher.add_storage(0, 6);

	var index := mesher.get_surface_index();
	index[mesher._index_count + 0] = corner_00;
	index[mesher._index_count + 1] = corner_10;
	index[mesher._index_count + 2] = corner_01;
	index[mesher._index_count + 3] = corner_10;
	index[mesher._index_count + 4] = corner_11;
	index[mesher._index_count + 5] = corner_01;

	mesher._index_count += 6;
	pass

## Sets the UVs of the quad at the given corner
static func quad_set_uvs(mesher : DPArrayMesher, corner_00 : int,
				  uv_00 : Vector2, uv_10 : Vector2,
				  uv_01 : Vector2, uv_11 : Vector2) -> void:
	var tex_uv = mesher.get_surface_tex_uv();
	tex_uv[corner_00 + 0] = uv_00;
	tex_uv[corner_00 + 1] = uv_10;
	tex_uv[corner_00 + 2] = uv_01;
	tex_uv[corner_00 + 3] = uv_11;
	pass
## Sets the UVs of the quad at the given corner
static func quad_set_uv2s(mesher : DPArrayMesher, corner_00 : int,
				  uv_00 : Vector2, uv_10 : Vector2,
				  uv_01 : Vector2, uv_11 : Vector2) -> void:
	var tex_uv2 = mesher.get_surface_tex_uv2();
	tex_uv2[corner_00 + 0] = uv_00;
	tex_uv2[corner_00 + 1] = uv_10;
	tex_uv2[corner_00 + 2] = uv_01;
	tex_uv2[corner_00 + 3] = uv_11;
	pass
	
## Sets the normal of the quad
static func quad_set_normal(mesher : DPArrayMesher, corner_00 : int, in_normal : Vector3) -> void:
	var normal = mesher.get_surface_normal();
	normal[corner_00 + 0] = in_normal;
	normal[corner_00 + 1] = in_normal;
	normal[corner_00 + 2] = in_normal;
	normal[corner_00 + 3] = in_normal;
		
## Sets the UVs of the quad at the given corner
static func quad_set_colors(mesher : DPArrayMesher, corner_00 : int,
					 color_00 : Color, color_10 : Color,
					 color_01 : Color, color_11 : Color) -> void:
	var color = mesher.get_surface_color();
	color[corner_00 + 0] = color_00;
	color[corner_00 + 1] = color_10;
	color[corner_00 + 2] = color_01;
	color[corner_00 + 3] = color_11;
	pass
