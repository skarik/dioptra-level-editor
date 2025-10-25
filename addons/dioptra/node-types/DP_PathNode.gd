@tool
extends Node3D
class_name DP_PathNode
## Class for building nodes.
##
## Unlike Curve3D, paths entirely use points, which allows for easier path changes.
##
## @experimental: In development

@export var from := Vector3(0, 0, 0):
	set(value):
		from = value;
		update_gizmos();
		editor_update_target_gizmos();
@export var to := Vector3(0, 0, 0):
	set(value):
		to = value;
		update_gizmos();
@export var nextNode : DP_PathNode = null:
	set(value):
		next_remove_from_previous_list()
		nextNode = value;
		next_add_to_previous_list()
		update_gizmos();
var previousNodes : Array[DP_PathNode] = []

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true);
		next_add_to_previous_list()
	pass
	
func _ready() -> void:
	next_add_to_previous_list()
	
func _exit_tree() -> void:
	next_remove_from_previous_list()
	
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		pass
	pass
	
func _notification(what: int) -> void:
	# Update the gizmoes when we move.
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		update_gizmos()
		editor_update_target_gizmos();
		pass

## In editor, will update the gizmos of all nodes that are targeting this one.
func editor_update_target_gizmos() -> void:
	if Engine.is_editor_hint():
		for node in previousNodes:
			# Ensue we're not updating a null node
			if node != null:
				node.update_gizmos();
		
## In editor, returns if any of the previous nodes are valid:
func editor_get_previous_nodes_valid() -> bool:
	if Engine.is_editor_hint():
		for node in previousNodes:
			if node != null:
				return true;
	return false;
		
## If it doesn't exist in the next node's "previous" list, will add self to it. 
func next_add_to_previous_list() -> void:
	if nextNode != null:
		if not nextNode.previousNodes.has(self):
			nextNode.previousNodes.append(self);
		pass

## If exists in next node's "previous" list, will remove self from it.
func next_remove_from_previous_list() -> void:
	if nextNode != null:
		var foundIndex = nextNode.previousNodes.find(self);
		if foundIndex != -1:
			nextNode.previousNodes.remove_at(foundIndex);
		pass
		
## Utility Functions for using DP_PathNodes Below:

## Get the position along the path given parametric input:
func get_position_from_t(t: float) -> Vector3:
	if nextNode != null:
		return lerp(
			self.position + self.to * t,
			nextNode.position + nextNode.from * (1.0 - t),
			t);
	return position;
	
## Get the position along the path given percentage of the motion:
func get_position_from_percent(t_p: float) -> Vector3:
	if nextNode != null:
		# TODO: Convert from t_p to t, based entirely on this node's to and the next node's from:
		var weighted_t : float = t_p;
		return get_position_from_t(weighted_t);
	return position;
	
## Get the direction along the path at the given parametric input, non-normalized:
func get_direction_from_t(t: float) -> Vector3:
	if nextNode != null:
		return (nextNode.position - self.position) + lerp(self.to, nextNode.from, t);
	return Vector3.FORWARD;

## Get the closest parametric value on the segment to the two points.
## The resulting value will be unclamped to test for going beyond the ends of a path.
func get_closest_parametric(world_position : Vector3) -> float:
	# todo: make work with curve
	if nextNode != null:
		var local_point := world_position - self.position;
		# project onto segement
		var dir := get_direction_from_t(0.0);
		var dirlen := dir.length();
		var t := local_point.dot(dir / dirlen) / dirlen;
		return t
	return 0.0;
