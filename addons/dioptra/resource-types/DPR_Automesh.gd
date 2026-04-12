class_name DPR_Automesh
extends Resource

## The shapes/meshes we have defined
enum Shape {
	STRAIGHT = 0,
	CAP,
	CORNER,
	TEE,
	CROSS,
	CORNER_UP,
	TEE_UP,
	CROSS_UP,
	CROSS_UP_DOWN,
	
	COUNT
};

## Meshes defined
@export var meshes : Array[Mesh] = [];
## Offsets defined
@export var offset_positions : Array[Vector3] = [];
@export var offset_rotations : Array[Vector3] = [];

# todo: make a plugin
# https://docs.godotengine.org/en/stable/tutorials/plugins/editor/inspector_plugins.html#setting-up-your-plugin
# https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html#creating-your-own-resources
