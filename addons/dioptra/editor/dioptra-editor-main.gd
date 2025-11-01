@tool
extends EditorPlugin
class_name DioptraEditorMainPlugin

#------------------------------------------------------------------------------#

const cDPG_PathNode := preload("res://addons/dioptra/editor/gizmos/DPG_PathNode.gd");
var DPGizmoPlugin_PathNode : EditorNode3DGizmoPlugin = null;

const cDPG_ToolCube := preload("res://addons/dioptra/editor/gizmos/DPG_ToolCube.gd");
var DPGizmoPlugin_ToolCube : EditorNode3DGizmoPlugin = null;

#------------------------------------------------------------------------------#

## Starts the given gizmo plugin, instantiating it if it's not read with the given factor
func start_gizmo_plugin(item : EditorNode3DGizmoPlugin, factory : Callable) -> EditorNode3DGizmoPlugin:
	if item == null:
		item = factory.call();
	if item:
		add_node_3d_gizmo_plugin(item);
	return item;
	
## Stops the given gizmo plugin if it's valid
func stop_gizmo_plugin(item : EditorNode3DGizmoPlugin) -> void:
	if item:
		remove_node_3d_gizmo_plugin(item);
	pass

func _enter_tree() -> void:
	DPGizmoPlugin_PathNode = start_gizmo_plugin(DPGizmoPlugin_PathNode, func(): return cDPG_PathNode.new(get_undo_redo()) );
	DPGizmoPlugin_ToolCube = start_gizmo_plugin(DPGizmoPlugin_ToolCube, func(): return cDPG_ToolCube.new(get_undo_redo()) );
	pass

func _exit_tree() -> void:
	stop_gizmo_plugin(DPGizmoPlugin_PathNode);
	DPGizmoPlugin_PathNode = null;
		
	stop_gizmo_plugin(DPGizmoPlugin_ToolCube);
	DPGizmoPlugin_ToolCube = null;
	pass

#------------------------------------------------------------------------------#

# Handle the DP_InternalTool, which lets us actually perform work with the editor
func _handles(object: Object) -> bool:
	if object is EditorDP_InternalTool:
		return true;
	return false;
	
	
