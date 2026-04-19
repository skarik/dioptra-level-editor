@tool
extends Node3D
class_name DP_Map
## Class for building maps
##
## TODO
##

#------------------------------------------------------------------------------#

## The solids that make up the map
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR)
var solids : Array[DPMapSolid] = [];

## The materials that make up the map, referenced by the solids
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR)
var materials : Array[Material] = [];
## The materials that make up the map, referenced by the non-solids.
## Split for editor and locality use. Items in materials will typically not be duplicated here.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR)
var material_objects : Array[Material] = [];

## The decals in the map
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR)
var decals : Array[DPMapDecal] = [];

#------------------------------------------------------------------------------#

@export_storage
var baked_geoemtry : Resource = null; # TODO

#------------------------------------------------------------------------------#

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		# Start up DP internals & settings if not there yet
		if not DioptraInterface._has_instance():
			DioptraInterface.init_instance();
	pass
	
func _ready() -> void:
	fix_member_valid_values();
	if Engine.is_editor_hint():
		rebuild_editor_mesh_groups();
		rebuild_editor_map();
		rebuild_editor_decals();
	else:
		# Rebuild the map:
		## TODO: this should just load whatever is baked but for now we just use the editor map
		rebuild_editor_mesh_groups();
		rebuild_editor_map();
		rebuild_editor_decals();
		rebuild_editor_map_collision();

#------------------------------------------------------------------------------#

func fix_member_valid_values() -> void:
	if solids == null: solids = [];
	if materials == null: materials = [];
	if material_objects == null: material_objects = [];
	if decals == null: decals = [];
	# TODO: mark as undoable action here.
	pass

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
var _editor_mesh_instances_decals : MeshInstance3D = null;

## Rebuilds the mesh groups.
##
## Editor mesh groups are the spatial groups of the editor solids, used to limit
## the amount of meshes that need to be rebuilt with a change.
func rebuild_editor_mesh_groups() -> void:
	fix_member_valid_values();
	_editor_mesh_groups = [];
	
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
	
	pass

## Rebuilds editor map, which is a separate case than the "baked" map but uses
## building similar techniques.
## If the solid is specified, only rebuilds part of the map (fast!).
## Otherwise, rebuilds the entire map (slow).
func rebuild_editor_map(solid : DPMapSolid = null) -> void:
	## Get solid index in list
	var solid_index := -1 if solid == null else solids.find(solid);
	
	## Figure out which management group the solid is with and rebuild that group:
	var containing_group := -1;
	if solid != null and solid_index == -1:
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
			mesher_list[material_index] = DPArrayMesher.new(
				DPArrayMesher.TypeFlags.VERTEX | DPArrayMesher.TypeFlags.NORMAL | DPArrayMesher.TypeFlags.TEX_UV
				| DPArrayMesher.TypeFlags.BONES
				| DPArrayMesher.TypeFlags.INDEX
			);
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
				
			# Build UVs for the face
			if face.material != -1:
				if face.uv_mode == DPMapFace.UVMode.WORLD:
					# Detect the face UV mode in world mode
					if face.uv_subflags & DPMapFace.UV_WORLD_FLAG_AUTO:
						face.uv_subflags = DPMapFace.UV_WORLD_FLAG_AUTO;
						var normal_abs := normal.abs();
						if normal_abs.x >= normal_abs.y and normal_abs.x >= normal_abs.z:
							face.uv_subflags |= DPMapFace.UV_WORLD_FLAG_X;
						elif normal_abs.y >= normal_abs.x and normal_abs.y >= normal_abs.z:
							face.uv_subflags |= DPMapFace.UV_WORLD_FLAG_Y;
						else:
							face.uv_subflags |= DPMapFace.UV_WORLD_FLAG_Z;
					# Pull everything we need:
					var material := materials[face.material];
					var positions := am.get_surface_vertex();
					var uvs := am.get_surface_tex_uv();
					var texture_scale1d := DioptraInterface.get_pixel_scale_top() * float(DioptraInterface.get_pixel_scale_div());
					var texture_scale2d := (Vector2(texture_scale1d, texture_scale1d) * face.uv_scale) / Vector2(DPHelpers.get_material_primary_texture_size(material));
					var texture_offset = (face.uv_offset / texture_scale1d);
					# Apply the world-mode UVs depending on the flag:
					if face.uv_subflags & DPMapFace.UV_WORLD_FLAG_X:
						for i_vertex in range(v0, am.get_vertex_count()):
							uvs[i_vertex] = ((Vector2(-positions[i_vertex].z, -positions[i_vertex].y)).rotated(deg_to_rad(face.uv_rotation)) + texture_offset) * texture_scale2d;
					elif face.uv_subflags & DPMapFace.UV_WORLD_FLAG_Y:
						for i_vertex in range(v0, am.get_vertex_count()):
							uvs[i_vertex] = ((Vector2(positions[i_vertex].x, positions[i_vertex].z)).rotated(deg_to_rad(face.uv_rotation)) + texture_offset) * texture_scale2d;
					elif face.uv_subflags & DPMapFace.UV_WORLD_FLAG_Z:
						for i_vertex in range(v0, am.get_vertex_count()):
							uvs[i_vertex] = ((Vector2(positions[i_vertex].x, -positions[i_vertex].y)).rotated(deg_to_rad(face.uv_rotation)) + texture_offset) * texture_scale2d;
					pass # End UVMode.WORLD
				#
				pass # End face.material != -1;
				
			# Pack in solid info into the bones:
			for i_vertex in range(v0, am.get_vertex_count()):
				am.get_surface_bone()[i_vertex * 4 + 0] = i_solid;
				am.get_surface_bone()[i_vertex * 4 + 1] = i_solid >> 8;
				am.get_surface_bone()[i_vertex * 4 + 2] = i_face;
				am.get_surface_bone()[i_vertex * 4 + 3] = i_vertex;
				
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

## Rebuilds the static mesh collision for the map using the editor meshes
func rebuild_editor_map_collision() -> void:
	for mesh_instance in _editor_mesh_instances:
		if mesh_instance.mesh != null:
			var static_body := StaticBody3D.new();
			mesh_instance.add_child(static_body, false);
			static_body.owner = mesh_instance;
			
			# Add in all the mesh back in
			# TODO: this can be the convex solids, cubes if prims
			var poly_shape := ConcavePolygonShape3D.new();
			var triangles := PackedVector3Array();
			for surface_id in mesh_instance.mesh.get_surface_count():
				var arrays := mesh_instance.mesh.surface_get_arrays(surface_id);
				var indicies := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array;
				var positions := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array;
				for tri_base in range(0, indicies.size(), 3):
					triangles.push_back(positions[indicies[tri_base + 0]]);
					triangles.push_back(positions[indicies[tri_base + 1]]);
					triangles.push_back(positions[indicies[tri_base + 2]]);
			poly_shape.set_faces(triangles);
			
			var collision_shape := CollisionShape3D.new();
			collision_shape.shape = poly_shape;
			static_body.add_child(collision_shape, false);
			collision_shape.owner = static_body;
	pass
	
## Rebuilds the decals static mesh for the map
## If the decal is specified, only rebuilds part of the decals (fast!).
## Otherwise, rebuilds the entire map (slow).
## TODO: That entire optimization
func rebuild_editor_decals(in_decal : DPMapDecal = null) -> void:
	# Set up the mesh we have
	var mesh_instance = _editor_get_mesh_instance_for_decals();
	
	# Maintain a dictionary of all the mats to array mesher
	var mesher_list : Dictionary[int, DPArrayMesher] = {};
	var get_mesher = func(material_index : int) -> DPArrayMesher:
		if not mesher_list.has(material_index):
			mesher_list[material_index] = DPArrayMesher.new(
				DPArrayMesher.TypeFlags.VERTEX | DPArrayMesher.TypeFlags.NORMAL | DPArrayMesher.TypeFlags.TEX_UV
				| DPArrayMesher.TypeFlags.BONES
				| DPArrayMesher.TypeFlags.INDEX
			);
		return mesher_list[material_index];
	
	for decal in decals:
		var am : DPArrayMesher = get_mesher.call(decal.material);
		#var v0 := am.get_vertex_count();
		
		# Grab all the info we need:
		var material := material_objects[decal.material];
		var pixels_per_gdunit := DioptraInterface.get_pixel_scale_top() / float(DioptraInterface.get_pixel_scale_div());
		var gdunit_per_dpunit := DioptraInterface.get_position_scale_div() / float(DioptraInterface.get_position_scale_top());
		var decal_texel_size := DPHelpers.get_material_primary_texture_size(material);
		var decal_size := decal_texel_size / pixels_per_gdunit;
		
		# Build the basis
		var decal_rotation := Quaternion.from_euler(decal.rotation);
		var normal := decal_rotation * -Vector3.FORWARD;
		var up := decal_rotation * Vector3.UP;
		var left := decal_rotation * Vector3.LEFT;
		var decal_position := decal.position.v3;
		
		# Build a quad
		#am.quad_add(decal.position.v3 + normal * 0.05, up, left);
		
		# Generate decal projection corners
		var w_up := up * decal_size.y * 0.5;
		var w_left := left * decal_size.x * 0.5;
		var decal_corners : PackedVector3Array = [
			decal_position - w_up - w_left + normal * decal.near_clip * gdunit_per_dpunit,
			decal_position - w_up + w_left + normal * decal.near_clip * gdunit_per_dpunit,
			decal_position + w_up + w_left + normal * decal.near_clip * gdunit_per_dpunit,
			decal_position + w_up - w_left + normal * decal.near_clip * gdunit_per_dpunit,
			
			decal_position - w_up - w_left + normal * decal.far_clip * gdunit_per_dpunit,
			decal_position - w_up + w_left + normal * decal.far_clip * gdunit_per_dpunit,
			decal_position + w_up + w_left + normal * decal.far_clip * gdunit_per_dpunit,
			decal_position + w_up - w_left + normal * decal.far_clip * gdunit_per_dpunit,
		];
		var decal_min := decal_corners[0];
		var decal_max := decal_corners[0];
		for i in range(1, 8):
			decal_min = decal_min.min(decal_corners[i]);
			decal_max = decal_max.max(decal_corners[i]);
		var decal_bbox := AABB(decal_min, decal_max - decal_min);
		
		# Build the planes
		var decal_planes : Array[Plane] = [
			Plane(normal, decal_position - normal * decal.near_clip * gdunit_per_dpunit),
			Plane(-normal, decal_position - normal * decal.far_clip * gdunit_per_dpunit),
			Plane( left, decal_position + w_left),
			Plane(-left, decal_position - w_left),
			Plane( up, decal_position + w_up),
			Plane(-up, decal_position - w_up),
		];
		
		var polygons : Array[PackedVector3Array] = [];
		
		# Get all the intersecting solids
		for solid in solids:
			# TODO: Cache the AABBs
			var min_p := solid.points[0].v3;
			var max_p := solid.points[0].v3;
			for point in solid.points:
				min_p = min_p.min(point.v3);
				max_p = max_p.max(point.v3);
			var solid_bbox := AABB(min_p, max_p - min_p); 
			# Hit against the AABB
			if decal_bbox.intersects(decal_bbox):
				# Check faces!
				# Build AABB against each face
				for face in solid.faces:
					var corners : PackedVector3Array;
					corners.resize(face.corners.size());
					for corner_index in face.corners.size():
						corners[corner_index] = solid.points[face.corners[corner_index]].v3;
					
					if not decal.project_colinear or not decal.project_two_sided:
						var face_normal := -((corners[1] - corners[0]).cross(corners[2] - corners[0])).normalized();
						var face_angle = normal.dot(face_normal);
						# Skip faces parallel
						if not decal.project_colinear:
							if absf(face_angle) < 0.01:
								continue;
						# Skip backfaces
						if not decal.project_two_sided:
							if face_angle < 0.0:
								continue;
					
					# If the face is inside, then start clipping based on the planes
					for plane in decal_planes:
						corners = Geometry3D.clip_polygon(corners, plane);
						if corners.is_empty():
							break;
							
					# If there's corners left let's add a polygon!
					if corners.size() > 2:
						polygons.push_back(corners);
				pass
		
		# If there's polygons add em
		if not polygons.is_empty():
			for polygon in polygons:
				var v0 := am.get_vertex_count();
				am.points_add(polygon);
				
				# Get a normal for the face
				for i_vertex in range(v0, am.get_vertex_count()):
					am.get_surface_normal()[i_vertex] = normal;
					
				# Build UVs for the face
				var positions := am.get_surface_vertex();
				var uvs := am.get_surface_tex_uv();
				for i_vertex in range(v0, am.get_vertex_count()):
					var position_2d_rot := (positions[i_vertex] - decal_position) * decal_rotation;
					var position_2d := Vector2(position_2d_rot.x, -position_2d_rot.y) / decal_size;
					uvs[i_vertex] = position_2d + Vector2(0.5, 0.5);
					
				# Push out positions by normal
				var polygon_normal : Vector3 = -((polygon[1] - polygon[0]).cross(polygon[2] - polygon[0])).normalized();
				for i_vertex in range(v0, am.get_vertex_count()):
					positions[i_vertex] += polygon_normal * gdunit_per_dpunit * 0.25;
					
				# Fill in the indicies
				for i_corner in range(1, polygon.size() - 1):
					am.tri_add_indicies(v0, v0 + i_corner + 0, v0 + i_corner + 1);
		
		pass # Per decal loop
	
	# Find the meshers and add the given meshes
	var mesh := ArrayMesh.new();
	var has_data := false;
	for material_index in mesher_list:
		var am : DPArrayMesher = mesher_list[material_index];
		# Only update if there's geometry in the index count
		if am.get_index_count() > 0:
			var surface_index = mesh.get_surface_count();
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, am.get_surface_array());
			mesh.surface_set_material(surface_index, null if (material_index == -1) else material_objects[material_index]);
			has_data = true; # Mark the mesh is valid
		pass
	
	# Apply the mesh
	mesh_instance.mesh = mesh if has_data else null;
	
	pass

# Returns the mesh instance for the given group.
# If it doesn't exist, it will be created
func _editor_get_mesh_instance_for_decals() -> MeshInstance3D:
	# fill in if null, instantiate a hidden child :)
	if _editor_mesh_instances_decals == null:
		var mesh_renderer := MeshInstance3D.new();
		add_child(mesh_renderer, false, Node.INTERNAL_MODE_FRONT);
		mesh_renderer.owner = self;
		_editor_mesh_instances_decals = mesh_renderer;
		
	return _editor_mesh_instances_decals;

#------------------------------------------------------------------------------#

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
	
	
## Adds the given object to the map
func editor_add_decal(decal : DPMapDecal) -> void:
	assert(not decals.has(decal), "Decal that already exists in the editor attempted to be added");
	
	# Add it to the decals list
	decals.append(decal);
	
	# That's it!
	pass

#------------------------------------------------------------------------------#

## Adds the given material to the array, or finds it. Returns material index in the map.
func get_or_add_material(mat : Material, for_objects : bool = false) -> int:
	fix_member_valid_values();
	var mat_list = materials if not for_objects else material_objects;
	var existing_index = mat_list.find(mat);
	if existing_index == -1:
		existing_index = mat_list.size();
		mat_list.push_back(mat);
	return existing_index;

#------------------------------------------------------------------------------#
