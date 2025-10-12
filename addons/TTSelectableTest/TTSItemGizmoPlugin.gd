@tool
extends EditorNode3DGizmoPlugin
class_name TTSItemGizmoPlugin

var mSelectMesh : Mesh;

func reload() -> void:
	unloadResources();
	loadResources();
func unload() -> void:
	unloadResources();

func loadResources() -> void:
	if (mSelectMesh == null):
		mSelectMesh = SphereMesh.new();
		mSelectMesh.radial_segments = 8;
		mSelectMesh.rings = 4;
		mSelectMesh.request_update();
	assert(mSelectMesh != null);

func unloadResources() -> void:
	if (mSelectMesh != null):
		mSelectMesh = null # Clear reference
	pass

func _init():
	create_material("main", Color(1, 0, 0))
	create_handle_material("handles")
	
	loadResources()
	print("init plugin gizmo %d" % self.get_instance_id())
	pass
	
func _create_gizmo(node):
	if node is TTSItem:
		return TTSItemGizmo.new()
	else:
		return null

func _get_gizmo_name() -> String:
	return "TTS Item"
