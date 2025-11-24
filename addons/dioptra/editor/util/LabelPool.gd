@tool
extends Node
class_name DPULabelPool
## Label pool vaguely based off of "Debug Draw 3D" but with a focus on usage with gizmos.
##
## Usage is the following: [br]
##   - Create labels with [code]DPULabelPool.get_label(...)[/code] and hold onto them [br]
##   - Update the internal node directly [br]
##   - Release the labels with the [code]label.release()[/code] [br]
##   - And that's it! [br]
## Do NOT use this during gameplay. This is explicitly for the editor.
## 

#------------------------------------------------------------------------------#

# Singleton definition
static var _Instance : DPULabelPool = null;
## Return current singleton instance of the label pool
static func get_instance() -> DPULabelPool:
	if _Instance == null:
		# Create the new node
		_Instance = DPULabelPool.new();
		# We need this node in the scene so it can update the sizes of items
		EditorInterface.get_edited_scene_root().add_child(_Instance, false, Node.INTERNAL_MODE_FRONT);
	return _Instance;
static func free_instance() -> void:
	if _Instance != null:
		_Instance.queue_free();
	_Instance = null;
	
# Options
static var TextFixedSize : bool = true;
static var UseCodeFont : bool = true;

#------------------------------------------------------------------------------#

## Item in the node pool with utilities of memory management
class LabelNodeItem:
	var _pool : DPULabelPool;
	var _node : Label3D;
	
	func _init(pool : DPULabelPool, node : Label3D):
		_pool = pool;
		_node = node;
		
	## Get the underlying Label3D node
	func get_node() -> Label3D:
		return _node;
	## Releases the given node back to the pool
	func release() -> void:
		_node.set_visible(false);
		_pool._release_item(self);
	## Updates the given size with the camera
	func process(camera : Camera3D) -> void:
		var pixel_size = 0.005; # Godot default
		if DPULabelPool.TextFixedSize:
			if camera:
				var viewport_size : Vector2 = camera.get_viewport().get_visible_rect().size;
				var keep_height : bool = camera.keep_aspect == Camera3D.KEEP_HEIGHT;
				var aspect_ratio : float = 1.0 / (viewport_size.y if keep_height else viewport_size.x);
				var fov : float = camera.fov if (camera.projection == Camera3D.PROJECTION_PERSPECTIVE) else 90.0;
				pixel_size = tan(deg_to_rad(fov) * 0.5) * aspect_ratio * 2.0; # rad_to_deg is not in the original source.
			pass
		_node.pixel_size = pixel_size;
		_node.fixed_size = DPULabelPool.TextFixedSize;

#------------------------------------------------------------------------------#

var _used_labels : Array[LabelNodeItem];
var _unused_labels : Array[LabelNodeItem];
var _last_camera : Camera3D = null;
var _editor_font : Font = null;
var _editor_font_size : int = 15;

#------------------------------------------------------------------------------#

func _init() -> void:
	_used_labels = [];
	_unused_labels = [];
	
	if UseCodeFont:
		_editor_font = EditorInterface.get_editor_theme().get_font("font", "CodeEdit");
		_editor_font_size = EditorInterface.get_editor_theme().get_font_size("font", "CodeEdit");
	else:
		_editor_font = EditorInterface.get_editor_theme().get_font("main_msdf", "EditorFonts");
		_editor_font_size = EditorInterface.get_editor_theme().default_font_size;
	
	# Check what fonts/colors are available in the editor theme:
	#print("Fonts:");
	#for type in EditorInterface.get_editor_theme().get_font_type_list():
		#print(type);
		#for name in EditorInterface.get_editor_theme().get_font_list(type):
			#print("  - %s" % name);
	#print("Colors:");
	#for type in EditorInterface.get_editor_theme().get_color_type_list():
		#print(type);
		#for name in EditorInterface.get_editor_theme().get_color_list(type):
			#print("-%s" % name);
	#print("Item Variations:");
	#for type in EditorInterface.get_editor_theme().get_type_list():
		#print(type);
		#for name in EditorInterface.get_editor_theme().get_type_variation_list(type):
			#print("-%s" % name);
	#print("Theme info:");
	#for type in EditorInterface.get_editor_theme().get_theme_item_type_list(Theme.DATA_TYPE_STYLEBOX):
		#print(type);
		#for name in EditorInterface.get_editor_theme().get_theme_item_list(Theme.DATA_TYPE_STYLEBOX, type):
			#print("-%s" % name);
	pass

func _exit_tree() -> void:
	# Clean up all the nodes
	for item in _used_labels:
		item.get_node().queue_free();
		#item.free();
	_used_labels.clear();
	for item in _unused_labels:
		item.get_node().queue_free();
		#item.free();
	_unused_labels.clear();
	
## Get a brand new label to draw the given text with
static func get_label(camera : Camera3D) -> LabelNodeItem:
	return get_instance()._get_label(camera);

# Gets an item for use
func _get_label(camera : Camera3D) -> LabelNodeItem:
	_last_camera = camera;
	## TODO: implement
	
	if _unused_labels.is_empty():
		# Create a new label:
		var lbl := _create_label3d(camera);
		var item := LabelNodeItem.new(self, lbl);
		_unused_labels.append(item);
	
	# Grab unused item & add to the used
	var item := _unused_labels.pop_back();
	_used_labels.push_back(item);

	# Let it be used now
	var lbl : Label3D = item.get_node()
	lbl.set_visible(true);
	lbl.set_font(_editor_font); 
	lbl.set_font_size(_editor_font_size);
	lbl.render_priority = 0;
	
	return item;
	
# Creates a new label in the current editor scene
static func _create_label3d(camera : Camera3D) -> Label3D:
	var lbl : Label3D = Label3D.new();
	#lbl.layers = TODO
	lbl.set_visible(false);
	lbl.set_draw_flag(Label3D.FLAG_DISABLE_DEPTH_TEST, true);
	lbl.set_billboard_mode(BaseMaterial3D.BILLBOARD_ENABLED);
	lbl.set_texture_filter(BaseMaterial3D.TEXTURE_FILTER_NEAREST); # disable filtering for non-SDF
	EditorInterface.get_edited_scene_root().add_child(lbl, false, Node.INTERNAL_MODE_BACK);
	return lbl;
	
# Put the item back into the unused labels
func _release_item(item : LabelNodeItem) -> void:
	_used_labels.erase(item);
	_unused_labels.append(item);
	pass

# Updates
func _process(delta: float) -> void:
	## TODO: Implement updating all items with the current camera
	for item in _used_labels:
		if item.get_node() == null:
			_used_labels.erase(item);
		else:
			item.process(_last_camera);
	pass
