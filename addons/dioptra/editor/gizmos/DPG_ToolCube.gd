@tool
extends EditorNode3DGizmoPlugin
## General purpose ToolCube gizmo plugin for doing Item gizmos

var enabled : bool = false;
var box_start : Vector3 = Vector3.ZERO;
var box_end : Vector3 = Vector3.ZERO;

var _label_x : DPULabelPool.LabelNodeItem = null;
var _label_y : DPULabelPool.LabelNodeItem = null;
var _label_z : DPULabelPool.LabelNodeItem = null;

func _init(undoredo : EditorUndoRedoManager) -> void:
	create_material("edges", Color(1.0, 1.0, 1.0, 1.0), false, true, true);
	create_material("geo", Color(1.0, 1.0, 1.0, 0.5), false, false, true);
	pass

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is EditorDP_InternalTool;
	
func _get_gizmo_name() -> String:
	return "DP Tool Cube"

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	if not enabled:
		return;
	
	if _label_x:
		_label_x.release();
		_label_x = null;
	if _label_y:
		_label_y.release();
		_label_y = null;
	if _label_z:
		_label_z.release();
		_label_z = null;
	
	var size := (box_start - box_end).abs();
	var halfsize := size * 0.5;
	var center := (box_start + box_end) * 0.5;
	
	var color_x : Color = EditorInterface.get_editor_theme().get_color("property_color_x", "Editor");
	var color_y : Color = EditorInterface.get_editor_theme().get_color("property_color_y", "Editor");
	var color_z : Color = EditorInterface.get_editor_theme().get_color("property_color_z", "Editor");
	var color_w : Color = EditorInterface.get_editor_theme().get_color("property_color_w", "Editor");
	
	var local_mesh : ArrayMesh = ArrayMesh.new();
	if true:
		var mesher_color := Color(color_w, color_w.a * 0.1);
		var am := DPArrayMesher.new(DPArrayMesher.TypeFlags.VERTEX \
			| DPArrayMesher.TypeFlags.NORMAL | DPArrayMesher.TypeFlags.TEX_UV \
			| DPArrayMesher.TypeFlags.COLOR \
			| DPArrayMesher.TypeFlags.INDEX);
		# Add top & bottom
		am.quad_add(center + Vector3(0, -halfsize.y, 0), Vector3(halfsize.x, 0, 0), Vector3(0, 0, halfsize.z));
		am.quad_add(center + Vector3(0,  halfsize.y, 0), Vector3(halfsize.x, 0, 0), Vector3(0, 0, halfsize.z));
		# Add left and right
		am.quad_add(center + Vector3(-halfsize.x, 0, 0), Vector3(0, halfsize.y, 0), Vector3(0, 0, halfsize.z));
		am.quad_add(center + Vector3( halfsize.x, 0, 0), Vector3(0, halfsize.y, 0), Vector3(0, 0, halfsize.z));
		# Add front and back
		am.quad_add(center + Vector3(0, 0, -halfsize.z), Vector3(0, halfsize.y, 0), Vector3(halfsize.x, 0, 0));
		am.quad_add(center + Vector3(0, 0, halfsize.z), Vector3(0, halfsize.y, 0), Vector3(halfsize.x, 0, 0));
		
		for i in am.get_surface_color().size():
			am.get_surface_color()[i] = mesher_color;
		
		local_mesh.add_surface_from_arrays(am.get_primitive_type(), am.get_surface_array());
	gizmo.add_mesh(local_mesh, get_material("geo", gizmo));
	#gizmo.add_collision_triangles(local_mesh.generate_triangle_mesh());
	
	
	_label_x = DPULabelPool.get_label(EditorInterface.get_editor_viewport_3d(0).get_camera_3d());
	var lbl_x : Label3D = _label_x.get_node();
	lbl_x.text = "%.1fm\n%dpx" % [size.x, int(size.x * 64.0)];
	lbl_x.global_position = center + Vector3(0, -halfsize.y, halfsize.z);
	lbl_x.modulate = color_x;
	
	_label_z = DPULabelPool.get_label(EditorInterface.get_editor_viewport_3d(0).get_camera_3d());
	var lbl_z : Label3D = _label_z.get_node();
	lbl_z.text = "%.1fm\n%dpx" % [size.z, int(size.z * 64.0)];
	lbl_z.global_position = center + Vector3(halfsize.x, -halfsize.y, 0);
	lbl_z.modulate = color_z;
	
	if size.y > 0:
		_label_y = DPULabelPool.get_label(EditorInterface.get_editor_viewport_3d(0).get_camera_3d());
		var lbl_y : Label3D = _label_y.get_node();
		lbl_y.text = "%.1fm\n%dpx" % [size.y, int(size.y * 64.0)];
		lbl_y.global_position = center + Vector3(halfsize.x, 0, halfsize.z);
		lbl_y.modulate = color_y;
	
	# Draw lines
	var edge_x := PackedVector3Array();
	var edge_y := PackedVector3Array();
	var edge_z := PackedVector3Array();
	
	edge_x.append(center + Vector3(-halfsize.x, -halfsize.y, halfsize.z));
	edge_x.append(center + Vector3( halfsize.x, -halfsize.y, halfsize.z));
	gizmo.add_lines(edge_x, get_material("edges", gizmo), true, EditorInterface.get_editor_theme().get_color("axis_x_color", "Editor"));
	
	edge_y.append(center + Vector3(halfsize.x, -halfsize.y, halfsize.z));
	edge_y.append(center + Vector3(halfsize.x, halfsize.y, halfsize.z));
	gizmo.add_lines(edge_y, get_material("edges", gizmo), true, EditorInterface.get_editor_theme().get_color("axis_y_color", "Editor"));
	
	edge_z.append(center + Vector3(halfsize.x, -halfsize.y, -halfsize.z));
	edge_z.append(center + Vector3(halfsize.x, -halfsize.y, halfsize.z));
	gizmo.add_lines(edge_z, get_material("edges", gizmo), true, EditorInterface.get_editor_theme().get_color("axis_z_color", "Editor"));

	pass
