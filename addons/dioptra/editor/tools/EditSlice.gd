extends DPUTool
class_name DPUTool_EditSlice

var _cursor : DPUCursorGhost = null;
var _cursor_position := MapVector3.new();
var _cursor_normal : Vector3 = Vector3.ZERO;

var _cut_lines : DPULines3D.LinesItem = null;

class Cut:
	var cutpoint_index0 : int = -1;
	var cutpoint_index1 : int = -1;
	var cut_edge0 : int = -1;
	var cut_edge1 : int = -1;
	var cut_face : int = -1;

var _cut_plane : Plane;
var _cut_solid : DPMapSolid;
var _cut_points : PackedVector3Array = [];
var _cut_listing : Array[Cut] = [];

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
				
				_cursor_position.v3 = collision_point;
				_cursor_normal = normal;
				var collision_point_grid := DioptraInterface.get_grid_round_v3(collision_point);
				
				_update_cut_preview(selection, collision_point_grid);
			
				# Update ghost:
				_cursor.position = _cursor_position.v3;
				_cursor.normal = _cursor_normal;
				_cursor.update(EditorInterface.get_editor_viewport_3d(0).get_camera_3d());
				
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_slice_on_edge_not_axis = not _slice_on_edge_not_axis;
			return EditorPlugin.AFTER_GUI_INPUT_STOP;
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# Cut
			_action_cut_solid();
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
	
	# Save it:
	_cut_plane = cut_plane;
	_cut_solid = selection.solid;
	_cut_listing.clear();
	_cut_points.clear();
	
	# Loop through the faces:
	for face_index in selection.solid.faces.size():
		var face := selection.solid.faces[face_index];
		
		if _slice_all_faces == false:
			if face != selection.face:
				continue; 
		
		var solid := selection.solid;
		
		var corners : PackedVector3Array;
		corners.resize(face.corners.size());
		for corner_index in face.corners.size():
			corners[corner_index] = solid.points[face.corners[corner_index]].v3;
		
		# Find the two edges with the cut:
		var edge_0 : int = 0;
		var edge_1 : int = 0;
		var cut_0 := Vector3.ZERO;
		var cut_1 := Vector3.ZERO;
		var cutting_0 : bool = true;
		
		for corner_index in face.corners.size():
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
		
		# Save the cut:
		var cut : Cut = Cut.new();
		cut.cut_face = face_index;
		cut.cut_edge0 = edge_0;
		cut.cut_edge1 = edge_1;
		cut.cutpoint_index0 = _get_or_add_cut_point(_cut_points, cut_0);
		cut.cutpoint_index1 = _get_or_add_cut_point(_cut_points, cut_1);
		_cut_listing.push_back(cut);
	
	if _cut_lines.points.is_empty():
		_cut_lines.release();
		_cut_lines = null;
	else:
		_cut_lines.update();
		
	pass
	
## Adds point to the given packed vector3 array in mapcoords. If it exists, doesn't add.
## In both cases, adds index of the point in the array
func _get_or_add_cut_point(points : PackedVector3Array, point : Vector3) -> int:
	var point_as_dp := MapVector3.from_v3(point);
	var temp_mapvec := MapVector3.new();
	for i in points.size():
		temp_mapvec.v3 = points[i];
		if temp_mapvec.equals(point_as_dp):
			return i;
	points.push_back(point);
	return points.size() - 1;
	
## Gets the given point from the packed vector3 array in mapcoords.
func _get_cut_point(points : PackedVector3Array, point : Vector3) -> int:
	var point_as_dp := MapVector3.from_v3(point);
	var temp_mapvec := MapVector3.new();
	for i in points.size():
		temp_mapvec.v3 = points[i];
		if temp_mapvec.equals(point_as_dp):
			return i;
	return -1;
	
	
	
func _action_cut_solid_with_cached_edge() -> void:
	_action_cut_solid(); # Cannot be bothered to determine which side of a cut is on the front side right now.
	pass
	
func _action_cut_face_with_cached_edge() -> void:
	# TODO
	pass
	
func _action_cut_solid() -> void:
	var map := _plugin.get_last_edited_map();
	
	if _cut_solid != null and map.solids.has(_cut_solid):
		# We need to clip with two planes: forward and back.
		# So we're making two new solids and removing the last one
		
		var solid_1 := _make_clipped_solid(_cut_solid, _cut_plane);
		var solid_2 := _make_clipped_solid(_cut_solid, -_cut_plane);
		
		# Remove original solid:
		map.solids.erase(_cut_solid);
		
		# Add the two solids:
		map.editor_add_solid(solid_1);
		map.editor_add_solid(solid_2);
	
	pass

func _make_clipped_solid(old_solid : DPMapSolid, plane : Plane) -> DPMapSolid:
	var new_solid := DPMapSolid.new();
	
	var all_corners : PackedVector3Array = [];
	var cut_planes : Array[Plane] = [];
	var cut_faces : PackedInt32Array = [];
	
	for face_index in old_solid.faces.size():
		var face = old_solid.faces[face_index];
		
		var corners : PackedVector3Array;
		corners.resize(face.corners.size());
		for corner_index in face.corners.size():
			corners[corner_index] = old_solid.points[face.corners[corner_index]].v3;
			
		# Is this face in the cuts?
		var face_is_cut := false;
		for cut in _cut_listing:
			if face_index == cut.cut_face:
				face_is_cut = true;
				break;
			
		var clipped := Geometry3D.clip_polygon(corners, plane);
		if clipped.is_empty():
			continue; # Skip anything not in the plane
			
		if not face_is_cut:
			# Copy the the face over entirely:
			var new_face := DPMapFace.new();
			new_face.copy_from(face);
			new_face.corners = [];
			# Add the old face's corners:
			for corner_index in face.corners.size():
				var point_index := _get_or_add_cut_point(all_corners, old_solid.points[face.corners[corner_index]].v3);
				new_face.corners.push_back(point_index);
			# Add face to solid
			new_solid.faces.push_back(new_face);
		else:
			# Building a new clipped face
			var new_face := DPMapFace.new();
			new_face.copy_from(face);
			new_face.corners = [];
			# Add the clipped polygon corners:
			for clipped_point in clipped:
				var point_index := _get_or_add_cut_point(all_corners, clipped_point);
				new_face.corners.push_back(point_index);
			# Add face to solid
			new_solid.faces.push_back(new_face);
			
			# Store the plane of this face:
			cut_planes.push_back(Plane(
				old_solid.points[face.corners[0]].v3,
				old_solid.points[face.corners[1]].v3,
				old_solid.points[face.corners[2]].v3
				))
			# Save this face as one of the cut ones
			cut_faces.push_back(new_solid.faces.size() - 1);
		
	# Save points now:
	for corner in all_corners:
		var mapvec := MapVector3.new();
		mapvec.v3 = corner;
		new_solid.points.push_back(mapvec);
	
	# Make face on the cut plane by organizing edges:
	# TODO: make this better somehow. This is ridiuclous.
	if true:
		var edges : PackedInt32Array = [];
	
		# First collect the new edges made by cutting:
		for cut_face_index in cut_faces:
			var cut_face = new_solid.faces[cut_face_index];
			
			var coplanar_edge00 := -1;
			var coplanar_edge01 := -1;
			
			# Find the coplanar edge
			for corner_index in cut_face.corners.size():
				var corner_point_mv := new_solid.points[cut_face.corners[corner_index]];
				var projected_point := plane.project(corner_point_mv.v3);
				var projected_point_mv := MapVector3.from_v3(projected_point);
				if corner_point_mv.equals(projected_point_mv):
					# We have a coplanar point, check forward & back for an edge
					for offset in [-1, 1]:
						var next_corner_index : int = (corner_index + offset + cut_face.corners.size()) % cut_face.corners.size();
						var next_corner_point_mv := new_solid.points[cut_face.corners[next_corner_index]]
						var next_projected_point := plane.project(next_corner_point_mv.v3);
						var next_proejcted_point_mv = MapVector3.from_v3(next_projected_point);
						if next_corner_point_mv.equals(next_proejcted_point_mv):
							if offset == -1:
								coplanar_edge00 = next_corner_index;
								coplanar_edge01 = corner_index;
							else:
								coplanar_edge00 = corner_index;
								coplanar_edge01 = next_corner_index;
							break;
					if coplanar_edge00 != -1 and coplanar_edge01 != -1:
						break;
			
			# Store the coplanar edge:
			if coplanar_edge00 != -1 and coplanar_edge01 != -1:
				edges.push_back(cut_face.corners[coplanar_edge00]);
				edges.push_back(cut_face.corners[coplanar_edge01]);
				
		if edges.size() < 2:
			push_warning("Bad math in slicing");
		else:
			# With a list of edges, start with the first and then sort them:
			var sort_index := -2;
			var previous_corner := edges[0];
			var working := true;
			while working:
				working = false;
				
				# Find the next pair with the previous corner
				for i in range(sort_index + 2, edges.size(), 2):
					if edges[i] == previous_corner:
						# Swap it into position
						var old0 := edges[sort_index + 0];
						var old1 := edges[sort_index + 1];
						edges[sort_index + 0] = edges[i + 0];
						edges[sort_index + 1] = edges[i + 1];
						edges[i + 0] = old0;
						edges[i + 1] = old1;
						# Set up next sorting iteration
						previous_corner = edges[sort_index + 1];
						sort_index += 2;
						# Next iteration
						working = true;
						break;
			# The edges now have all the corners on the 2nd coord.
			
			# Check if we need to flip it:
			var new_normal : Vector3 = -(
				(new_solid.points[edges[2]].v3 - new_solid.points[edges[0]].v3)
				.cross(new_solid.points[edges[4]].v3 - new_solid.points[edges[0]].v3)
				).normalized();
			if new_normal.dot(plane.normal) < 0.0:
				edges.reverse();
				new_normal = -new_normal;
			
			# Find the face with the new normal's best match
			var best_match : DPMapFace = null;
			var best_match_val : float = -INF;
			for face in old_solid.faces:
				var face_normal : Vector3 = -(
					(old_solid.points[face.corners[1]].v3 - old_solid.points[face.corners[0]].v3)
					.cross(old_solid.points[face.corners[2]].v3 - old_solid.points[face.corners[0]].v3)
					).normalized();
				var new_val : float = new_normal.dot(face_normal);
				if new_val > best_match_val:
					best_match = face;
					best_match_val = new_val;
					
			# Start with a copy of the face
			var new_face := DPMapFace.new();
			new_face.copy_from(best_match);
			new_face.corners = [];
			
			# Copy over the corners
			for i in range(0, edges.size(), 2):
				new_face.corners.push_back(edges[i]);
				
			# Add face to solid
			new_solid.faces.push_back(new_face);
			
		pass
	
	return new_solid;
