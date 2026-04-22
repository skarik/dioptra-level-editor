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

var input_tap_time : float = 0.2;

@export var motion_settings : GMCharacterMotionSettings = GMCharacterMotionSettings.new();

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

func _ready() -> void:
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
	#_animation_player.mixer_applied.connect(_update_camera); 
	
	_model_bone_eye_node = BoneAttachment3D.new();
	_model_bone_eye_node.bone_idx = _model_bone_eye;
	_model_bone_eye_node.bone_name = "guide.eyes";
	_model_skeleton.add_child(_model_bone_eye_node);
	pass
	
func clampInputs() -> void:
	mCameraForwardAngle.x = clamp(mCameraForwardAngle.x, deg_to_rad(-100.0), deg_to_rad(100.0));

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

func _process(delta: float) -> void:
	_process_animation(delta);
	_process_camera();
	_process_stabilizer(delta);
	_process_input(delta);
	pass
	
func _physics_process(delta: float) -> void:
	_physics_process_input_motion(delta);
	_physics_process_motion_collision(delta);
		
	pass

#------------------------------------------------------------------------------#

func queue_remote_free(node : Node) -> void:
	node.queue_free();
	
#------------------------------------------------------------------------------#
	
func _process_camera() -> void:
	# Update the forward direction
	mCameraForwardDirection = Vector2.UP.rotated(-mCameraForwardAngle.y);
		
	var forward := Vector3.FORWARD \
		.rotated(Vector3.RIGHT, mCameraForwardAngle.x) \
		.rotated(Vector3.UP, mCameraForwardAngle.y);
		
	# Update where the camera is:
	#var eyeTransform := _model_skeleton.get_bone_global_pose(_model_bone_eye);
	#var cameraCenterPosition := _model.transform * eyeTransform * Vector3.ZERO + mStablizerOffsetCamera;
	var cameraCenterPosition := _model.transform * _model_bone_eye_node.transform * Vector3.ZERO + mStablizerOffsetCamera;
	_camera.position = forward * 0.05 + cameraCenterPosition;
	_camera.rotation = Vector3(mCameraForwardAngle.x, mCameraForwardAngle.y, 0);
	
	# Update rotating the head ik
	_head_ik.camera_angle = mCameraForwardAngle;
	
func _process_stabilizer(delta: float) -> void:
	# Smooth out offsets:
	var smoothWeight0 := 1.0 - exp(-8.0 * delta);
	var smoothWeight1 := 1.0 - exp(-16.0 * delta);
	var smoothWeight2 := 1.0 - exp(-40.0 * delta);
	mStablizerOffsetCamera = mStablizerOffsetCamera.lerp(Vector3.ZERO, smoothWeight0);
	mStablizerOffsetModel = mStablizerOffsetModel.lerp(Vector3.ZERO, smoothWeight1);
	mStabilizerRotateCamera = mStabilizerRotateCamera.lerp(Vector4.ZERO, smoothWeight2);
	
	
func _process_animation(delta: float) -> void:
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
	pass
	
func _process_input(delta: float) -> void:
	# Update the jump logic
	mJumpState.updateProcess();
	if (mJumpState.was_enabled()):
		print("jump pressed");
		mJumpNextPhysicsFrame = true;
	
#------------------------------------------------------------------------------#

func _physics_process_input_motion(delta : float) -> void:
	# Get motion input impulse from the input & camera angle
	mInputVector = Vector2(
		Input.get_axis("move_left", "move_right"),
		-Input.get_axis("move_back", "move_forward")).normalized();
	var rotatedInputVector : Vector2 = mInputVector.rotated(-mCameraForwardAngle.y);
	
	# Extract flat motion from velocity
	mFullMotion = self.velocity;
	mFlatMotion = Vector2(mFullMotion.x, mFullMotion.z);
	
	# Apply next motion
	var possibleNextMotion : Vector2 = mFlatMotion;
	var possibleMaxSpeed : float = motion_settings.max_ground_walk_speed;
	if (mSprintState.is_enabled()):
		possibleMaxSpeed = motion_settings.max_ground_sprint_speed;
	if (mDisableSpeedLimitUntilGround):
		possibleMaxSpeed = max(possibleMaxSpeed, motion_settings.grind_speed);
		
	if (not mDashing):
		# Calculate both motion accel and friction accel
		var targetDelta : Vector2 = (rotatedInputVector * possibleMaxSpeed) - mFlatMotion;
		var targetDeltaLength : float = targetDelta.length();
		var targetDeltaNormalized : Vector2 = targetDelta / max(0.0001, targetDeltaLength);
		var possibleNextMotionAccel : Vector2 = mFlatMotion + targetDeltaNormalized * min(targetDeltaLength, motion_settings.ground_acceleration * delta);
		var possibleNextMotionFrict : Vector2 = mFlatMotion + targetDeltaNormalized * min(targetDeltaLength, motion_settings.ground_friction * delta);
		
		# Apply friction if the friction is closer to stopping, or the friction is in a different direction than the acceleration
		possibleNextMotion = possibleNextMotionAccel;
		var isBrakingFaster : bool     = possibleNextMotionFrict.length_squared() < possibleNextMotionAccel.length_squared();
		var isChangingDirection : bool = possibleNextMotionFrict.dot(possibleNextMotionAccel) < 0.0;
		
		if (isBrakingFaster or isChangingDirection):
			possibleNextMotion = possibleNextMotionFrict;
			#if isChangingDirection:
				#var juiceNode : Node3D = mAssetJuice.instantiate()
				#juiceNode.position = position
				#juiceNode.rotation = Vector3(0, mFlatMotion.angle_to(Vector2.RIGHT), 0);
				#get_parent().add_child(juiceNode) # probably bad
			
	elif (mDashing):
		# We dash:
		possibleNextMotion = mDashingDirection * lerp(
			motion_settings.dash_speed,
			(motion_settings.max_ground_walk_speed + motion_settings.dash_speed) * 0.5, 
			mDashingTime / motion_settings.dash_time);
		# State tracking for the dash:
		mDashingTime += delta;
		if (mDashingTime > motion_settings.dash_time):
			mDashing = false;
			
	# Use the chosen motion!
	mFlatMotion = possibleNextMotion;
	
func _physics_process_motion_collision(delta : float) -> void:
	# Collision Steps:
	# 1. Do stair checks in the given "flat" motion
	#    1b. Generate Z offset
	# 2. Recombine w/ motion and move & collide normal
	
	var lHasGround : bool = false;
	var lPositionStart : Vector3 = self.position;
	
	# Stair check
	# Set up "flat" motion:
	mFullMotion = Vector3(mFlatMotion.x, 0, mFlatMotion.y);
	# Move with contact:
	self.position = lPositionStart;
	var lCollisionStair0 :  KinematicCollision3D;
	lCollisionStair0 = move_and_collide(mFullMotion * delta, true);
	if (lCollisionStair0 and lCollisionStair0.get_collision_count() > 0):
		self.position = lPositionStart \
			# Move to contact position
			+ lCollisionStair0.get_travel() \
			# Move a bit into the stair
			+ lCollisionStair0.get_travel().normalized() * min(cStairPenetrationBias, lCollisionStair0.get_remainder().length()) \
			# Start above the max stair height
			+ mFloorNormal * (cStairMaxHeight + cFlatMotionBias);
		# Cast downward
		var lCollisionStair1 : KinematicCollision3D; 
		lCollisionStair1 = move_and_collide(-mFloorNormal * cStairMaxHeight, true);
		# We have a stair!
		if (lCollisionStair1 and lCollisionStair1.get_collision_count() > 0):
			# Was there any space to move?
			if (lCollisionStair1.get_travel().length_squared() > 0):
				# Pull the starting position upwards
				var lStairHeight : float = cStairMaxHeight - lCollisionStair1.get_travel().length();
				print("stair height %f" % [lStairHeight]);
				lPositionStart += mFloorNormal * max(0, lStairHeight + cFlatMotionBias);
				# Mark we have ground so we can get our slide onto the stair:
				lHasGround = true;
				
				# Add offset
				mStablizerOffsetCamera -= mFloorNormal * max(0, lStairHeight + cFlatMotionBias);
				mStablizerOffsetModel -= mFloorNormal * max(0, lStairHeight + cFlatMotionBias);
			pass
		pass
	# TODO: Move with contact down stairs when on the ground (ground "glue")
		
	if not lHasGround:
		# Recombine the "flat" motion with the 3D motion
		mFullMotion.y = self.velocity.y;
		# Do gravity
		mFullMotion += self.get_gravity() * delta;
	else:
		# Stop vertical motion
		mFullMotion.y = 0;
	
	# Reset position
	self.position = lPositionStart;

	# Update ground check
	var lCollisionFloor0 : KinematicCollision3D;
	lCollisionFloor0 = move_and_collide(-mFloorNormal * cFlatMotionBias * 2.0, true);
	if (lCollisionFloor0 and lCollisionFloor0.get_collision_count() > 0):
		mOnGround = true;
	else:
		mOnGround = false;
	
	if mOnGround:
		mDisableSpeedLimitUntilGround = false;
		
	# Do grinding
	#physicsProcessGrindPaths(delta);
	
	# Do jumping logic
	if mJumpNextPhysicsFrame:
		mJumpNextPhysicsFrame = false;
		if mOnGround:
			mFullMotion.y = motion_settings.jump_velocity;
		pass
	
	# Do motion checks now
	self.velocity = mFullMotion;
	move_and_slide();
	
	# Read back resulting motion
	mFullMotion = self.velocity;
	
	if lHasGround:
		print("vertical speed %f" % mFullMotion.y);
	pass
