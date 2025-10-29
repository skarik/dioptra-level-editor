class_name DPArrayMesher

## DPArrayMesher lets you make array meshes with ease!
## It kind of takes the mesh arrays and mushes them. Like a sled.
## Due to poor triangle strip restart support (35% of reported hardware supports Vulkan 1.3) this uses triangle lists.

var _surface_array : Array[Variant] = [];

enum TypeFlags {
	VERTEX = Mesh.ARRAY_FORMAT_VERTEX, ## Mesher contains vertices
	NORMAL = Mesh.ARRAY_FORMAT_NORMAL, ## Mesher contains normals
	TANGENT = Mesh.ARRAY_FORMAT_TANGENT, ## Mesher contains tangets
	COLOR = Mesh.ARRAY_FORMAT_COLOR, ## Mesher contains colors
	TEX_UV = Mesh.ARRAY_FORMAT_TEX_UV, ## Mesher contains UVs
	TEX_UV2 = Mesh.ARRAY_FORMAT_TEX_UV2, ## Mesher contains second UVs
	CUSTOM0 = Mesh.ARRAY_FORMAT_CUSTOM0, ## Mesher contains custom channel index 0
	CUSTOM1 = Mesh.ARRAY_FORMAT_CUSTOM1, ## Mesher contains custom channel index 1
	CUSTOM2 = Mesh.ARRAY_FORMAT_CUSTOM2, ## Mesher contains custom channel index 2
	CUSTOM3 = Mesh.ARRAY_FORMAT_CUSTOM3, ## Mesher contains custom channel index 3
	BONES = Mesh.ARRAY_FORMAT_BONES, ## Mesher contains bones
	WEIGHTS = Mesh.ARRAY_FORMAT_WEIGHTS, ## Mesher contains bone weights
	INDEX = Mesh.ARRAY_FORMAT_INDEX, ## Mesher uses indices
};
var _types_contained : int = 0;

var _vertex_count: int = 0;
var _index_count: int = 0;

# We ALWAYS use triangles for the AM
var _primitive_type : Mesh.PrimitiveType = Mesh.PRIMITIVE_TRIANGLES;

const _FuncQuads = preload("arraymesher_quads.gd");

## Creates a new DP with the given arrays available in it.
func _init(types : int = TypeFlags.VERTEX | TypeFlags.NORMAL | TypeFlags.TEX_UV | TypeFlags.INDEX) -> void:
	_surface_array = [];
	_surface_array.resize(Mesh.ARRAY_MAX);
	_types_contained = types;
	_vertex_count = 0;
	_index_count = 0;
	
	assert(_types_contained & TypeFlags.VERTEX);
	if (_types_contained & TypeFlags.VERTEX):
		_surface_array[Mesh.ARRAY_VERTEX] = PackedVector3Array();
	if (_types_contained & TypeFlags.NORMAL):
		_surface_array[Mesh.ARRAY_NORMAL] = PackedVector3Array();
	if (_types_contained & TypeFlags.TANGENT):
		_surface_array[Mesh.ARRAY_TANGENT] = PackedFloat32Array();
	if (_types_contained & TypeFlags.COLOR):
		_surface_array[Mesh.ARRAY_COLOR] = PackedColorArray();
	if (_types_contained & TypeFlags.TEX_UV):
		_surface_array[Mesh.ARRAY_TEX_UV] = PackedVector2Array();
	if (_types_contained & TypeFlags.TEX_UV2):
		_surface_array[Mesh.ARRAY_TEX_UV2] = PackedVector2Array();
	if (_types_contained & TypeFlags.CUSTOM0):
		_surface_array[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array();
	if (_types_contained & TypeFlags.CUSTOM1):
		_surface_array[Mesh.ARRAY_CUSTOM1] = PackedFloat32Array();
	if (_types_contained & TypeFlags.CUSTOM2):
		_surface_array[Mesh.ARRAY_CUSTOM2] = PackedFloat32Array();
	if (_types_contained & TypeFlags.CUSTOM3):
		_surface_array[Mesh.ARRAY_CUSTOM3] = PackedFloat32Array();
	if (_types_contained & TypeFlags.BONES):
		_surface_array[Mesh.ARRAY_BONES] = PackedInt32Array();
	if (_types_contained & TypeFlags.WEIGHTS):
		_surface_array[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array();
	if (_types_contained & TypeFlags.INDEX):
		_surface_array[Mesh.ARRAY_INDEX] = PackedInt32Array();
			
#------------------------------------------------------------------------------#
			
func get_surface_array() -> Array[Variant]:
	resize(_vertex_count, _index_count);
	return _surface_array;
func get_surface_vertex() -> PackedVector3Array:
	return _surface_array[Mesh.ARRAY_VERTEX];
func get_surface_normal() -> PackedVector3Array:
	return _surface_array[Mesh.ARRAY_NORMAL];
func get_surface_tex_uv() -> PackedVector2Array:
	return _surface_array[Mesh.ARRAY_TEX_UV];
func get_surface_index() -> PackedInt32Array:
	return _surface_array[Mesh.ARRAY_INDEX];
	
func get_primitive_type() -> Mesh.PrimitiveType:
	return _primitive_type;

#------------------------------------------------------------------------------#

## Resize the used type meshes to the given input amount.
## If the container finds that it needs more room, it still still allocate more.
func preallocate(vertices : int, indicies : int) -> void:
	for i in (Mesh.ARRAY_MAX - 1):
		var type_mask := 1 << i;
		if (_types_contained & type_mask):
			if (i == Mesh.ARRAY_TANGENT or i == Mesh.ARRAY_CUSTOM0 or i == Mesh.ARRAY_CUSTOM1 \
			or i == Mesh.ARRAY_CUSTOM2 or i == Mesh.ARRAY_CUSTOM3 or i == Mesh.ARRAY_BONES \
			or i == Mesh.ARRAY_WEIGHTS):
				if (_surface_array[i].size() < vertices * 4):
					_surface_array[i].resize(vertices * 4);
			else:
				if (_surface_array[i].size() < vertices):
					_surface_array[i].resize(vertices);
	if (_types_contained & TypeFlags.INDEX):
		if (_surface_array[Mesh.ARRAY_INDEX].size() < indicies):
			_surface_array[Mesh.ARRAY_INDEX].resize(indicies);
	pass
	
func preallocate_triangles(triangles : int) -> void:
	var vertexCount := triangles * 3;
	var indexCount := triangles * 3;
	preallocate(vertexCount, indexCount);
	
func preallocate_quads(quads : int) -> void:
	var vertexCount := quads * 4;
	var indexCount := quads * 6;
	preallocate(vertexCount, indexCount);
	
## Adds the given amount of storage
func add_storage(vertices : int, indicies : int) -> void:
	preallocate(_vertex_count + vertices, _index_count + indicies);

## Sets the storage to the given size and sets the vertex and index count to that same size
##
## Sets the internal arrays to the same size. Unlike preallocate, this will shrink arrays and delete
## data. This also sets the internal vertex and index count used for adding additional geometry and
## thus will affect any subsequent *_add calls.
func resize(vertices : int, indicies : int) -> void:
	for i in (Mesh.ARRAY_MAX - 1):
		var type_mask := 1 << i;
		if (_types_contained & type_mask):
			if (i == Mesh.ARRAY_TANGENT or i == Mesh.ARRAY_CUSTOM0 or i == Mesh.ARRAY_CUSTOM1 \
			or i == Mesh.ARRAY_CUSTOM2 or i == Mesh.ARRAY_CUSTOM3 or i == Mesh.ARRAY_BONES \
			or i == Mesh.ARRAY_WEIGHTS):
				_surface_array[i].resize(vertices * 4);
			else:
				_surface_array[i].resize(vertices);
	if (_types_contained & TypeFlags.INDEX):
		_surface_array[Mesh.ARRAY_INDEX].resize(indicies);
	_vertex_count = vertices;
	_index_count = indicies;
	pass
	
#------------------------------------------------------------------------------#
	
## Does this mesher have indicies?
func has_indicies() -> bool:
	return (_types_contained & TypeFlags.INDEX) != 0;
## Does this mesher have normals?
func has_normals() -> bool:
	return (_types_contained & TypeFlags.NORMAL) != 0;
## Does this mesher have UVs?
func has_uv() -> bool:
	return (_types_contained & TypeFlags.TEX_UV) != 0;
## Does this mesher have secondary UVs?
func has_uv2() -> bool:
	return (_types_contained & TypeFlags.TEX_UV2) != 0;
	
#------------------------------------------------------------------------------#

## Adds a quad to the positions.
##
## Adds a quad to the vertex positions, with normal if enabled. UVs added defaults to a 0,0 -> 1,1 cube.
func quad_add(position : Vector3, up : Vector3, right : Vector3) -> void:
	assert(has_indicies());
	_FuncQuads.quad_add(self, position, up, right);
