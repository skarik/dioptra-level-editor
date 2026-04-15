extends CharacterBody3D

#------------------------------------------------------------------------------#

var _camera : Camera3D = null;
var _model : PlayerTest8ModelObject;
var _model_skeleton : Skeleton3D;
var _model_bone_eye : int;
var _head_ik : Proto_PlayerTestFPS_IKTest;
var _animation_player : AnimationPlayer;

var _model_bone_eye_node : BoneAttachment3D;

#------------------------------------------------------------------------------#

const cTapTime = 0.2;
const cDashTime = 0.14;

const cMaxMoveSpeed = 4.0;
const cMaxSprintSpeed = 7.5;
const cGroundAcceleration = 15.0;
const cGroundFriction = 50.0;

const cDashSpeed = 20.0;
const cJumpImpulse = 5.0;
const cGrindSpeed = 11.0;

const cCameraBaseFOV = 75.0;
const cCameraDashFOV = +10.0;

#------------------------------------------------------------------------------#

## Stores pitch & yaw
var mCameraForwardAngle := Vector2.ZERO;
## Actual forward direction pulled from forward angle
var mCameraForwardDirection := Vector2.ZERO;
## Camera offset of what we're following
var mCameraFollowOffset := Vector3.ZERO;

var mCameraFollowOffsetBlended := Vector3.ZERO;

var mInputVector : Vector2 = Vector2(0, 0);

var mSprintState : FrameVar.AsBool = FrameVar.AsBool.new(false);
var mSprintPressTime : float = 0.0;

var mJumpState : FrameVar.AsBool = FrameVar.AsBool.new(false);
var mJumpNextPhysicsFrame : bool = false;

var mDashing : bool = false;
var mDashingTime : float = 0.0;
var mDashingDirection : Vector2 = Vector2(0, 0);

var cFlatMotionBias : float = 0.015;
var cStairPenetrationBias : float = 0.05;
var cStairMaxHeight : float = 0.4;

# Flattened move speed, motion XZ may actually be less than this due to slopes.
var mFlatMotion : Vector2 = Vector2(0, 0);
var mFullMotion : Vector3 = Vector3(0, 0, 0);
var mFloorNormal : Vector3 = Vector3(0, 1, 0);

var mOnGround : bool = false;

var mWasDashing := bool(false);
var mWasGrinding := bool(false);

var mGrinding : bool = false;
var mGrindingDirection : int = 0;
var mGrindingLastT : float = 0;
var mGrindingNode : DP_PathNode = null;
var mGrindJuiceTimer : float = 0;
var mDisableSpeedLimitUntilGround : bool = false;

var mModelRotationOffset : Quaternion;
var mModelUpdateTimer : float = 0.0;

## Stabilizers for smoothing out motion. Jumps in motion are added to these and then blended out over time.
var mStablizerOffsetCamera := Vector3(0, 0, 0);			## Stabilizer for camera position
var mStablizerOffsetModel := Vector3(0, 0, 0);			## Stabilizer for model position
var mStabilizerRotateCamera := Vector4(0, 0, 0, 0); 	## Stabilizer for camera rotation

#------------------------------------------------------------------------------#

func _ready():
	_camera = $Camera3D as Camera3D;
	_model = $CharacterModel as PlayerTest8ModelObject;
	assert(_camera != null);
	assert(_model != null);
	
	_model_skeleton = $CharacterModel/Skeleton3D as Skeleton3D;
	_model_bone_eye = _model_skeleton.find_bone("guide.eyes");
	
	_head_ik = Proto_PlayerTestFPS_IKTest.new();
	_model_skeleton.add_child(_head_ik);
	#_head_ik.owner = _model_skeleton;
	_animation_player = _model.get_node("AnimationPlayer") as AnimationPlayer;
	_animation_player.mixer_applied.connect(_update_camera); 
	
	_model_bone_eye_node = BoneAttachment3D.new();
	_model_bone_eye_node.bone_idx = _model_bone_eye;
	_model_bone_eye_node.bone_name = "guide.eyes";
	_model_skeleton.add_child(_model_bone_eye_node);
	pass
	
func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseMotion):
		const rotationSpeed = PI / 180.0 * 0.5; #todo: make 0.5 sensitivity value
		mCameraForwardAngle.y -= event.screen_relative.x * rotationSpeed;
		mCameraForwardAngle.x -= event.screen_relative.y * rotationSpeed;
		clampInputs();
	elif (event.is_action("action_sprint")):
		if (event.is_pressed() and not event.is_echo()):
			mSprintState.updateValue(true);
			mSprintPressTime = 0.0;
		elif (event.is_released()):
			mSprintState.updateValue(false);
	elif (event.is_action("action_jump")):
		if (event.is_pressed() and not event.is_echo()):
			mJumpState.updateValue(true);
		elif (event.is_released()):
			mJumpState.updateValue(false);
	return

func queue_remote_free(node : Node) -> void:
	node.queue_free();

func _process(delta: float) -> void:
	# Animations
	_animation_player.play("anim test 2/Idle 1");
	
	# Update animator
	_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;
	#const Framerate = 1.0 / 24.0;
	#mModelUpdateTimer += delta;
	#while (mModelUpdateTimer >= Framerate):
		#animationPlayer.advance(Framerate);
		#mModelUpdateTimer -= Framerate;
	_animation_player.advance(delta);
	
func _update_camera() -> void:
	# Update the forward direction
	mCameraForwardDirection = Vector2.UP.rotated(-mCameraForwardAngle.y);
		
	var forward := Vector3.FORWARD \
		.rotated(Vector3.RIGHT, mCameraForwardAngle.x) \
		.rotated(Vector3.UP, mCameraForwardAngle.y);
		
	# Update where the camera is:
	var eyeTransform := _model_skeleton.get_bone_global_pose(_model_bone_eye);
	#var cameraCenterPosition := _model.transform * eyeTransform * Vector3.ZERO + mStablizerOffsetCamera;
	var cameraCenterPosition := _model.transform * _model_bone_eye_node.transform * Vector3.ZERO + mStablizerOffsetCamera;
	_camera.position = forward * 0.05 + cameraCenterPosition;
	_camera.rotation = Vector3(mCameraForwardAngle.x, mCameraForwardAngle.y, 0);
	
	# Update rotating the head ik
	_head_ik.camera_angle = mCameraForwardAngle;
	
#------------------------------------------------------------------------------#

func clampInputs() -> void:
	mCameraForwardAngle.x = clamp(mCameraForwardAngle.x, deg_to_rad(-100.0), deg_to_rad(100.0));
