@tool
extends Control

var _plugin : DioptraEditorMainPlugin = null;

#@onready var _itemlist_assets : ItemList = $"Box Asset View/ItemList";
@onready var _itemlist_assets : DPC_AssetItemList = $"Asset View Container/ItemContainer";
var _materials : Dictionary[int, Material] = {};

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
	_materials = {};
	scan_materials("");
	
#------------------------------------------------------------------------------#

func scan_materials(filter : String) -> void:
	var materials : Array[Material] = [];
	
	var extensions := ResourceLoader.get_recognized_extensions_for_type("Material");
	
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
	
	set_items(materials);


func set_items(materials : Array[Material]) -> void:
	var previewer := EditorInterface.get_resource_previewer();
	
	_itemlist_assets.clear();
	for mat in materials:
		var mat_name := mat.resource_path.get_basename().get_file();
		var item_index := _itemlist_assets.add_item(mat_name, null, true);
		#previewer.queue_resource_preview(mat.resource_path, self, "_on_preview_done_genny", item_index);
		_queue_resource_preview_internal(mat, item_index);
		
		#TODO signifier or skip items internal to Dioptra
		pass
	
	pass

func _on_preview_done_genny(path : String, preview : Texture2D, thumbnail_preview : Texture2D, userdata : Variant) -> void:
	var index := userdata as int;
	_itemlist_assets.set_item_icon(index, preview);
	pass
	
	
	
	
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
			self.call_deferred("_on_preview_done_genny", "", tex, tex, index);
	pass
