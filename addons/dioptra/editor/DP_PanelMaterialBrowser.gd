@tool
extends Control

var _plugin : DioptraEditorMainPlugin = null;

@onready var _itemlist_assets : DPC_AssetItemList = $"Asset View Container/ItemContainer";

class CachedMaterialInfo:
	var _material : Material;
	var _idx : int;
	
	## Last used index in the viewer
	var last_used_index : int;
	## Flat thumbnail
	var thumb_flat : Texture2D;
	## Godot thumbnail
	var thumb_godot : Texture2D;
	
	func _init(mat : Material, idx : int) -> void:
		_material = mat;
		_idx = idx;
	func get_material() -> Material:
		return _material;
	func get_idx() -> int:
		return _idx;

## All materials currently loaded and possible to display
var _all_materials : Array[CachedMaterialInfo] = [];
## Current materials visible in the item list
var _visible_materials : Dictionary[int, CachedMaterialInfo] = {};

enum DisplayMode {
	FLAT, ## Displays flat
	GODOT, ## Displays with default godot thumbnail maker
};
## Current display mode of the items
var _display_mode : DisplayMode = DisplayMode.FLAT;

var _preview_worker_continue : bool = true;
var _preview_worker_thread : Thread;
var _preview_worker_semaphore : Semaphore;
var _preview_worker_request_mutex : Mutex;
var _preview_worker_request_items : Array[Material] = [];
var _preview_worker_request_indexes : Array[int] = [];
var _preview_worker_generator : DP_MaterialPreviewGenerator = null;

func _ready() -> void:
	_preview_worker_continue = true;
	_preview_worker_semaphore = Semaphore.new();
	_preview_worker_request_mutex = Mutex.new();
	_preview_worker_thread = Thread.new();
	_preview_worker_thread.start(_preview_build_thread);
	_preview_worker_generator = DP_MaterialPreviewGenerator.new(null);
	
	#var buttongroup_displaymode : ButtonGroup = $"Box Settings/ButtonFlat".button_group;
	#buttongroup_displaymode.pressed.connect(on_change_displaymode);
	pass
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_preview_worker_continue = false;
		if _preview_worker_semaphore:
			_preview_worker_semaphore.post();
		_preview_worker_thread.wait_to_finish();
		_preview_worker_generator = null;
	
func setPlugin(plugin : DioptraEditorMainPlugin) -> void:
	_plugin = plugin;
	_visible_materials = {};
	scan_materials();
	build_itemlist("");
	
#------------------------------------------------------------------------------#
	
func change_displaymode(mode : DisplayMode) -> void:
	if mode != _display_mode:
		_display_mode = mode;
	for item_index in range(_visible_materials.size()):
		var cached := _visible_materials[item_index];
		var icon := cached.thumb_godot;
		if _display_mode == DisplayMode.FLAT:
			icon = cached.thumb_flat;
		_itemlist_assets.set_item_icon(item_index, icon);
	
#------------------------------------------------------------------------------#

func scan_materials() -> void:
	var materials : Array[Material] = [];
	
	var extensions := ResourceLoader.get_recognized_extensions_for_type("Material");
	#TODO signifier or skip items internal to Dioptra
	var skip_list : PackedStringArray = [];
	
	# Build a list of every single resource as we scan
	var dirs : Array[String] = [];
	dirs.push_back("res://");
	while not dirs.is_empty():
		var dir_path := dirs.pop_front();
		var dir : DirAccess = DirAccess.open(dir_path);
		if not dir:
			continue;
		
		var dir_list := dir.get_current_dir();
		
		dir.list_dir_begin()
		var file_name : String;
		while true:
			file_name = dir.get_next();
			if file_name == "":
				break;
			if dir.current_is_dir():
				dirs.push_back(dir_path + "/" + file_name);
			else:
				var extension := file_name.get_extension().to_lower();
				if extensions.has(extension):
					# Actual file
					var resource := ResourceLoader.load(dir_path + "/" + file_name);
					if resource and resource.resource_path != "":
						var mat := resource as Material;
						if mat:
							materials.push_back(mat);
							
	# Cache the material!
	for mat in materials:
		_all_materials.push_back(CachedMaterialInfo.new(mat, _all_materials.size()));
		print(mat.resource_path);
	
func build_itemlist(filter : String) -> void:
	var materials : Array[CachedMaterialInfo] = [];
	
	if filter.is_empty():
		for cached in _all_materials:
			cached.last_used_index = -1;
			materials.push_back(cached);
	else:
		for cached in _all_materials:
			cached.last_used_index = -1;
			var mat := cached.get_material();
			if mat.resource_path.get_basename().contains(filter):
				materials.push_back(cached);
		
	set_items(materials);

func set_items(materials : Array[CachedMaterialInfo]) -> void:
	var previewer := EditorInterface.get_resource_previewer();
	
	_visible_materials.clear();
	_itemlist_assets.clear();
	for cached in materials:
		var mat := cached.get_material();
		var mat_name := mat.resource_path.get_basename().get_file();
		var icon := cached.thumb_godot;
		if _display_mode == DisplayMode.FLAT:
			icon = cached.thumb_flat;
				
		var item_index := _itemlist_assets.add_item(mat_name, icon, true);
		cached.last_used_index = item_index;
		_visible_materials[item_index] = cached;
		
		if cached.thumb_godot == null:
			previewer.queue_resource_preview(mat.resource_path, self, "_on_preview_done_genny", cached.get_idx());
		if cached.thumb_flat == null:
			_queue_resource_preview_internal(mat, cached.get_idx());
		
		pass
	pass

func _on_preview_done_genny(path : String, preview : Texture2D, thumbnail_preview : Texture2D, userdata : Variant) -> void:
	var index := userdata as int;
	var cached := _all_materials[index];
	cached.thumb_godot = preview;
	if _display_mode == DisplayMode.GODOT:
		_itemlist_assets.set_item_icon(cached.last_used_index, preview);
	pass
	
func _on_preview_done_genny_flat(path : String, preview : Texture2D, thumbnail_preview : Texture2D, userdata : Variant) -> void:
	var index := userdata as int;
	var cached := _all_materials[index];
	cached.thumb_flat = preview;
	if _display_mode == DisplayMode.FLAT:
		_itemlist_assets.set_item_icon(cached.last_used_index, preview);
	pass
	
#------------------------------------------------------------------------------#
	
	
	
#------------------------------------------------------------------------------#

func _queue_resource_preview_internal(item : Material, index : int) -> void:
	_preview_worker_request_mutex.lock();
	_preview_worker_request_items.push_back(item);
	_preview_worker_request_indexes.push_back(index);
	_preview_worker_request_mutex.unlock();
	_preview_worker_semaphore.post();
	pass
	
func _preview_build_thread() -> void:
	while true:
		_preview_worker_semaphore.wait();
		if not _preview_worker_continue:
			break;
			
		_preview_worker_request_mutex.lock();
		var item : Material = _preview_worker_request_items.pop_front();
		var index : int = _preview_worker_request_indexes.pop_front();
		_preview_worker_request_mutex.unlock();
		
		var tex := _preview_worker_generator._generate(item, DPHelpers.get_material_primary_texture_size(item).min(Vector2i(256, 256)), {});
		
		if tex:
			self.call_deferred("_on_preview_done_genny_flat", "", tex, tex, index);
	pass
