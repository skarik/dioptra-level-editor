@tool
extends RefCounted
class_name DPUTool
## Base class type for tools that do something.

#------------------------------------------------------------------------------#

var _plugin : DioptraEditorMainPlugin = null;

#------------------------------------------------------------------------------#

## Constructor that must be called
func _init(plugin : DioptraEditorMainPlugin) -> void:
	_plugin = plugin;
	
## Overridable cleanup
func cleanup() -> void:
	pass

## Overrideable GUI input handling
func forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	return EditorPlugin.AFTER_GUI_INPUT_STOP;

## Overridable frame-update 
func process(delta: float) -> void:
	pass

#------------------------------------------------------------------------------#
