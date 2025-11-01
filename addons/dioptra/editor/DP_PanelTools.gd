@tool
extends Control

var _plugin : DioptraEditorMainPlugin = null;

func _ready() -> void:
	pass
	
func setPlugin(plugin : DioptraEditorMainPlugin) -> void:
	_plugin = plugin;
	
func onSelect_Select() -> void:
	return onToolSelect(DioptraEditorMainPlugin.ToolMode.SELECT);
func onSelect_BoxTest() -> void:
	return onToolSelect(DioptraEditorMainPlugin.ToolMode.BOX_TEST);
	
func onToolSelect(tool : DioptraEditorMainPlugin.ToolMode) -> void:
	# Forward it
	_plugin.onToolSelect(tool);
	# TODO: toggle the rest of the tools off
	pass
