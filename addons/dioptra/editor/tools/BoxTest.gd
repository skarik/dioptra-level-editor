extends DPUTool
class_name DPUTool_BoxTest

enum {
	TOOLSTATE_WAITING = 0,
	TOOLSTATE_DRAGGING_PLANE = 1,
	TOOLSTATE_WAITING_WITH_PLANE = 2,
	TOOLSTATE_LIFTING_NORMAL = 3,
	TOOLSTATE_WAITING_WITH_CUBE = 4
}
var _state : int = TOOLSTATE_WAITING;
var _normal_axis : int = 0;
var _box_start := MapVector3.new();
var _box_end := MapVector3.new();
var _drag_start : Vector3;

var _ghost_box : DPUBoxGhost = null;

func _init(plugin : DioptraEditorMainPlugin) -> void:
	super(plugin);
	_ghost_box = DPUBoxGhost.new();
	
## Overridable cleanup
func cleanup() -> void:
	if _ghost_box != null:
		_ghost_box.cleanup()
	
## Overrideable GUI input handling
func forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	#if _plugin and _plugin.DPGizmoPlugin_ToolCube:
	#	_plugin.DPGizmoPlugin_ToolCube.enabled = true;
	
	var grid_round : float = 8;
	
	if _state == TOOLSTATE_WAITING:
		# Waiting for an initial drag, so we wait for a click:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Get the normal:
			_normal_axis = 1; # Lock to Y axis now
			# Get the hit position to start the box:
			var drag_from : Vector3 = viewport_camera.project_ray_origin(event.position);
			var drag_dir : Vector3 = viewport_camera.project_ray_normal(event.position);
			
			var world_hit_point := Vector3.ZERO; # TODO
			
			# Cast on the working plane:
			const AxesLookup := [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)];
			var drag_plane : Plane = Plane(AxesLookup[_normal_axis], world_hit_point);
			var drag_position_result : Variant = drag_plane.intersects_ray(drag_from, drag_dir);
			if drag_position_result != null:
				var drag_position = drag_position_result as Vector3;
				_drag_start = drag_position;
				_box_start.v3 = (drag_position * grid_round).round() / grid_round;
				
				_ghost_box.box_start = _box_start.v3;
				_ghost_box.box_end = _box_start.v3;
				_ghost_box.update(viewport_camera);
				
			_state = TOOLSTATE_DRAGGING_PLANE;
			pass
		# Otherwise, let other events through
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS;
		pass
	elif _state == TOOLSTATE_DRAGGING_PLANE:
		# When the mouse moves, update
		if event is InputEventMouseMotion:
			# Get the hit position on current plane to start the box:
			var drag_from : Vector3 = viewport_camera.project_ray_origin(event.position);
			var drag_dir : Vector3 = viewport_camera.project_ray_normal(event.position);
			
			# Cast on the working plane:
			const AxesLookup := [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)];
			var drag_plane : Plane = Plane(AxesLookup[_normal_axis], _drag_start);
			var drag_position_result : Variant = drag_plane.intersects_ray(drag_from, drag_dir);
			if drag_position_result != null:
				var drag_position = drag_position_result as Vector3;
				_box_end.v3 = (drag_position * grid_round).round() / grid_round;
				
				_ghost_box.box_start = _box_start.v3;
				_ghost_box.box_end = _box_end.v3;
				_ghost_box.update(viewport_camera);
			pass
			
		# When the mouse click releases, stop dragging
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_state = TOOLSTATE_WAITING_WITH_PLANE;
			
		pass
	elif _state == TOOLSTATE_WAITING_WITH_PLANE:
		# Waiting for a second drag, so wait for another click
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Get the hit position on current plane to start the box:
			var drag_from : Vector3 = viewport_camera.project_ray_origin(event.position);
			var drag_dir : Vector3 = viewport_camera.project_ray_normal(event.position);
			
			# Cast on the working plane:
			const AxesLookup := [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)];
			var drag_plane : Plane = Plane(AxesLookup[_normal_axis], (_box_start.v3 + _box_end.v3) * 0.5);
			var drag_position_result : Variant = drag_plane.intersects_ray(drag_from, drag_dir);
			if drag_position_result != null:
				var drag_position = drag_position_result as Vector3;
				_drag_start = drag_position;
				_state = TOOLSTATE_LIFTING_NORMAL;
			pass
		# Otherwise, let other events through
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS;
	elif _state == TOOLSTATE_LIFTING_NORMAL:
		# When the mouse moves, update
		if event is InputEventMouseMotion:
			# Get the hit position on current plane to start the box:
			var drag_from : Vector3 = viewport_camera.project_ray_origin(event.position);
			var drag_dir : Vector3 = viewport_camera.project_ray_normal(event.position);
			
			# Cast on the working plane:
			const AxesLookup := [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)];
			var drag_plane : Plane = Plane(AxesLookup[_normal_axis].cross(viewport_camera.basis.x).normalized(), _drag_start);
			var drag_position_result : Variant = drag_plane.intersects_ray(drag_from, drag_dir);
			if drag_position_result != null:
				var drag_position = drag_position_result as Vector3;
				
				var current_box_end = _box_end.v3;
				current_box_end[_normal_axis] = round(drag_position[_normal_axis] * grid_round) / grid_round;
				_box_end.v3 = current_box_end;
				
				_ghost_box.box_start = _box_start.v3;
				_ghost_box.box_end = _box_end.v3;
				_ghost_box.update(viewport_camera);
			pass
		
		# When the mouse click releases, stop dragging
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_state = TOOLSTATE_WAITING_WITH_CUBE;
		
		pass
	elif _state == TOOLSTATE_WAITING_WITH_CUBE:
		# Waiting for the user to commit the box or edit the box
		
		# Otherwise, let other events through
		return EditorPlugin.AFTER_GUI_INPUT_PASS;
		pass
	
	return EditorPlugin.AFTER_GUI_INPUT_STOP;

## Overridable frame-update 
func process(delta: float) -> void:
	pass
	
	
	
