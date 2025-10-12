extends CharacterBody3D

const cTapTime = 0.2;
const cDashTime = 0.14;

const cMaxMoveSpeed = 4.0;
const cMaxSprintSpeed = 7.5;
const cGroundAcceleration = 15.0;
const cGroundFriction = 50.0;

const cDashSpeed = 20.0;
const cJumpImpulse = 5.0;

const cCameraBaseFOV = 75.0;
const cCameraDashFOV = +10.0;

var mCamera : Camera3D;
# Stores pitch & yaw
var mForwardAngle : Vector2 = Vector2(0, 0);
# Actual forward direction pulled from forward angle
var mForwardDirection : Vector2 = Vector2(0, 0);

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

var mModelNode : PlayerTest8ModelObject;
var mModelRotationOffset : Quaternion;

var mStablizerOffsetCamera : Vector3 = Vector3(0, 0, 0);
var mStablizerOffsetModel : Vector3 = Vector3(0, 0, 0);

@export
var mAssetJuice : PackedScene;

func clampInputs():
	mForwardAngle.x = clamp(mForwardAngle.x, deg_to_rad(-100.0), deg_to_rad(100.0));

func _ready():
	mCamera = get_node("Camera3D") as Camera3D;
	mModelNode = get_node("alana lowpoly") as PlayerTest8ModelObject;
	assert(mCamera != null);
	assert(mModelNode != null);
	
	mModelRotationOffset = mModelNode.quaternion;
	return

func _unhandled_input(event: InputEvent):
	if (event is InputEventMouseMotion):
		const rotationSpeed = PI / 180.0 * 0.5; #todo: make 0.5 sensitivity value
		mForwardAngle.y -= event.screen_relative.x * rotationSpeed;
		mForwardAngle.x -= event.screen_relative.y * rotationSpeed;
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

func _process(delta: float):
	# Update the forward direction
	mForwardDirection = Vector2.UP.rotated(-mForwardAngle.y);
	
	var forward = Vector3.FORWARD \
		.rotated(Vector3.RIGHT, mForwardAngle.x) \
		.rotated(Vector3.UP, mForwardAngle.y);
	
	mCamera.position = -forward * 4 + Vector3(0, 1, 0) + mStablizerOffsetCamera;
	mCamera.rotation = Vector3(mForwardAngle.x, mForwardAngle.y, 0);
	
	mCamera.fov = cCameraBaseFOV;
	if (mDashing):
		mCamera.fov += cCameraDashFOV;
	
	# Update the motion logic
	mSprintState.updateProcess();
	if (mSprintState.was_disabled()):
		print("released at %f vs %f" % [mSprintPressTime, cTapTime]);
		
		if (mSprintPressTime < cTapTime):
			mDashing = true;
			mDashingTime = 0.0;
			mDashingDirection = (mInputVector + Vector2(0, -0.001)).rotated(-mForwardAngle.y).normalized();
			
			var juiceNode : Node3D = mAssetJuice.instantiate()
			juiceNode.position = position
			juiceNode.rotation = Vector3(0, mForwardAngle.y + (-mDashingDirection).angle_to(Vector2.RIGHT), 0);
			get_parent().add_child(juiceNode) # probably bad
			
	elif (mSprintState.is_enabled()):
		mSprintPressTime += delta;
		
	# Update the jump logic
	mJumpState.updateProcess();
	if (mJumpState.was_enabled()):
		print("jump pressed");
		mJumpNextPhysicsFrame = true;
		
	# Update the model
	# Rotation is going to be from the mFlatMotion
	if (mFlatMotion.length_squared() > 0.01):
		mModelNode.rotation = Vector3(0, mFlatMotion.angle_to(Vector2.UP), 0);
		mModelNode.quaternion *= mModelRotationOffset;
	mModelNode.position = mStablizerOffsetModel;
	
	# Smooth out offsets:
	var smoothWeight0 = 1.0 - exp(-8.0 * delta);
	var smoothWeight1 = 1.0 - exp(-16.0 * delta);
	mStablizerOffsetCamera = mStablizerOffsetCamera.lerp(Vector3.ZERO, smoothWeight0);
	mStablizerOffsetModel = mStablizerOffsetModel.lerp(Vector3.ZERO, smoothWeight1);
	
	return
	
func _physics_process(delta: float):
	# Get motion input impulse from the input & camera angle
	mInputVector = Vector2(
		Input.get_axis("move_left", "move_right"),
		-Input.get_axis("move_back", "move_forward"));
	var rotatedInputVector : Vector2 = mInputVector.rotated(-mForwardAngle.y);
	
	#var floorX : Vector3 = Vector3(1, 0, 0);
	#var floorZ : Vector3 = floorX.cross(mFloorNormal);
	#floorX = floorZ.cross(mFloorNormal);
	#var floorTransform :  = Transform3D(floorX, mFloorNormal, floorZ);
	
	# Extract flat motion from velocity
	mFullMotion = self.velocity;
	mFlatMotion = Vector2(mFullMotion.x, mFullMotion.z);
	
	# Apply next motion
	var possibleNextMotion : Vector2 = mFlatMotion;
	var possibleMaxSpeed : float = cMaxMoveSpeed;
	if (mSprintState.is_enabled()):
		possibleMaxSpeed = cMaxSprintSpeed;
	
	if (not mDashing):
		# Calculate both motion accel and friction accel
		var targetDelta : Vector2 = (rotatedInputVector * possibleMaxSpeed) - mFlatMotion;
		var targetDeltaLength : float = targetDelta.length();
		var targetDeltaNormalized : Vector2 = targetDelta / max(0.0001, targetDeltaLength);
		var possibleNextMotionAccel : Vector2 = mFlatMotion + targetDeltaNormalized * min(targetDeltaLength, cGroundAcceleration * delta);
		var possibleNextMotionFrict : Vector2 = mFlatMotion + targetDeltaNormalized * min(targetDeltaLength, cGroundFriction * delta);
		
		# Apply friction if the friction is closer to stopping, or the friction is in a different direction than the acceleration
		possibleNextMotion = possibleNextMotionAccel;
		var isBrakingFaster : bool     = possibleNextMotionFrict.length_squared() < possibleNextMotionAccel.length_squared();
		var isChangingDirection : bool = possibleNextMotionFrict.dot(possibleNextMotionAccel) < 0.0;
		
		if (isBrakingFaster or isChangingDirection):
			possibleNextMotion = possibleNextMotionFrict;
			if isChangingDirection:
				var juiceNode : Node3D = mAssetJuice.instantiate()
				juiceNode.position = position
				juiceNode.rotation = Vector3(0, mFlatMotion.angle_to(Vector2.RIGHT), 0);
				get_parent().add_child(juiceNode) # probably bad
			
	elif (mDashing):
		# We dash:
		possibleNextMotion = mDashingDirection * lerp(cDashSpeed, (cMaxMoveSpeed + cDashSpeed) * 0.5, mDashingTime / cDashTime);
		# State tracking for the dash:
		mDashingTime += delta;
		if (mDashingTime > cDashTime):
			mDashing = false;
			
	# Use the chosen motion!
	mFlatMotion = possibleNextMotion;
	
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
		
	if not lHasGround:
		# Recombine the "flat" motion with the 3D motion
		mFullMotion.y = self.velocity.y;
		# Do gravity
		mFullMotion += self.get_gravity() * delta;
	else:
		# Stop vertical motion
		mFullMotion.y = 0;
	
	# Do jumping logic
	if mJumpNextPhysicsFrame:
		mJumpNextPhysicsFrame = false;
		mFullMotion.y = cJumpImpulse;
	pass
	
	# Do motion checks now
	self.position = lPositionStart;
	self.velocity = mFullMotion;
	move_and_slide();
	
	# Read back resulting motion
	mFullMotion = self.velocity;
	
	if lHasGround:
		print("vertical speed %f" % mFullMotion.y);
	
	return
