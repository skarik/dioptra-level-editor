@tool
extends EditorNode3DGizmoPlugin
## General purpose ToolCube gizmo plugin for doing Item gizmos

var enabled : bool = false;

func _init(undoredo : EditorUndoRedoManager) -> void:
	pass

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return enabled and (for_node_3d is EditorDP_InternalTool);
	
func _get_gizmo_name() -> String:
	return "DP Tool Cube"

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
