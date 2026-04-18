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
		_ghost_box = null;
	
## Overrideable GUI input handling
func forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	#if _plugin and _plugin.DPGizmoPlugin_ToolCube:
	#	_plugin.DPGizmoPlugin_ToolCube.enabled = true;
	
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
				_box_start.v3 = DioptraInterface.get_grid_round_v3(drag_position);
				
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
				_box_end.v3 = DioptraInterface.get_grid_round_v3(drag_position);
				
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
				var drag_position := drag_position_result as Vector3;
				
				var current_box_end := _box_end.v3;
				current_box_end[_normal_axis] = DioptraInterface.get_grid_round_v3(drag_position)[_normal_axis];
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
		# Update ghost for the camera when we're working here:
		_ghost_box.update(viewport_camera);
		
		# Waiting for the user to commit the box or edit the box
		if event is InputEventKey and event.keycode == KEY_ENTER:			
			# Create a cube in the current map with the ghost:
			_add_box();
		
			# Clean up the state of the tool
			_ghost_box.cleanup();
			_state = TOOLSTATE_WAITING; # Reset
		
		# Otherwise, let other events through
		return EditorPlugin.AFTER_GUI_INPUT_PASS;
		pass
	
	return EditorPlugin.AFTER_GUI_INPUT_STOP;

func process(delta: float) -> void:
	pass
	
#------------------------------------------------------------------------------#
	
# Adds a box to the current map. Builds the solid and then passes it to the manager above
func _add_box() -> void:
	# Using _box_end and _box_start
	var solid := DPMapSolid.new();
	
	var box_min : Vector3i = _box_start.v3i.min(_box_end.v3i);
	var box_max : Vector3i = _box_start.v3i.max(_box_end.v3i);
	
	# Add the 8 points of a cube (clockwise geometry):
	solid.points.resize(8);
	solid.points[0] = MapVector3.new(Vector3i(box_min.x, box_min.y, box_min.z));
	solid.points[1] = MapVector3.new(Vector3i(box_max.x, box_min.y, box_min.z));
	solid.points[2] = MapVector3.new(Vector3i(box_max.x, box_max.y, box_min.z));
	solid.points[3] = MapVector3.new(Vector3i(box_min.x, box_max.y, box_min.z));
	solid.points[4] = MapVector3.new(Vector3i(box_min.x, box_min.y, box_max.z));
	solid.points[5] = MapVector3.new(Vector3i(box_max.x, box_min.y, box_max.z));
	solid.points[6] = MapVector3.new(Vector3i(box_max.x, box_max.y, box_max.z));
	solid.points[7] = MapVector3.new(Vector3i(box_min.x, box_max.y, box_max.z));
	
	# Now build the 6 faces
	solid.faces.resize(6);
	solid.faces[0] = DPMapFace.new();
	solid.faces[0].corners = [0, 1, 2, 3];
	solid.faces[1] = DPMapFace.new();
	solid.faces[1].corners = [4, 7, 6, 5];
	solid.faces[2] = DPMapFace.new();
	solid.faces[2].corners = [0, 4, 5, 1];
	solid.faces[3] = DPMapFace.new();
	solid.faces[3].corners = [2, 6, 7, 3];
	solid.faces[4] = DPMapFace.new();
	solid.faces[4].corners = [0, 3, 7, 4];
	solid.faces[5] = DPMapFace.new();
	solid.faces[5].corners = [1, 5, 6, 2];
	
	# Set up face materials of the solid (done here due to copy-paste)
	var material_index = _plugin.get_last_edited_map().get_or_add_material(_plugin._last_material);
	for face in solid.faces:
		face.material = material_index;
	
	# Find the correct map
	_plugin.add_new_solid(solid);
	
	pass
	
