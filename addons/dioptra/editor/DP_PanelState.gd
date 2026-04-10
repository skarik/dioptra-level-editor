@tool
extends Control

var _plugin : DioptraEditorMainPlugin = null;

func _ready() -> void:
	pass
	
func setPlugin(plugin : DioptraEditorMainPlugin) -> void:
	_plugin = plugin;

func onSelectionTypePressed(selectionType : int) -> void:
	_plugin._selectionMode =  selectionType as DioptraEditorMainPlugin.SelectMode;
	print("Selection Mode: %s" % _plugin.SelectMode.find_key(_plugin._selectionMode));
	
	for child in $Box/Selection.get_children():
		var child_button := child as Button;
		if child_button != null:
			child_button.button_pressed = false;
			
	var child_main = $Box/Selection.get_children()[selectionType];
	var child_main_button = child_main as Button;
	if child_main_button != null:
		child_main_button.button_pressed = true;
			
	pass

#func _input(event: InputEvent) -> void:
	#if DioptraInterface._get_instance().shortcut_select_solids.matches_event(event) && event.is_pressed() and not event.is_echo():
		#onSelectionTypePressed(DioptraEditorMainPlugin.SelectMode.SOLID);
	#if DioptraInterface._get_instance().shortcut_select_faces.matches_event(event) && event.is_pressed() and not event.is_echo():
		#onSelectionTypePressed(DioptraEditorMainPlugin.SelectMode.FACE);
