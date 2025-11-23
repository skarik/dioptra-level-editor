class_name DPHelpers


static func get_material_primary_texture_size(mat : Material) -> Vector2i:
	if mat is StandardMaterial3D:
		var smat := mat as StandardMaterial3D;
		return Vector2i(smat.albedo_texture.get_size());
	
	return Vector2i(1, 1) * DioptraInterface.get_pixel_scale_top();
