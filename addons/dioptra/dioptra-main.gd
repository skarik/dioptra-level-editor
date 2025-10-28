@tool
extends EditorPlugin

# The main plugin is located at res://addons/dioptra/
const cPluginName = "dioptra"

func _enable_plugin() -> void:
	EditorInterface.set_plugin_enabled(cPluginName + "/node-types", true)
	EditorInterface.set_plugin_enabled(cPluginName + "/editor", true)

func _disable_plugin() -> void:
	EditorInterface.set_plugin_enabled(cPluginName + "/node-types", false)
	EditorInterface.set_plugin_enabled(cPluginName + "/editor", false)

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
