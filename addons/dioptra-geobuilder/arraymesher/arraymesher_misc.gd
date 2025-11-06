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

# Adds an array
static func points_add(mesher : DPArrayMesher, positions : PackedVector3Array) -> void:
	var size := positions.size();
	
	mesher.add_storage(size, 0);
	
	var vertex := mesher.get_surface_vertex();
	for i in size:
		vertex[mesher._vertex_count + i] = positions[i];
		
	if mesher.has_normals():
		var normal = mesher.get_surface_normal();
		for i in size:
			normal[mesher._vertex_count + i] = Vector3.UP;
	
	if mesher.has_uv():
		var tex_uv = mesher.get_surface_tex_uv();
		for i in size:
			tex_uv[mesher._vertex_count + i] = Vector2.ZERO;
		
	if mesher.has_colors():
		var color = mesher.get_surface_color();
		for i in size:
			color[mesher._vertex_count + i] = Color.WHITE;
		
	mesher._vertex_count += size;
	pass
