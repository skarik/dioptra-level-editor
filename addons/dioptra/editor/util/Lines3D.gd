@tool
extends Node3D
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
	add_child(_line_renderer, false, Node.INTERNAL_MODE_FRONT);
	_line_renderer.owner = self;
	
	_line_rebuild_requested = false;
	pass
	
func _exit_tree() -> void:
	# Clean up all the items
	for item in _lines:
		#if item != null:
		#	item.free();
		item = null;
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
	_lines.push_back(line);
	_request_update();
	return line;
	
## Releases the given item from the list
static func release_item(line : LinesItem) -> void:
	return get_instance()._release_item(line);
	
func _release_item(line : LinesItem) -> void:
	var line_item_pos := _lines.find(line);
	if line_item_pos != -1:
		#_lines[line_item_pos].free();
		_lines.remove_at(line_item_pos);
		_request_update();
	pass
	
#------------------------------------------------------------------------------#

## Rebuilds the internal line mesh immediately
func rebuild_line_mesh() -> void:
	var am := DPArrayMesher.new(DPArrayMesher.TypeFlags.VERTEX \
		| DPArrayMesher.TypeFlags.NORMAL \
		| DPArrayMesher.TypeFlags.COLOR | DPArrayMesher.TypeFlags.TEX_UV \
		| DPArrayMesher.TypeFlags.TEX_UV2 \
		| DPArrayMesher.TypeFlags.INDEX);
	
	for item in _lines:
		# Skip invalid items
		if item == null:
			continue;
		# Ensure item has valid data
		assert(item.points.size() == item.colors.size());
		assert(item.points.size() >= 2);
		if item.segments:
			assert((item.points.size() % 2) == 0);
		# Loop through the points in the item
		var step_size := 2 if item.segments else 1;
		am.preallocate(item.points.size() * 8 / step_size, item.points.size() * 12 / step_size);
		for i in range(0, item.points.size() - 1, step_size):
			var point_0 := item.points[i];
			var point_1 := item.points[i + 1];
			var color_0 := item.colors[i];
			var color_1 := item.colors[i + 1];
		
			var vertex_0 = am.get_vertex_count();
		
			am.point_add(point_0 + Vector3.LEFT * 0.1);
			am.point_add(point_0 + Vector3.UP * 0.1);
			am.point_add(point_1 + Vector3.LEFT * 0.1);
			am.point_add(point_1 + Vector3.UP * 0.1);
			
			am.quad_set_uvs(vertex_0, 
				Vector2(0.0, 0.5), Vector2(1.0, 0.5),
				Vector2(0.0, 0.5), Vector2(1.0, 0.5));
			am.quad_set_uv2s(vertex_0, 
				Vector2(item.width, 0.0), Vector2(item.width, 0.0),
				Vector2(item.width, 0.0), Vector2(item.width, 0.0));
			am.quad_set_normal(vertex_0, point_1 - point_0);
			am.quad_set_colors(vertex_0, color_0, color_0, color_1, color_1);
			
			am.quad_add_indicies(
				vertex_0, vertex_0 + 1,
				vertex_0 + 2, vertex_0 + 3);
			pass
		pass
		
	if am.get_index_count() > 0:
		var old_mesh = _line_renderer.mesh;
		var new_mesh = ArrayMesh.new();
		new_mesh.add_surface_from_arrays(am.get_primitive_type(), am.get_surface_array());
		new_mesh.surface_set_material(0, preload("res://addons/dioptra/editor/util/line3d_material.tres"));
		_line_renderer.mesh = new_mesh;
		
		# TODO: check if mesh is freeing properly
		old_mesh = null;
		pass
	else:
		var old_mesh = _line_renderer.mesh;
		_line_renderer.mesh = null;
		
		# TODO: check if mesh is freeing properly
		old_mesh = null;
		pass
		
		
	pass # End rebuild_line_mesh
