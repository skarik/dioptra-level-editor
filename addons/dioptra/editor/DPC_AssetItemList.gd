@tool
extends Control
class_name DPC_AssetItemList

static var UseCodeFont : bool = true;

var _reference_item : Control;#= $ReferenceItem;

var _item_dict : Dictionary[int, Control] = {};

func _ready() -> void:
	#_reference_item.visible = false;
	pass
	
func _setup_if_not_ready() -> void:
	if _reference_item == null:
		_reference_item = $ReferenceItem;
	_reference_item.visible = false;

func clear() -> void:
	_setup_if_not_ready();
	
	# Clear clear off all the child items
	_item_dict.clear();
	for child in get_children():
		var control := child as Control;
		if control and control != _reference_item:
			remove_child(control);
			control.queue_free();
	pass
	
func add_item(text: String, icon: Texture2D = null, selectable: bool = true) -> int:
	_setup_if_not_ready();
	var item := _reference_item.duplicate() as Control;
	if item == null:
		push_error("Couldn't create item, duplicating reference was null <%s>" % _reference_item.to_string());
		return -1;
	add_child(item);
	item.visible = true;
	
	var index := _item_dict.size();
	_item_dict[index] = item;

	var tex_rect : TextureRect = item.get_node("VBoxContainer/TextureRect");
	var label : Label = item.get_node("VBoxContainer/LabelName");
	
	tex_rect.texture = icon;
	label.text = text;
	if UseCodeFont:
		label.add_theme_font_override("font", EditorInterface.get_editor_theme().get_font("font", "CodeEdit"));
		label.add_theme_font_size_override("font_size", int(EditorInterface.get_editor_theme().get_font_size("font", "CodeEdit") / 1.2));
	
	return index;

func set_item_icon(idx: int, icon: Texture2D) -> void:
	_setup_if_not_ready();
	var item := _item_dict[idx];
	var tex_rect : TextureRect = item.get_node("VBoxContainer/TextureRect");
	tex_rect.texture = icon;
	pass
