@tool
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

var shortcut_select_solids : Shortcut = null;
var shortcut_select_faces : Shortcut = null;

func _init():
	print("DioptraInterface started");
	
	if true:
		var key_event := InputEventKey.new();
		key_event.keycode = KEY_1;
		shortcut_select_solids = Shortcut.new();
		shortcut_select_solids.events = [key_event];
	if true:
		var key_event := InputEventKey.new();
		key_event.keycode = KEY_2;
		shortcut_select_faces = Shortcut.new();
		shortcut_select_faces.events = [key_event];
		
	# Load Settings now that items initialized
	init_settings();
	pass

#------------------------------------------------------------------------------#

var _scale_dpunits_per : int = 128;
var _scale_per_gdunits : int = 1;
var _tscale_pixels_per : int = 32;
var _tscale_per_gdunits : int = 1;

## Returns the integer numerator of how many units are in one Godot unit. 
## If you have a MapVector3, divide by this value to get Godot meters.
static func get_position_scale_top() -> int:
	return _get_instance()._scale_dpunits_per;
	
## Returns the integer divisor of how many units are in one Godot unit. 
## If you have a MapVector3, multiply by this value to get Godot meters.
static func get_position_scale_div() -> int:
	return _get_instance()._scale_per_gdunits;
	
## Returns the integer numerator of how many pixels are in one Godot unit.
static func get_pixel_scale_top() -> int:
	return _get_instance()._tscale_pixels_per;

## Returns the integer divisor of how many pixels are in one Godot unit.
static func get_pixel_scale_div() -> int:
	return _get_instance()._tscale_per_gdunits;

## TODO	
#static func get_settings() -> 

const FutureSettingTrue : bool = true;
const FutureSettingFalse : bool = false;

## Load Project Settings
## todo: also call this when settings change
func init_settings() -> void:
	# Project Settings
	if ProjectSettings.has_setting("dioptra/grid/world_dp_units_per"):
		_scale_dpunits_per = (int)(ProjectSettings.get_setting("dioptra/grid/world_dp_units_per", 128));
	if ProjectSettings.has_setting("dioptra/grid/world_per_gd_units"):
		_scale_per_gdunits = (int)(ProjectSettings.get_setting("dioptra/grid/world_per_gd_units", 1));
	if ProjectSettings.has_setting("dioptra/grid/tex_pixels_per"):
		_tscale_pixels_per = (int)(ProjectSettings.get_setting("dioptra/grid/tex_pixels_per", 32));
	if ProjectSettings.has_setting("dioptra/grid/tex_per_gd_units"):
		_tscale_per_gdunits = (int)(ProjectSettings.get_setting("dioptra/grid/tex_per_gd_units", 1));
	
	# Editor Settings
	if Engine.is_editor_hint():
		var editor_settings := EditorInterface.get_editor_settings();
		if editor_settings:
			# Set up shortcuts
			if editor_settings.has_method("has_shortcut"):
				# Hotkey info
				if !editor_settings.has_shortcut("dioptra/select_solids"):
					editor_settings.add_shortcut("dioptra/select_solids", shortcut_select_solids);
				shortcut_select_solids = editor_settings.get_shortcut("dioptra/select_solids");
				if !editor_settings.has_shortcut("dioptra/select_faces"):
					editor_settings.add_shortcut("dioptra/select_faces", shortcut_select_faces);
				shortcut_select_faces = editor_settings.get_shortcut("dioptra/select_faces");
			pass # End editor settings
		pass # End editor-only info
		
	pass # end init_settings()

#------------------------------------------------------------------------------#

var _grid_round : float = 8;

## Rounds the given Vector3 to the current editor grid settings.
static func get_grid_round_v3(vector : Vector3) -> Vector3:
	var inst := _get_instance();
	return (vector * inst._grid_round).round() / inst._grid_round;

#------------------------------------------------------------------------------#
