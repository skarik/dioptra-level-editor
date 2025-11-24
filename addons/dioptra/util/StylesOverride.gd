@tool
extends Control

@export_custom(PROPERTY_HINT_DICTIONARY_TYPE, "String;String")
var colors : Dictionary = {};

func _ready() -> void:
	for item in colors:
		var color_name = colors[item];
		if item is String and color_name is String: 
			var color : Color = EditorInterface.get_editor_theme().get_color(color_name, "Editor");
			self.add_theme_color_override(item, color);
