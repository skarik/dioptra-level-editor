extends DPUTool
class_name DPUTool_Decal

var _ghost_box : DPUBoxGhost = null;

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
	var map_gizmo_plugin := _plugin.DPGizmoPlugin_MapTest1;
	var map := _plugin.get_last_edited_map();
	var map_gizmo := helper_plugin._get_target_gizmo(_plugin, map);
	
	if event is InputEventMouseMotion:
		var old_selection := _plugin._selectionMode;
		_plugin._selectionMode = _plugin.SelectMode.FACE;
		var subgizmo_id := map_gizmo_plugin._subgizmos_intersect_ray(map_gizmo, viewport_camera, event.position);
		_plugin._selectionMode = old_selection;
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
				_ghost_box.box_start = collision_point - Vector3.ONE * 0.2;
				_ghost_box.box_end = collision_point + Vector3.ONE * 0.2;
				_ghost_box.update(EditorInterface.get_editor_viewport_3d(0).get_camera_3d());
			
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS;
	
func process(delta: float) -> void:
	pass
	
#------------------------------------------------------------------------------#
