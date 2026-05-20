@tool
extends RefCounted
class_name DioptraInterface

#------------------------------------------------------------------------------#

static var _Instance : DioptraInterface = null;

static func _get_instance() -> DioptraInterface:
	assert(_Instance != null);
	return _Instance;

static func _has_instance() -> bool:
	return is_instance_valid(_Instance);
	
static func init_if_not() -> void:
	if not _has_instance():
		init_instance();

static func init_instance() -> void:
	_Instance = DioptraInterface.new();
	
static func free_instance() -> void:
	_Instance = null; # Refcounted, so should clear up
	
static func get_instance() -> DioptraInterface:
	return _get_instance(); #for connecting signals :/

#------------------------------------------------------------------------------#

var shortcut_select_solids : Shortcut = null;
var shortcut_select_faces : Shortcut = null;
var shortcut_select_edges : Shortcut = null;
var shortcut_select_verts : Shortcut = null;

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
	if true:
		var key_event := InputEventKey.new();
		key_event.keycode = KEY_3;
		shortcut_select_edges = Shortcut.new();
		shortcut_select_edges.events = [key_event];
	if true:
		var key_event := InputEventKey.new();
		key_event.keycode = KEY_4;
		shortcut_select_verts = Shortcut.new();
		shortcut_select_verts.events = [key_event];
		
	# Load Settings now that items initialized
	init_settings();
	
	# Connect signals
	ProjectSettings.settings_changed.connect(_on_settings_changed);
	pass

func _on_settings_changed() -> void:
	init_settings();

#------------------------------------------------------------------------------#

var _scale_dpunits_per : int = 128;
var _scale_per_gdunits : int = 1;
var _tscale_pixels_per : int = 32;
var _tscale_per_gdunits : int = 1;

## Returns the integer numerator of how many units are in one Godot unit. 
## If you have a MapVector3, divide by this value to get Godot meters.
static func get_position_scale_top() -> int:
	if not _has_instance(): return 128;
	return _get_instance()._scale_dpunits_per;
	
## Returns the integer divisor of how many units are in one Godot unit. 
## If you have a MapVector3, multiply by this value to get Godot meters.
static func get_position_scale_div() -> int:
	if not _has_instance(): return 1;
	return _get_instance()._scale_per_gdunits;
	
## Returns the integer numerator of how many pixels are in one Godot unit.
static func get_pixel_scale_top() -> int:
	if not _has_instance(): return 32;
	return _get_instance()._tscale_pixels_per;

## Returns the integer divisor of how many pixels are in one Godot unit.
static func get_pixel_scale_div() -> int:
	if not _has_instance(): return 1;
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
				
				if !editor_settings.has_shortcut("dioptra/select_edges"):
					editor_settings.add_shortcut("dioptra/select_edges", shortcut_select_edges);
				shortcut_select_edges = editor_settings.get_shortcut("dioptra/select_edges");
				
				if !editor_settings.has_shortcut("dioptra/select_verts"):
					editor_settings.add_shortcut("dioptra/select_verts", shortcut_select_verts);
				shortcut_select_verts = editor_settings.get_shortcut("dioptra/select_verts");
			pass # End editor settings
		pass # End editor-only info
		
		# Load last grid (or just update ui with latest)
		#EditorInterface.get_edited_scene_root().get_tree().process_frame.connect(func(): DioptraInterface.set_grid_size(16), CONNECT_ONE_SHOT);
		# Can't, have to do this another way
		
	pass # end init_settings()

#------------------------------------------------------------------------------#

# Signal for editor 3D mouse moving
signal cursor3d_moved(position : Vector3);

#------------------------------------------------------------------------------#

# Current size of the grid in DP units
var _grid_size : int = 16;
# Degrees per div
var _angle_round : float = 15;
# Is the grid visible
var _grid_visible : bool = true;

# TODO: move these signals to a separate object these are not used outside of editor
# Signal for grid size changing
signal grid_size_changed(grid_size : int);
# Signal for grid enable/disable
signal grid_visual_enabled(enabled : bool);

## Sets the current grid size
static func set_grid_size(grid_size : int) -> void:
	var inst := _get_instance();
	inst._grid_size = max(0, grid_size);
	#inst.grid_size_changed.emit(inst._grid_size);
	EditorInterface.get_edited_scene_root().get_tree().process_frame.connect(func(): inst.grid_size_changed.emit(inst._grid_size), CONNECT_ONE_SHOT);
static func get_grid_size() -> int:
	var inst := _get_instance();
	return inst._grid_size;

static func set_grid_visible(visible : bool, change_setting : bool = true) -> void:
	var inst := _get_instance();
	if change_setting:
		inst._grid_visible = visible;
	#inst.grid_visual_enabled.emit(visible); # TODO only emit when value changes
	EditorInterface.get_edited_scene_root().get_tree().process_frame.connect(func(): inst.grid_visual_enabled.emit(visible), CONNECT_ONE_SHOT);
static func get_grid_visible() -> bool:
	var inst := _get_instance();
	return inst._grid_visible;

## Rounds the given Vector3 to the current editor grid settings.
static func get_grid_round_v3(vector : Vector3) -> Vector3:
	var inst := _get_instance();
	if inst._grid_size == 0:
		return vector;
	else:
		# Get DP vector:
		var v3i := Vector3(vector * get_position_scale_top() / get_position_scale_div());
		# Round DP vector:
		v3i = (v3i / inst._grid_size).round() * inst._grid_size;
		# Convert back to Godot units
		return Vector3(v3i) * get_position_scale_div() / get_position_scale_top();

## Rounds the given float to the current editor grid settings.
static func get_grid_round_v1(value : float) -> float:
	var inst := _get_instance();
	if inst._grid_size == 0:
		return value;
	else:
		# Get DP vector:
		var vi := float(value * get_position_scale_top() / get_position_scale_div());
		# Round DP vector:
		vi = roundf(vi / inst._grid_size) * inst._grid_size;
		# Convert back to Godot units
		return float(vi) * get_position_scale_div() / get_position_scale_top();

## Rounds the given angle to the current editor angle settings.
static func get_angle_round(angle : float) -> float:
	var inst := _get_instance();
	return roundf(angle / inst._angle_round) * inst._angle_round;

## Returns the current DP grid size in Godot units
static func get_grid_div_godot() -> float:
	var inst := _get_instance();
	return float(inst._grid_size) * get_position_scale_div() / get_position_scale_top();

#------------------------------------------------------------------------------#
