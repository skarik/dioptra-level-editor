extends RefCounted
class_name DPUBoxGhost

var box_start : Vector3 = Vector3.ZERO;
var box_end : Vector3 = Vector3.ZERO;

var _label_x : DPULabelPool.LabelNodeItem = null;
var _label_y : DPULabelPool.LabelNodeItem = null;
var _label_z : DPULabelPool.LabelNodeItem = null;
var _lines : DPULines3D.LinesItem = null;

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
	if _lines:
		_lines.release();
		_lines = null;

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
	
	# Update the current state
	var size := (box_start - box_end).abs();
	var halfsize := size * 0.5;
	var center := (box_start + box_end) * 0.5;
	
	var color_x : Color = EditorInterface.get_editor_theme().get_color("property_color_x", "Editor");
	var color_y : Color = EditorInterface.get_editor_theme().get_color("property_color_y", "Editor");
	var color_z : Color = EditorInterface.get_editor_theme().get_color("property_color_z", "Editor");
	var color_w : Color = EditorInterface.get_editor_theme().get_color("property_color_w", "Editor");
	
	# TODO: mesh
	
	# Wires
	if _lines == null:
		_lines = DPULines3D.get_line();
		_lines.points.resize(24);
		_lines.colors.resize(24);
		_lines.segments = true;

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
		_lines.colors[i] = Color.WHITE;
	
	_lines.update();
	
	# Labels:
	_label_x = DPULabelPool.get_label(viewport_camera);
	var lbl_x : Label3D = _label_x.get_node();
	lbl_x.text = "%.1fm\n%dpx" % [size.x, int(size.x * 64.0)];
	lbl_x.global_position = center + Vector3(0, -halfsize.y, halfsize.z);
	lbl_x.modulate = color_x;
	
	_label_z = DPULabelPool.get_label(viewport_camera);
	var lbl_z : Label3D = _label_z.get_node();
	lbl_z.text = "%.1fm\n%dpx" % [size.z, int(size.z * 64.0)];
	lbl_z.global_position = center + Vector3(halfsize.x, -halfsize.y, 0);
	lbl_z.modulate = color_z;
	
	if size.y > 0:
		_label_y = DPULabelPool.get_label(viewport_camera);
		var lbl_y : Label3D = _label_y.get_node();
		lbl_y.text = "%.1fm\n%dpx" % [size.y, int(size.y * 64.0)];
		lbl_y.global_position = center + Vector3(halfsize.x, 0, halfsize.z);
		lbl_y.modulate = color_y;
