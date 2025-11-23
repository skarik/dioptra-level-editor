extends RefCounted
class_name DioptraInterface

#------------------------------------------------------------------------------#

static var _Instance : DioptraInterface = null;

static func _get_instance() -> DioptraInterface:
	assert(_Instance != null);
	return _Instance;

static func init_instance() -> void:
	_Instance = DioptraInterface.new();
	
static func free_instance() -> void:
	_Instance = null; # Refcounted, so should clear up

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

## TODO	
#static func get_settings() -> 

const FutureSettingTrue : bool = true;

#------------------------------------------------------------------------------#

var _grid_round : float = 8;

## Rounds the given Vector3 to the current editor grid settings.
static func get_grid_round_v3(vector : Vector3) -> Vector3:
	var inst := _get_instance();
	return (vector * inst._grid_round).round() / inst._grid_round;

#------------------------------------------------------------------------------#
