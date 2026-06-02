extends DPUTool
class_name DPUTool_Box

enum {
	TOOLSTATE_WAITING = 0,
	TOOLSTATE_DRAGGING_PLANE = 1,
	TOOLSTATE_WAITING_WITH_PLANE = 2,
	TOOLSTATE_LIFTING_NORMAL = 3,
	TOOLSTATE_WAITING_WITH_CUBE = 4,
	TOOLSTATE_LIFTING_FACE = 5,
}
var _state : int = TOOLSTATE_WAITING;
var _normal_axis : int = 0;
var _box_start := MapVector3.new();
var _box_end := MapVector3.new();
var _drag_start : Vector3;
var _drag_flip : bool = false;

var _ghost_box : DPUBoxGhost = null;
var _cursor : DPUCursorGhost = null;

func _init(plugin : DioptraEditorMainPlugin) -> void:
	super(plugin);
	_ghost_box = DPUBoxGhost.new();
	_cursor = DPUCursorGhost.new();
	
## Overridable cleanup
func cleanup() -> void:
	if _ghost_box != null:
		_ghost_box.cleanup()
		_ghost_box = null;
	if _cursor != null:
		_cursor.cleanup();
		_cursor = null;
	
## Overrideable GUI input handling
func forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	# TODO: minimize the _plugin._get_editor_plugin().update_overlays();
	
	# If they hit cancel & want to remove the box, then yeah stop it
	if event is InputEventKey and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE):
		 # Clean up the state of the tool
		_ghost_box.cleanup();
		_state = TOOLSTATE_WAITING; # Reset
		
		# Capture the input
		return EditorPlugin.AFTER_GUI_INPUT_STOP;
	
	if _state == TOOLSTATE_WAITING:
		# Update ghost:
		var cursor_position := DioptraInterface.get_grid_round_v3(_plugin._last_3d_mouse_position);
		_cursor.position = cursor_position;
		_cursor.normal = _plugin._last_3d_mouse_normal;
		_cursor.radius = DioptraInterface.get_grid_div_godot();
		_cursor.update(EditorInterface.get_editor_viewport_3d(0).get_camera_3d());
		
		# Update tooltip
		overlay_text = "Click and drag to start building a solid.";
		_plugin.update_overlays();
		
		# Waiting for an initial drag, so we wait for a click:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Get the normal:
			if _plugin._last_3d_mouse_hit:
				var abs_normal = _plugin._last_3d_mouse_normal.abs();
				_normal_axis = abs_normal.max_axis_index();
			else:
				_normal_axis = Vector3.AXIS_Y; # Lock to Y axis now
			# Get the hit position to start the box:
			var drag_from : Vector3 = viewport_camera.project_ray_origin(event.position);
			var drag_dir : Vector3 = viewport_camera.project_ray_normal(event.position);
			
			# Get a basis for the plane we're gonna work on
			var world_hit_point := Vector3.ZERO;
			if _plugin._last_3d_mouse_hit:
				world_hit_point = _plugin._last_3d_mouse_position;
			
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
				_ghost_box.show_face_highlight = true;
				_ghost_box.highlighted_face = -1;
				_ghost_box.update(viewport_camera);
				
			_state = TOOLSTATE_DRAGGING_PLANE;
			return EditorPlugin.AFTER_GUI_INPUT_STOP;
			
		# Otherwise, let other events through
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS;
			
		pass
		
	elif _state == TOOLSTATE_DRAGGING_PLANE:
		# Update tooltip
		overlay_text = "Release mouse to finish shape.";
		_plugin.update_overlays();
		
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
			
			return EditorPlugin.AFTER_GUI_INPUT_STOP;
			
		# When the mouse click releases, stop dragging
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_state = TOOLSTATE_WAITING_WITH_PLANE;
			
		pass
		
	elif _state == TOOLSTATE_WAITING_WITH_PLANE:
		# Update tooltip
		overlay_text = "Click and drag to extra shape out.";
		_plugin.update_overlays();
		
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
			
			return EditorPlugin.AFTER_GUI_INPUT_STOP;
			
		# Otherwise, let other events through
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS;
			
	elif _state == TOOLSTATE_LIFTING_NORMAL:
		# Update tooltip
		overlay_text = "";
		_plugin.update_overlays();
		
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
		if event is InputEventMouseMotion:
			_drag_start = _highlight_ghost_box_face(viewport_camera, event);
		_ghost_box.update(viewport_camera);
		
		# Update tooltip
		overlay_text = "Press Enter to make new solid. Drag faces to resize.";
		_plugin.update_overlays();
		
		# Clicking:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _ghost_box.highlighted_face != -1:
				_normal_axis = _ghost_box.highlighted_face / 2;
				_drag_flip = (_ghost_box.highlighted_face % 2) == 1;
				
				# For this we box min < box max so
				var box_min : Vector3i = _box_start.v3i.min(_box_end.v3i);
				var box_max : Vector3i = _box_start.v3i.max(_box_end.v3i);
				_box_start.v3i = box_min;
				_box_end.v3i = box_max;
				
				_state = TOOLSTATE_LIFTING_FACE;
				return EditorPlugin.AFTER_GUI_INPUT_STOP;
		# Commit box:
		elif event is InputEventKey and event.keycode == KEY_ENTER:
			# Create a cube in the current map with the ghost:
			_add_box();
		
			# Clean up the state of the tool
			_ghost_box.cleanup();
			_state = TOOLSTATE_WAITING; # Reset
			
			# Capture the input
			return EditorPlugin.AFTER_GUI_INPUT_STOP;
		
		# Otherwise, let other events through
		return EditorPlugin.AFTER_GUI_INPUT_PASS;
		
	elif _state == TOOLSTATE_LIFTING_FACE:
		# Update tooltip
		overlay_text = "";
		_plugin.update_overlays();
		
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
				
				if not _drag_flip:
					var current_box_start := _box_start.v3;
					current_box_start[_normal_axis] = DioptraInterface.get_grid_round_v3(drag_position)[_normal_axis];
					_box_start.v3 = current_box_start;
				else:
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
	
	return EditorPlugin.AFTER_GUI_INPUT_STOP;

func process(delta: float) -> void:
	pass
	
#------------------------------------------------------------------------------#

## Highlights a box face on the ghost box based on planes of the box
func _highlight_ghost_box_face(viewport_camera : Camera3D, event : InputEventMouseMotion) -> Vector3:
	# Cast against the box with the mouse:
	_ghost_box.highlighted_face = -1;
	var box_min : Vector3 = _box_start.v3.min(_box_end.v3);
	var box_max : Vector3 = _box_start.v3.max(_box_end.v3);
	var box_planes : Array[Plane] = [
		Plane(Vector3(-1, 0, 0), box_min),	
		Plane(Vector3( 1, 0, 0), box_max),	
		Plane(Vector3( 0,-1, 0), box_min),	
		Plane(Vector3( 0, 1, 0), box_max),	
		Plane(Vector3( 0, 0,-1), box_min),	
		Plane(Vector3( 0, 0, 1), box_max),	
	];
	var drag_from : Vector3 = viewport_camera.project_ray_origin(event.position);
	var drag_dir : Vector3 = viewport_camera.project_ray_normal(event.position);
	for i in box_planes.size():
		if not box_planes[i].is_point_over(drag_from):
			continue;
		var hit_result = box_planes[i].intersects_ray(drag_from, drag_dir);
		if hit_result != null:
			var hit_position := hit_result as Vector3;
			var invalid_hit := false;
			# Check points is inside each plane
			for j in range(2, box_planes.size()):
				var j_idx := ((i - i % 2) + j) % box_planes.size();
				if box_planes[j_idx].is_point_over(hit_position):
					invalid_hit = true;
			# If it's valid we got our face
			if not invalid_hit:
				_ghost_box.highlighted_face = i;
				return hit_position;
	return Vector3.ZERO;
	
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
	var material_index = _plugin.get_or_add_last_edited_map().get_or_add_material(_plugin._last_material);
	for face in solid.faces:
		face.material = material_index;
	
	# Find the correct map
	_plugin.add_new_solid(solid);
	
	pass
	
