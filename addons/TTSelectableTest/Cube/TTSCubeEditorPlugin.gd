@tool
extends EditorPlugin
class_name TTSCubeEditorPlugin

var _tool_state : int = 0;
var _tool_start : Vector3;
var _tool_end : Vector3;
var _tool_target : TTSCube = null;
var _tool_update_start : bool = false;


func _handles(object: Object) -> bool:
	if object is TTSCube:
		return true;
	return false;

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if _tool_state <= 5:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_tool_state += 1;
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				_tool_state += 1;
			if _tool_state == 1:
				_tool_start = Vector3(0, 0, 0);
				_tool_end = _tool_start;
				_tool_update_start = true;
			_tool_target.update_gizmos();
			
		if event is InputEventMouseMotion:
			if (_tool_state % 2) == 1:
				const AxesLookup := [0, 2, 1];
				var axes_index : int = AxesLookup[_tool_state / 2];
				const AxesUpLookup := [Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(1, 0, 0)];
				var axes_up : Vector3 = AxesUpLookup[_tool_state / 2]; # TODO: y is going to align with camera
				
				# Mouse position projection:
				var drag_from : Vector3 = viewport_camera.project_ray_origin(event.position);
				var drag_dir : Vector3 = viewport_camera.project_ray_normal(event.position);
				var drag_plane : Plane = Plane(axes_up, _tool_target.global_position);
				var drag_position_result : Variant = drag_plane.intersects_ray(drag_from, drag_dir);
				if drag_position_result != null:
					var drag_position = drag_position_result as Vector3;
					_tool_end[axes_index] = drag_position[axes_index];
					if _tool_update_start:
						_tool_start = drag_position;
						_tool_update_start = false;
					_tool_target.update_gizmos();
				pass
				
		if (_tool_state % 2) == 1:
			_tool_target.size = (_tool_start - _tool_end).abs();
			_tool_target.global_position = (_tool_start + _tool_end) * 0.5;
		
		return EditorPlugin.AFTER_GUI_INPUT_STOP;
	else:
		return EditorPlugin.AFTER_GUI_INPUT_PASS;
	
func _apply_changes() -> void:
	pass
	
func _edit(object: Object) -> void:
	if object == null:
		_tool_state = 0;
		_tool_target = null;
	else:
		_tool_state = 0;
		_tool_target = object as TTSCube;
	pass
