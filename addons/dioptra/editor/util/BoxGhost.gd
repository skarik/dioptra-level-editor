extends RefCounted
class_name DPUBoxGhost

var box_start : Vector3 = Vector3.ZERO;
var box_end : Vector3 = Vector3.ZERO;
var icon_corners : bool = false;
var show_size_labels : bool = true;
var show_edge_highlight : bool = true;
var show_face_highlight : bool = false;
var highlighted_face : int = -1; ## X-, X+, Y-, Y+, Z-, Z+ in order

var _label_x : DPULabelPool.LabelNodeItem = null;
var _label_y : DPULabelPool.LabelNodeItem = null;
var _label_z : DPULabelPool.LabelNodeItem = null;
var _mesh_renderer : MeshInstance3D = null;
var _lines : DPULines3D.LinesItem = null;
var _lines_edge : DPULines3D.LinesItem = null;

var _last_valid_camera : Camera3D = null;

func cleanup() -> void:
	if _label_x:
		_label_x.release();
		_label_x = null;
	if _label_y:
		_label_y.release();
		_label_y = null;
	if _label_z:
		_label_z.release();
		_label_z = null;
	if _mesh_renderer:
		_mesh_renderer.queue_free();
		_mesh_renderer = null;
	if _lines:
		_lines.release();
		_lines = null;
	if _lines_edge:
		_lines_edge.release();
		_lines_edge = null;
	

func update(viewport_camera : Camera3D) -> void:
	# Cleanup the previous state:
	if _label_x:
		_label_x.release();
		_label_x = null;
	if _label_y:
		_label_y.release();
		_label_y = null;
	if _label_z:
		_label_z.release();
		_label_z = null;
		
	# Grab a good camera
	if viewport_camera:
		_last_valid_camera = viewport_camera;
	
	# Update the current state
	var size := (box_start - box_end).abs();
	var halfsize := size * 0.5;
	var center := (box_start + box_end) * 0.5;
	
	var color_x : Color = EditorInterface.get_editor_theme().get_color("property_color_x", "Editor");
	var color_y : Color = EditorInterface.get_editor_theme().get_color("property_color_y", "Editor");
	var color_z : Color = EditorInterface.get_editor_theme().get_color("property_color_z", "Editor");
	var color_w : Color = EditorInterface.get_editor_theme().get_color("property_color_w", "Editor");
	var color_h : Color = DPHelpers.COLOR_GEO_ACCENT;
	
	# Create arraymesher
	var am := DPArrayMesher.new(DPArrayMesher.TypeFlags.VERTEX \
		| DPArrayMesher.TypeFlags.NORMAL \
		| DPArrayMesher.TypeFlags.COLOR | DPArrayMesher.TypeFlags.TEX_UV \
		| DPArrayMesher.TypeFlags.TEX_UV2 \
		| DPArrayMesher.TypeFlags.INDEX);
	
	# Wires
	if _lines == null:
		_lines = DPULines3D.get_line();
		_lines.points.resize(24);
		_lines.colors.resize(24);
		_lines.segments = true;
		_lines.width = 1.0;

	_lines.points[0] = center + Vector3(-halfsize.x, -halfsize.y, -halfsize.z);
	_lines.points[1] = center + Vector3( halfsize.x, -halfsize.y, -halfsize.z);
	_lines.points[2] = center + Vector3(-halfsize.x,  halfsize.y, -halfsize.z);
	_lines.points[3] = center + Vector3( halfsize.x,  halfsize.y, -halfsize.z);
	
	_lines.points[4] = center + Vector3(-halfsize.x, -halfsize.y,  halfsize.z);
	_lines.points[5] = center + Vector3( halfsize.x, -halfsize.y,  halfsize.z);
	_lines.points[6] = center + Vector3(-halfsize.x,  halfsize.y,  halfsize.z);
	_lines.points[7] = center + Vector3( halfsize.x,  halfsize.y,  halfsize.z);
	
	_lines.points[8] = center + Vector3( halfsize.x, -halfsize.y, -halfsize.z);
	_lines.points[9] = center + Vector3( halfsize.x, -halfsize.y,  halfsize.z);
	_lines.points[10]= center + Vector3( halfsize.x,  halfsize.y, -halfsize.z);
	_lines.points[11]= center + Vector3( halfsize.x,  halfsize.y,  halfsize.z);
	
	_lines.points[12]= center + Vector3(-halfsize.x, -halfsize.y, -halfsize.z);
	_lines.points[13]= center + Vector3(-halfsize.x, -halfsize.y,  halfsize.z);
	_lines.points[14]= center + Vector3(-halfsize.x,  halfsize.y, -halfsize.z);
	_lines.points[15]= center + Vector3(-halfsize.x,  halfsize.y,  halfsize.z);
	
	_lines.points[16]= center + Vector3(-halfsize.x, -halfsize.y, -halfsize.z);
	_lines.points[17]= center + Vector3(-halfsize.x,  halfsize.y, -halfsize.z);
	_lines.points[18]= center + Vector3( halfsize.x, -halfsize.y, -halfsize.z);
	_lines.points[19]= center + Vector3( halfsize.x,  halfsize.y, -halfsize.z);
	
	_lines.points[20]= center + Vector3(-halfsize.x, -halfsize.y,  halfsize.z);
	_lines.points[21]= center + Vector3(-halfsize.x,  halfsize.y,  halfsize.z);
	_lines.points[22]= center + Vector3( halfsize.x, -halfsize.y,  halfsize.z);
	_lines.points[23]= center + Vector3( halfsize.x,  halfsize.y,  halfsize.z);
	
	for i in _lines.colors.size():
		_lines.colors[i] = color_w;
	
	_lines.update();
	
	if show_size_labels:
		# Labels:
		if size.x > 0:
			_label_x = DPULabelPool.get_label(_last_valid_camera);
		if size.z > 0:
			_label_z = DPULabelPool.get_label(_last_valid_camera);
		if size.y > 0:
			_label_y = DPULabelPool.get_label(_last_valid_camera);
		_update_labels(_last_valid_camera);
		
	if show_edge_highlight:
		if _lines_edge == null:
			_lines_edge = DPULines3D.get_line();
			_lines_edge.points.resize(6);
			_lines_edge.colors.resize(6);
			_lines_edge.segments = true;
			_lines_edge.width = 3.0;
		_update_edge(_last_valid_camera);
		
	if show_face_highlight:
		# Build faces
		# Each face gets their own 4 points as they can have different colors
		var points : PackedVector3Array = [];
		points.resize(6 * 4);
		# X Faces
		points[0] = Vector3(-1, -1, -1);
		points[1] = Vector3(-1, -1,  1);
		points[2] = Vector3(-1,  1, -1);
		points[3] = Vector3(-1,  1,  1);
		points[4] = Vector3( 1, -1, -1);
		points[5] = Vector3( 1, -1,  1);
		points[6] = Vector3( 1,  1, -1);
		points[7] = Vector3( 1,  1,  1);
		# Y Faces
		points[8] = Vector3(-1, -1, -1);
		points[9] = Vector3(-1, -1,  1);
		points[10] = Vector3( 1, -1, -1);
		points[11] = Vector3( 1, -1,  1);
		points[12] = Vector3(-1,  1, -1);
		points[13] = Vector3(-1,  1,  1);
		points[14] = Vector3( 1,  1, -1);
		points[15] = Vector3( 1,  1,  1);
		# Z Faces
		points[16] = Vector3(-1, -1, -1);
		points[17] = Vector3(-1,  1, -1);
		points[18] = Vector3( 1, -1, -1);
		points[19] = Vector3( 1,  1, -1);
		points[20] = Vector3(-1, -1,  1);
		points[21] = Vector3(-1,  1,  1);
		points[22] = Vector3( 1, -1,  1);
		points[23] = Vector3( 1,  1,  1);
		# Fix positions
		for v in 24:
			points[v] = center + points[v] * halfsize;
		
		am.points_add(points);
		
		# Fix colors
		for v in 24:
			am.get_surface_color()[v] = Color(color_h * 0.5, 0.2);
		# Face highlight
		if highlighted_face != -1:
			var v0 := highlighted_face * 4;
			for v in 4:
				am.get_surface_color()[v0 + v] = Color(color_h, 0.3);
			
		# Build quads
		for face in 6:
			var v0 = face * 4;
			am.quad_add_indicies(v0 + 0, v0 + 1, v0 + 2, v0 + 3);
			

	if am.get_index_count() > 0:
		# Mesh
		if _mesh_renderer == null:
			_mesh_renderer = MeshInstance3D.new();
			EditorInterface.get_edited_scene_root().add_child(_mesh_renderer, false, Node.INTERNAL_MODE_FRONT);
		
		var old_mesh = _mesh_renderer.mesh;
		var new_mesh = ArrayMesh.new();
		new_mesh.add_surface_from_arrays(am.get_primitive_type(), am.get_surface_array());
		new_mesh.surface_set_material(0, preload("res://addons/dioptra/editor/util/ghost_transparent.tres"));
		_mesh_renderer.mesh = new_mesh;
		old_mesh = null;
		pass
	else:
		if _mesh_renderer:
			var old_mesh = _mesh_renderer.mesh;
			_mesh_renderer.mesh = null;
			old_mesh = null;
		pass
	
	pass

func _update_labels(viewport_camera : Camera3D) -> void:
	# Update the current state
	var size := (box_start - box_end).abs();
	var halfsize := size * 0.5;
	var center := (box_start + box_end) * 0.5;
	
	# Get the theme colors
	var color_x : Color = EditorInterface.get_editor_theme().get_color("property_color_x", "Editor");
	var color_y : Color = EditorInterface.get_editor_theme().get_color("property_color_y", "Editor");
	var color_z : Color = EditorInterface.get_editor_theme().get_color("property_color_z", "Editor");
	
	# Get the sign of all edges:
	var delta := viewport_camera.global_position - center;
	var signs := delta.sign();
	
	var texture_scale1d := DioptraInterface.get_pixel_scale_top() * float(DioptraInterface.get_pixel_scale_div());
	
	if _label_x:
		var lbl_x : Label3D = _label_x.get_node();
		lbl_x.visible = true;
		lbl_x.text = "%.1fm\n%dpx" % [size.x, int(size.x * texture_scale1d)];
		lbl_x.global_position = center + Vector3(0, halfsize.y, halfsize.z) * signs;
		lbl_x.modulate = color_x;
		lbl_x.render_priority = 10;
	
	if _label_z:
		var lbl_z : Label3D = _label_z.get_node();
		lbl_z.visible = true;
		lbl_z.text = "%.1fm\n%dpx" % [size.z, int(size.z * texture_scale1d)];
		lbl_z.global_position = center + Vector3(halfsize.x, halfsize.y, 0) * signs;
		lbl_z.modulate = color_z;
		lbl_z.render_priority = 10;
	
	if _label_y:
		var lbl_y : Label3D = _label_y.get_node();
		lbl_y.visible = true;
		lbl_y.text = "%.1fm\n%dpx" % [size.y, int(size.y * texture_scale1d)];
		lbl_y.global_position = center + Vector3(halfsize.x, 0, halfsize.z) * signs;
		lbl_y.modulate = color_y;
		lbl_y.render_priority = 10;

func _update_edge(viewport_camera : Camera3D) -> void:
	# Update the current state
	var size := (box_start - box_end).abs();
	var halfsize := size * 0.5;
	var center := (box_start + box_end) * 0.5;
	
	# Get the theme colors
	var color_x : Color = EditorInterface.get_editor_theme().get_color("axis_x_color", "Editor");
	var color_y : Color = EditorInterface.get_editor_theme().get_color("axis_y_color", "Editor");
	var color_z : Color = EditorInterface.get_editor_theme().get_color("axis_z_color", "Editor");
	
	# Get the sign of all edges:
	var delta := viewport_camera.global_position - center;
	var signs := delta.sign();
	
	if _lines_edge:
		_lines_edge.points[0] = center + Vector3(-halfsize.x, halfsize.y, halfsize.z) * signs;
		_lines_edge.points[1] = center + Vector3( halfsize.x, halfsize.y, halfsize.z) * signs;
		_lines_edge.colors[0] = color_x;
		_lines_edge.colors[1] = color_x;
		
		_lines_edge.points[2] = center + Vector3(halfsize.x, halfsize.y, -halfsize.z) * signs;
		_lines_edge.points[3] = center + Vector3(halfsize.x, halfsize.y,  halfsize.z) * signs;
		_lines_edge.colors[2] = color_z;
		_lines_edge.colors[3] = color_z;
		
		_lines_edge.points[4] = center + Vector3(halfsize.x, -halfsize.y, halfsize.z) * signs;
		_lines_edge.points[5] = center + Vector3(halfsize.x,  halfsize.y, halfsize.z) * signs;
		_lines_edge.colors[4] = color_y;
		_lines_edge.colors[5] = color_y;
		
		_lines_edge.update();
