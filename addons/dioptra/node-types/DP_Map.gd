@tool
extends Node3D
class_name DP_Map
## Class for building maps
##
## TODO
##

#------------------------------------------------------------------------------#

## The solids that make up the map
#@export_storage
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR)
var solids : Array[DPMapSolid] = [];
## The materials that make up the map, referenced by the solids
@export_storage
var materials : Array[Material] = [];

#------------------------------------------------------------------------------#

@export_storage
var baked_geoemtry : Resource = null; # TODO

#------------------------------------------------------------------------------#

## Mesh group that managing which solids it contains
class EditorMeshGroup:
	var start_solid : int = 0;
	var end_solid : int = 1;

	## Does this group contain the given solid?
	func has_solid(map : DP_Map, solid : int) -> bool:
		return solid >= start_solid and solid < end_solid;

	pass

var _editor_mesh_groups : Array[EditorMeshGroup] = [];
var _editor_mesh_instances : Array[MeshInstance3D] = [];

## Rebuilds editor map, which is a separate case than the "baked" map but uses
## building similar techniques.
## If the solid is specified, only rebuilds part of the map (fast!).
## Otherwise, rebuilds the entire map (slow).
func rebuild_editor_map(solid : DPMapSolid = null) -> void:
	## Get solid index in list
	var solid_index := solids.find(solid);
	
	## Figure out which management group the solid is with and rebuild that group:
	var containing_group := -1;
	if solid_index == -1:
		for i_group in _editor_mesh_groups.size():
			var group := _editor_mesh_groups[i_group];
			if group.has_solid(self, solid_index):
				containing_group = i_group;
		assert(containing_group != -1, \
			"Solid passed into rebuild that is not part of a management group.");
		pass
		
	## Rebuild groups!
	if containing_group != -1:
		_rebuild_editor_map_group(containing_group);
	else:
		for i_group in _editor_mesh_groups.size():
			_editor_get_mesh_instance(i_group).mesh = null; # Null out mesh for the renderers
			_rebuild_editor_map_group(i_group);
			pass
		pass
	pass

# Rebuilds the mesh for the given group
func _rebuild_editor_map_group(group_index : int) -> void:
	var group := _editor_mesh_groups[group_index];
	
	# Set up the mesh we have
	var mesh_instance = _editor_get_mesh_instance(group_index);
	
	# Maintain a dictionary of all the mats to array mesher
	var mesher_list : Dictionary[int, DPArrayMesher] = {};
	var get_mesher = func(material_index : int) -> DPArrayMesher:
		if not mesher_list.has(material_index):
			mesher_list[material_index] = DPArrayMesher.new();
		return mesher_list[material_index];
	
	# Loop through all the items in the group and rebuild the mesh
	for i_solid in range(group.start_solid, group.end_solid):
		var solid := solids[i_solid];
		# Loop through each face in the group
		for i_face in solid.faces.size():
			var face := solid.faces[i_face];
			var am : DPArrayMesher = get_mesher.call(face.material);
			var v0 := am.get_vertex_count();
			
			# Build a quad or triangles with the given item
			var face_corners : PackedVector3Array = [];
			face_corners.resize(face.corners.size());
			for i_corner in face.corners.size():
				face_corners[i_corner] = solid.points[face.corners[i_corner]].v3;
			am.points_add(face_corners);
			
			# Get a normal for the face
			var normal : Vector3 = -((face_corners[1] - face_corners[0]).cross(face_corners[2] - face_corners[0])).normalized();
			for i_vertex in range(v0, am.get_vertex_count()):
				am.get_surface_normal()[i_vertex] = normal;
				
			# Fill in the indicies
			for i_corner in range(1, face.corners.size() - 1):
				am.tri_add_indicies(v0, v0 + i_corner + 0, v0 + i_corner + 1);
				
			pass # i_face
		pass # i_solid
	
	# Find the meshers and add the given meshes
	var mesh := ArrayMesh.new();
	var has_data := false;
	for material_index in mesher_list:
		var am : DPArrayMesher = mesher_list[material_index];
		# Only update if there's geometry in the index count
		if am.get_index_count() > 0:
			var surface_index = mesh.get_surface_count();
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, am.get_surface_array());
			mesh.surface_set_material(surface_index, null if (material_index == -1) else materials[material_index]);
			has_data = true; # Mark the mesh is valid
		pass
	
	# Apply the mesh
	mesh_instance.mesh = mesh if has_data else null;
		
	pass # func _rebuild_editor_map_group
	
# Returns the mesh instance for the given group.
# If it doesn't exist, it will be created
func _editor_get_mesh_instance(group_index : int) -> MeshInstance3D:
	if group_index >= _editor_mesh_instances.size():
		_editor_mesh_instances.resize(group_index + 1);
		
	# fill in if null, instantiate a hidden child :)
	if _editor_mesh_instances[group_index] == null:
		var mesh_renderer := MeshInstance3D.new();
		add_child(mesh_renderer, false, Node.INTERNAL_MODE_FRONT);
		mesh_renderer.owner = self;
		_editor_mesh_instances[group_index] = mesh_renderer;
		
	return _editor_mesh_instances[group_index];

## Adds the given solid to the map
func editor_add_solid(solid : DPMapSolid) -> void:
	assert(not solids.has(solid), "Solid that already exists in the editor attempted to be added");
	
	# First, add it to the solids list:
	solids.append(solid);
	# Now, make it part of an editor group
	var mesh_group : EditorMeshGroup = null;
	if _editor_mesh_groups.is_empty():
		_editor_mesh_groups.append(EditorMeshGroup.new());
		mesh_group = _editor_mesh_groups[0];
		mesh_group.start_solid = 0;
	else:
		mesh_group = _editor_mesh_groups[0];
		
	# For now make it run the whole way
	mesh_group.end_solid = solids.size();
	
	# And it's added!
	pass

#------------------------------------------------------------------------------#
