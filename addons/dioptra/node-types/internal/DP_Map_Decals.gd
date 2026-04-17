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

# TODO: move to map. this needs material info to work.
func get_plane(plane : Projection.Planes) -> Plane:
	var quat : Quaternion = Quaternion.from_euler(rotation);
	
	var up : Vector3 = Vector3.UP * quat;
	var forward : Vector3 = Vector3.FORWARD * quat;
	var left : Vector3 = Vector3.LEFT * quat;
	
	var from_dp_to_world : float = DioptraInterface.get_position_scale_div() / float(DioptraInterface.get_position_scale_top());
	
	if plane == Projection.Planes.PLANE_NEAR:
		return Plane(forward, position.v3 + forward * near_clip * from_dp_to_world);
	elif plane == Projection.Planes.PLANE_FAR:
		return Plane(-forward, position.v3 + forward * far_clip * from_dp_to_world);
		
	return Plane();
