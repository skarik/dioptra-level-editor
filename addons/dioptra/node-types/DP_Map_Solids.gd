@tool
extends RefCounted
class_name DPMapSolid

@export_storage
var points : Array[MapVector3];
@export_storage
var faces : Array[DPMapFace];

# Serialization interface
func _get_property_list() -> Array[Dictionary]:
	var properties : Array[Dictionary] = [];
	properties.append({ "name" : "points", "type" : TYPE_ARRAY });
	properties.append({ "name" : "faces", "type" : TYPE_ARRAY });
	return properties;
func _set(property: StringName, value: Variant) -> bool:
	if property == "points": points = value; return true;
	elif property == "faces": faces = value; return true;
	return false;
func _get(property: StringName) -> Variant:
	if property == "points": return points;
	elif property == "faces": return faces;
	return null;
