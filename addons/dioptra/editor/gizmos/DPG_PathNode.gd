@tool
extends EditorNode3DGizmoPlugin

const cBlendSteps : int = 10;
const cIconSize : float = 0.02;

static var PathNodeList : Array[DP_PathNode] = [];

enum DragMode {DRAG_NONE, DRAG_CONNECTION, DRAG_FROM, DRAG_TO};
var mouseDragMode : DragMode = DragMode.DRAG_NONE;
var mouseDragPosition : Vector3 = Vector3.ZERO;

var mUndoRedo : EditorUndoRedoManager = null;

func _init(undoredo : EditorUndoRedoManager):
	create_material("main", Color(0.2, 1.0, 0.5))
	create_material("handle_bars", Color(1.0, 1.0, 0.2, 0.5))
	create_handle_material("handles")
	create_icon_material("icon", preload("res://icon.svg"))
	
	mUndoRedo = undoredo;
	pass
	
func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is DP_PathNode;
	
#func _enter_tree():
	# Connect to the selection_changed signal.
	#EditorInterface.get_selection().connect("selection_changed", Callable(self, "_on_selection_changed"))
	
#func _exit_tree():
	# Disconnect the signal when the plugin is removed.
	#EditorInterface.get_selection().disconnect("selection_changed", Callable(self, "_on_selection_changed"))

func _get_gizmo_name() -> String:
	return "DP PathNode"

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var node3d := gizmo.get_node_3d()
	var pathnode := node3d as DP_PathNode;
	
	if not PathNodeList.has(pathnode):
		PathNodeList.append(pathnode);
	
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
	
	if pathnode.nextNode == null and mouseDragPosition != null:
		handles.push_back(mouseDragPosition);
	handles.push_back(pathnode.from * 0.5)
	handles.push_back(pathnode.to * 0.5)
	gizmo.add_handles(handles, get_material("handles", gizmo), [])

func _begin_handle_action(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> void:
	var node3d := gizmo.get_node_3d()
	var pathnode := node3d as DP_PathNode;
	
	if pathnode.nextNode == null:
		mouseDragMode = DragMode.DRAG_CONNECTION;
	pass

## Returns the z-depth of the position in relation to the camera
func get_z_depth(camera: Camera3D, position: Vector3) -> float:
	var cameraPosition := camera.global_position;
	var cameraForward := -camera.global_transform.basis.z;
	var toPosition := position - cameraPosition;
	return toPosition.dot(cameraForward);

func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var node3d := gizmo.get_node_3d()
	var pathnode := node3d as DP_PathNode;
	
	# Are we in connection mode?
	if pathnode.nextNode == null or mouseDragMode == DragMode.DRAG_CONNECTION:
		mouseDragPosition = camera.project_position(screen_pos, get_z_depth(camera, pathnode.global_position)) * pathnode.global_transform;
		mouseDragMode = DragMode.DRAG_CONNECTION;
		pathnode.update_gizmos();
		
		# Find all the similar nodes in the connection radius:
		var closestNode : DP_PathNode = null;
		const cConnectionRadius : float = 20.0 * 20.0;
		for node in PathNodeList:
			if node != null and node != pathnode:
				var pos2d = camera.unproject_position(node.global_position)
				if (pos2d - screen_pos).length_squared() < cConnectionRadius:
					if closestNode == null:
						closestNode = node;
					else:
						var lc = (closestNode.global_position - camera.global_position).length_squared();
						var ln = (node.global_position - camera.global_position).length_squared();
						if ln < lc:
							closestNode = node;
		if closestNode != null:
			pathnode.nextNode = closestNode;
			mouseDragPosition = closestNode.global_position * pathnode.global_transform
		else:
			pathnode.nextNode = null;
		pass
	else:
		
		pass
	
	pass

func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	var node3d := gizmo.get_node_3d()
	var pathnode := node3d as DP_PathNode;
	
	var undoRedo = gizmo.get_plugin().mUndoRedo; 
	
	match mouseDragMode:
		DragMode.DRAG_CONNECTION:
			#var undoRedo = UndoRedo.new();
			undoRedo.create_action("Pathnode Edit");
			undoRedo.add_do_property(pathnode, "nextNode", pathnode.nextNode);
			undoRedo.add_undo_property(pathnode, "nextNode", restore);
			undoRedo.commit_action();
		_:
			pass
	
	mouseDragPosition = Vector3.ZERO;
	mouseDragMode = DragMode.DRAG_NONE;
	
	pass
