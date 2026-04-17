@tool
extends EditorNode3DGizmoPlugin
## General purpose ToolCube gizmo plugin for highlighting faces under cursor

var enabled : bool = false;
var solid : DPMapSolid = null;
var face : DPMapFace = null;
var cursor_pos : Vector3 = Vector3.ZERO;

var _editor_plugin : DioptraEditorMainPlugin = null;

const cGlowSize = 8.0;

func _init(editorPlugin : DioptraEditorMainPlugin):
	create_material("lines", Color(1.0, 1.0, 1.0), false, true, true);
	create_material("geo", Color(1.0, 1.0, 1.0, 0.5), false, false, true);

	_editor_plugin = editorPlugin;
	pass

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return (for_node_3d is DP_Map) or (for_node_3d is EditorDP_InternalTool);

func _get_gizmo_name() -> String:
	return "DP 3D Cursor";

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	if not enabled:
		return;
		
	var color_sel : Color = EditorInterface.get_editor_theme().get_color("warning_color", "Editor");
		
	# Do all solids
	var linesNormie := PackedVector3Array();
	var linesSelect := PackedVector3Array();
	var am := DPArrayMesher.new(DPArrayMesher.TypeFlags.VERTEX \
			| DPArrayMesher.TypeFlags.NORMAL | DPArrayMesher.TypeFlags.TEX_UV \
			| DPArrayMesher.TypeFlags.COLOR \
			| DPArrayMesher.TypeFlags.INDEX);
		
	if solid and face:
		var corner_count : int = face.corners.size();
		
		# Generate normal
		var normal : Vector3 = -(solid.points[face.corners[1]].v3 - solid.points[face.corners[0]].v3).cross(
			solid.points[face.corners[2]].v3 - solid.points[face.corners[0]].v3).normalized();
		normal /= DioptraInterface.get_position_scale_top();
		normal *= DioptraInterface.get_position_scale_div();
			
		# Add glow mesh around the face
		var scale : float = DioptraInterface.get_position_scale_div() / float(DioptraInterface.get_position_scale_top());
		for corner_index in range(corner_count):
			var corner_0 := corner_index + 0;
			var corner_1 := (corner_index + 1) % corner_count;
			var corner_2 := (corner_index + 2) % corner_count;
			var corner_3 := (corner_index + 3) % corner_count;
			var point_0 := solid.points[face.corners[corner_0]].v3;
			var point_1 := solid.points[face.corners[corner_1]].v3;
			var point_2 := solid.points[face.corners[corner_2]].v3;
			var point_3 := solid.points[face.corners[corner_3]].v3;
			var d_12 = (point_2 - point_1).normalized() * scale * cGlowSize;
			var d_01 = (point_1 - point_0).normalized() * scale * cGlowSize;
			var d_23 = (point_3 - point_2).normalized() * scale * cGlowSize;
			var vert0 := am.get_vertex_count();
			am.point_add(point_1 + normal);
			am.point_add(point_1 + normal + d_01 - d_12);
			am.point_add(point_2 + normal);
			am.point_add(point_2 + normal - d_23 + d_12);
			am.tri_add_indicies(vert0 + 0, vert0 + 1, vert0 + 2);
			am.tri_add_indicies(vert0 + 2, vert0 + 1, vert0 + 3);
			am.get_surface_color()[vert0 + 0] = color_sel; 
			am.get_surface_color()[vert0 + 2] = color_sel;
			am.get_surface_color()[vert0 + 1] = color_sel * Color(1.0, 1.0, 1.0, 0.0);
			am.get_surface_color()[vert0 + 3] = color_sel * Color(1.0, 1.0, 1.0, 0.0);
		pass # End adding glowmesh
