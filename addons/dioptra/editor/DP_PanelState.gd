@tool
extends Control

var _plugin : DioptraEditorMainPlugin = null;

var _last_grid_value : int = 0;

#------------------------------------------------------------------------------#

## Get the closest exponent of 2
func get_closest_exp_of_2(value : int) -> int:
	var closest_pow : int = roundf(log(value) / log(2));
	return closest_pow;
## Get the closest power of 2
func get_closest_pow_of_2(value : int) -> int:
	var closest_pow : int = roundf(log(value) / log(2));
	value = 1 << closest_pow;
	return value;

#------------------------------------------------------------------------------#

func _ready() -> void:
	pass
	
func setPlugin(plugin : DioptraEditorMainPlugin) -> void:
	_plugin = plugin;
	
	$Box/Editor/SnapSize.set_value_no_signal(float(DioptraInterface._get_instance()._grid_size));
	_last_grid_value = int($Box/Editor/SnapSize.value);

func onSelectionTypePressed(selectionType : int) -> void:
	_plugin._selectionMode =  selectionType as DioptraEditorMainPlugin.SelectMode;
	print("Selection Mode: %s" % _plugin.SelectMode.find_key(_plugin._selectionMode));
	
	var child_main = $Box/Selection.get_children()[selectionType];
	var child_main_button = child_main as Button;
	if child_main_button != null:
		child_main_button.button_pressed = true;
			
	pass

func on_grid_value_changed(gridValue : float) -> void:
	if gridValue < _last_grid_value:
		var closest_power := get_closest_exp_of_2(_last_grid_value);
		_last_grid_value = 1 << max(0, closest_power - 1);
	else:
		var max_power := get_closest_exp_of_2($Box/Editor/SnapSize.max_value);
		var closest_power := get_closest_exp_of_2(_last_grid_value);
		_last_grid_value = 1 << min(max_power, closest_power + 1);
	$Box/Editor/SnapSize.set_value_no_signal(float(_last_grid_value));
	
	DioptraInterface.set_grid_size(_last_grid_value);

func on_grid_vis_toggled(enabled : bool) -> void:
	DioptraInterface.set_grid_visible(enabled);	
