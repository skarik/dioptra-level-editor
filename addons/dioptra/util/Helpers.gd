@tool
class_name DPHelpers

#------------------------------------------------------------------------------#

static func get_material_primary_texture_size(mat : Material) -> Vector2i:
	if mat is StandardMaterial3D:
		var smat := mat as StandardMaterial3D;
		return Vector2i(smat.albedo_texture.get_size());
	
	return Vector2i(1, 1) * DioptraInterface.get_pixel_scale_top();

#------------------------------------------------------------------------------#
# Selection System

const SELECTION_MAX_VALUE : int = (1 << 15) - 1;
const SELBIT_MASK_SOLID : int = 0x7FFF;
const SELBIT_HAS_FACE : int = (1 << 15);
const SELBIT_SHIFT_FACE : int = 16;
const SELBIT_MASK_FACE : int = 0x3FF;
const SELBIT_HAS_EDGE : int = (1 << 26);
const SELBIT_SHIFT_EDGE : int = 27;
const SELBIT_MASK_EDGE : int = 0x3FF;
const SELBIT_HAS_VERTEX : int = (1 << 37);
const SELBIT_SHIFT_VERTEX : int = 38;
const SELBIT_MASK_VERTEX : int = 0x3FF;

enum SelectionType {
	NONE = -1,
	SOLID = 0,
	FACE = 1,
	EDGE = 2,
	VERTEX = 3,
}

## Given a subgizmo_id from editor gizmo, returns the type of selection it is
static func get_selection_type(subgizmo_id : int) -> SelectionType:
	if subgizmo_id >= 0:
		if subgizmo_id < SELECTION_MAX_VALUE:
			return SelectionType.SOLID;
		elif (subgizmo_id & SELBIT_HAS_FACE) != 0:
			return SelectionType.FACE;
		elif (subgizmo_id & SELBIT_HAS_EDGE) != 0:
			return SelectionType.EDGE;
		elif (subgizmo_id & SELBIT_HAS_VERTEX) != 0:
			return SelectionType.VERTEX;
	return SelectionType.NONE;

## Given subgizmo_id, returns a dictionary referencing the actual DP_Map objects
static func get_selection(map : DP_Map, subgizmo_id : int) -> Dictionary:
	var selection_type = get_selection_type(subgizmo_id);
	var solid_id = subgizmo_id & SELBIT_MASK_SOLID;
	var face_id = (subgizmo_id >> SELBIT_SHIFT_FACE) & SELBIT_MASK_FACE;
	var edge_id = (subgizmo_id >> SELBIT_SHIFT_EDGE) & SELBIT_MASK_EDGE;
	var vertex_id = (subgizmo_id >> SELBIT_SHIFT_VERTEX) & SELBIT_MASK_VERTEX;
	
	if selection_type == SelectionType.SOLID:
		return {
			"solid": map.solids[solid_id],
			"face": null,
			};
	elif selection_type == SelectionType.FACE:
		return {
			"solid": map.solids[solid_id], 
			"face": map.solids[solid_id].faces[face_id],
			};
	return {
		"solid": null,
		"face": null,
		};
	
