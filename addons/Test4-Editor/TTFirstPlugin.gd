@tool
extends EditorPlugin


# A class member to hold the dock during the plugin life cycle.
var dock

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	
	dock = preload("res://addons/Test4-Editor/TTFPDock.tscn").instantiate()
	
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)
	
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	
	# Remove the dock.
	remove_control_from_docks(dock)
	# Erase the control from the memory.
	dock.free()
	pass


func _process(delta):
	if Engine.is_editor_hint():
		# Code to execute in editor.
		pass

	if not Engine.is_editor_hint():
		# Code to execute in game.
		pass

	# Code to execute both in editor and in game.
	pass
