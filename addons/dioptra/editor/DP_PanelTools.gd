@tool
extends Control

var _plugin : DioptraEditorMainPlugin = null;

func _ready() -> void:
	pass
	
func setPlugin(plugin : DioptraEditorMainPlugin) -> void:
	_plugin = plugin;
	
func onSelect_Select() -> void:
	return onToolSelect(DioptraEditorMainPlugin.ToolMode.SELECT, $Selection);
func onSelect_BoxTest() -> void:
	return onToolSelect(DioptraEditorMainPlugin.ToolMode.BOX_TEST, $Box);
func onSelect_Decal() -> void:
	return onToolSelect(DioptraEditorMainPlugin.ToolMode.DECAL, $Decal);
	
func onToolSelect(tool : DioptraEditorMainPlugin.ToolMode, button : Button) -> void:
	# Untoggle all the tools
	for child in get_children():
		var child_button := child as Button;
		if child_button != null:
			child_button.button_pressed = false;
			
	# Toggle on the actual hit button
	if button != null:
		button.button_pressed = true;
	
	# Forward it
	_plugin.onToolSelect(tool);
	# TODO: toggle the rest of the tools off
	pass
