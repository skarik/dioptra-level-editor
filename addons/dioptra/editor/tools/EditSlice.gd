extends DPUTool
class_name DPUTool_EditSlice

var _cursor : DPUCursorGhost = null;
var _decal_position := MapVector3.new();
var _decal_normal : Vector3 = Vector3.ZERO;

func _init(plugin : DioptraEditorMainPlugin) -> void:
	super(plugin);
	_cursor = DPUCursorGhost.new();

func cleanup() -> void:
	if _cursor != null:
		_cursor.cleanup();
		_cursor = null;
	pass

## Overrideable GUI input handling
func forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	
	# Update tooltip
	overlay_text = "Click on a solid to slice along the shown line into two separate solids.\nRight click to toggle between edge slice & axis slice.\nHold Shift to only slice single face.";
	
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
	
			var normal : Vector3 = -(solid.points[face.corners[1]].v3 - solid.points[face.corners[0]].v3).cross(
				solid.points[face.corners[2]].v3 - solid.points[face.corners[0]].v3).normalized();
				
			var collision_plane := Plane(normal, solid.points[face.corners[0]].v3);
			var collision := collision_plane.intersects_ray(viewport_camera.project_ray_origin(event.position), viewport_camera.project_ray_normal(event.position));
			if collision != null:
				var collision_point := collision as Vector3;
				
				_decal_position.v3 = collision_point;
				_decal_normal = normal;
			
				# Update ghost:
				_cursor.position = _decal_position.v3;
				_cursor.normal = _decal_normal;
				_cursor.update(EditorInterface.get_editor_viewport_3d(0).get_camera_3d());
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS;

func process(delta: float) -> void:
	pass
