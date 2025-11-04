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
	var points : PackedVector3Array = [];
	var colors : PackedColorArray = []; 
	var width : float = 2.0;
	var segments : bool = false; ## Is this one big line or a collection of lines?

	func _init(lines : DPULines3D) -> void:
		#_lines = lines;
		pass
		
	## Requests an update to the lines. Call when the mesh changes.
	func update() -> void:
		#_lines._request_update();
		DPULines3D.request_update();

	## Releases the given node back to the pool
	func release() -> void:
		DPULines3D.release_item(self);

#------------------------------------------------------------------------------#

#var _used_lines : Array[LinesItem];
#var _unused_lines : Array[LinesItem];
#var _last_camera : Camera3D = null;
var _lines : Array[LinesItem];
var _line_renderer : MeshInstance3D;
var _line_rebuild_requested : bool = false;

#------------------------------------------------------------------------------#

func _init() -> void:
	#_used_lines = [];
	#_unused_lines = [];
	_lines = [];
	_line_renderer = MeshInstance3D.new();
	_line_renderer.owner = self;
	add_child(_line_renderer, false, Node.INTERNAL_MODE_FRONT);
	
	_line_rebuild_requested = false;
	pass
	
func _exit_tree() -> void:
	# Clean up all the items
	for item in _lines:
		if item != null:
			item.free();
	_lines.clear();
	# We shouldn't need to touch _line_renderer, as it's a child of this node.

func _process(delta: float) -> void:
	if _line_rebuild_requested:
		_line_rebuild_requested = false;
		rebuild_line_mesh();
	pass
	
#------------------------------------------------------------------------------#
	
## Requests the mesh to update the next time it's used
static func request_update() -> void:
	return get_instance()._request_update();
	
func _request_update() -> void:
	_line_rebuild_requested = true;
	
## Get a brand new label to draw the given text with
static func get_line() -> LinesItem:
	return get_instance()._get_line();

func _get_line() -> LinesItem:
	var line = LinesItem.new(self);
	_request_update();
	return line;
	
## Releases the given item from the list
static func release_item(line : LinesItem) -> void:
	return get_instance()._release_item(line);
	
func _release_item(line : LinesItem) -> void:
	var line_item_pos := _lines.find(line);
	if line_item_pos != -1:
		_lines[line_item_pos].free();
		_lines.remove_at(line_item_pos);
		_request_update();
	pass
	
#------------------------------------------------------------------------------#

## Rebuilds the internal line mesh immediately
func rebuild_line_mesh() -> void:
	var mesher := DPArrayMesher.new(DPArrayMesher.TypeFlags.VERTEX
		| DPArrayMesher.TypeFlags.NORMAL
		| DPArrayMesher.TypeFlags.COLOR | DPArrayMesher.TypeFlags.TEX_UV
		| DPArrayMesher.TypeFlags.INDEX);
	
	for item in _lines:
		# Skip invalid items
		if item == null:
			continue;
		# Ensure item has valid data
		assert(item._points.size() == item._colors.size());
		assert(item._points.size() >= 2);
		if item.segments:
			assert((item._points.size() % 2) == 0);
		# Loop through the points in the item
		var step_size := 2 if item.segments else 1;
		for i in range(0, item._points.size() - 1, step_size):
			var point_0 := item.points[i];
			var point_1 := item.points[i];
			var color_0 := item.colors[i];
			var color_1 := item.colors[i];
		
			var vertex_0 = mesher.get_vertex_count();
		
			mesher.add_point(point_0);
			mesher.add_point(point_0);
			mesher.add_point(point_1);
			mesher.add_point(point_1);
			
			mesher.quad_set_uvs(vertex_0, 
				Vector2(0.0, 0.5), Vector2(1.0, 0.5),
				Vector2(0.0, 0.5), Vector2(1.0, 0.5));
			mesher.quad_set_uv2s(vertex_0, 
				Vector2(item.width, 0.0), Vector2(item.width, 0.0),
				Vector2(item.width, 0.0), Vector2(item.width, 0.0));
			mesher.quad_set_normal(vertex_0, point_1 - point_0);
			mesher.quad_set_colors(vertex_0, color_0, color_0, color_1, color_1);
			
			mesher.quad_add_indicies(
				vertex_0, vertex_0 + 1,
				vertex_0 + 2, vertex_0 + 3);
			pass
		pass
		
	var old_mesh = _line_renderer.mesh;
	var new_mesh = ArrayMesh.new();
	new_mesh.add_surface_from_arrays(mesher.get_primitive_type(), mesher.get_surface_array());
	_line_renderer.mesh = new_mesh;
	
	# TODO: check if mesh is freeing properly
	old_mesh = null;
	
	pass # End rebuild_line_mesh
