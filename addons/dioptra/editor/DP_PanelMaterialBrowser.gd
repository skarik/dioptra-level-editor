@tool
extends Control

var _plugin : DioptraEditorMainPlugin = null;

#@onready var _itemlist_assets : ItemList = $"Box Asset View/ItemList";
@onready var _itemlist_assets : DPC_AssetItemList = $"Asset View Container/ItemContainer";

func _ready() -> void:
	pass
	
func setPlugin(plugin : DioptraEditorMainPlugin) -> void:
	_plugin = plugin;
	scan_materials("");

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
		previewer.queue_resource_preview(mat.resource_path, self, "_on_preview_done_genny", item_index);
		
		#TODO signifier or skip items internal to Dioptra
		pass
	
	pass

func _on_preview_done_genny(path : String, preview : Texture2D, thumbnail_preview : Texture2D, userdata : Variant) -> void:
	var index := userdata as int;
	_itemlist_assets.set_item_icon(index, preview);
	pass
