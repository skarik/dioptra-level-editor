@tool
extends EditorPlugin

var dock : Control;

const cTTSItemGizmoPlugin	:= preload("res://addons/TTSelectableTest/TTSItemGizmoPlugin.gd");
var mTTSItemGizmoPlugin : EditorNode3DGizmoPlugin;
const cTTSCubeGizmoPlugin	:= preload("res://addons/TTSelectableTest/Cube/TTSCubeGizmoPlugin.gd");
var mTTSCubeGizmoPlugin : EditorNode3DGizmoPlugin;


func add_gizmo_plugin(plugin_script : GDScript, plugin : EditorNode3DGizmoPlugin, loader : bool = false) -> EditorNode3DGizmoPlugin:
	if plugin == null:
		plugin = plugin_script.new();
	if plugin:
		if loader:
			plugin.reload()
		add_node_3d_gizmo_plugin(plugin)
	return plugin

func remove_gizmo_plugin(plugin : EditorNode3DGizmoPlugin, loader : bool = false) -> void:
	if plugin:
		if loader:
			plugin.unload()
		remove_node_3d_gizmo_plugin(plugin)

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	
	dock = preload("res://addons/TTSelectableTest/TTSDock.tscn").instantiate()
	if dock:
		#add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)
		pass
	
	mTTSItemGizmoPlugin = add_gizmo_plugin(cTTSItemGizmoPlugin, mTTSItemGizmoPlugin, true);
	mTTSCubeGizmoPlugin = add_gizmo_plugin(cTTSCubeGizmoPlugin, mTTSCubeGizmoPlugin);
	
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	
	if dock:
		#remove_control_from_docks(dock)
		dock.free()
		pass
	
	remove_gizmo_plugin(mTTSItemGizmoPlugin, true);
	remove_gizmo_plugin(mTTSCubeGizmoPlugin);
	
	pass
