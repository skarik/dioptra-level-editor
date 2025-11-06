## Adds a quad:
static func tri_add_indicies(mesher : DPArrayMesher, corner_0 : int, corner_1 : int, corner_2 : int) -> void:
	mesher.add_storage(0, 3);

	var index := mesher.get_surface_index();
	index[mesher._index_count + 0] = corner_0;
	index[mesher._index_count + 1] = corner_1;
	index[mesher._index_count + 2] = corner_2;

	mesher._index_count += 3;
	pass
