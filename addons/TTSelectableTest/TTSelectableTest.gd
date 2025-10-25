@tool
extends EditorPlugin

var dock : Control;

const cTTSItemGizmoPlugin = preload("res://addons/TTSelectableTest/TTSItemGizmoPlugin.gd");
var gizmo_plugin = cTTSItemGizmoPlugin.new();

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	
	dock = preload("res://addons/TTSelectableTest/TTSDock.tscn").instantiate()
	if dock:
		#add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)
		pass
	
	if gizmo_plugin:
		gizmo_plugin.reload()
		add_node_3d_gizmo_plugin(gizmo_plugin)
	
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	
	if dock:
		#remove_control_from_docks(dock)
		dock.free()
		pass
	
	if gizmo_plugin:
		gizmo_plugin.unload()
		remove_node_3d_gizmo_plugin(gizmo_plugin)
	
	pass
