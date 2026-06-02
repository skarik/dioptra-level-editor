@tool
class_name DPHelpers

#------------------------------------------------------------------------------#

const COLOR_GEO_ACCENT := Color(0.2, 0.95, 1.0);
const RENDER_PRIORITY_LABEL := 11;
const RENDER_PRIORITY_LABEL_OUTLINE := 9;
const RENDER_PRIORITY_SELECT_LINE := 8;

#------------------------------------------------------------------------------#

static func get_material_primary_texture_size(mat : Material) -> Vector2i:
	var smat := mat as StandardMaterial3D;
	if smat != null and smat.albedo_texture != null:
		return Vector2i(smat.albedo_texture.get_size());
	
	return Vector2i(1, 1) * DioptraInterface.get_pixel_scale_top();

#------------------------------------------------------------------------------#
# Selection System

enum SelectionType {
	NONE = 0x7,
	SOLID = 0,
	FACE = 1,
	EDGE = 2,
	VERTEX = 3,
	
	OBJECT = 4,
	DECAL = 5,
};

 # Subgizmo ID is internally a 32-bit integer so we have to limit what we're working with.

const SELECTION_MAX_VALUE : int = (1 << 15) - 1;
const SELBIT_INDEX_MASK : int = 0x7FFF;
const SELBIT_TYPE_MASK : int = 0x7;
const SELBIT_TYPE_SHIFT : int = 15;
const SELBIT_FACE_MASK : int = 0x3F;
const SELBIT_FACE_SHIFT : int = 18;
const SELBIT_EDGE_MASK : int = 0x3F;
const SELBIT_EDGE_SHIFT : int = 24;
const SELBIT_VERTEX_MASK : int = 0x3F; # Doesn't fit. We reconstruct:
const SELBIT_VERTEX_SHIFT : int = 32;

## Gets the encoded subgizmo ID for the given selection item
static func get_subgizmo(selection : DPSelectionItem) -> int:
	var subgizmo_id = -1;
	
	if selection.type <= SelectionType.VERTEX:
		subgizmo_id = 0;
		subgizmo_id |= selection.solid_id & SELBIT_INDEX_MASK;
		subgizmo_id |= selection.type << SELBIT_TYPE_SHIFT;
		subgizmo_id |= (selection.face_id & SELBIT_FACE_MASK) << SELBIT_FACE_SHIFT;
		subgizmo_id |= (selection.edge_id & SELBIT_EDGE_MASK) << SELBIT_EDGE_SHIFT;
		subgizmo_id |= (selection.vertex_id & SELBIT_VERTEX_MASK) << SELBIT_VERTEX_SHIFT;
	elif selection.type == SelectionType.DECAL:
		subgizmo_id = 0;
		subgizmo_id |= selection.decal_id & SELBIT_INDEX_MASK;
		subgizmo_id |= selection.type << SELBIT_TYPE_SHIFT;
	
	return subgizmo_id;

## Given a subgizmo_id from editor gizmo, returns the type of selection it is
## If the selection is invalid for the given map, will return none
static func get_selection_type(map : DP_Map, subgizmo_id : int) -> SelectionType:
	if subgizmo_id != -1 and map != null:
		var selection_type := (subgizmo_id >> SELBIT_TYPE_SHIFT) & SELBIT_TYPE_MASK;
		if selection_type <= SelectionType.VERTEX:
			var solid_id = subgizmo_id & SELBIT_INDEX_MASK;
			if solid_id < map.solids.size():
				if selection_type == SelectionType.SOLID:
					return SelectionType.SOLID;
				elif selection_type == SelectionType.FACE:
					var face_id = (subgizmo_id >> SELBIT_FACE_SHIFT) & SELBIT_FACE_MASK;
					if face_id < map.solids[solid_id].faces.size():
						return SelectionType.FACE;
				elif selection_type == SelectionType.EDGE:
					var face_id = (subgizmo_id >> SELBIT_FACE_SHIFT) & SELBIT_FACE_MASK;
					var edge_id = (subgizmo_id >> SELBIT_EDGE_SHIFT) & SELBIT_EDGE_MASK;
					if face_id < map.solids[solid_id].faces.size():
						if edge_id < map.solids[solid_id].faces[face_id].corners.size():
							return SelectionType.EDGE;
				elif selection_type == SelectionType.VERTEX:
					var face_id = (subgizmo_id >> SELBIT_FACE_SHIFT) & SELBIT_FACE_MASK;
					var edge_id = (subgizmo_id >> SELBIT_EDGE_SHIFT) & SELBIT_EDGE_MASK;
					var vert_id = (subgizmo_id >> SELBIT_VERTEX_SHIFT) & SELBIT_VERTEX_MASK;
					if face_id < map.solids[solid_id].faces.size():
						if edge_id < map.solids[solid_id].faces[face_id].corners.size():
							if vert_id < map.solids[solid_id].points.size():
								return SelectionType.VERTEX;
		elif selection_type == SelectionType.DECAL:
			var decal_id = subgizmo_id & SELBIT_INDEX_MASK;
			if decal_id < map.decals.size():
				return SelectionType.DECAL;
		else:
			return selection_type; # TODO
	return SelectionType.NONE;

## Given subgizmo_id, returns an object referencing the actual DP_Map objects
## All values are already error-checked, eliminating the need to excessively error-check
static func get_selection(map : DP_Map, subgizmo_id : int) -> DPSelectionItem:
	var selection_type = get_selection_type(map, subgizmo_id);
	
	var result = DPSelectionItem.new();
	result.type = selection_type;
	
	if selection_type <= SelectionType.VERTEX:
		var solid_id = subgizmo_id & SELBIT_INDEX_MASK;
		var face_id = (subgizmo_id >> SELBIT_FACE_SHIFT) & SELBIT_FACE_MASK;
		var edge_id = (subgizmo_id >> SELBIT_EDGE_SHIFT) & SELBIT_EDGE_MASK;
		var vert_id = (subgizmo_id >> SELBIT_VERTEX_SHIFT) & SELBIT_VERTEX_MASK;
		
		result.solid_id = -1 if (solid_id == SELBIT_INDEX_MASK) else solid_id;
		result.face_id = -1 if (face_id == SELBIT_FACE_MASK) else face_id;
		result.edge_id = -1 if (edge_id == SELBIT_EDGE_MASK) else edge_id;
		result.vertex_id = -1 if (vert_id == SELBIT_VERTEX_MASK) else vert_id;
		
		if selection_type == SelectionType.SOLID:
			result.solid = map.solids[solid_id];
		elif selection_type == SelectionType.FACE || selection_type == SelectionType.EDGE || selection_type == SelectionType.VERTEX:
			result.solid = map.solids[solid_id];
			result.face = map.solids[solid_id].faces[face_id];
			
		# HACK: Reconstruct vertex_id using edge_id because vertex_id is outside of 32 bit limit
		if selection_type == SelectionType.VERTEX:
			result.vertex_id = map.solids[solid_id].faces[face_id].corners[result.edge_id];
			
	elif selection_type == SelectionType.DECAL:
		var decal_id = subgizmo_id & SELBIT_INDEX_MASK;
		
		result.decal_id = decal_id;
		result.decal = map.decals[decal_id];
		
	return result;
	
#------------------------------------------------------------------------------#
# Geometry

static func face_fix_flags(solid : DPMapSolid, face : DPMapFace) -> void:
	# Build a quad or triangles with the given item
	var face_corners : PackedVector3Array = [];
	face_corners.resize(face.corners.size());
	for i_corner in face.corners.size():
		face_corners[i_corner] = solid.points[face.corners[i_corner]].v3;
	
	# Get a normal for the face
	var normal : Vector3 = -((face_corners[1] - face_corners[0]).cross(face_corners[2] - face_corners[0])).normalized();
	
	# Build UVs for the face
	if face.uv_mode == DPMapFace.UVMode.WORLD:
		# Detect the face UV mode in world mode
		if face.uv_subflags & DPMapFace.UV_WORLD_FLAG_AUTO:
			face.uv_subflags = DPMapFace.UV_WORLD_FLAG_AUTO;
			var normal_abs := normal.abs();
			var normal_max_axis := normal_abs.max_axis_index();
			if   normal_max_axis == 0:	face.uv_subflags |= DPMapFace.UV_WORLD_FLAG_X;
			elif normal_max_axis == 1:	face.uv_subflags |= DPMapFace.UV_WORLD_FLAG_Y;
			elif normal_max_axis == 2:	face.uv_subflags |= DPMapFace.UV_WORLD_FLAG_Z;
	
	# Done with UV flags


static func face_get_texture_basis(solid : DPMapSolid, face : DPMapFace) -> Basis:
	face_fix_flags(solid, face);
	
	# Build a quad or triangles with the given item
	var face_corners : PackedVector3Array = [];
	face_corners.resize(face.corners.size());
	for i_corner in face.corners.size():
		face_corners[i_corner] = solid.points[face.corners[i_corner]].v3;
	
	# Get a normal for the face
	var normal : Vector3 = -((face_corners[1] - face_corners[0]).cross(face_corners[2] - face_corners[0])).normalized();
	
	# World mapping is very simple:
	if face.uv_mode == DPMapFace.UVMode.WORLD:
		if face.uv_subflags & DPMapFace.UV_WORLD_FLAG_X:
			return Basis(Vector3(0, 0, -1), Vector3(0, -1, 0), Vector3(1, 0, 0));
		elif face.uv_subflags & DPMapFace.UV_WORLD_FLAG_Y:
			return Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0));
		elif face.uv_subflags & DPMapFace.UV_WORLD_FLAG_Z:
			return Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1));
	# Face mapping needs to be aligned wit hthe face
	elif face.uv_mode == DPMapFace.UVMode.FACE:
		# Generate X and Y directions for the face:
		var uvdir_x := Vector3.LEFT;
		var uvdir_y := Vector3.UP;
		# Use normal axis to set up uvdir_x and uvdir_y
		var normal_abs := normal.abs();
		var normal_max_axis := normal_abs.max_axis_index();
		
		# We do Y axis last because we really want it to be as unchanged as possible:
		# If X normal is dominant:
		if normal_max_axis == 0:
			uvdir_x = normal.cross(Vector3(0, -1, 0)).normalized();
			uvdir_y = normal.cross(-uvdir_x);
		# If Y normal is dominant:
		elif normal_max_axis == 1:
			uvdir_x = normal.cross(Vector3(0, 0, 1)).normalized();
			uvdir_y = -normal.cross(uvdir_x);
		# If Z normal is dominant:
		elif normal_max_axis == 2:
			uvdir_x = normal.cross(Vector3(0, -1, 0)).normalized();
			uvdir_y = -normal.cross(uvdir_x);
			
		var base_rotation := Basis(uvdir_x, uvdir_y, normal);
		var inv_rotation := base_rotation;
		return inv_rotation;
		
	# Catch-all: don't do anything.
	return Basis.IDENTITY;

static func face_get_texture_base_position(solid : DPMapSolid, face : DPMapFace) -> Vector3:
	if face.uv_mode == DPMapFace.UVMode.WORLD:
		return Vector3.ZERO;
	elif face.uv_mode == DPMapFace.UVMode.FACE:
		return solid.points[face.corners[0]].v3;
	return Vector3.ZERO;
