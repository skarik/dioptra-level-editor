extends SkeletonModifier3D
class_name Proto_PlayerTestFPS_IKTest

var camera_angle : Vector2;

var _model_bone_neck : int;
var _model_bone_head : int;

# todo: update to _process_modification_with_delta
func _process_modification() -> void:
	var skeleton := get_skeleton();

	#var forward := Vector3.FORWARD \
		#.rotated(Vector3.RIGHT, mCameraForwardAngle.x) \
		#.rotated(Vector3.UP, mCameraForwardAngle.y);
		
	#var headTransform := _model_skeleton.get_bone_pose(_model_bone_head);
	#headTransform = headTransform.rotated(Vector3.RIGHT, mCameraForwardAngle.x);
	#_model_skeleton.set_bone_pose(_model_bone_head, headTransform);
	
	_model_bone_neck = skeleton.find_bone("neck");
	_model_bone_head = skeleton.find_bone("head");

	var headTransform := skeleton.get_bone_pose(_model_bone_head);
	headTransform = headTransform.rotated(Vector3.RIGHT, camera_angle.x);
	headTransform = headTransform.rotated(Vector3.UP, camera_angle.y);
	skeleton.set_bone_pose(_model_bone_head, headTransform);

	pass
