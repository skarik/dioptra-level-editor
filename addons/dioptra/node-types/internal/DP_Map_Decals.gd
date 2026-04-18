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
@export_storage var near_clip : float = -1.0;
# Distance of the far end of the frustum, in DP units
@export_storage var far_clip : float = 1.0;
# Scale of the far end of the frustum in refernce to the main scale
@export_storage var far_scale : Vector2 = Vector2.ONE;
## Reference to a material index in the containing map
@export_storage var material : int = 0;
## Color offset for the base decal in OklabLCH offset (light, chroma, hue)
@export_storage var color_lch_offset : Vector3 = Vector3.ZERO;
## Project this decal also the backside or not
@export_storage var project_two_sided : bool = false;
## Project this decal onto co-linear faces that stretch it infinity or not
@export_storage var project_colinear : bool = false;

# Serialization interface
func _get_property_list() -> Array[Dictionary]:
	var properties : Array[Dictionary] = [];
	properties.append({ "name" : "position", "type" : TYPE_VECTOR3I });
	properties.append({ "name" : "rotation", "type" : TYPE_VECTOR3 });
	properties.append({ "name" : "scale", "type" : TYPE_VECTOR2 });
	properties.append({ "name" : "near_clip", "type" : TYPE_FLOAT });
	properties.append({ "name" : "far_clip", "type" : TYPE_FLOAT });
	properties.append({ "name" : "far_scale", "type" : TYPE_VECTOR2 });
	properties.append({ "name" : "material", "type" : TYPE_INT });
	properties.append({ "name" : "color_lch_offset", "type" : TYPE_VECTOR3 });
	properties.append({ "name" : "project_two_sided", "type" : TYPE_BOOL });
	properties.append({ "name" : "project_colinear", "type" : TYPE_BOOL });
	return properties;
func _set(property: StringName, value: Variant) -> bool:
	if property == "position": position.v3i = value; return true;
	elif property == "rotation": rotation = value; return true;
	elif property == "scale": scale = value; return true;
	elif property == "near_clip": near_clip = value; return true;
	elif property == "far_clip": far_clip = value; return true;
	elif property == "far_scale": far_scale = value; return true;
	elif property == "material": material = value; return true;
	elif property == "color_lch_offset": color_lch_offset = value; return true;
	elif property == "project_two_sided": project_two_sided = value; return true;
	elif property == "project_colinear": project_colinear = value; return true;
	return false;
func _get(property: StringName) -> Variant:
	if property == "position": return position.v3i;
	elif property == "rotation": return rotation;
	elif property == "scale": return scale;
	elif property == "near_clip": return near_clip;
	elif property == "far_clip": return far_clip;
	elif property == "far_scale": return far_scale;
	elif property == "material": return material;
	elif property == "color_lch_offset": return color_lch_offset;
	elif property == "project_two_sided": return project_two_sided;
	elif property == "project_colinear": return project_colinear;
	return null;


# TODO: move to map. this needs material info to work.
#func get_plane(plane : Projection.Planes) -> Plane:
	#var quat : Quaternion = Quaternion.from_euler(rotation);
	#
	#var up : Vector3 = Vector3.UP * quat;
	#var forward : Vector3 = Vector3.FORWARD * quat;
	#var left : Vector3 = Vector3.LEFT * quat;
	#
	#var from_dp_to_world : float = DioptraInterface.get_position_scale_div() / float(DioptraInterface.get_position_scale_top());
	#
	#if plane == Projection.Planes.PLANE_NEAR:
		#return Plane(forward, position.v3 + forward * near_clip * from_dp_to_world);
	#elif plane == Projection.Planes.PLANE_FAR:
		#return Plane(-forward, position.v3 + forward * far_clip * from_dp_to_world);
		#
	#return Plane();
