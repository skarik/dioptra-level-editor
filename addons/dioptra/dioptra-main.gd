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
	DioptraInterface.init_instance();
	pass

func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	DPULabelPool.free_instance();
	DioptraInterface.free_instance();
	pass

func _has_main_screen():
	return false;
func _get_plugin_name() -> String:
	return "Dioptra";
func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/dioptra/asset/plugin-icon-white.svg");

func _get_window_layout(configuration: ConfigFile) -> void:
	# TODO: use for saving global dioptra settings data.
	pass
