extends Node
class_name DPULines3D

#------------------------------------------------------------------------------#

# Singleton definition
static var _Instance : DPULines3D = null;
## Return current singleton instance of the label pool
static func get_instance() -> DPULines3D:
	if _Instance == null:
		# Create the new node
		_Instance = DPULines3D.new();
		# We need this node in the scene so it can update the camera position.
		EditorInterface.get_edited_scene_root().add_child(_Instance, false, Node.INTERNAL_MODE_FRONT);
	return _Instance;
static func free_instance() -> void:
	if _Instance != null:
		_Instance.queue_free();
	_Instance = null;
	
# Options
#static var TextFixedSize : bool = true;
#static var UseCodeFont : bool = true;

#------------------------------------------------------------------------------#

## Item in the node pool with utilities of memory management
class LinesItem:
	#var _lines : DPULines3D;
	var _points : PackedVector3Array;
	var _colors : PackedColorArray; 

	func _init(lines : DPULines3D):
		#_lines = lines;
		pass

#------------------------------------------------------------------------------#

#var _used_lines : Array[LinesItem];
#var _unused_lines : Array[LinesItem];
#var _last_camera : Camera3D = null;
var _lines : Array[LinesItem];
var _line_renderer : MeshInstance3D;

#------------------------------------------------------------------------------#

func _init() -> void:
	#_used_lines = [];
	#_unused_lines = [];
	_lines = [];
	_line_renderer = MeshInstance3D.new();
	_line_renderer.owner = self;
	add_child(_line_renderer, false, Node.INTERNAL_MODE_FRONT);
	pass
	
func _exit_tree() -> void:
	# Clean up all the items
	for item in _lines:
		item.free();
	_lines.clear();
	# We shouldn't need to touch _line_renderer, as it's a child of this node.

func _process(delta: float) -> void:
	pass
	
#------------------------------------------------------------------------------#
	
func rebuild_line_mesh() -> void:
	
	var mesher := DPArrayMesher.new(DPArrayMesher.TypeFlags.VERTEX
		| DPArrayMesher.TypeFlags.NORMAL
		| DPArrayMesher.TypeFlags.COLOR | DPArrayMesher.TypeFlags.TEX_UV
		| DPArrayMesher.TypeFlags.INDEX);
	
	for item in _lines:
		assert(item._points.size() == item._colors.size());
		assert(item._points.size() >= 2);
		for i in item._points.size() - 1:
			var point_0 := item._points[i];
			var point_1 := item._points[i];
			var color_0 := item._colors[i];
			var color_1 := item._colors[i];
		
			var vertex_0 = mesher.get_vertex_count();
		
			mesher.add_point(point_0);
			mesher.add_point(point_0);
			mesher.add_point(point_1);
			mesher.add_point(point_1);
			
			mesher.quad_add_indicies(
				vertex_0, vertex_0 + 1,
				vertex_0 + 2, vertex_0 + 3);
			mesher.quad_set_uvs(vertex_0, 
				Vector2(0.0, 0.5), Vector2(1.0, 0.5),
				Vector2(0.0, 0.5), Vector2(1.0, 0.5));
			mesher.quad_set_normal(vertex_0, point_1 - point_0);
			mesher.quad_set_colors(vertex_0, color_0, color_0, color_1, color_1);
		
		pass
		
	var old_mesh = _line_renderer.mesh;
	var new_mesh = ArrayMesh.new();
	new_mesh.add_surface_from_arrays(mesher.get_primitive_type(), mesher.get_surface_array());
	_line_renderer.mesh = new_mesh;
