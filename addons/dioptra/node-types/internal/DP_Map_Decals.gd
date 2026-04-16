@tool
extends RefCounted
class_name DPMapDecal

# Projection position of the decal
@export_storage var position : MapVector3 = MapVector3.new(Vector3i.ZERO);
# Rotation position of the decal
@export_storage var rotation : Vector3 = Vector3.ZERO;
# Scale of the decal before projection
@export_storage var scale : Vector2 = Vector2.ONE;
# Distance of the start frustum, in DP units
@export_storage var near_clip : float = 0.0;
# Distance of the far end of the frustum, in DP units
@export_storage var far_clip : float = 2.0;
# Scale of the far end of the frustum in refernce to the main scale
@export_storage var far_scale : Vector2 = Vector2.ONE;
## Reference to a material index in the containing map
@export_storage var material : int = 0;
## Color offset for the base decal in OklabLCH offset (light, chroma, hue)
@export_storage var color_lch_offset : Vector3 = Vector3.ZERO;
