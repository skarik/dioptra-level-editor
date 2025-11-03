@tool
extends EditorPlugin
class_name DioptraEditorMainPlugin

#------------------------------------------------------------------------------#

enum ToolMode {
	SELECT = 0,
	BOX_TEST = 1,
}

#------------------------------------------------------------------------------#

const cDPG_PathNode := preload("res://addons/dioptra/editor/gizmos/DPG_PathNode.gd");
var DPGizmoPlugin_PathNode : EditorNode3DGizmoPlugin = null;

const cDPG_ToolCube := preload("res://addons/dioptra/editor/gizmos/DPG_ToolCube.gd");
var DPGizmoPlugin_ToolCube : EditorNode3DGizmoPlugin = null;

const cDock_Tools := preload("res://addons/dioptra/editor/panel-tools.tscn");
var DPDock_Tools : Control = null;
const cScript_Tools := preload("res://addons/dioptra/editor/DP_PanelTools.gd");

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
	
	if DPDock_Tools == null:
		DPDock_Tools = cDock_Tools.instantiate()
	if DPDock_Tools:
		add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, DPDock_Tools);
		var tools := DPDock_Tools as cScript_Tools;
		tools.setPlugin(self);
	pass

func _exit_tree() -> void:
	stop_gizmo_plugin(DPGizmoPlugin_PathNode);
	DPGizmoPlugin_PathNode = null;
		
	stop_gizmo_plugin(DPGizmoPlugin_ToolCube);
	DPGizmoPlugin_ToolCube = null;
	
	if DPDock_Tools:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, DPDock_Tools);
		DPDock_Tools.queue_free()
	pass

#------------------------------------------------------------------------------#

var _editorNode : EditorDP_InternalTool = null;
var _currentTool : DPUTool = null;

func onToolSelect(tool : ToolMode) -> void:
	# We want to make a EditorDP_InternalTool node.
	if _editorNode == null:
		# Create the new node
		_editorNode = EditorDP_InternalTool.new();
		# We need this node in the scene so it can update the sizes of items
		EditorInterface.get_edited_scene_root().add_child(_editorNode, false, Node.INTERNAL_MODE_FRONT);
	
	# Switch to the editor mode
	EditorInterface.get_selection().clear();
	if tool != ToolMode.SELECT:
		_editorNode.basis = Basis.IDENTITY;
		_editorNode.global_position = Vector3.ZERO;
		EditorInterface.get_selection().add_node(_editorNode);
	else:
		_editorNode.queue_free();
	
	var newTool : DPUTool = null;
	# Select the type of tool:
	if tool == ToolMode.SELECT:
		if _currentTool != null:
			_currentTool.cleanup();
		_currentTool = null;
	elif tool == ToolMode.BOX_TEST:
		if not (_currentTool is DPUTool_BoxTest):
			newTool = DPUTool_BoxTest.new(self);
	
	# Switch to the new tool after cleaning up
	if newTool != null:
		if _currentTool != null:
			_currentTool.cleanup();
		_currentTool = newTool;
	
	# Tools will be automatically cleared as they are RefCounted.
	
	pass

## Returns editor node, mostly for updating gizmos
#func get_editor_node() -> EditorDP_InternalTool:
	#return _editorNode;

#------------------------------------------------------------------------------#

# Handle the DP_InternalTool, which lets us actually perform work with the editor
func _handles(object: Object) -> bool:
	if object is EditorDP_InternalTool:
		return true;
	return false;
	
func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if _currentTool != null:
		return _currentTool.forward_3d_gui_input(viewport_camera, event);
	return EditorPlugin.AFTER_GUI_INPUT_PASS;
