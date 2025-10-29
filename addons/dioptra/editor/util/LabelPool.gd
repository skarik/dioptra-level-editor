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
## 

# Singleton definition
static var _Instance : DPULabelPool = null;
## Return current singleton instance of the label pool
static func get_instance() -> DPULabelPool:
	if _Instance == null:
		_Instance = DPULabelPool.new();
	return _Instance;
	
# Options
static var TextFixedSize : bool = true;

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
		_node.visible = false;
		_pool._release_item(self);
	## Updates the given size with the camera
	func update(camera : Camera3D) -> void:
		var pixel_size = 0.005; # Godot default
		if DPULabelPool.TextFixedSize:
			if camera:
				var viewport_size : Vector2 = camera.get_viewport().get_visible_rect().size;
				var keep_height : bool = camera.keep_aspect == Camera3D.KEEP_HEIGHT;
				var aspect_ratio : float = 1.0 / (viewport_size.y if keep_height else viewport_size.x);
				var fov : float = camera.fov if camera.projection == Camera3D.PROJECTION_PERSPECTIVE else 90.0;
				pixel_size = atan(rad_to_deg(fov) * 0.5) * aspect_ratio; # rad_to_deg is not in the original source.
				## TODO: test if rad_to_deg is correct?
			pass
		_node.pixel_size = pixel_size;

var _used_labels : Array[LabelNodeItem];
var _unused_labels : Array[LabelNodeItem];
var _last_camera : Camera3D = null;

func _init() -> void:
	pass
	
## Get a brand new label to draw the given text with
static func get_label(camera : Camera3D) -> LabelNodeItem:
	return _Instance._get_label(camera);

# Gets an item for use
func _get_label(camera : Camera3D) -> LabelNodeItem:
	## TODO: implement
	return null;
	
# Put the item back into the unused labels
func _release_item(item : LabelNodeItem) -> void:
	_used_labels.erase(item);
	_unused_labels.append(item);
	pass

# Updates
func _process(delta: float) -> void:
	## TODO: Implement updating all items with the current camera
	pass
