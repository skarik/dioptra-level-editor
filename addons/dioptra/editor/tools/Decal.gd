extends DPUTool
class_name DPUTool_Decal

var _ghost_box : DPUBoxGhost = null;
var _decal_position := MapVector3.new();
var _decal_normal : Vector3 = Vector3.ZERO;

func _init(plugin : DioptraEditorMainPlugin) -> void:
	super(plugin);
	_ghost_box = DPUBoxGhost.new();
	
func cleanup() -> void:
	if _ghost_box != null:
		_ghost_box.cleanup()
		_ghost_box = null;
	pass
	
## Overrideable GUI input handling
func forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	
	# TODO: grab the last selected material and use that as a decal that we just BIPBAP on with a click
	# OR: wait for a material to be set in the material editor.
	
	var helper_plugin := _plugin._plugin_maphelper;
	var map := _plugin.get_last_edited_map();
	var map_gizmo := helper_plugin._get_target_gizmo(_plugin, map);
	
	if event is InputEventMouseMotion:
		var subgizmo_id := DPEditorSelection.subgizmo_intersect_ray(map, viewport_camera, event.position, DioptraEditorMainPlugin.SelectMode.FACE);
		var selection_type := DPHelpers.get_selection_type(map, subgizmo_id);
		var selection := DPHelpers.get_selection(map, subgizmo_id);
		
		if selection_type == DPHelpers.SelectionType.FACE or selection_type == DPHelpers.SelectionType.SOLID:
			var solid := selection.solid;
			var face := selection.face;
			
			# Draw ghost box for the sizes (only one box so it'll work for the last selection)
			#var min_p := solid.points[0].v3;
			#var max_p := solid.points[0].v3;
			#for point in solid.points:
				#min_p = min_p.min(point.v3);
				#max_p = max_p.max(point.v3);
			#_ghost_box.box_start = min_p;
			#_ghost_box.box_end = max_p;
			#_ghost_box.update(EditorInterface.get_editor_viewport_3d(0).get_camera_3d());
			
			var normal : Vector3 = -(solid.points[face.corners[1]].v3 - solid.points[face.corners[0]].v3).cross(
				solid.points[face.corners[2]].v3 - solid.points[face.corners[0]].v3).normalized();
				
			var collision_plane := Plane(normal, solid.points[face.corners[0]].v3);
			var collision := collision_plane.intersects_ray(viewport_camera.project_ray_origin(event.position), viewport_camera.project_ray_normal(event.position));
			if collision != null:
				var collision_point := collision as Vector3;
				#collision_point = DioptraInterface.get_grid_round_v3(collision_point);
				_ghost_box.box_start = collision_point - Vector3.ONE * 0.2;
				_ghost_box.box_end = collision_point + Vector3.ONE * 0.2;
				_ghost_box.update(EditorInterface.get_editor_viewport_3d(0).get_camera_3d());
				
				_decal_position.v3 = collision_point;
				_decal_normal = normal;
			
	# When the mouse click releases, stop dragging
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# Build a decal
		_add_decal();
		# use the stored hit face & normal & spawn decal there
		return EditorPlugin.AFTER_GUI_INPUT_STOP;
		pass
		
	# Update gizmos!
	_plugin.get_last_edited_map().update_gizmos();
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS;
	
func process(delta: float) -> void:
	pass
	
#------------------------------------------------------------------------------#

func _add_decal() -> void:
	print("New decal");
	var decal = DPMapDecal.new();
	
	# Set position
	decal.position.v3i = _decal_position.v3i;
	
	# Make rotation by rotating towards the wall
	var up : Vector3 = Vector3.UP;
	if (absf(up.dot(_decal_normal)) > 0.717):
		up = Vector3.FORWARD;
	var rot_wall : Basis = Basis.looking_at(-_decal_normal, up);
	decal.rotation = rot_wall.get_euler();
	
	# Set up face materials of the solid (done here due to copy-paste)
	var material_index = _plugin.get_last_edited_map().get_or_add_material(_plugin._last_material, true);
	decal.material = material_index;
	
	# We're done!
	
	# Find the correct map
	_plugin.add_new_decal(decal);
	
	# Update gizmos!
	_plugin.get_last_edited_map().update_gizmos();
	
	pass
