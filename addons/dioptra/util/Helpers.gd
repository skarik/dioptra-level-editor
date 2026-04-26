@tool
class_name DPHelpers

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

const SELECTION_MAX_VALUE : int = (1 << 15) - 1;
const SELBIT_INDEX_MASK : int = 0x7FFF;
const SELBIT_TYPE_MASK : int = 0x7;
const SELBIT_TYPE_SHIFT : int = 15;
const SELBIT_FACE_MASK : int = 0x3FF;
const SELBIT_FACE_SHIFT : int = 18;
const SELBIT_EDGE_MASK : int = 0x3FF;
const SELBIT_EDGE_SHIFT : int = 28;
const SELBIT_VERTEX_MASK : int = 0x3FF;
const SELBIT_VERTEX_SHIFT : int = 38;

## Gets the encoded subgizmo ID for the given selection item
static func get_subgizmo(selection : DPSelectionItem) -> int:
	var subgizmo_id = -1;
	
	if selection.type <= SelectionType.VERTEX:
		subgizmo_id = 0;
		subgizmo_id |= selection.solid_id & SELBIT_INDEX_MASK;
		subgizmo_id |= selection.type << SELBIT_TYPE_SHIFT;
		subgizmo_id |= (selection.face_id & SELBIT_FACE_MASK) << SELBIT_FACE_SHIFT;
	elif selection.type == SelectionType.DECAL:
		subgizmo_id = 0;
		subgizmo_id |= selection.decal_id & SELBIT_INDEX_MASK;
		subgizmo_id |= selection.type << SELBIT_TYPE_SHIFT;
	
	return subgizmo_id;

## Given a subgizmo_id from editor gizmo, returns the type of selection it is
## If the selection is invalid for the given map, will return none
static func get_selection_type(map : DP_Map, subgizmo_id : int) -> SelectionType:
	if subgizmo_id >= 0:
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
					return SelectionType.EDGE;
				elif selection_type == SelectionType.VERTEX:
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
		var vertex_id = (subgizmo_id >> SELBIT_VERTEX_SHIFT) & SELBIT_VERTEX_MASK;
		
		result.solid_id = solid_id;
		result.face_id = face_id;
		
		if selection_type == SelectionType.SOLID:
			result.solid = map.solids[solid_id];
		elif selection_type == SelectionType.FACE:
			result.solid = map.solids[solid_id];
			result.face = map.solids[solid_id].faces[face_id];
	elif selection_type == SelectionType.DECAL:
		var decal_id = subgizmo_id & SELBIT_INDEX_MASK;
		
		result.decal_id = decal_id;
		result.decal = map.decals[decal_id];
		
	return result;
	
