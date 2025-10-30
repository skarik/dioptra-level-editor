@tool
extends EditorPlugin
class_name TTSCubeEditorPlugin

func _handles(object: Object) -> bool:
	if object is TTSCube:
		return true;
	return false;

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	return EditorPlugin.AFTER_GUI_INPUT_STOP;
	
func _apply_changes() -> void:
	pass
	
func _edit(object: Object) -> void:
	pass
