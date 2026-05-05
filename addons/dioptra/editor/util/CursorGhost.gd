extends RefCounted
class_name DPUCursorGhost

var position : Vector3;
var normal : Vector3 = Vector3.UP;
var radius : float = 0.2;

var _mesh_renderer : MeshInstance3D = null;
var _lines : DPULines3D.LinesItem = null;

var _last_valid_camera : Camera3D = null;

const CURSOR_SIZE := 0.2;

func cleanup() -> void:
	if _lines:
		_lines.release();
		_lines = null;
	if _mesh_renderer:
		_mesh_renderer.queue_free();
		_mesh_renderer = null;
	pass

func update(viewport_camera : Camera3D) -> void:
	# Grab a good camera
	if viewport_camera:
		_last_valid_camera = viewport_camera;
		
	var normal_valid := normal.is_normalized();
		
	var color_x : Color = EditorInterface.get_editor_theme().get_color("property_color_x", "Editor");
	var color_y : Color = EditorInterface.get_editor_theme().get_color("property_color_y", "Editor");
	var color_z : Color = EditorInterface.get_editor_theme().get_color("property_color_z", "Editor");
	var color_w : Color = EditorInterface.get_editor_theme().get_color("property_color_w", "Editor");
	
	# Generate scale
	var cursor_scale = CURSOR_SIZE * EditorInterface.get_editor_scale();
	if _last_valid_camera:
		var camera := _last_valid_camera;
		var viewport_size : Vector2 = camera.get_viewport().get_visible_rect().size;
		var keep_height : bool = camera.keep_aspect == Camera3D.KEEP_HEIGHT;
		var aspect_ratio : float = 1.0 / (viewport_size.y if keep_height else viewport_size.x);
		var fov : float = camera.fov if (camera.projection == Camera3D.PROJECTION_PERSPECTIVE) else 90.0;
		cursor_scale *= tan(deg_to_rad(fov) * 0.5) * aspect_ratio * 2.0; # rad_to_deg is not in the original source.
		cursor_scale *= position.distance_to(camera.global_position) * 133;
		
	# Create arraymesher
	var am := DPArrayMesher.new(DPArrayMesher.TypeFlags.VERTEX \
		| DPArrayMesher.TypeFlags.NORMAL \
		| DPArrayMesher.TypeFlags.COLOR | DPArrayMesher.TypeFlags.TEX_UV \
		| DPArrayMesher.TypeFlags.TEX_UV2 \
		| DPArrayMesher.TypeFlags.INDEX);

	# Wires
	if _lines == null:
		_lines = DPULines3D.get_line();
		_lines.points.resize(2);
		_lines.colors.resize(2);
		_lines.segments = true;
		_lines.width = 1.0;
		_lines.dpi_aware = true;
		
	# Add a wire pointing away from the position
	_lines.points[0] = position;
	_lines.points[1] = position + normal * cursor_scale;
	
	for i in _lines.colors.size():
		_lines.colors[i] = color_w;
	
	_lines.update();
	
	# Add circle mesh by mouse
	if am and normal_valid:
		am.point_add(position + normal * 0.001);
		var left := normal.cross(Vector3.FORWARD);
		if left.length_squared() < 0.001:
			left = normal.cross(Vector3.LEFT);
		left = left.normalized();
		
		const POINTS := 20;
		for i in POINTS:
			var percent := float(i) / POINTS;
			am.point_add(position + normal * 0.001 + left.rotated(normal, percent * 2 * PI) * radius);
		
		for i in POINTS:
			am.tri_add_indicies(0, 1 + i, 1 + (i + 1) % POINTS);
			
		for v in am.get_vertex_count():
			am.get_surface_color()[v] = Color(color_w, 0.0);
		am.get_surface_color()[0].a = 0.20;
		
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
