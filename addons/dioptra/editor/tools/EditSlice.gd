extends DPUTool
class_name DPUTool_EditSlice

var _cursor : DPUCursorGhost = null;
var _decal_position := MapVector3.new();
var _decal_normal : Vector3 = Vector3.ZERO;

var _cut_lines : DPULines3D.LinesItem = null;

static var _slice_on_edge_not_axis : bool = true; ## Are we slicing on edge or axis
static var _slice_all_faces : bool = true; ## Are we slicing all faces

func _init(plugin : DioptraEditorMainPlugin) -> void:
	super(plugin);
	_cursor = DPUCursorGhost.new();
	
	_slice_all_faces = true;

func cleanup() -> void:
	if _cursor != null:
		_cursor.cleanup();
		_cursor = null;
	if _cut_lines:
		_cut_lines.release();
		_cut_lines = null;
	pass

## Overrideable GUI input handling
func forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	
	# Update tooltip
	overlay_text = ("Click on a solid to slice along the shown line into two separate solids."
		+ "\nMiddle click to toggle between edge slice & axis slice."
		+ "\nHold Shift to only slice single face.");
	
	var helper_plugin := _plugin._plugin_maphelper;
	var map := _plugin.get_last_edited_map();
	var map_gizmo := helper_plugin._get_target_gizmo(_plugin, map);
	
	_slice_all_faces = true;
	
	if event is InputEventMouseMotion:
		var subgizmo_id := DPEditorSelection.subgizmo_intersect_ray(map, viewport_camera, event.position, DioptraEditorMainPlugin.SelectMode.EDGE);
		var selection_type := DPHelpers.get_selection_type(map, subgizmo_id);
		var selection := DPHelpers.get_selection(map, subgizmo_id);
		
		if selection_type == DPHelpers.SelectionType.EDGE:
			var solid := selection.solid;
			var face := selection.face;
	
			var normal : Vector3 = -(solid.points[face.corners[1]].v3 - solid.points[face.corners[0]].v3).cross(
				solid.points[face.corners[2]].v3 - solid.points[face.corners[0]].v3).normalized();
				
			var collision_plane := Plane(normal, solid.points[face.corners[0]].v3);
			var collision := collision_plane.intersects_ray(viewport_camera.project_ray_origin(event.position), viewport_camera.project_ray_normal(event.position));
			if collision != null:
				var collision_point := collision as Vector3;
				
				_decal_position.v3 = collision_point;
				_decal_normal = normal;
				var collision_point_grid := DioptraInterface.get_grid_round_v3(collision_point);
				
				_update_cut_preview(selection, collision_point_grid);
			
				# Update ghost:
				_cursor.position = _decal_position.v3;
				_cursor.normal = _decal_normal;
				_cursor.update(EditorInterface.get_editor_viewport_3d(0).get_camera_3d());
				
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_slice_on_edge_not_axis = not _slice_on_edge_not_axis;
			return EditorPlugin.AFTER_GUI_INPUT_STOP;
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# Cut
			pass
			return EditorPlugin.AFTER_GUI_INPUT_STOP;
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS;

func process(delta: float) -> void:
	pass

func _update_cut_preview(selection : DPSelectionItem, hit_point : Vector3) -> void:
	var color_w : Color = EditorInterface.get_editor_theme().get_color("property_color_w", "Editor");
	
	# Need lines set up
	if _cut_lines == null:
		_cut_lines = DPULines3D.get_line();
		_cut_lines.width = 2.0;
		_cut_lines.segments = true;
		
	_cut_lines.points.clear();
	_cut_lines.colors.clear();
		
	# First, take the main face and build a plane:
	var cut_normal := (
		selection.solid.points[selection.face.corners[(selection.edge_id + 1) % selection.face.corners.size()]].v3 
		- selection.solid.points[selection.face.corners[selection.edge_id + 0]].v3
		).normalized();
	# If slicing on axis, find the main matching one.
	if not _slice_on_edge_not_axis:
		var max_axis := cut_normal.abs().max_axis_index();
		var new_normal := Vector3.ZERO;
		new_normal[max_axis] = cut_normal.sign()[max_axis];
		cut_normal = new_normal;
	# We now have the cut plane!
	var cut_plane := Plane(cut_normal, hit_point);
	
	# Loop through the faces:
	for face in selection.solid.faces:
		if _slice_all_faces == false:
			if face != selection.face:
				continue; 
		
		var solid := selection.solid;
		
		var corners : PackedVector3Array;
		corners.resize(face.corners.size());
		for corner_index in face.corners.size():
			corners[corner_index] = solid.points[face.corners[corner_index]].v3;
		
		# Make a polygon and cut:
		#Geometry3D.clip_polygon(corners, cut_plane);
		
		# Find the two edges with the cut:
		var edge_0 : int = 0;
		var edge_1 : int = 0;
		var cut_0 := Vector3.ZERO;
		var cut_1 := Vector3.ZERO;
		var cutting_0 : bool = true;
		
		for corner_index in face.corners.size():
			#var cut_points := Geometry3D.segment_intersects_convex(
				#corners[corner_index + 0],
				#corners[(corner_index + 1) % face.corners.size()],
				#[cut_plane]);
			var segment_cut := cut_plane.intersects_segment(
				corners[corner_index + 0],
				corners[(corner_index + 1) % face.corners.size()],
				);
			
			if segment_cut == null:
				continue;
				
			if cutting_0:
				cut_0 = segment_cut as Vector3;
				edge_0 = corner_index;
				cutting_0 = false;
			else:
				cut_1 = segment_cut as Vector3;
				edge_1 = corner_index;
				break;
		
		# Do we not have two edges?
		if edge_1 <= edge_0:
			continue;
			
		# Draw a line between the two edges:
		_cut_lines.points.push_back(cut_0);
		_cut_lines.points.push_back(cut_1);
		_cut_lines.colors.push_back(color_w);
		_cut_lines.colors.push_back(color_w);
	
	if _cut_lines.points.is_empty():
		_cut_lines.release();
		_cut_lines = null;
	else:
		_cut_lines.update();
		
	pass
