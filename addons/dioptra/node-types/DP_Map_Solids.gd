@tool
extends RefCounted
class_name DPMapSolid

## UV Mode for controlling how the UV scale and offset work for a face
enum UVMode {
	WORLD = 0, ## Texturing using one of the world planes
	FACE = 1, ## Texturing using the plane of the face itself
	HOTSPOT = 2 ## Texturing using hotspot textures and face area matches
}

enum {
	UV_WORLD_FLAG_NONE = 0, ## No flags
	UV_WORLD_FLAG_X = 0x1, ## Use the world YZ planes to do UVs
	UV_WORLD_FLAG_Y = 0x2, ## Use the world XZ planes to do UVs (floor/ceiling)
	UV_WORLD_FLAG_Z = 0x4, ## Use the world XY planes to do UVs
	UV_WORLD_FLAG_AUTO = 0x8, ## Do we let the editor auto-update the flags?
}

class Face:
	## Corners (3+) of the face. Should be convex as triangles are built from this.
	@export_storage var corners : Array[int] = [0, 0, 0, 0];
	## Reference to a material index in the containing map
	@export_storage var material : int = 0;
	## UV mode, controlling how UV scale and offset work, as well as the basis for the texture.
	@export_storage var uv_mode : UVMode = UVMode.WORLD;
	## UV submode, for determining additional information
	@export_storage var uv_subflags : int = UV_WORLD_FLAG_AUTO;
	## UV scaling
	@export_storage var uv_scale : Vector2 = Vector2(1, 1);
	## UV offset
	@export_storage var uv_offset : Vector2 = Vector2(0, 0);
	## UV rotation
	@export_storage var uv_rotation : float = 0;

@export_storage
var points : Array[MapVector3];
@export_storage
var faces : Array[Face];
