@tool
extends EditorNode3DGizmoPlugin

const cBlendSteps : int = 10;
const cIconSize : float = 0.02;

func _init():
	create_material("main", Color(0.2, 1.0, 0.5))
	create_material("handle_bars", Color(1.0, 1.0, 0.2, 0.5))
	create_handle_material("handles")
	create_icon_material("icon", preload("res://icon.svg"))
	pass

func _has_gizmo(node):
	return node is DP_PathNode;
	
#func _enter_tree():
	# Connect to the selection_changed signal.
	#EditorInterface.get_selection().connect("selection_changed", Callable(self, "_on_selection_changed"))
	
#func _exit_tree():
	# Disconnect the signal when the plugin is removed.
	#EditorInterface.get_selection().disconnect("selection_changed", Callable(self, "_on_selection_changed"))

func _get_gizmo_name() -> String:
	return "DP PathNode"

func _redraw(gizmo):
	gizmo.clear()

	var node3d = gizmo.get_node_3d()
	var pathnode = node3d as DP_PathNode;
	
	if pathnode.nextNode != null:
		gizmo.add_unscaled_billboard(get_material("icon", gizmo), cIconSize);
	else:
		gizmo.add_unscaled_billboard(get_material("icon", gizmo), cIconSize, Color(1.0, 0.5, 0.5, 1.0));

	if pathnode.nextNode != null:
		var lines = PackedVector3Array()
		
		var step_position_a : Vector3;
		var step_position_b : Vector3;
		var target_position : Vector3 = pathnode.nextNode.position - pathnode.position;
		
		for step in (cBlendSteps + 1):
			# Calulate next position
			var step_t : float = float(step) / cBlendSteps;
			step_position_a = step_position_b;
			step_position_b = lerp(
				pathnode.to * step_t,
				target_position + pathnode.nextNode.from * (1.0 - step_t),
				step_t);
			# Add the segment to drawing
			if (step != 0):
				# Segment
				lines.push_back(step_position_a);
				lines.push_back(step_position_b);
				# Indicator of Direction
				var lDelta := (step_position_b - step_position_a).normalized();
				var lSide := lDelta.cross(Vector3.UP).normalized();
				var lUp := lSide.cross(lDelta);
				lines.push_back(step_position_b);
				lines.push_back(step_position_b - (lDelta + lUp) * 0.1);
				lines.push_back(step_position_b);
				lines.push_back(step_position_b - (lDelta - lUp) * 0.1);
			pass;
		
		gizmo.add_lines(lines, get_material("main", gizmo), false)
		
	
	var handles = PackedVector3Array()
	
	var nodes = EditorInterface.get_selection().get_selected_nodes()
	if nodes.has(node3d):
		var handle_lines = PackedVector3Array()
		handle_lines.push_back(Vector3.ZERO)	
		handle_lines.push_back(pathnode.from * 0.5)
		handle_lines.push_back(Vector3.ZERO)	
		handle_lines.push_back(pathnode.to * 0.5)
		gizmo.add_lines(handle_lines, get_material("handle_bars", gizmo), false)
	
	handles.push_back(pathnode.from * 0.5)
	handles.push_back(pathnode.to * 0.5)
	gizmo.add_handles(handles, get_material("handles", gizmo), [])
