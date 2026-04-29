@tool
extends Control
class_name DP_PanelMaterialBrowser;

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

var _preview_worker : DP_MaterialBrowserWorker = null;

var _last_filter : String = "";

func _ready() -> void:
	if not _preview_worker:
		_preview_worker = DP_MaterialBrowserWorker.new(self);
	_preview_worker.start_working();
	pass
	
func _exit_tree() -> void:
	if _preview_worker:
		_preview_worker.stop_working();
		_preview_worker.free();
	
func setPlugin(plugin : DioptraEditorMainPlugin) -> void:
	_plugin = plugin;
	_visible_materials = {};
	scan_materials(true);
	
#------------------------------------------------------------------------------#

func _process(delta: float) -> void:
	if _preview_worker:
		_preview_worker.process();
	
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
		
func clear_filter() -> void:
	var line_edit := $"Box File Tree/VBoxContainer/Filter Container/LineEdit";
	line_edit.text = "";
	line_edit.text_changed.emit("");
	
#------------------------------------------------------------------------------#

func scan_materials(rebuild_itemlist : bool = false) -> void:
	var materials : Array[Material] = [];
	
	#TODO signifier or skip items internal to Dioptra
	var skip_list : PackedStringArray = ["addons/dioptra/"];
	
	# TODO: sub to EditorFileSystem signals: resources_reimported, resources_reload
	
	# If we're still scanning the filesystem, defer the call until the next frame
	if EditorInterface.get_resource_filesystem().is_scanning():
		get_tree().process_frame.connect(scan_materials.bind(rebuild_itemlist), CONNECT_ONE_SHOT);
		return;
	
	var dirs : Array[EditorFileSystemDirectory] = [];
	dirs.push_back(EditorInterface.get_resource_filesystem().get_filesystem());
	while not dirs.is_empty():
		var dir : EditorFileSystemDirectory = dirs.pop_front();
		if not dir:
			continue;
		# Add subdirs to search
		for dir_idx in dir.get_subdir_count():
			var subdir := dir.get_subdir(dir_idx);
			# Check if dir in skip list
			var skip := false;
			for skip_item in skip_list:
				if subdir.get_path().to_lower().contains(skip_item):
					skip = true;
					break;
			if not skip:
				dirs.push_back(subdir);
			pass # End subdirs loop
		# Go through files
		for file_idx in dir.get_file_count():
			# Skip broken files
			if not dir.get_file_import_is_valid(file_idx):
				continue;
			var file_type := dir.get_file_type(file_idx);
			if ClassDB.is_parent_class(file_type, "Material"):
				var file_path := dir.get_file_path(file_idx);
				var skip = false;
				for skip_item in skip_list:
					if file_path.to_lower().contains(skip_item):
						skip = true;
						break;
				if not skip:
					# Actual file
					var resource := ResourceLoader.load(file_path);
					if resource and resource.resource_path != "":
						var mat := resource as Material;
						if mat:
							materials.push_back(mat);
			pass # End subfile loop
		pass # End while dirs loop
	
	# Cache the material!
	for mat in materials:
		_all_materials.push_back(CachedMaterialInfo.new(mat, _all_materials.size()));
		
	if rebuild_itemlist:
		build_itemlist(_last_filter);
		
	return; # End scan_materials
	
func build_itemlist(filter : String) -> void:
	var materials : Array[CachedMaterialInfo] = [];
	
	_last_filter = filter;
	
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
			_preview_worker.queue_resource_preview_internal(mat, cached.get_idx());
		
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
	
func on_item_clicked(index : int) -> void:
	# Update UI with the material
	var texturing_dock := _plugin.DPDock_Texturing as DioptraEditorMainPlugin.cScript_Texturing; # circular, reboot godot
	if texturing_dock:
		var mat := _visible_materials[index].get_material() if _visible_materials.has(index) else null;
		if mat:
			texturing_dock.update_ui_with_material(mat);
	pass

func on_item_double_clicked(index : int) -> void:
	var mat := _visible_materials[index].get_material() if _visible_materials.has(index) else null;
	if mat:
		var texturing_dock := _plugin.DPDock_Texturing as DioptraEditorMainPlugin.cScript_Texturing; # circular, reboot godot
		if texturing_dock:
			texturing_dock.update_ui_with_material(mat);
		_plugin._plugin_maphelper.do_assign_material(mat);
	pass
	
#------------------------------------------------------------------------------#
