@tool
extends EditorPlugin

const cDPG_PathNode = preload("res://addons/dioptra/editor/gizmos/DPG_PathNode.gd");
var DPGizmoPlugin_PathNode = null;

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	
	if DPGizmoPlugin_PathNode == null:
		DPGizmoPlugin_PathNode = cDPG_PathNode.new(get_undo_redo());
	
	if DPGizmoPlugin_PathNode:
		add_node_3d_gizmo_plugin(DPGizmoPlugin_PathNode)
	
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	
	if DPGizmoPlugin_PathNode:
		remove_node_3d_gizmo_plugin(DPGizmoPlugin_PathNode)
		
	DPGizmoPlugin_PathNode = null;
	
	pass
