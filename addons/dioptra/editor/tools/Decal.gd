extends DPUTool
class_name DPUTool_Decal

func _init(plugin : DioptraEditorMainPlugin) -> void:
	super(plugin);
	#_ghost_box = DPUBoxGhost.new();
	
func cleanup() -> void:
	pass
	
## Overrideable GUI input handling
func forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	
	# TODO: grab the last selected material and use that as a decal that we just BIPBAP on with a click
	# OR: wait for a material to be set in the material editor.
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS;
	
func process(delta: float) -> void:
	pass
	
#------------------------------------------------------------------------------#
