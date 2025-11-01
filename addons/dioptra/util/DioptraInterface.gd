extends RefCounted
class_name DioptraInterface

#------------------------------------------------------------------------------#

static var _Instance : DioptraInterface = null;

static func _get_instance() -> DioptraInterface:
	assert(_Instance != null);
	return _Instance;

#------------------------------------------------------------------------------#

var _scale_dpunits_per : int = 128;
var _scale_per_gdunits : int = 1;

## Returns the integer numerator of how many units are in one Godot unit. 
## If you have a MapVector3, divide by this value to get Godot meters.
static func get_position_scale_top() -> int:
	return _get_instance()._scale_dpunits_per;
	
## Returns the integer divisor of how many units are in one Godot unit. 
## If you have a MapVector3, multiply by this value to get Godot meters.
static func get_position_scale_div() -> int:
	return _get_instance()._scale_per_gdunits;

#------------------------------------------------------------------------------#
