@tool
extends Object
class_name DP_MaterialBrowserWorker;

var _panel : DP_PanelMaterialBrowser = null;

var _thread_continue : bool = true;
var _thread : Thread;
var _semaphore : Semaphore;
var _request_mutex : Mutex;
var _request_items : Array[Material] = [];
var _request_indexes : Array[int] = [];
var _generator : DP_MaterialPreviewGenerator = null;

func _init(panel : DP_PanelMaterialBrowser) -> void:
	_panel = panel;
	
	_thread_continue = true;
	_semaphore = Semaphore.new();
	_request_mutex = Mutex.new();
	_thread = Thread.new();
	_generator = DP_MaterialPreviewGenerator.new(null);
	pass
	
func start_working() -> void:
	if not _thread.is_alive():
		_thread.start(_preview_build_thread);
	
	pass
	
func stop_working() -> void:
	_thread_continue = false;
	if _semaphore:
		_semaphore.post();
	if _thread.is_alive():
		_thread.wait_to_finish();
	_generator = null;

func process() -> void:
	pass

## Push an item to have a preview generated
func queue_resource_preview_internal(item : Material, index : int) -> void:
	_request_mutex.lock();
	_request_items.push_back(item);
	_request_indexes.push_back(index);
	_request_mutex.unlock();
	_semaphore.post();
	pass
	
	
# Worker thread
func _preview_build_thread() -> void:
	while true:
		_semaphore.wait();
		if not _thread_continue:
			break;
			
		_request_mutex.lock();
		var item : Material = _request_items.pop_front();
		var index : int = _request_indexes.pop_front();
		_request_mutex.unlock();
		
		var tex := _generator._generate(item, DPHelpers.get_material_primary_texture_size(item).min(Vector2i(256, 256)), {});
		
		# If we have a texture, pass it to the main thread with a call_deferred
		if tex:
			_panel._on_preview_done_genny_flat.call_deferred("", tex, tex, index);
	pass
